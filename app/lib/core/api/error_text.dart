import '../../l10n/app_localizations.dart';
import 'api_exception.dart';

/// Where a conflict/not-found happened, so the same code maps to a specific line
/// (§6.2). The server message is never shown — only these localized strings.
enum ErrorContext { generic, animalTag, receipt }

/// Maps an [ApiException] to ONE short, friendly, localized sentence (§6.2).
/// `401` (refresh) and `402` (paywall) are handled by interceptor/router and
/// normally never reach here; they fall back to sensible text if they do.
String errorText(L10n t, ApiException e, {ErrorContext ctx = ErrorContext.generic}) {
  if (e.isOffline) return t.errOffline;

  switch (e.status) {
    case 401:
      return t.errSessionExpired;
    case 403:
      return t.errForbidden;
    case 404:
      return ctx == ErrorContext.animalTag ? t.errAnimalNotFound : t.errNotFound;
    case 409:
      switch (ctx) {
        case ErrorContext.animalTag:
          return t.errTagExists;
        case ErrorContext.receipt:
          return t.errReceiptUsed;
        case ErrorContext.generic:
          return t.errConflict;
      }
    case 422:
      return t.errValidation;
    case 429:
      return t.errRateLimited;
    default:
      return t.errGeneric; // 400 / 500 / unknown — never leak the server string
  }
}
