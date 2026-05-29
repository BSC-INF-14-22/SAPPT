import 'package:flutter/material.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/core/services/language_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final _identifierController =
      TextEditingController(); // Can be email or phone
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isChichewa =>
      LanguageService.currentLanguage == AppLanguage.chichewa;

  String _text(String english, String chichewa) {
    return _isChichewa ? chichewa : english;
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String identifier = _identifierController.text.trim();
    String password = _passwordController.text.trim();
    String? emailToSignIn = identifier;

    try {
      // 1. Check if identifier is a phone number, allowing spaces/dashes.
      final phoneDigits = identifier.replaceAll(RegExp(r'\D'), '');
      bool isPhone = !identifier.contains('@') &&
          RegExp(r'^[\+\d\s\-\(\)]{7,24}$').hasMatch(identifier) &&
          phoneDigits.length >= 7 &&
          phoneDigits.length <= 15;

      if (isPhone) {
        // Find email associated with this phone number before Firebase login.
        final indexedEmail = await FirestoreService().getEmailByPhone(
          identifier,
        );
        if (indexedEmail != null) {
          emailToSignIn = indexedEmail;
        } else {
          final userData = await FirestoreService().getUserByPhone(identifier);
          if (userData != null && userData['email'] != null) {
            emailToSignIn = userData['email'];
          } else if (userData != null) {
            throw Exception(
              _text(
                'This phone number exists, but it is not linked to an email/password account. Please sign in with email or reset the account.',
                'Nambala iyi ilipo, koma siyolumikizidwa ndi akaunti ya imelo/mawu achinsinsi. Chonde lowani ndi imelo kapena konzani akauntiyi.',
              ),
            );
          } else {
            throw Exception(
              _text(
                'No account found with this phone number. Please sign in once with email, or ask admin to update the phone login index.',
                'Palibe akaunti yomwe yapezeka ndi nambala iyi. Lowani kamodzi ndi imelo, kapena funsani admin akonze phone login index.',
              ),
            );
          }
        }
      }

      // 2. Sign in with Email and Password
      await AuthService().signIn(email: emailToSignIn!, password: password);

      // 3. Enforce approval for Cooperative Officers
      final uid = AuthService().currentUser?.uid;
      if (uid == null) {
        throw Exception('Unable to determine user after sign-in.');
      }

      final userData = await FirestoreService().getUserByUid(uid);
      if (userData != null && userData['role'] == 'Cooperative Officer') {
        final approved = userData['approved'] == true;
        if (!approved) {
          // Prevent login until admin approves
          await AuthService().signOut();
          throw Exception(
            _text(
              'Your cooperative account is pending admin approval. You will be notified once approved.',
              'Akaunti yanu ya cooperative ikuyembekezera kuvomerezedwa ndi admin. Mudziwitsidwa ikavomerezedwa.',
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRouter.home);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty || !identifier.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'Please enter your email to reset password',
              'Chonde lembani imelo kuti musinthe mawu achinsinsi',
            ),
          ),
        ),
      );
      return;
    }

    try {
      await AuthService().sendPasswordResetEmail(identifier);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                'Password reset email sent!',
                'Imelo yosinthira mawu achinsinsi yatumizidwa!',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _loginFormKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.eco, size: 80, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 24),
                  Text(
                    _text('Welcome Back', 'Takulandirani'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      'Login to your SAPPT account',
                      'Lowani mu akaunti yanu ya SAPPT',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Email or Phone Field
                  TextFormField(
                    controller: _identifierController,
                    decoration: InputDecoration(
                      labelText: _text(
                        'Email or Phone Number',
                        'Imelo kapena Nambala ya Foni',
                      ),
                      hintText: _text(
                        'e.g. user@email.com or +265...',
                        'monga user@email.com kapena +265...',
                      ),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _text(
                          'Please enter email or phone',
                          'Chonde lembani imelo kapena foni',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: _text('Password', 'Mawu Achinsinsi'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _text(
                          'Please enter your password',
                          'Chonde lembani mawu achinsinsi',
                        );
                      }
                      if (value.length < 6) {
                        return _text(
                          'Password too short',
                          'Mawu achinsinsi ndi afupi kwambiri',
                        );
                      }
                      return null;
                    },
                  ),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _handleForgotPassword,
                      child: Text(
                        _text('Forgot Password?', 'Mwayiwala Mawu Achinsinsi?'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Loading Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _text('LOGIN', 'LOWANI'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_text('Don\'t have an account?', 'Mulibe akaunti?')),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRouter.register),
                        child: Text(_text('Sign Up', 'Lembetsani')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
