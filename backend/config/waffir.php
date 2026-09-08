<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Refresh tokens
    |--------------------------------------------------------------------------
    */
    'refresh_token_days' => (int) env('WAFFIR_REFRESH_TOKEN_DAYS', 30),

    /*
    |--------------------------------------------------------------------------
    | One time passwords
    |--------------------------------------------------------------------------
    */
    'otp' => [
        'length'                   => (int) env('WAFFIR_OTP_LENGTH', 6),
        'ttl_minutes'              => (int) env('WAFFIR_OTP_TTL_MINUTES', 10),
        'max_attempts'             => (int) env('WAFFIR_OTP_MAX_ATTEMPTS', 5),
        'resend_cooldown_seconds'  => (int) env('WAFFIR_OTP_RESEND_COOLDOWN_SECONDS', 60),
        'sms_driver'               => env('WAFFIR_SMS_DRIVER', 'log'),
        // Honoured ONLY in local/testing (see OtpService::isTestCodeAllowed()).
        'test_code'                => env('OTP_TEST_CODE'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Representative real-price aggregation
    |--------------------------------------------------------------------------
    | Everything the median/MAD algorithm needs is configurable so the thesis
    | can be reproduced with different parameters without touching code.
    */
    'pricing' => [
        'freshness_days'          => (int) env('WAFFIR_PRICE_FRESHNESS_DAYS', 30),
        // Modified z-score cut-off (Iglewicz & Hoaglin recommend 3.5).
        'mad_threshold'           => (float) env('WAFFIR_PRICE_MAD_THRESHOLD', 3.5),
        // Below this sample count no outlier filtering is applied at all.
        'min_samples_for_filter'  => (int) env('WAFFIR_PRICE_MIN_SAMPLES_FOR_FILTER', 5),
        // IQR fallback multiplier used when MAD cannot discriminate (MAD = 0).
        'iqr_multiplier'          => (float) env('WAFFIR_PRICE_IQR_MULTIPLIER', 1.5),
    ],

    /*
    |--------------------------------------------------------------------------
    | Dashboard
    |--------------------------------------------------------------------------
    */
    'dashboard' => [
        'growth_period_days' => (int) env('WAFFIR_DASHBOARD_PERIOD_DAYS', 30),
        'recent_activity_limit' => (int) env('WAFFIR_RECENT_ACTIVITY_LIMIT', 20),
    ],
];
