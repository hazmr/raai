import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// How many consecutive frames must decode the SAME value before we accept it.
/// A single misread can't survive this — it breaks the streak — so the tag we act
/// on is the one the camera read identically several times in a row.
const int _kConsensusFrames = 3;

/// The matching value must also persist at least this long, so a value that just
/// flickered through for a couple of fast frames can't trip the consensus.
const int _kMinDwellMs = 350;

/// Reasonable bound on tag length — rejects absurd payloads outright.
const int _kMaxTagLen = 18;

/// Ear tags from `qr_grid.py` encode a plain number. We only accept numeric
/// payloads, so a stray QR/barcode in view is ignored rather than acted on.
final RegExp _kTagPattern = RegExp(r'^\d+$');

enum _ScanAction { open, add, rescan }

/// Scan (§5.4) — built to be *sure* of the tag before acting:
/// 1. accept a value only after [_kConsensusFrames] identical decodes,
/// 2. accept only numeric tags ([_kTagPattern]),
/// 3. then **pause and confirm**: show the number big + whether it's in the herd,
///    so the user verifies it against the number printed on the tag before any
///    navigation or create. A keyboard button gives a manual fallback.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final MobileScannerController _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  String? _candidate; // value currently building consensus
  int _streak = 0;
  DateTime? _since; // when the current candidate first appeared (dwell check)
  bool _multiple = false; // >1 distinct tag visible → ambiguous, refuse to lock
  bool _busy = false; // paused for lookup/confirm/navigation

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;

    // Keep only valid numeric tags of a sane length from this frame.
    final tags = <String>{};
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null &&
          _kTagPattern.hasMatch(v) &&
          v.length <= _kMaxTagLen) {
        tags.add(v);
      }
    }

    // DOUBLE-CHECK: if more than one distinct tag is in view (e.g. aiming at a
    // printed sheet), refuse to lock onto any of them — the user must isolate one.
    if (tags.length > 1) {
      setState(() {
        _multiple = true;
        _candidate = null;
        _streak = 0;
        _since = null;
      });
      return;
    }
    if (tags.isEmpty) return; // nothing usable this frame; keep current streak

    final raw = tags.first;
    final now = DateTime.now();
    if (raw == _candidate) {
      _streak++;
    } else {
      _candidate = raw;
      _streak = 1;
      _since = now;
    }
    setState(() => _multiple = false); // refresh live readout

    // Accept only after enough identical frames AND enough elapsed time.
    final dwelled = _since != null && now.difference(_since!).inMilliseconds >= _kMinDwellMs;
    if (_streak >= _kConsensusFrames && dwelled) _onStable(raw);
  }

  /// A value has been read consistently. Pause, look it up, and confirm with the
  /// user before doing anything.
  Future<void> _onStable(String code) async {
    final t = L10n.of(context);
    setState(() => _busy = true);
    await _controller.stop();
    try {
      final page = await ref.read(apiProvider).animals(barcode: code);
      if (!mounted) return;
      final existing = page.data.isEmpty ? null : page.data.first;
      final action = await _confirm(code, existing);
      if (!mounted) return;
      switch (action) {
        case _ScanAction.open:
          await context.push('/animals/${existing!.id}', extra: existing);
        case _ScanAction.add:
          await context.push<bool>('/animals/new', extra: code);
        case _ScanAction.rescan:
        case null:
          break; // just resume scanning
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(t, e))));
      }
    } finally {
      if (mounted) {
        setState(() {
          _candidate = null;
          _streak = 0;
          _since = null;
          _multiple = false;
          _busy = false;
        });
        await _controller.start();
      }
    }
  }

  /// The "are you 1000% sure" gate: shows the decoded number prominently so the
  /// user can compare it to the number printed under the QR before proceeding.
  Future<_ScanAction?> _confirm(String code, Animal? existing) {
    final t = L10n.of(context);
    return showModalBottomSheet<_ScanAction>(
      context: context,
      backgroundColor: AppTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rTile)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.scanConfirmTitle,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.labelSmall),
            const SizedBox(height: AppTokens.s8),
            // The decoded number, big, for eyeball verification.
            Text(code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textPrimary)),
            const SizedBox(height: AppTokens.s4),
            Text(t.scanCheckNumber,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.labelSmall),
            const SizedBox(height: AppTokens.s16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(existing != null ? Icons.check_circle : Icons.info_outline,
                    size: 18,
                    color: existing != null ? AppTokens.success : AppTokens.warning),
                const SizedBox(width: AppTokens.s8),
                Text(
                  existing != null
                      ? '${t.scanInHerd} · ${t.noteCountLabel(existing.noteCount)}'
                      : t.scanNotInHerd,
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: AppTokens.s24),
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(
                  existing != null ? _ScanAction.open : _ScanAction.add),
              icon: Icon(existing != null ? Icons.visibility : Icons.add),
              label: Text(existing != null ? t.open : t.addAnimal),
            ),
            const SizedBox(height: AppTokens.s8),
            TextButton.icon(
              onPressed: () => Navigator.of(ctx).pop(_ScanAction.rescan),
              icon: const Icon(Icons.refresh),
              label: Text(t.rescan),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manualEntry() async {
    final t = L10n.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.scanManualTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: t.barcode),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(t.scanLookup),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) _onStable(code);
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.tileScan),
        actions: [
          IconButton(
            tooltip: t.scanManualTitle,
            onPressed: _manualEntry,
            icon: const Icon(Icons.keyboard),
          ),
          IconButton(
            tooltip: 'Torch',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _CameraError(onManual: _manualEntry),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _multiple
                        ? AppTokens.warning
                        : (_streak > 0 ? AppTokens.success : Colors.white),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(AppTokens.rTile),
                ),
              ),
            ),
          ),
          // Live feedback: hint, or the value being verified with its n/3 progress.
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
                child: Text(
                  _multiple
                      ? t.scanMultiple
                      : (_candidate == null
                          ? t.scanHoldSteady
                          : '$_candidate  ($_streak/$_kConsensusFrames)'),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
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

class _CameraError extends StatelessWidget {
  const _CameraError({required this.onManual});
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, size: 48, color: Colors.white70),
              const SizedBox(height: AppTokens.s12),
              Text(t.errGeneric,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: AppTokens.s16),
              FilledButton.icon(
                onPressed: onManual,
                icon: const Icon(Icons.keyboard),
                label: Text(t.scanManualTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
