<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\AdminLoginRequest;
use App\Http\Requests\Auth\ChangePasswordRequest;
use App\Http\Requests\Auth\ForgotPasswordRequest;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\ResendOtpRequest;
use App\Http\Requests\Auth\ResetPasswordRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Http\Requests\Auth\VerifyOtpRequest;
use App\Http\Resources\UserResource;
use App\Models\ActivityLog;
use App\Models\AuthOtp;
use App\Models\User;
use App\Services\ActivityLogger;
use App\Services\OtpService;
use App\Services\TokenService;
use App\Support\ApiResponse;
use App\Support\Msg;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;

class AuthController extends Controller
{
    public function __construct(
        private readonly OtpService $otp,
        private readonly TokenService $tokens,
        private readonly ActivityLogger $activity,
    ) {
    }

    /**
     * POST /auth/register
     *
     * Creates an UNVERIFIED account and sends an OTP. No access or refresh
     * token is issued here on purpose: the client must verify the phone first.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = DB::transaction(function () use ($data) {
            $user = User::create([
                'name' => $data['name'],
                'phone_number' => $data['phone_number'],
                'password' => $data['password'],
                'location_id' => $data['location_id'] ?? null,
                'role' => User::ROLE_USER,
                'is_active' => true,
                'phone_verified_at' => null,
            ]);

            $this->otp->send($user->phone_number, AuthOtp::PURPOSE_REGISTRATION, $user);

            return $user;
        });

        return ApiResponse::created([
            'requires_verification' => true,
            'phone_number' => $user->phone_number,
        ], Msg::REGISTERED);
    }

    /**
     * POST /auth/verify-otp
     *
     * Confirms the phone number of a freshly registered account. This is the
     * point where tokens are issued and the client may store them.
     */
    public function verifyOtp(VerifyOtpRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = User::where('phone_number', $data['phone_number'])->first();

        if ($user === null) {
            return ApiResponse::fail(Msg::OTP_NOT_FOUND, 404);
        }

        if ($user->hasVerifiedPhone()) {
            return ApiResponse::fail(Msg::PHONE_ALREADY_VERIFIED, 409);
        }

        $result = $this->otp->verify(
            $data['phone_number'],
            AuthOtp::PURPOSE_REGISTRATION,
            $data['code'],
        );

        if ($result !== OtpService::RESULT_OK) {
            return ApiResponse::fail($this->otp->messageFor($result), 422, [
                'code' => [$this->otp->messageFor($result)],
            ]);
        }

        $user->forceFill(['phone_verified_at' => Carbon::now()])->save();

        $this->activity->log(
            ActivityLog::TYPE_USER,
            Msg::activityUserRegistered($user->name),
            $user->id,
            $user,
        );

        $tokens = $this->tokens->issue($user, $request);

        return ApiResponse::ok([
            'access_token' => $tokens['access_token'],
            'refresh_token' => $tokens['refresh_token'],
            'user' => (new UserResource($this->withCounts($user)))->resolve(),
        ], Msg::VERIFIED);
    }

    /** POST /auth/resend-otp */
    public function resendOtp(ResendOtpRequest $request): JsonResponse
    {
        $phone = $request->validated('phone_number');
        $user = User::where('phone_number', $phone)->first();

        $purpose = $user !== null && ! $user->hasVerifiedPhone()
            ? AuthOtp::PURPOSE_REGISTRATION
            : AuthOtp::PURPOSE_PASSWORD_RESET;

        $result = $this->otp->send($phone, $purpose, $user);

        if ($result['cooldown']) {
            return ApiResponse::fail(Msg::OTP_COOLDOWN, 429);
        }

        return ApiResponse::action(Msg::OTP_SENT);
    }

    /** POST /auth/login - normal users (role 0). */
    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = User::where('phone_number', $data['phone_number'])->first();

        if ($user === null || ! Hash::check($data['password'], $user->password)) {
            return ApiResponse::fail(Msg::INVALID_CREDENTIALS, 401);
        }

        if (! $user->is_active) {
            return ApiResponse::fail(Msg::ACCOUNT_BLOCKED, 403);
        }

        if (! $user->hasVerifiedPhone()) {
            return ApiResponse::fail(Msg::PHONE_NOT_VERIFIED, 403, [
                'phone_number' => [Msg::PHONE_NOT_VERIFIED],
            ]);
        }

        $tokens = $this->tokens->issue($user, $request);

        return ApiResponse::ok([
            'access_token' => $tokens['access_token'],
            'refresh_token' => $tokens['refresh_token'],
            'user' => (new UserResource($this->withCounts($user)))->resolve(),
        ], Msg::LOGGED_IN);
    }

    /**
     * POST /auth/admin/login
     *
     * `username` accepts either a phone number or an email address. Only
     * roles 1 and 2 may authenticate here - the Flutter admin screen is never
     * treated as proof of anything.
     */
    public function adminLogin(AdminLoginRequest $request): JsonResponse
    {
        $data = $request->validated();
        $username = $data['username'];

        $user = User::where('phone_number', $username)
            ->orWhere('email', $username)
            ->first();

        if ($user === null || ! Hash::check($data['password'], $user->password)) {
            return ApiResponse::fail(Msg::INVALID_ADMIN_CREDENTIALS, 401);
        }

        if (! $user->isAdmin()) {
            return ApiResponse::fail(Msg::NOT_ADMIN, 403);
        }

        if (! $user->is_active) {
            return ApiResponse::fail(Msg::ACCOUNT_BLOCKED, 403);
        }

        $tokens = $this->tokens->issue($user, $request);

        return ApiResponse::ok([
            'access_token' => $tokens['access_token'],
            'refresh_token' => $tokens['refresh_token'],
            'user' => (new UserResource($this->withCounts($user)))->resolve(),
        ], Msg::LOGGED_IN);
    }

    /**
     * POST /auth/refresh
     *
     * Rotates the refresh token: the presented one is revoked immediately.
     */
    public function refresh(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'refresh_token' => ['required', 'string'],
        ]);

        $tokens = $this->tokens->rotate($validated['refresh_token'], $request);

        if ($tokens === null) {
            return ApiResponse::fail(Msg::REFRESH_INVALID, 401);
        }

        return ApiResponse::ok($tokens, Msg::REFRESHED);
    }

    /** POST /auth/logout */
    public function logout(Request $request): JsonResponse
    {
        $user = $request->user();
        $token = $user->currentAccessToken();

        // A TransientToken (session guard, or actingAs() in a test) has no row
        // to revoke, so only a real personal access token is touched here.
        if ($token instanceof PersonalAccessToken) {
            $this->tokens->revokeForAccessToken($user, $token->getKey());
            $token->delete();
        }

        return ApiResponse::action(Msg::LOGGED_OUT);
    }

    /** GET /auth/me */
    public function me(Request $request): JsonResponse
    {
        return ApiResponse::ok(
            new UserResource($this->withCounts($request->user())),
            Msg::FETCHED,
        );
    }

    /** PUT /auth/profile - name and/or account location. */
    public function updateProfile(UpdateProfileRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->validated();

        $user->fill(array_filter([
            'name' => $data['name'] ?? null,
            'location_id' => $data['location_id'] ?? null,
        ], static fn ($v) => $v !== null))->save();

        return ApiResponse::ok(
            new UserResource($this->withCounts($user->fresh())),
            Msg::PROFILE_UPDATED,
        );
    }

    /** POST /auth/forgot-password */
    public function forgotPassword(ForgotPasswordRequest $request): JsonResponse
    {
        $phone = $request->validated('phone_number');
        $user = User::where('phone_number', $phone)->first();

        $result = $this->otp->send($phone, AuthOtp::PURPOSE_PASSWORD_RESET, $user);

        if ($result['cooldown']) {
            return ApiResponse::fail(Msg::OTP_COOLDOWN, 429);
        }

        return ApiResponse::action(Msg::OTP_SENT);
    }

    /** PUT /auth/reset-password */
    public function resetPassword(ResetPasswordRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = User::where('phone_number', $data['phone_number'])->first();

        if ($user === null) {
            return ApiResponse::fail(Msg::OTP_NOT_FOUND, 404);
        }

        $result = $this->otp->verify(
            $data['phone_number'],
            AuthOtp::PURPOSE_PASSWORD_RESET,
            $data['code'],
        );

        if ($result !== OtpService::RESULT_OK) {
            return ApiResponse::fail($this->otp->messageFor($result), 422, [
                'code' => [$this->otp->messageFor($result)],
            ]);
        }

        DB::transaction(function () use ($user, $data) {
            $user->forceFill([
                'password' => Hash::make($data['new_password']),
                // Recovering the password also proves ownership of the number.
                'phone_verified_at' => $user->phone_verified_at ?? Carbon::now(),
            ])->save();

            // Every existing session is invalidated after a password reset.
            $this->tokens->revokeAll($user);
        });

        return ApiResponse::action(Msg::PASSWORD_CHANGED);
    }

    /** POST /auth/change-password/request-otp - authenticated. */
    public function requestChangePasswordOtp(Request $request): JsonResponse
    {
        $user = $request->user();

        $result = $this->otp->send(
            $user->phone_number,
            AuthOtp::PURPOSE_PASSWORD_CHANGE,
            $user,
        );

        if ($result['cooldown']) {
            return ApiResponse::fail(Msg::OTP_COOLDOWN, 429);
        }

        return ApiResponse::action(Msg::OTP_SENT);
    }

    /**
     * PUT /auth/change-password
     *
     * The primary flow is OTP based. `current_password` is still accepted for
     * backward compatibility with the older settings screen.
     */
    public function changePassword(ChangePasswordRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->validated();

        if (! empty($data['code'])) {
            $result = $this->otp->verify(
                $user->phone_number,
                AuthOtp::PURPOSE_PASSWORD_CHANGE,
                $data['code'],
            );

            if ($result !== OtpService::RESULT_OK) {
                return ApiResponse::fail($this->otp->messageFor($result), 422, [
                    'code' => [$this->otp->messageFor($result)],
                ]);
            }
        } elseif (! empty($data['current_password'])) {
            if (! Hash::check($data['current_password'], $user->password)) {
                return ApiResponse::fail(Msg::CURRENT_PASSWORD_WRONG, 422, [
                    'current_password' => [Msg::CURRENT_PASSWORD_WRONG],
                ]);
            }
        } else {
            return ApiResponse::fail(Msg::VALIDATION, 422, [
                'code' => [Msg::OTP_NOT_FOUND],
            ]);
        }

        $token = $user->currentAccessToken();
        $currentTokenId = $token instanceof PersonalAccessToken ? $token->getKey() : null;

        DB::transaction(function () use ($user, $data, $currentTokenId) {
            $user->forceFill(['password' => Hash::make($data['new_password'])])->save();
            // Every OTHER device is signed out; the one performing the change
            // keeps working so the user is not kicked out of the app.
            $this->tokens->revokeAllExcept($user, $currentTokenId);
        });

        return ApiResponse::action(Msg::PASSWORD_CHANGED);
    }

    private function withCounts(User $user): User
    {
        return $user->loadCount(['prices', 'ratings', 'reports'])
            ->load('location.sector');
    }
}
