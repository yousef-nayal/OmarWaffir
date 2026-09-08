<?php

namespace App\Sms;

interface SmsSenderInterface
{
    /**
     * Deliver a message to a phone number.
     *
     * Implementations must never throw for transport problems in a way that
     * breaks the surrounding database transaction; log and return false.
     */
    public function send(string $phoneNumber, string $message): bool;
}
