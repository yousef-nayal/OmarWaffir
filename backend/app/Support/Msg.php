<?php

namespace App\Support;

/**
 * Every user-facing message the API can return, in Arabic.
 *
 * Keeping them in one place means the rest of the codebase stays ASCII-only
 * and there is a single file to review when the wording changes.
 */
final class Msg
{
    // ── Generic ────────────────────────────────────────────────────────────
    public const SUCCESS = 'تمت العملية بنجاح';
    public const CREATED = 'تمت الإضافة بنجاح';
    public const UPDATED = 'تم التحديث بنجاح';
    public const DELETED = 'تم الحذف بنجاح';
    public const FETCHED = 'تم جلب البيانات بنجاح';

    // ── Errors ─────────────────────────────────────────────────────────────
    public const VALIDATION = 'يرجى التحقق من البيانات المدخلة';
    public const UNAUTHENTICATED = 'انتهت جلستك. يرجى تسجيل الدخول مجدداً';
    public const FORBIDDEN = 'لا تملك صلاحية لتنفيذ هذه العملية';
    public const NOT_FOUND = 'العنصر المطلوب غير موجود';
    public const SERVER_ERROR = 'حدث خطأ في الخادم. حاول مجدداً لاحقاً';
    public const RATE_LIMITED = 'عدد كبير من المحاولات، يرجى المحاولة لاحقاً';
    public const METHOD_NOT_ALLOWED = 'طلب غير مدعوم';

    // ── Auth ───────────────────────────────────────────────────────────────
    public const INVALID_CREDENTIALS = 'رقم الهاتف أو كلمة المرور غير صحيحة';
    public const INVALID_ADMIN_CREDENTIALS = 'بيانات الدخول غير صحيحة';
    public const ACCOUNT_BLOCKED = 'الحساب محظور، يرجى التواصل مع الإدارة';
    public const PHONE_NOT_VERIFIED = 'يجب تأكيد رقم الهاتف أولاً';
    public const PHONE_ALREADY_VERIFIED = 'رقم الهاتف مؤكد مسبقاً';
    public const REGISTERED = 'تم إرسال رمز التحقق';
    public const LOGGED_IN = 'تم تسجيل الدخول بنجاح';
    public const LOGGED_OUT = 'تم تسجيل الخروج بنجاح';
    public const VERIFIED = 'تم تأكيد رقم الهاتف بنجاح';
    public const PROFILE_UPDATED = 'تم تحديث البيانات بنجاح';
    public const PASSWORD_CHANGED = 'تم تغيير كلمة المرور بنجاح';
    public const CURRENT_PASSWORD_WRONG = 'كلمة المرور الحالية غير صحيحة';
    public const NOT_ADMIN = 'هذا الحساب لا يملك صلاحية الدخول للوحة الإدارة';

    // ── OTP ────────────────────────────────────────────────────────────────
    public const OTP_SENT = 'تم إرسال رمز التحقق';
    public const OTP_INVALID = 'رمز التحقق غير صحيح';
    public const OTP_EXPIRED = 'انتهت صلاحية رمز التحقق';
    public const OTP_TOO_MANY_ATTEMPTS = 'تم تجاوز عدد المحاولات المسموح بها، اطلب رمزاً جديداً';
    public const OTP_COOLDOWN = 'يرجى الانتظار قليلاً قبل طلب رمز جديد';
    public const OTP_NOT_FOUND = 'لا يوجد رمز تحقق فعّال لهذا الرقم';

    // ── Sessions / refresh ─────────────────────────────────────────────────
    public const REFRESH_INVALID = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً';
    public const REFRESHED = 'تم تجديد الجلسة';

    // ── Domain ─────────────────────────────────────────────────────────────
    public const PRODUCT_NOT_FOUND = 'المنتج غير موجود';
    public const STORE_NOT_FOUND = 'المتجر غير موجود';
    public const PRICE_NOT_FOUND = 'السعر غير موجود';
    public const SELF_VOTE = 'لا يمكنك تقييم سعر أضفته بنفسك';
    public const VOTE_SAVED = 'تم حفظ تقييمك';
    public const REPORT_SAVED = 'تم إرسال البلاغ بنجاح';
    public const STORE_SUBMITTED = 'تم إرسال اقتراح المتجر، بانتظار التوثيق';
    public const STORE_VERIFIED = 'تم توثيق المتجر';
    public const STORE_UNVERIFIED = 'تم إلغاء توثيق المتجر';
    public const PRICE_SUBMITTED = 'تم إضافة السعر بنجاح';
    public const IN_USE = 'لا يمكن الحذف لأن العنصر مستخدم في بيانات أخرى';

    // ── Admin / user management ────────────────────────────────────────────
    public const USER_BLOCKED = 'تم حظر المستخدم';
    public const USER_UNBLOCKED = 'تم رفع الحظر عن المستخدم';
    public const ROLE_UPDATED = 'تم تحديث الصلاحية';
    public const CANNOT_MODIFY_SELF = 'لا يمكنك تنفيذ هذه العملية على حسابك الخاص';
    public const CANNOT_MANAGE_ADMIN = 'إدارة حسابات المسؤولين متاحة للمسؤول الرئيسي فقط';
    public const CANNOT_DELETE_LAST_SUPER_ADMIN = 'لا يمكن حذف آخر مسؤول رئيسي في النظام';
    public const CANNOT_CREATE_SUPER_ADMIN = 'إنشاء مسؤول رئيسي متاح للمسؤول الرئيسي فقط';

    // ── Notifications ──────────────────────────────────────────────────────
    public const NOTIFICATION_READ = 'تم تعليم الإشعار كمقروء';
    public const NOTIFICATIONS_READ = 'تم تعليم كل الإشعارات كمقروءة';

    // ── Activity log / notification templates ──────────────────────────────
    public static function activityPriceAdded(string $user, string $product, string $store): string
    {
        return "أضاف {$user} سعراً جديداً لـ{$product} في {$store}";
    }

    public static function activityReportAdded(string $user, string $product): string
    {
        return "أرسل {$user} بلاغاً عن سعر {$product}";
    }

    public static function activityUserRegistered(string $user): string
    {
        return "انضم مستخدم جديد: {$user}";
    }

    public static function activityStoreSubmitted(string $user, string $store): string
    {
        return "اقترح {$user} متجراً جديداً: {$store}";
    }

    public static function activityStoreVerified(string $store): string
    {
        return "تم توثيق المتجر {$store}";
    }

    public static function activityOfficialPrice(string $product, string $price): string
    {
        return "تم تحديث السعر الرسمي لـ{$product} إلى {$price} ل.س";
    }

    public static function notificationOfficialPriceChanged(string $product, string $old, string $new): string
    {
        return "تغيّر السعر الرسمي لـ{$product} من {$old} إلى {$new} ل.س";
    }

    public static function notificationOfficialPriceAdded(string $product, string $price): string
    {
        return "تمت إضافة سعر رسمي جديد لـ{$product}: {$price} ل.س";
    }

    public static function smsOtp(string $code): string
    {
        return "رمز التحقق الخاص بتطبيق وفّر هو: {$code}";
    }
}
