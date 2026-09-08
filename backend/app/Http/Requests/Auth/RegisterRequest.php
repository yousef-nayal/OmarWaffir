<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'min:2', 'max:255'],
            'phone_number' => [
                'required', 'string', 'regex:/^[0-9+]{9,15}$/',
                Rule::unique('users', 'phone_number')->whereNull('deleted_at'),
            ],
            'password' => ['required', 'string', 'min:6', 'max:255', 'confirmed'],
            // Flutter serialises ids as strings, so numeric strings are fine.
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('location_id') && $this->input('location_id') !== null) {
            $this->merge(['location_id' => (int) $this->input('location_id')]);
        }
    }
}
