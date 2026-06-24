import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Doctor entry (farm refactor): scan the QR the farm admin shows → redeem it for
/// a temporary, farm-scoped session. No account is created. When the admin ends
/// the invite, the doctor's next request fails and they're bounced to login.
class DoctorRedeemScreen extends ConsumerStatefulWidget {
  const DoctorRedeemScreen({super.key});

  @override
  ConsumerState<DoctorRedeemScreen> createState() => _DoctorRedeemScreenState();
}

class _DoctorRedeemScreenState extends ConsumerState<DoctorRedeemScreen> {
  final MobileScannerController _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && v.isNotEmpty) {
        _redeem(v);
        return;
      }
    }
  }

  Future<void> _redeem(String token) async {
    final t = L10n.of(context);
    setState(() => _busy = true);
    await _controller.stop();
    try {
      await ref.read(sessionControllerProvider.notifier).redeemDoctor(token);
      // Router redirect takes over once the doctor session is live.
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorText(t, e))));
      setState(() => _busy = false);
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.doctorScanTitle),
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s24),
                child: Text(t.errGeneric,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(AppTokens.rTile),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.s16, vertical: AppTokens.s8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppTokens.rTile),
                ),
                child: Text(t.inviteShowQr,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ),
          if (_busy)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
