<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class ResetPasswordRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'phone_number' => ['required', 'string', 'exists:users,phone_number'],
            'code' => ['required', 'string', 'digits:'.config('waffir.otp.length', 6)],
            'new_password' => ['required', 'string', 'min:6', 'max:255', 'confirmed'],
        ];
    }
}
