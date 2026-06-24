import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Raai'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get register;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @roleFarmer.
  ///
  /// In en, this message translates to:
  /// **'Herder'**
  String get roleFarmer;

  /// No description provided for @roleVet.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get roleVet;

  /// No description provided for @roleQuestion.
  ///
  /// In en, this message translates to:
  /// **'I am a'**
  String get roleQuestion;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @needAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get needAccount;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get haveAccount;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get homeGreeting;

  /// No description provided for @tileHerd.
  ///
  /// In en, this message translates to:
  /// **'Herd'**
  String get tileHerd;

  /// No description provided for @tileScan.
  ///
  /// In en, this message translates to:
  /// **'Scan tag'**
  String get tileScan;

  /// No description provided for @tileNewVisit.
  ///
  /// In en, this message translates to:
  /// **'New visit'**
  String get tileNewVisit;

  /// No description provided for @tileOpenVisits.
  ///
  /// In en, this message translates to:
  /// **'Open visits'**
  String get tileOpenVisits;

  /// No description provided for @tileSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get tileSubscription;

  /// No description provided for @herdCount.
  ///
  /// In en, this message translates to:
  /// **'{count} head'**
  String herdCount(int count);

  /// No description provided for @subscriptionActive.
  ///
  /// In en, this message translates to:
  /// **'Subscription active'**
  String get subscriptionActive;

  /// No description provided for @subscriptionExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get subscriptionExpiring;

  /// No description provided for @subscriptionLapsed.
  ///
  /// In en, this message translates to:
  /// **'Subscription needed'**
  String get subscriptionLapsed;

  /// No description provided for @renewsOn.
  ///
  /// In en, this message translates to:
  /// **'Renews {date}'**
  String renewsOn(String date);

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @searchByTag.
  ///
  /// In en, this message translates to:
  /// **'Search by ear tag'**
  String get searchByTag;

  /// No description provided for @herdEmpty.
  ///
  /// In en, this message translates to:
  /// **'No animals yet'**
  String get herdEmpty;

  /// No description provided for @addAnimal.
  ///
  /// In en, this message translates to:
  /// **'Add animal'**
  String get addAnimal;

  /// No description provided for @barcode.
  ///
  /// In en, this message translates to:
  /// **'Ear-tag number'**
  String get barcode;

  /// No description provided for @noteCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String noteCountLabel(int count);

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get notesTitle;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmpty;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @vetBadge.
  ///
  /// In en, this message translates to:
  /// **'Vet'**
  String get vetBadge;

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'Write the note'**
  String get noteHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @tplVaccination.
  ///
  /// In en, this message translates to:
  /// **'Vaccination'**
  String get tplVaccination;

  /// No description provided for @tplCheckup.
  ///
  /// In en, this message translates to:
  /// **'Checkup'**
  String get tplCheckup;

  /// No description provided for @tplTreatment.
  ///
  /// In en, this message translates to:
  /// **'Treatment'**
  String get tplTreatment;

  /// No description provided for @tplBirth.
  ///
  /// In en, this message translates to:
  /// **'Birth'**
  String get tplBirth;

  /// No description provided for @scanManualTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter ear-tag number'**
  String get scanManualTitle;

  /// No description provided for @scanLookup.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get scanLookup;

  /// No description provided for @animalNotFoundAdd.
  ///
  /// In en, this message translates to:
  /// **'Tag not found. Add this animal?'**
  String get animalNotFoundAdd;

  /// No description provided for @scanHoldSteady.
  ///
  /// In en, this message translates to:
  /// **'Hold steady on the code'**
  String get scanHoldSteady;

  /// No description provided for @scanMultiple.
  ///
  /// In en, this message translates to:
  /// **'More than one tag in view — move closer to just one'**
  String get scanMultiple;

  /// No description provided for @scanConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm this tag'**
  String get scanConfirmTitle;

  /// No description provided for @scanInHerd.
  ///
  /// In en, this message translates to:
  /// **'In your herd'**
  String get scanInHerd;

  /// No description provided for @scanNotInHerd.
  ///
  /// In en, this message translates to:
  /// **'Not in your herd'**
  String get scanNotInHerd;

  /// No description provided for @scanCheckNumber.
  ///
  /// In en, this message translates to:
  /// **'Check it matches the number printed on the tag'**
  String get scanCheckNumber;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @rescan.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get rescan;

  /// No description provided for @visitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get visitsTitle;

  /// No description provided for @locationType.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get locationType;

  /// No description provided for @locClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinic'**
  String get locClinic;

  /// No description provided for @locFarm.
  ///
  /// In en, this message translates to:
  /// **'Farm'**
  String get locFarm;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location label (optional)'**
  String get locationLabel;

  /// No description provided for @vetPhone.
  ///
  /// In en, this message translates to:
  /// **'Vet phone (optional)'**
  String get vetPhone;

  /// No description provided for @openVisit.
  ///
  /// In en, this message translates to:
  /// **'Open visit'**
  String get openVisit;

  /// No description provided for @closeVisit.
  ///
  /// In en, this message translates to:
  /// **'Close visit'**
  String get closeVisit;

  /// No description provided for @visitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No visits'**
  String get visitsEmpty;

  /// No description provided for @openVisitsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No open visits'**
  String get openVisitsEmpty;

  /// No description provided for @visitOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get visitOpen;

  /// No description provided for @visitClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get visitClosed;

  /// No description provided for @visitAnimals.
  ///
  /// In en, this message translates to:
  /// **'Visit animals'**
  String get visitAnimals;

  /// No description provided for @farmName.
  ///
  /// In en, this message translates to:
  /// **'Farm name'**
  String get farmName;

  /// No description provided for @enterAsDoctor.
  ///
  /// In en, this message translates to:
  /// **'Enter as a doctor (scan visit QR)'**
  String get enterAsDoctor;

  /// No description provided for @doctorScanTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan the visit QR'**
  String get doctorScanTitle;

  /// No description provided for @tileFarmers.
  ///
  /// In en, this message translates to:
  /// **'Farmers'**
  String get tileFarmers;

  /// No description provided for @tileDoctors.
  ///
  /// In en, this message translates to:
  /// **'Doctor visits'**
  String get tileDoctors;

  /// No description provided for @addFarmer.
  ///
  /// In en, this message translates to:
  /// **'Add farmer'**
  String get addFarmer;

  /// No description provided for @tempPassword.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get tempPassword;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @membersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No farmers yet'**
  String get membersEmpty;

  /// No description provided for @newDoctorVisit.
  ///
  /// In en, this message translates to:
  /// **'New doctor visit'**
  String get newDoctorVisit;

  /// No description provided for @doctorName.
  ///
  /// In en, this message translates to:
  /// **'Doctor name'**
  String get doctorName;

  /// No description provided for @createInvite.
  ///
  /// In en, this message translates to:
  /// **'Create visit QR'**
  String get createInvite;

  /// No description provided for @inviteShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show this QR to the doctor'**
  String get inviteShowQr;

  /// No description provided for @inviteScanHint.
  ///
  /// In en, this message translates to:
  /// **'The doctor opens the app, taps \"I\'m a doctor\", and scans it'**
  String get inviteScanHint;

  /// No description provided for @endAccess.
  ///
  /// In en, this message translates to:
  /// **'End access'**
  String get endAccess;

  /// No description provided for @inviteActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get inviteActive;

  /// No description provided for @inviteEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get inviteEnded;

  /// No description provided for @invitesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No doctor visits yet'**
  String get invitesEmpty;

  /// No description provided for @doctorBadge.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get doctorBadge;

  /// No description provided for @notesWritten.
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String notesWritten(int count);

  /// No description provided for @confirmRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove this farmer?'**
  String get confirmRemove;

  /// No description provided for @confirmEnd.
  ///
  /// In en, this message translates to:
  /// **'End this doctor\'s access?'**
  String get confirmEnd;

  /// No description provided for @choosePlan.
  ///
  /// In en, this message translates to:
  /// **'Choose a plan'**
  String get choosePlan;

  /// No description provided for @planMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get planMonthly;

  /// No description provided for @planYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get planYearly;

  /// No description provided for @amountEgp.
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String amountEgp(int amount);

  /// No description provided for @payToLabel.
  ///
  /// In en, this message translates to:
  /// **'Send to'**
  String get payToLabel;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @paywallStep.
  ///
  /// In en, this message translates to:
  /// **'Send the amount on InstaPay, then paste the reference'**
  String get paywallStep;

  /// No description provided for @referenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference number'**
  String get referenceLabel;

  /// No description provided for @screenshotOptional.
  ///
  /// In en, this message translates to:
  /// **'Screenshot URL (optional)'**
  String get screenshotOptional;

  /// No description provided for @submitPayment.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get submitPayment;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get underReview;

  /// No description provided for @underReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Your subscription activates once the transfer is confirmed'**
  String get underReviewBody;

  /// No description provided for @errOffline.
  ///
  /// In en, this message translates to:
  /// **'No connection — try again'**
  String get errOffline;

  /// No description provided for @errSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session ended — please log in again'**
  String get errSessionExpired;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this'**
  String get errForbidden;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found'**
  String get errNotFound;

  /// No description provided for @errAnimalNotFound.
  ///
  /// In en, this message translates to:
  /// **'Animal not found'**
  String get errAnimalNotFound;

  /// No description provided for @errConflict.
  ///
  /// In en, this message translates to:
  /// **'This already exists'**
  String get errConflict;

  /// No description provided for @errTagExists.
  ///
  /// In en, this message translates to:
  /// **'This tag is already registered'**
  String get errTagExists;

  /// No description provided for @errReceiptUsed.
  ///
  /// In en, this message translates to:
  /// **'This receipt was already used'**
  String get errReceiptUsed;

  /// No description provided for @errValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check the details'**
  String get errValidation;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many tries — wait a moment'**
  String get errRateLimited;

  /// No description provided for @errGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — try later'**
  String get errGeneric;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get fieldRequired;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordTooShort;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return L10nAr();
    case 'en': return L10nEn();
  }

  throw FlutterError(
    'L10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
