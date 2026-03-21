// lib/REST API/screens/auth_gate.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:local_auth/local_auth.dart';

import '../../theme/app_colors.dart';
import '../../theme/typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// How long the app can be in the background before it auto-locks.
const _kLockTimeout = Duration(seconds: 15);
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps the entire widget tree and gates access behind biometric /
/// device-credential authentication.
///
/// • Authenticates on first launch.
/// • Re-locks and re-authenticates if the app has been backgrounded for
///   longer than [_kLockTimeout].
/// • Gracefully degrades: if the device has no screen lock configured the
///   app opens without asking (nothing to authenticate against).
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({required this.child, super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();

  bool _locked        = true;
  bool _authenticating = false;
  bool _deviceSupported = true; // assume supported until we know otherwise
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuthenticate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt = DateTime.now();
      case AppLifecycleState.resumed:
        if (!_locked && _backgroundedAt != null) {
          final away = DateTime.now().difference(_backgroundedAt!);
          if (away >= _kLockTimeout) {
            setState(() => _locked = true);
            _tryAuthenticate();
          }
        }
        _backgroundedAt = null;
      default:
        break;
    }
  }

  Future<void> _tryAuthenticate() async {
    if (_authenticating || !_locked) return;
    _authenticating = true;

    try {
      // Check whether the device has any screen-lock protection at all.
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        // No lock screen configured — unlock silently.
        if (mounted) setState(() { _locked = false; _deviceSupported = false; });
        return;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Unlock Comic Vault to access your collection',
        options: const AuthenticationOptions(
          biometricOnly: false,  // also accepts PIN / pattern / password
          stickyAuth: true,      // keep prompt alive if user switches apps
        ),
      );

      if (mounted && authenticated) setState(() => _locked = false);
    } catch (_) {
      // Authentication error (e.g. hardware unavailable) — keep locked
      // so the user can tap the retry button.
    } finally {
      _authenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return _LockScreen(onUnlock: _tryAuthenticate);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lock screen UI
// ─────────────────────────────────────────────────────────────────────────────

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lock icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textSecondary,
                    size: 38,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: 32),

                Text(
                  'Comic Vault',
                  style: tDisplay(28,
                      color: AppColors.textPrimary,
                      weight: FontWeight.w700,
                      letterSpacing: -0.5),
                )
                    .animate(delay: 80.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.15, duration: 400.ms, curve: Curves.easeOutCubic),

                const SizedBox(height: 8),

                Text(
                  'Your collection is locked',
                  style: tUi(14,
                      color: AppColors.textSecondary,
                      weight: FontWeight.w400),
                )
                    .animate(delay: 120.ms)
                    .fadeIn(duration: 400.ms),

                const SizedBox(height: 56),

                // Unlock button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onUnlock,
                    icon: const Icon(Icons.fingerprint_rounded, size: 22),
                    label: Text(
                      'Unlock',
                      style: tUi(15, weight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.surface1,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: AppColors.border.withOpacity(0.6))),
                    ),
                  ),
                )
                    .animate(delay: 180.ms)
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
