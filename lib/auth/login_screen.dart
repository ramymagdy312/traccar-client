import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bg;
import 'package:serb_tracker_client/main.dart';
import 'package:serb_tracker_client/preferences.dart';

import '../l10n/app_localizations.dart';
import 'auth_api.dart';
import 'session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onLoginSuccess});

  final VoidCallback? onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final token = await AuthApi().login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      await SessionManager.saveLoginSession(
        accessToken: token.accessToken,
        expiresInSeconds: token.expiresIn,
      );
      final repId = token.repId ?? token.userId;
      if (repId != null) {
        await Preferences.instance.setString(Preferences.id, repId.toString());
        await bg.BackgroundGeolocation.setConfig(Preferences.geolocationConfig(true));
      }
      final username = token.userName;
      if (username != null && username.isNotEmpty) {
        await Preferences.instance.setString(Preferences.username, username);
      }
      await Preferences.instance.setString(
        Preferences.roles,
        token.roles.join(','),
      );
      if (!mounted) return;
      final onSuccess = widget.onLoginSuccess;
      if (onSuccess != null) {
        onSuccess();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      final l = AppLocalizations.of(context)!;
      final message =
          e is InvalidCredentialsException
              ? l.invalidCredentials
              : e.toString().replaceFirst('Exception: ', '');
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/app_icon.png',
                          width: 100,
                          height: 100,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppLocalizations.of(context)!.loginTitle,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppLocalizations.of(context)!.loginSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Spacer(flex: 1),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.1),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: _usernameController,
                                  autofillHints: const [AutofillHints.username],
                                  decoration: InputDecoration(
                                    labelText:
                                        AppLocalizations.of(
                                          context,
                                        )!.usernameLabel,
                                    hintText:
                                        AppLocalizations.of(
                                          context,
                                        )!.usernameHint,
                                    prefixIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator:
                                      (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? AppLocalizations.of(
                                                context,
                                              )!.requiredField
                                              : null,
                                  enabled: !_loading,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText:
                                        AppLocalizations.of(
                                          context,
                                        )!.passwordLabel,
                                    hintText:
                                        AppLocalizations.of(
                                          context,
                                        )!.passwordHint,
                                    prefixIcon: Icon(
                                      Icons.lock_outline_rounded,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onPressed:
                                          () => setState(
                                            () =>
                                                _obscurePassword =
                                                    !_obscurePassword,
                                          ),
                                    ),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.primary,
                                        width: 2,
                                      ),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: colorScheme.error,
                                      ),
                                    ),
                                  ),
                                  textInputAction: TextInputAction.done,
                                  validator:
                                      (v) =>
                                          (v == null || v.isEmpty)
                                              ? AppLocalizations.of(
                                                context,
                                              )!.requiredField
                                              : null,
                                  enabled: !_loading,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                                const SizedBox(height: 24),
                                FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child:
                                      _loading
                                          ? SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.onPrimary,
                                            ),
                                          )
                                          : Text(
                                            AppLocalizations.of(
                                              context,
                                            )!.loginButton,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
