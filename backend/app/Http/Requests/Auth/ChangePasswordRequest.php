<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class ChangePasswordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Primary flow: OTP. `current_password` stays accepted for the
            // older settings screen until it is fully migrated.
            'code' => ['nullable', 'string', 'digits:'.config('waffir.otp.length', 6)],
            'current_password' => ['nullable', 'string'],
            'new_password' => ['required', 'string', 'min:6', 'max:255', 'confirmed'],
        ];
    }
}
