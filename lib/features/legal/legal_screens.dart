import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════
// عناصر مشتركة لعرض المستندات القانونية (سياسة الخصوصية / الشروط والأحكام)
// ══════════════════════════════════════════════════════════════════════════

class _LegalScaffold extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<_LegalSection> sections;

  const _LegalScaffold({
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'آخر تحديث: $lastUpdated',
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context), fontSize: 12),
            ),
            const SizedBox(height: 20),
            ...sections.map((s) => _SectionWidget(section: s)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text('لأي استفسار تواصل معنا',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      SizedBox(width: 8),
                      Icon(Icons.mail_outline,
                          color: AppColors.primary, size: 18),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text('support@waffir.sy',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final List<String> paragraphs;
  final List<String>? bullets;
  const _LegalSection(this.title, this.paragraphs, {this.bullets});
}

class _SectionWidget extends StatelessWidget {
  final _LegalSection section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppColors.textPrimaryOf(context);
    final textSecondary = AppColors.textSecondaryOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(section.title,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          const SizedBox(height: 8),
          ...section.paragraphs.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(p,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 13.5, height: 1.6, color: textSecondary)),
              )),
          if (section.bullets != null)
            ...section.bullets!.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(b,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.6,
                                color: textSecondary)),
                      ),
                      const SizedBox(width: 8),
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle,
                            size: 5, color: AppColors.primary),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PRIVACY POLICY
// ══════════════════════════════════════════════════════════════════════════
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'سياسة الخصوصية',
      lastUpdated: '8 يوليو 2026',
      sections: [
        _LegalSection(
          'مقدمة',
          [
            'يحترم تطبيق "وفّر" خصوصية مستخدميه، وتوضح هذه السياسة نوع البيانات '
                'التي نجمعها منك، وكيفية استخدامها وحمايتها عند استخدامك للتطبيق. '
                'باستخدامك للتطبيق فإنك توافق على الممارسات الموضحة في هذه السياسة.',
          ],
        ),
        _LegalSection(
          'البيانات التي نجمعها',
          [
            'نجمع الحد الأدنى من البيانات اللازمة لتشغيل خدمات التطبيق:',
          ],
          bullets: [
            'بيانات الحساب: الاسم الكامل، رقم الهاتف، والمحافظة/المنطقة التي تحددها عند التسجيل.',
            'المحتوى الذي تضيفه: الأسعار، أسماء المتاجر المقترحة، البلاغات، والتقييمات (إعجاب/عدم إعجاب) التي ترسلها.',
            'بيانات تقنية أساسية مثل نوع الجهاز ونظام التشغيل، لأغراض تحسين الأداء واستكشاف الأخطاء فقط.',
            'الموقع التقريبي (المحافظة/المنطقة) الذي تختاره يدوياً من داخل التطبيق — لا نجمع الموقع الجغرافي الدقيق (GPS) في الوقت الحالي.',
          ],
        ),
        _LegalSection(
          'كيف نستخدم بياناتك',
          [],
          bullets: [
            'عرض الأسعار الحقيقية ومقارنتها بالأسعار الرسمية للمستخدمين الآخرين.',
            'التحقق من حسابك وتفعيل ميزات التطبيق (تسجيل الدخول، استرجاع كلمة المرور).',
            'مراجعة الأسعار والبلاغات المُقدَّمة من المستخدمين من قبل فريق الإشراف لضمان دقتها.',
            'التواصل معك في حال وجود مشكلة تخص حسابك أو المحتوى الذي أضفته.',
            'تحسين التطبيق وإصلاح الأخطاء التقنية.',
          ],
        ),
        _LegalSection(
          'مشاركة البيانات مع أطراف أخرى',
          [
            'نحن لا نبيع بياناتك الشخصية لأي طرف ثالث. الأسعار والمعلومات التي تضيفها '
                'تُعرض بشكل عام على المستخدمين الآخرين مع اسمك كما هو مسجّل في التطبيق '
                '(حتى يتمكن المستخدمون من معرفة مصدر السعر)، لكن رقم هاتفك يبقى خاصاً '
                'ولا يظهر لأي مستخدم آخر.',
            'قد نشارك بيانات محدودة مع مزوّدي الخدمات التقنية (مثل خدمات الاستضافة) '
                'فقط بالقدر اللازم لتشغيل التطبيق، وبموجب التزامهم بالحفاظ على سريتها.',
          ],
        ),
        _LegalSection(
          'أمان البيانات',
          [
            'نستخدم اتصالاً مشفّراً (HTTPS) بين التطبيق والخادم، ونخزّن رموز الدخول '
                '(access/refresh tokens) بشكل آمن على جهازك عبر التخزين الآمن للنظام. '
                'مع ذلك، لا يوجد نظام آمن بنسبة 100%، ونعمل باستمرار على تحسين إجراءات الحماية.',
          ],
        ),
        _LegalSection(
          'حقوقك',
          [],
          bullets: [
            'يمكنك تعديل بيانات ملفك الشخصي (الاسم، الموقع) في أي وقت من داخل التطبيق.',
            'يمكنك طلب حذف حسابك وبياناتك عبر التواصل مع فريق الدعم.',
            'يمكنك تغيير كلمة المرور الخاصة بك متى شئت من إعدادات الحساب.',
          ],
        ),
        _LegalSection(
          'الاحتفاظ بالبيانات',
          [
            'نحتفظ ببياناتك طالما حسابك نشطاً. عند حذف الحساب، تُحذف بياناتك الشخصية '
                'خلال مدة معقولة، مع إمكانية الاحتفاظ ببعض السجلات المجهّلة (anonymized) '
                'لأغراض إحصائية لا تتيح التعرّف عليك.',
          ],
        ),
        _LegalSection(
          'التعديلات على هذه السياسة',
          [
            'قد نقوم بتحديث سياسة الخصوصية من وقت لآخر. سنُعلمك بأي تغييرات جوهرية '
                'عبر إشعار داخل التطبيق، ويُعتبر استمرارك في استخدام التطبيق بعد التحديث '
                'موافقة ضمنية على النسخة الجديدة.',
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TERMS OF SERVICE
// ══════════════════════════════════════════════════════════════════════════
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalScaffold(
      title: 'الشروط والأحكام',
      lastUpdated: '8 يوليو 2026',
      sections: [
        _LegalSection(
          'قبول الشروط',
          [
            'باستخدامك تطبيق "وفّر"، فإنك تقرّ بأنك قرأت هذه الشروط وفهمتها ووافقت '
                'على الالتزام بها. إذا كنت لا توافق على أي بند من هذه الشروط، يُرجى '
                'عدم استخدام التطبيق.',
          ],
        ),
        _LegalSection(
          'طبيعة الخدمة',
          [
            'تطبيق "وفّر" منصة تُتيح للمستخدمين مشاركة الأسعار الحقيقية للمنتجات في '
                'المتاجر ومقارنتها بالأسعار الرسمية الصادرة عن الجهات المختصة، بهدف '
                'زيادة الشفافية ومساعدة المستهلكين على اتخاذ قرارات شراء أفضل.',
          ],
        ),
        _LegalSection(
          'إخلاء مسؤولية بخصوص دقة الأسعار',
          [
            'الأسعار المعروضة في قسم "الأسعار الحقيقية" هي بيانات مُقدَّمة من '
                'المستخدمين (crowd-sourced) وتخضع لمراجعة إدارية، لكن التطبيق لا '
                'يضمن دقتها الكاملة أو تحديثها اللحظي، فقد تتغير الأسعار الفعلية في '
                'المتاجر بين وقت الإضافة والاطلاع عليها.',
            'الأسعار الرسمية المعروضة مصدرها الجهات الحكومية المعنية كما هو موضّح '
                'في كل شاشة، ولسنا الجهة المصدرة لها.',
            'لا يتحمّل التطبيق أي مسؤولية عن أي قرار شراء يتخذه المستخدم بناءً على '
                'الأسعار المعروضة.',
          ],
        ),
        _LegalSection(
          'التزامات المستخدم',
          [
            'عند إضافة سعر، بلاغ، أو اقتراح متجر، يوافق المستخدم على:',
          ],
          bullets: [
            'تقديم معلومات صحيحة وحديثة بقدر معرفته.',
            'عدم إدخال بيانات مضلّلة أو كاذبة بقصد الإضرار بمتجر أو منتج معيّن.',
            'عدم استخدام التطبيق لأي غرض غير قانوني أو مخالف للآداب العامة.',
            'عدم محاولة التلاعب بنظام التقييمات (الإعجاب/عدم الإعجاب) عبر حسابات وهمية.',
          ],
        ),
        _LegalSection(
          'المحتوى المُقدَّم من المستخدمين',
          [
            'يبقى المستخدم مسؤولاً عن أي محتوى يضيفه (أسعار، بلاغات، اقتراحات '
                'متاجر). يحتفظ فريق الإشراف بحق مراجعة أو تعديل أو حذف أي محتوى '
                'يخالف هذه الشروط، أو رفضه دون إبداء الأسباب، أو إيقاف الحساب في '
                'حال تكرار المخالفات.',
          ],
        ),
        _LegalSection(
          'حسابات المستخدمين',
          [
            'أنت مسؤول عن الحفاظ على سرية كلمة المرور الخاصة بحسابك، وعن أي نشاط '
                'يتم من خلاله. يجب إبلاغنا فوراً في حال الاشتباه بأي استخدام غير '
                'مصرّح به لحسابك.',
          ],
        ),
        _LegalSection(
          'الملكية الفكرية',
          [
            'جميع عناصر التصميم والشعار والواجهة الخاصة بتطبيق "وفّر" هي ملك لفريق '
                'التطبيق، ولا يجوز نسخها أو إعادة استخدامها تجارياً دون إذن خطي مسبق.',
          ],
        ),
        _LegalSection(
          'تعليق أو إنهاء الحساب',
          [
            'يحق لإدارة التطبيق تعليق أو حذف أي حساب يخالف هذه الشروط، أو يُساء '
                'استخدامه لنشر معلومات كاذبة بشكل متكرر، دون إشعار مسبق في الحالات '
                'الجسيمة.',
          ],
        ),
        _LegalSection(
          'التعديلات على الخدمة والشروط',
          [
            'نحتفظ بحق تعديل هذه الشروط أو ميزات التطبيق في أي وقت. سيتم إعلامك '
                'بالتغييرات الجوهرية عبر إشعار داخل التطبيق، واستمرارك في الاستخدام '
                'بعدها يُعدّ موافقة على الشروط المُحدَّثة.',
          ],
        ),
        _LegalSection(
          'القانون الواجب التطبيق',
          [
            'تخضع هذه الشروط وتُفسَّر وفقاً للقوانين النافذة في الجمهورية العربية '
                'السورية، وأي نزاع ينشأ عن استخدام التطبيق يخضع لاختصاص المحاكم '
                'المختصة فيها.',
          ],
        ),
      ],
    );
  }
}
