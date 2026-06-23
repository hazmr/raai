import 'app_localizations.dart';

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Raai';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Create account';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get password => 'Password';

  @override
  String get roleFarmer => 'Farmer';

  @override
  String get roleVet => 'Vet';

  @override
  String get roleQuestion => 'I am a';

  @override
  String get signIn => 'Sign in';

  @override
  String get createAccount => 'Create account';

  @override
  String get needAccount => 'New here? Create an account';

  @override
  String get haveAccount => 'Already have an account? Log in';

  @override
  String get homeGreeting => 'Welcome';

  @override
  String get tileHerd => 'Herd';

  @override
  String get tileScan => 'Scan tag';

  @override
  String get tileNewVisit => 'New visit';

  @override
  String get tileOpenVisits => 'Open visits';

  @override
  String get tileSubscription => 'Subscription';

  @override
  String herdCount(int count) {
    return '$count head';
  }

  @override
  String get subscriptionActive => 'Subscription active';

  @override
  String get subscriptionExpiring => 'Expiring soon';

  @override
  String get subscriptionLapsed => 'Subscription needed';

  @override
  String renewsOn(String date) {
    return 'Renews $date';
  }

  @override
  String get logout => 'Log out';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get search => 'Search';

  @override
  String get loading => 'Loading…';

  @override
  String get errOffline => 'No connection — try again';

  @override
  String get errSessionExpired => 'Your session ended — please log in again';

  @override
  String get errForbidden => 'You don\'t have access to this';

  @override
  String get errNotFound => 'Not found';

  @override
  String get errAnimalNotFound => 'Animal not found';

  @override
  String get errConflict => 'This already exists';

  @override
  String get errTagExists => 'This tag is already registered';

  @override
  String get errReceiptUsed => 'This receipt was already used';

  @override
  String get errValidation => 'Please check the details';

  @override
  String get errRateLimited => 'Too many tries — wait a moment';

  @override
  String get errGeneric => 'Something went wrong — try later';

  @override
  String get fieldRequired => 'Required';

  @override
  String get passwordTooShort => 'At least 6 characters';
}
