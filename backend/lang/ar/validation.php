<?php

/**
 * Arabic validation messages. Only the rules this API actually uses are
 * translated; anything else falls back to the English file.
 */
return [
    'accepted' => 'يجب قبول :attribute.',
    'after' => 'يجب أن يكون :attribute تاريخاً لاحقاً لـ :date.',
    'alpha' => 'يجب أن يحتوي :attribute على أحرف فقط.',
    'alpha_dash' => 'يجب أن يحتوي :attribute على أحرف وأرقام وشرطات فقط.',
    'alpha_num' => 'يجب أن يحتوي :attribute على أحرف وأرقام فقط.',
    'array' => 'يجب أن يكون :attribute مصفوفة.',
    'before' => 'يجب أن يكون :attribute تاريخاً سابقاً لـ :date.',
    'between' => [
        'numeric' => 'يجب أن تكون قيمة :attribute بين :min و :max.',
        'string' => 'يجب أن يكون طول :attribute بين :min و :max حرفاً.',
    ],
    'boolean' => 'يجب أن تكون قيمة :attribute صحيحة أو خاطئة.',
    'confirmed' => 'تأكيد :attribute غير مطابق.',
    'current_password' => 'كلمة المرور غير صحيحة.',
    'date' => 'قيمة :attribute ليست تاريخاً صحيحاً.',
    'different' => 'يجب أن يكون :attribute مختلفاً عن :other.',
    'digits' => 'يجب أن يتكون :attribute من :digits أرقام.',
    'digits_between' => 'يجب أن يتكون :attribute من عدد أرقام بين :min و :max.',
    'email' => 'يجب أن يكون :attribute بريداً إلكترونياً صحيحاً.',
    'exists' => 'قيمة :attribute المحددة غير موجودة.',
    'in' => 'قيمة :attribute المحددة غير صالحة.',
    'integer' => 'يجب أن يكون :attribute رقماً صحيحاً.',
    'max' => [
        'numeric' => 'يجب ألا تتجاوز قيمة :attribute :max.',
        'string' => 'يجب ألا يتجاوز طول :attribute :max حرفاً.',
    ],
    'min' => [
        'numeric' => 'يجب ألا تقل قيمة :attribute عن :min.',
        'string' => 'يجب ألا يقل طول :attribute عن :min أحرف.',
    ],
    'not_in' => 'قيمة :attribute المحددة غير صالحة.',
    'numeric' => 'يجب أن يكون :attribute رقماً.',
    'regex' => 'صيغة :attribute غير صحيحة.',
    'required' => 'حقل :attribute مطلوب.',
    'required_if' => 'حقل :attribute مطلوب.',
    'same' => 'يجب أن يتطابق :attribute مع :other.',
    'size' => [
        'numeric' => 'يجب أن تكون قيمة :attribute :size.',
        'string' => 'يجب أن يكون طول :attribute :size أحرف.',
    ],
    'string' => 'يجب أن يكون :attribute نصاً.',
    'unique' => 'قيمة :attribute مستخدمة مسبقاً.',

    'custom' => [
        'phone_number' => [
            'unique' => 'رقم الهاتف مستخدم مسبقاً',
            'required' => 'رقم الهاتف مطلوب',
            'regex' => 'رقم الهاتف غير صحيح',
        ],
        'email' => [
            'unique' => 'البريد الإلكتروني مستخدم مسبقاً',
        ],
        'password' => [
            'min' => 'يجب ألا تقل كلمة المرور عن :min أحرف',
            'confirmed' => 'تأكيد كلمة المرور غير مطابق',
        ],
        'new_password' => [
            'min' => 'يجب ألا تقل كلمة المرور الجديدة عن :min أحرف',
            'confirmed' => 'تأكيد كلمة المرور غير مطابق',
        ],
        'code' => [
            'required' => 'رمز التحقق مطلوب',
            'digits' => 'رمز التحقق يجب أن يتكون من :digits أرقام',
        ],
        'description' => [
            'required_if' => 'يرجى كتابة تفاصيل البلاغ',
        ],
    ],

    'attributes' => [
        'name' => 'الاسم',
        'phone_number' => 'رقم الهاتف',
        'username' => 'اسم المستخدم',
        'email' => 'البريد الإلكتروني',
        'password' => 'كلمة المرور',
        'password_confirmation' => 'تأكيد كلمة المرور',
        'current_password' => 'كلمة المرور الحالية',
        'new_password' => 'كلمة المرور الجديدة',
        'code' => 'رمز التحقق',
        'location_id' => 'الموقع',
        'sector_id' => 'الكتلة',
        'district' => 'الحي',
        'store_id' => 'المتجر',
        'product_id' => 'المنتج',
        'unit_id' => 'الوحدة',
        'brand_id' => 'العلامة التجارية',
        'price_id' => 'السعر',
        'amount' => 'الكمية',
        'price' => 'السعر',
        'category' => 'التصنيف',
        'address' => 'العنوان',
        'type' => 'نوع البلاغ',
        'description' => 'التفاصيل',
        'role' => 'الصلاحية',
        'is_verified' => 'حالة التوثيق',
        'refresh_token' => 'رمز التجديد',
    ],
];
