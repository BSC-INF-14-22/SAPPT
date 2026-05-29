import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_agri_price_tracker/core/services/auth_service.dart';
import 'package:smart_agri_price_tracker/core/services/firestore_service.dart';
import 'package:smart_agri_price_tracker/core/services/language_service.dart';
import 'package:smart_agri_price_tracker/core/services/notification_service.dart';
import 'package:smart_agri_price_tracker/core/routing/app_router.dart';
import 'package:smart_agri_price_tracker/features/auth/domain/validators.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _registerFormKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'Farmer';
  String _selectedDistrict = 'Lilongwe';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _roles = ['Farmer', 'Cooperative Officer', 'Admin'];
  final List<String> _districts = [
    'Lilongwe',
    'Blantyre',
    'Mzuzu',
    'Zomba',
    'Dedza',
    'Kasungu',
    'Mangochi',
    'Salima',
    'Thyolo',
    'Mulanje',
  ];

  bool get _isChichewa =>
      LanguageService.currentLanguage == AppLanguage.chichewa;

  String _text(String english, String chichewa) {
    return _isChichewa ? chichewa : english;
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'Farmer':
        return _text('Farmer', 'Mlimi');
      case 'Cooperative Officer':
        return _text('Cooperative Officer', 'Wogwira Ntchito ku Cooperative');
      case 'Admin':
        return _text('Admin', 'Admin');
      default:
        return role;
    }
  }

  String? _validatePassword(String? value) {
    final error = validatePassword(value);
    if (error == null) return null;

    switch (error) {
      case 'Enter a password':
        return _text(error, 'Lembani mawu achinsinsi');
      case 'Password must be at least 8 characters':
        return _text(error, 'Mawu achinsinsi akhale osachepera zilembo 8');
      case 'Include at least one uppercase letter':
        return _text(error, 'Ikani chilembo chimodzi chachikulu');
      case 'Include at least one lowercase letter':
        return _text(error, 'Ikani chilembo chimodzi chaching\'ono');
      case 'Include at least one number':
        return _text(error, 'Ikani nambala imodzi');
      case 'Include at least one special character':
        return _text(error, 'Ikani chizindikiro chapadera chimodzi');
      default:
        return error;
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // 1. Create Auth User
      final credential = await AuthService().signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (credential?.user != null) {
        // 2. Save Additional Data to Firestore using UID as document ID
        final isCoop = _selectedRole == 'Cooperative Officer';
        await FirestoreService().setData('users', credential!.user!.uid, {
          'uid': credential.user!.uid,
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'normalizedPhone': FirestoreService.normalizePhoneForStorage(
            _phoneController.text,
          ),
          'role': _selectedRole,
          'district': _selectedDistrict,
          'createdAt': DateTime.now().toIso8601String(),
          // Approval flags for Cooperative accounts
          'approved': isCoop ? false : true,
          'approvalStatus': isCoop ? 'pending' : 'approved',
        });
        await FirestoreService().setPhoneLoginIndex(
          phone: _phoneController.text,
          email: _emailController.text,
          uid: credential.user!.uid,
        );

        if (mounted) {
          if (isCoop) {
            // Notify Admins to approve this cooperative
            await NotificationService().sendRoleBroadcast(
              role: 'Admin',
              title: 'New Cooperative Registration',
              message:
                  '${_nameController.text.trim()} registered as a Cooperative Officer and awaits approval.',
            );

            // Sign the user out until admin approves the account
            await AuthService().signOut();

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _text(
                    'Registration successful! Awaiting admin approval.',
                    'Kulembetsa kwatheka! Kudikira kuvomerezedwa ndi admin.',
                  ),
                ),
              ),
            );
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, AppRouter.login);
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _text('Registration successful!', 'Kulembetsa kwatheka!'),
                ),
              ),
            );
            if (!mounted) return;
            Navigator.pushReplacementNamed(context, AppRouter.home);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String message = 'Registration failed: ${e.message}';
        if (e.code == 'email-already-in-use') {
          message = 'This email is already registered. Please login instead.';
        }
        if (_isChichewa) {
          message = e.code == 'email-already-in-use'
              ? 'Imelo iyi inalembedwa kale. Chonde lowani.'
              : 'Kulembetsa kwalephera: ${e.message}';
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text(
              'An unexpected error occurred: $e',
              'Vuto losayembekezereka lachitika: $e',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Using shared validators from features/auth/domain/validators.dart

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_text('Create Account', 'Pangani Akaunti')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _registerFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _text('Join SAPPT', 'Lowani SAPPT'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      'Sign up to access market data',
                      'Lembetsani kuti mupeze zambiri za misika',
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Full Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _text('Full Name', 'Dzina Lonse'),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => (value == null || value.isEmpty)
                        ? _text('Enter your full name', 'Lembani dzina lonse')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: _text('Email Address', 'Imelo'),
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => isValidEmail(value)
                        ? null
                        : _text(
                            'Enter a valid email address',
                            'Lembani imelo yolondola',
                          ),
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: _text('Phone Number', 'Nambala ya Foni'),
                      prefixIcon: const Icon(Icons.phone_android),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) => (value == null || value.isEmpty)
                        ? _text(
                            'Enter your phone number',
                            'Lembani nambala yanu ya foni',
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRole,
                    decoration: InputDecoration(
                      labelText: _text('Select Role', 'Sankhani Udindo'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    items: _roles.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(_roleLabel(role)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // District Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDistrict,
                    decoration: InputDecoration(
                      labelText: _text('Select District', 'Sankhani Boma'),
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    items: _districts.map((district) {
                      return DropdownMenuItem(
                        value: district,
                        child: Text(district),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedDistrict = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: _text('Password', 'Mawu Achinsinsi'),
                      helperText: _text(
                        'Use at least 8 chars, upper/lowercase, number, and special character',
                        'Gwiritsani zilembo 8+, zazikulu/zazing\'ono, nambala ndi chizindikiro chapadera',
                      ),
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
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(
                      labelText: _text(
                        'Confirm Password',
                        'Tsimikizani Mawu Achinsinsi',
                      ),
                      prefixIcon: const Icon(Icons.lock_reset),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: _obscureConfirmPassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return _text(
                          'Confirm your password',
                          'Tsimikizani mawu achinsinsi',
                        );
                      }
                      if (value != _passwordController.text) {
                        return _text(
                          'Passwords do not match',
                          'Mawu achinsinsi sakufanana',
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Register Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _text('REGISTER', 'LEMBETSANI'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _text('Already have an account?', 'Muli ndi akaunti?'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(_text('Login', 'Lowani')),
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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
