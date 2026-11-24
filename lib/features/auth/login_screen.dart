import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/repositories/repository_providers.dart';
import '../../services/auth/auth_service.dart';

/// `highfi/03-login.png`
///
/// The account screen. Signing in is optional — the brief requires the
/// "Continue as guest" path to stay open. Signed-in students get their
/// schedule synced across devices via Firestore; guests keep everything
/// on the device only.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _identity = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _signUpMode = false;
  bool _passwordVisible = false;
  bool _busy = false;
  String? _error;

  AuthService get _auth => ref.read(authServiceProvider);

  @override
  void dispose() {
    _identity.dispose();
    _password.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _auth.describeError(e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  bool _validate() {
    if (_identity.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your ID/email and password.');
      return false;
    }
    if (_signUpMode && _password.text.length < 6) {
      setState(() => _error = 'Password needs at least 6 characters.');
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) {
      return;
    }
    final auth = _auth;
    final identity = _identity.text;
    final password = _password.text;
    await _run(() async {
      if (_signUpMode) {
        await auth.signUp(identity, password);
      } else {
        await auth.signIn(identity, password);
      }
      // Pull the account's schedule, or upload this device's on first sign-in.
      await ref.read(scheduleProvider.notifier).syncWithRemote();
      if (mounted) {
        context.go('/home');
      }
    });
  }

  Future<void> _sendReset() async {
    if (_identity.text.trim().isEmpty) {
      setState(() => _error = 'Enter your ID/email above first.');
      return;
    }
    final identity = _identity.text;
    await _run(() async {
      await _auth.sendPasswordReset(identity);
      if (mounted) {
        _showSnack(
          'If that account exists, a reset link is on its way to your email.',
        );
      }
    });
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?', style: AppTypography.cardTitle),
        content: const Text(
          'Your schedule stays on this device. Sign back in anytime to '
          'sync it again.',
          style: AppTypography.cardBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _run(() async {
      await _auth.signOut();
      if (mounted) {
        setState(() => _signUpMode = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: user == null ? _buildSignInForm() : _buildAccountCard(user),
        ),
      ),
    );
  }

  Widget _buildAccountCard(User user) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const CampusNavLogo(size: 120),
        const SizedBox(height: AppSpacing.lg),
        const Text('CAMPUS NAV', style: AppTypography.wordMark),
        const SizedBox(height: AppSpacing.xl),
        const CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryDeep,
          child: Icon(Icons.person, size: 36, color: Colors.white),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          user.email?.replaceAll('@${AuthService.studentEmailDomain}', '') ??
              'Signed in',
          style: AppTypography.cardTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Row(
            children: [
              const IconTile(icon: Icons.sync),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Synced schedule', style: AppTypography.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      'Your classes are backed up to this account and '
                      'follow you to any device.',
                      style: AppTypography.cardBody,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: 256,
          child: PillButton(
            label: 'Sign out',
            variant: PillButtonVariant.primary,
            onPressed: _busy ? null : _signOut,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Text(
            'Back to Home',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              color: AppColors.onCanvas,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildSignInForm() {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xxl),
        const CampusNavLogo(size: 140),
        const SizedBox(height: AppSpacing.lg),
        const Text(
          'CAMPUS NAV',
          style: AppTypography.wordMark,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          _signUpMode ? 'Create your account' : 'Welcome Back!',
          style: TextStyle(
            fontFamily: AppTypography.family,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onCanvas,
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppTextField(
          controller: _identity,
          hintText: _signUpMode ? 'Email or student ID' : 'Email or student ID',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _password,
          hintText: _signUpMode ? 'Choose a password' : 'Password',
          obscureText: !_passwordVisible,
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _passwordVisible = !_passwordVisible),
            tooltip: _passwordVisible ? 'Hide password' : 'Show password',
            icon: Icon(
              _passwordVisible ? Icons.visibility_off : Icons.visibility,
              color: AppColors.inkMuted,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _error!,
            style: AppTypography.caption.copyWith(color: AppColors.onCanvas),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 256,
          child: PillButton(
            label: _busy
                ? 'Please wait…'
                : (_signUpMode ? 'Sign up' : 'Log in'),
            variant: PillButtonVariant.gold,
            onPressed: _busy ? null : _submit,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: _busy ? null : _sendReset,
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              decoration: TextDecoration.underline,
              color: AppColors.onCanvas,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                  _signUpMode = !_signUpMode;
                  _error = null;
                }),
          child: Text(
            _signUpMode
                ? 'I already have an account — Log in'
                : "New student? Create an account",
            style: const TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              color: AppColors.onCanvas,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => context.go('/home'),
          child: const Text(
            'Continue as guest',
            style: TextStyle(
              fontFamily: AppTypography.family,
              fontSize: 12,
              color: AppColors.onCanvas,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
