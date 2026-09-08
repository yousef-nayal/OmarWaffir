<?php

namespace App\Services;

use App\Models\RefreshToken;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Issues the Sanctum bearer access token plus the custom refresh token that
 * backs it. Refresh tokens are random, hashed before storage and rotated on
 * every successful refresh.
 */
class TokenService
{
    /**
     * @return array{access_token: string, refresh_token: string}
     */
    public function issue(User $user, ?Request $request = null): array
    {
        return DB::transaction(function () use ($user, $request) {
            $accessToken = $user->createToken('waffir-app');

            $plainRefresh = $this->generatePlainToken();

            RefreshToken::create([
                'user_id' => $user->id,
                'token_hash' => $this->hash($plainRefresh),
                'access_token_id' => $accessToken->accessToken->getKey(),
                'expires_at' => Carbon::now()->addDays((int) config('waffir.refresh_token_days')),
                'user_agent' => $request?->userAgent(),
                'ip_address' => $request?->ip(),
            ]);

            return [
                'access_token' => $accessToken->plainTextToken,
                'refresh_token' => $plainRefresh,
            ];
        });
    }

    /**
     * Rotates a refresh token: the presented token is revoked and a brand new
     * access/refresh pair is issued. Returns null when the token is unusable.
     *
     * @return array{access_token: string, refresh_token: string}|null
     */
    public function rotate(string $plainRefreshToken, ?Request $request = null): ?array
    {
        return DB::transaction(function () use ($plainRefreshToken, $request) {
            /** @var RefreshToken|null $record */
            $record = RefreshToken::where('token_hash', $this->hash($plainRefreshToken))
                ->lockForUpdate()
                ->first();

            if ($record === null || ! $record->isUsable()) {
                return null;
            }

            $user = $record->user;

            if ($user === null || ! $user->is_active) {
                return null;
            }

            // Revoke the old pair before issuing the new one.
            $record->forceFill([
                'revoked_at' => Carbon::now(),
                'last_used_at' => Carbon::now(),
            ])->save();

            if ($record->access_token_id !== null) {
                $user->tokens()->whereKey($record->access_token_id)->delete();
            }

            return $this->issue($user, $request);
        });
    }

    /** Revokes the refresh session tied to the given access token id. */
    public function revokeForAccessToken(User $user, int|string|null $accessTokenId): void
    {
        if ($accessTokenId === null) {
            return;
        }

        $user->refreshTokens()
            ->where('access_token_id', $accessTokenId)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => Carbon::now()]);
    }

    /** Kills every session of a user (used after a password reset/change). */
    public function revokeAll(User $user): void
    {
        $user->tokens()->delete();

        $user->refreshTokens()
            ->whereNull('revoked_at')
            ->update(['revoked_at' => Carbon::now()]);
    }

    /** Kills every session except the one belonging to $keepAccessTokenId. */
    public function revokeAllExcept(User $user, int|string|null $keepAccessTokenId): void
    {
        $user->tokens()->when($keepAccessTokenId !== null, fn ($q) => $q->whereKeyNot($keepAccessTokenId))->delete();

        $user->refreshTokens()
            ->whereNull("revoked_at")
            ->when($keepAccessTokenId !== null, fn ($q) => $q->where("access_token_id", "!=", $keepAccessTokenId))
            ->update(["revoked_at" => Carbon::now()]);
    }
    public function hash(string $plain): string
    {
        return hash('sha256', $plain);
    }

    private function generatePlainToken(): string
    {
        return Str::random(24).'|'.bin2hex(random_bytes(32));
    }
}
