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
  String get roleFarmer => 'Herder';

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
  String get close => 'Close';

  @override
  String get searchByTag => 'Search by ear tag';

  @override
  String get herdEmpty => 'No animals yet';

  @override
  String get addAnimal => 'Add animal';

  @override
  String get barcode => 'Ear-tag number';

  @override
  String noteCountLabel(int count) {
    return '$count notes';
  }

  @override
  String get notesTitle => 'History';

  @override
  String get notesEmpty => 'No notes yet';

  @override
  String get addNote => 'Add note';

  @override
  String get vetBadge => 'Vet';

  @override
  String get noteHint => 'Write the note';

  @override
  String get send => 'Send';

  @override
  String get tplVaccination => 'Vaccination';

  @override
  String get tplCheckup => 'Checkup';

  @override
  String get tplTreatment => 'Treatment';

  @override
  String get tplBirth => 'Birth';

  @override
  String get scanManualTitle => 'Enter ear-tag number';

  @override
  String get scanLookup => 'Look up';

  @override
  String get animalNotFoundAdd => 'Tag not found. Add this animal?';

  @override
  String get scanHoldSteady => 'Hold steady on the code';

  @override
  String get scanMultiple => 'More than one tag in view — move closer to just one';

  @override
  String get scanConfirmTitle => 'Confirm this tag';

  @override
  String get scanInHerd => 'In your herd';

  @override
  String get scanNotInHerd => 'Not in your herd';

  @override
  String get scanCheckNumber => 'Check it matches the number printed on the tag';

  @override
  String get open => 'Open';

  @override
  String get rescan => 'Rescan';

  @override
  String get visitsTitle => 'Visits';

  @override
  String get locationType => 'Location';

  @override
  String get locClinic => 'Clinic';

  @override
  String get locFarm => 'Farm';

  @override
  String get locationLabel => 'Location label (optional)';

  @override
  String get vetPhone => 'Vet phone (optional)';

  @override
  String get openVisit => 'Open visit';

  @override
  String get closeVisit => 'Close visit';

  @override
  String get visitsEmpty => 'No visits';

  @override
  String get openVisitsEmpty => 'No open visits';

  @override
  String get visitOpen => 'Open';

  @override
  String get visitClosed => 'Closed';

  @override
  String get visitAnimals => 'Visit animals';

  @override
  String get farmName => 'Farm name';

  @override
  String get enterAsDoctor => 'Enter as a doctor (scan visit QR)';

  @override
  String get doctorScanTitle => 'Scan the visit QR';

  @override
  String get tileFarmers => 'Farmers';

  @override
  String get tileDoctors => 'Doctor visits';

  @override
  String get addFarmer => 'Add farmer';

  @override
  String get tempPassword => 'Temporary password';

  @override
  String get remove => 'Remove';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get membersEmpty => 'No farmers yet';

  @override
  String get newDoctorVisit => 'New doctor visit';

  @override
  String get doctorName => 'Doctor name';

  @override
  String get createInvite => 'Create visit QR';

  @override
  String get inviteShowQr => 'Show this QR to the doctor';

  @override
  String get inviteScanHint => 'The doctor opens the app, taps \"I\'m a doctor\", and scans it';

  @override
  String get endAccess => 'End access';

  @override
  String get inviteActive => 'Active';

  @override
  String get inviteEnded => 'Ended';

  @override
  String get invitesEmpty => 'No doctor visits yet';

  @override
  String get doctorBadge => 'Doctor';

  @override
  String notesWritten(int count) {
    return '$count notes';
  }

  @override
  String get confirmRemove => 'Remove this farmer?';

  @override
  String get confirmEnd => 'End this doctor\'s access?';

  @override
  String get choosePlan => 'Choose a plan';

  @override
  String get planMonthly => 'Monthly';

  @override
  String get planYearly => 'Yearly';

  @override
  String amountEgp(int amount) {
    return '$amount EGP';
  }

  @override
  String get payToLabel => 'Send to';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get paywallStep => 'Send the amount on InstaPay, then paste the reference';

  @override
  String get referenceLabel => 'Reference number';

  @override
  String get screenshotOptional => 'Screenshot URL (optional)';

  @override
  String get submitPayment => 'Submit for review';

  @override
  String get underReview => 'Under review';

  @override
  String get underReviewBody => 'Your subscription activates once the transfer is confirmed';

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
