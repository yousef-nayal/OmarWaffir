<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class AdminLoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // Either a phone number or an email address.
            'username' => ['required', 'string', 'max:255'],
            'password' => ['required', 'string'],
        ];
    }
}
