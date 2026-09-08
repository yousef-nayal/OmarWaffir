<?php

namespace App\Sms;

class NullSmsSender implements SmsSenderInterface
{
    public function send(string $phoneNumber, string $message): bool
    {
        return true;
    }
}
