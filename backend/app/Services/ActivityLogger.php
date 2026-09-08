<?php

namespace App\Services;

use App\Models\ActivityLog;
use Illuminate\Database\Eloquent\Model;

class ActivityLogger
{
    public function log(string $type, string $text, ?int $userId = null, ?Model $subject = null): ActivityLog
    {
        return ActivityLog::create([
            'type' => $type,
            'text' => $text,
            'user_id' => $userId,
            'subject_type' => $subject !== null ? $subject::class : null,
            'subject_id' => $subject?->getKey(),
        ]);
    }
}
