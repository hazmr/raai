import 'app_localizations.dart';

/// The translations for Arabic (`ar`).
class L10nAr extends L10n {
  L10nAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'راعي';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get register => 'حساب جديد';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get password => 'كلمة المرور';

  @override
  String get roleFarmer => 'مزارع';

  @override
  String get roleVet => 'طبيب بيطري';

  @override
  String get roleQuestion => 'أنا';

  @override
  String get signIn => 'دخول';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get needAccount => 'مستخدم جديد؟ أنشئ حساباً';

  @override
  String get haveAccount => 'لديك حساب؟ سجّل الدخول';

  @override
  String get homeGreeting => 'أهلاً';

  @override
  String get tileHerd => 'القطيع';

  @override
  String get tileScan => 'مسح الرقم';

  @override
  String get tileNewVisit => 'زيارة جديدة';

  @override
  String get tileOpenVisits => 'الزيارات المفتوحة';

  @override
  String get tileSubscription => 'الاشتراك';

  @override
  String herdCount(int count) {
    return '$count رأس';
  }

  @override
  String get subscriptionActive => 'الاشتراك فعّال';

  @override
  String get subscriptionExpiring => 'ينتهي قريباً';

  @override
  String get subscriptionLapsed => 'الاشتراك مطلوب';

  @override
  String renewsOn(String date) {
    return 'يتجدد $date';
  }

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get search => 'بحث';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get errOffline => 'لا يوجد اتصال — حاول مرة أخرى';

  @override
  String get errSessionExpired => 'انتهت الجلسة — سجّل الدخول من جديد';

  @override
  String get errForbidden => 'لا تملك صلاحية لهذا الإجراء';

  @override
  String get errNotFound => 'غير موجود';

  @override
  String get errAnimalNotFound => 'لم يتم العثور على هذا الحيوان';

  @override
  String get errConflict => 'هذا العنصر موجود بالفعل';

  @override
  String get errTagExists => 'هذا الرقم مسجّل بالفعل';

  @override
  String get errReceiptUsed => 'هذا الإيصال مُستخدم من قبل';

  @override
  String get errValidation => 'تحقق من البيانات';

  @override
  String get errRateLimited => 'محاولات كثيرة — انتظر قليلاً';

  @override
  String get errGeneric => 'حدث خطأ ما — حاول لاحقاً';

  @override
  String get fieldRequired => 'مطلوب';

  @override
  String get passwordTooShort => '٦ أحرف على الأقل';
}
