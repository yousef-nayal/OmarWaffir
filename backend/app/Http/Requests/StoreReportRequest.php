<?php

namespace App\Http\Requests;

use App\Models\Report;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreReportRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'price_id' => ['required', 'integer', 'exists:prices,id'],
            'type' => ['required', 'string', Rule::in(Report::types())],
            // A description is mandatory for "معلومات غير صحيحة" and forbidden
            // for the other two types (mirrors the database CHECK constraint).
            'description' => [
                'nullable',
                'string',
                'max:1000',
                Rule::requiredIf(fn (): bool => $this->input('type') === Report::TYPE_WRONG_INFO),
            ],
        ];
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('price_id')) {
            $this->merge(['price_id' => (int) $this->input('price_id')]);
        }
    }
}
