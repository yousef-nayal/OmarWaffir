<?php

namespace App\Services;

use App\Models\AuthOtp;
use App\Models\User;
use App\Sms\SmsSenderInterface;
use App\Support\Msg;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * One-time password issuing and verification.
 *
 * The code is never stored in plaintext: only a bcrypt hash is persisted.
 * In local/testing environments a fixed OTP_TEST_CODE may be configured so the
 * project can be demonstrated without an SMS gateway; it is ignored outside
 * those environments.
 */
class OtpService
{
    public function __construct(private readonly SmsSenderInterface $sms)
    {
    }

    public const RESULT_OK = 'ok';
    public const RESULT_NOT_FOUND = 'not_found';
    public const RESULT_EXPIRED = 'expired';
    public const RESULT_INVALID = 'invalid';
    public const RESULT_TOO_MANY = 'too_many';

    /**
     * Creates and sends a fresh OTP, invalidating any previous unused code for
     * the same phone/purpose pair.
     *
     * @return array{sent: bool, cooldown: bool, code: ?string}
     */
    public function send(string $phoneNumber, string $purpose, ?User $user = null): array
    {
        $cooldown = (int) config('waffir.otp.resend_cooldown_seconds');

        $recent = AuthOtp::where('phone_number', $phoneNumber)
            ->where('purpose', $purpose)
            ->where('created_at', '>', Carbon::now()->subSeconds($cooldown))
            ->exists();

        if ($recent) {
            return ['sent' => false, 'cooldown' => true, 'code' => null];
        }

        $code = $this->generateCode();

        DB::transaction(function () use ($phoneNumber, $purpose, $user, $code) {
            AuthOtp::where('phone_number', $phoneNumber)
                ->where('purpose', $purpose)
                ->where('is_used', false)
                ->update(['is_used' => true]);

            AuthOtp::create([
                'user_id' => $user?->id,
                'phone_number' => $phoneNumber,
                'purpose' => $purpose,
                'otp_hash' => Hash::make($code),
                'attempts' => 0,
                'is_used' => false,
                'expires_at' => Carbon::now()->addMinutes((int) config('waffir.otp.ttl_minutes')),
                'created_at' => Carbon::now(),
            ]);
        });

        $this->sms->send($phoneNumber, Msg::smsOtp($code));

        return [
            'sent' => true,
            'cooldown' => false,
            // Returned only so tests can assert on it; never exposed by the API.
            'code' => $code,
        ];
    }

    /**
     * Consumes an OTP atomically. Returns one of the RESULT_* constants.
     */
    public function verify(string $phoneNumber, string $purpose, string $code): string
    {
        return DB::transaction(function () use ($phoneNumber, $purpose, $code) {
            /** @var AuthOtp|null $otp */
            $otp = AuthOtp::where('phone_number', $phoneNumber)
                ->where('purpose', $purpose)
                ->where('is_used', false)
                ->orderByDesc('id')
                ->lockForUpdate()
                ->first();

            if ($otp === null) {
                return self::RESULT_NOT_FOUND;
            }

            if ($otp->isExpired()) {
                $otp->forceFill(['is_used' => true])->save();

                return self::RESULT_EXPIRED;
            }

            if ($otp->attempts >= (int) config('waffir.otp.max_attempts')) {
                $otp->forceFill(['is_used' => true])->save();

                return self::RESULT_TOO_MANY;
            }

            $matches = Hash::check($code, $otp->otp_hash)
                || ($this->isTestCodeAllowed() && $code === (string) config('waffir.otp.test_code'));

            if (! $matches) {
                $otp->increment('attempts');

                return self::RESULT_INVALID;
            }

            $otp->forceFill([
                'is_used' => true,
                'verified_at' => Carbon::now(),
            ])->save();

            return self::RESULT_OK;
        });
    }

    public function messageFor(string $result): string
    {
        return match ($result) {
            self::RESULT_EXPIRED => Msg::OTP_EXPIRED,
            self::RESULT_TOO_MANY => Msg::OTP_TOO_MANY_ATTEMPTS,
            self::RESULT_NOT_FOUND => Msg::OTP_NOT_FOUND,
            default => Msg::OTP_INVALID,
        };
    }

    /** The fixed development code is only ever honoured locally. */
    public function isTestCodeAllowed(): bool
    {
        return config('waffir.otp.test_code') !== null
            && in_array(app()->environment(), ['local', 'testing'], true);
    }

    private function generateCode(): string
    {
        if ($this->isTestCodeAllowed()) {
            return (string) config('waffir.otp.test_code');
        }

        $length = (int) config('waffir.otp.length');
        $max = (10 ** $length) - 1;

        return str_pad((string) random_int(0, $max), $length, '0', STR_PAD_LEFT);
    }
}
