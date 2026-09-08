<?php

namespace App\Sms;

use Illuminate\Support\Facades\Log;

/**
 * Development driver: the "SMS" is written to storage/logs/laravel.log so the
 * project can be run end-to-end without paying for an SMS gateway.
 */
class LogSmsSender implements SmsSenderInterface
{
    public function send(string $phoneNumber, string $message): bool
    {
        Log::channel(config('logging.default'))->info('[SMS] '.$phoneNumber.' :: '.$message);

        return true;
    }
}
