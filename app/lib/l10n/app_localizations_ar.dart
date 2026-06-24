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
  String get roleFarmer => 'راعي';

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
  String get close => 'إغلاق';

  @override
  String get searchByTag => 'ابحث برقم الأذن';

  @override
  String get herdEmpty => 'لا توجد حيوانات بعد';

  @override
  String get addAnimal => 'إضافة حيوان';

  @override
  String get barcode => 'رقم الأذن';

  @override
  String noteCountLabel(int count) {
    return '$count ملاحظة';
  }

  @override
  String get notesTitle => 'السجل';

  @override
  String get notesEmpty => 'لا توجد ملاحظات بعد';

  @override
  String get addNote => 'إضافة ملاحظة';

  @override
  String get vetBadge => 'طبيب';

  @override
  String get noteHint => 'اكتب الملاحظة';

  @override
  String get send => 'إرسال';

  @override
  String get tplVaccination => 'تطعيم';

  @override
  String get tplCheckup => 'فحص';

  @override
  String get tplTreatment => 'علاج';

  @override
  String get tplBirth => 'ولادة';

  @override
  String get scanManualTitle => 'أدخل رقم الأذن';

  @override
  String get scanLookup => 'بحث';

  @override
  String get animalNotFoundAdd => 'لم يُعثر على هذا الرقم. هل تريد إضافته؟';

  @override
  String get scanHoldSteady => 'ثبّت الكاميرا على الرمز';

  @override
  String get scanMultiple => 'أكثر من بطاقة في الإطار — اقترب من واحدة فقط';

  @override
  String get scanConfirmTitle => 'تأكيد هذا الرقم';

  @override
  String get scanInHerd => 'موجود في القطيع';

  @override
  String get scanNotInHerd => 'غير موجود في القطيع';

  @override
  String get scanCheckNumber => 'تأكد أنه يطابق الرقم المطبوع على البطاقة';

  @override
  String get open => 'فتح';

  @override
  String get rescan => 'إعادة المسح';

  @override
  String get visitsTitle => 'الزيارات';

  @override
  String get locationType => 'المكان';

  @override
  String get locClinic => 'عيادة';

  @override
  String get locFarm => 'مزرعة';

  @override
  String get locationLabel => 'وصف المكان (اختياري)';

  @override
  String get vetPhone => 'رقم هاتف الطبيب (اختياري)';

  @override
  String get openVisit => 'بدء الزيارة';

  @override
  String get closeVisit => 'إنهاء الزيارة';

  @override
  String get visitsEmpty => 'لا توجد زيارات';

  @override
  String get openVisitsEmpty => 'لا توجد زيارات مفتوحة';

  @override
  String get visitOpen => 'مفتوحة';

  @override
  String get visitClosed => 'مغلقة';

  @override
  String get visitAnimals => 'حيوانات الزيارة';

  @override
  String get farmName => 'اسم المزرعة';

  @override
  String get enterAsDoctor => 'دخول كطبيب (مسح رمز الزيارة)';

  @override
  String get doctorScanTitle => 'امسح رمز الزيارة';

  @override
  String get tileFarmers => 'الرعاة';

  @override
  String get tileDoctors => 'زيارات الأطباء';

  @override
  String get addFarmer => 'إضافة راعٍ';

  @override
  String get tempPassword => 'كلمة مرور مؤقتة';

  @override
  String get remove => 'إزالة';

  @override
  String get roleAdmin => 'مسؤول';

  @override
  String get membersEmpty => 'لا يوجد رعاة بعد';

  @override
  String get newDoctorVisit => 'زيارة طبيب جديدة';

  @override
  String get doctorName => 'اسم الطبيب';

  @override
  String get createInvite => 'إنشاء رمز الزيارة';

  @override
  String get inviteShowQr => 'اعرض هذا الرمز للطبيب';

  @override
  String get inviteScanHint => 'يفتح الطبيب التطبيق ويضغط «أنا طبيب» ثم يمسح الرمز';

  @override
  String get endAccess => 'إنهاء الوصول';

  @override
  String get inviteActive => 'نشطة';

  @override
  String get inviteEnded => 'منتهية';

  @override
  String get invitesEmpty => 'لا توجد زيارات أطباء بعد';

  @override
  String get doctorBadge => 'طبيب';

  @override
  String notesWritten(int count) {
    return '$count ملاحظة';
  }

  @override
  String get confirmRemove => 'إزالة هذا الراعي؟';

  @override
  String get confirmEnd => 'إنهاء وصول هذا الطبيب؟';

  @override
  String get choosePlan => 'اختر الخطة';

  @override
  String get planMonthly => 'شهري';

  @override
  String get planYearly => 'سنوي';

  @override
  String amountEgp(int amount) {
    return '$amount ج.م';
  }

  @override
  String get payToLabel => 'حوّل إلى';

  @override
  String get copy => 'نسخ';

  @override
  String get copied => 'تم النسخ';

  @override
  String get paywallStep => 'حوّل المبلغ على إنستاباي ثم الصق رقم العملية';

  @override
  String get referenceLabel => 'رقم العملية';

  @override
  String get screenshotOptional => 'رابط صورة الإيصال (اختياري)';

  @override
  String get submitPayment => 'إرسال للمراجعة';

  @override
  String get underReview => 'قيد المراجعة';

  @override
  String get underReviewBody => 'سيتم تفعيل اشتراكك بعد التأكد من التحويل';

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
