<?php

namespace App\Http\Requests\Auth;

use Illuminate\Foundation\Http\FormRequest;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'min:2', 'max:255'],
            'location_id' => ['sometimes', 'nullable', 'integer', 'exists:locations,id'],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('location_id') && $this->input('location_id') !== null) {
            $this->merge(['location_id' => (int) $this->input('location_id')]);
        }
    }
}
