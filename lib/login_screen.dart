import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

bool registrationPending = false;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool isVerificationSent = false;
  bool isEmailVerified = false;
  bool accountCreated = false;
  bool hidePassword = true;
  bool isRegistering = false;
  String? selectedCurrency;

  Timer? verificationTimer;

  Future<void> verifyEmail() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields and select a currency.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      registrationPending = true;
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        'currency_${credential.user!.uid}',
        selectedCurrency ?? 'MYR',
      );

      await prefs.setString(
        'baseCurrency_${credential.user!.uid}',
        selectedCurrency ?? 'MYR',
      );

      await credential.user!.updateDisplayName(username);
      await credential.user!.sendEmailVerification();

      if (!mounted) return;

      setState(() {
        accountCreated = true;
        isVerificationSent = true;
        isEmailVerified = false;
      });
      startVerificationTimer();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Please check your inbox.'),
          duration: Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        try {
          final credential =
              await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          await credential.user!.reload();

          final existingUser = FirebaseAuth.instance.currentUser;
          final verified = existingUser?.emailVerified ?? false;

          if (verified) {
            await FirebaseAuth.instance.signOut();
          } else {
            registrationPending = true;
          }

          if (!mounted) return;

          setState(() {
            accountCreated = true;
            isVerificationSent = !verified;
            isEmailVerified = verified;
          });
          if (!verified) {
            startVerificationTimer();
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                verified
                    ? 'This email is already verified. You can log in.'
                    : 'Account already exists. You can resend the verification email.',
              ),
            ),
          );
        } on FirebaseAuthException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Unable to access existing account: ${error.message}',
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your account again.'),
        ),
      );
      return;
    }

    try {
      await user.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new verification email has been sent!'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to resend email: ${e.message}'),
        ),
      );
    }
  }

  Future<void> checkEmailVerification() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;
      final verified = refreshedUser?.emailVerified ?? false;

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      setState(() {
        isEmailVerified = verified;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified
                ? 'Email verified successfully!'
                : 'Your email is not verified yet. Please check your inbox.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification check failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> completeRegistration() async {
    verificationTimer?.cancel();

    await FirebaseAuth.instance.signOut();

    registrationPending = false;

    if (!mounted) return;

    setState(() {
      isLogin = true;
      accountCreated = false;
      isVerificationSent = false;
      isEmailVerified = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Registration complete! You can now log in.'),
      ),
    );
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email address first.'),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent! Please check your inbox.'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to send reset email: ${e.message}'),
        ),
      );
    }
  }

  Future<void> authenticate() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (!isLogin && username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a username.')),
      );
      return;
    }

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user!.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null || !refreshedUser.emailVerified) {
        await FirebaseAuth.instance.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please verify your email before logging in.',
              ),
            ),
          );
        }

        return;
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed. Please try again.';

      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Incorrect email or password.';
      } else if (e.code == 'email-already-in-use') {
        message = 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        message = 'Password must be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Please enter a valid email address.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  void startVerificationTimer() {
    verificationTimer?.cancel();

    verificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) async {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) return;

        try {
          await user.reload();

          final refreshedUser = FirebaseAuth.instance.currentUser;

          if (refreshedUser?.emailVerified == true && mounted) {
            timer.cancel();

            setState(() {
              isEmailVerified = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Email verified successfully! You can register now.'),
              ),
            );
          }
        } catch (e) {
          debugPrint('Verification check failed: $e');
        }
      },
    );
  }

  @override
  void dispose() {
    verificationTimer?.cancel();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF121826);
    const cardColor = Color(0xFF1E293B);
    const accentColor = Color(0xFF38BDF8);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  size: 75,
                  color: accentColor,
                ),
                const SizedBox(height: 20),
                const Text(
                  'BudgetBuddy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isLogin
                      ? 'Welcome back! Please log in.'
                      : 'Create an account to get started.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 35),
                if (!isLogin) ...[
                  TextField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: selectedCurrency,
                    hint: const Text(
                      'Select preferred currency',
                      style: TextStyle(color: Colors.white70),
                    ),
                    dropdownColor: cardColor,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Preferred Currency',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(
                        Icons.currency_exchange,
                        color: Colors.white70,
                      ),
                      filled: true,
                      fillColor: cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'MYR',
                        child: Text('MYR - Malaysian Ringgit (RM)'),
                      ),
                      DropdownMenuItem(
                        value: 'SGD',
                        child: Text('SGD - Singapore Dollar (S\$)'),
                      ),
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('USD - US Dollar (\$)'),
                      ),
                      DropdownMenuItem(
                        value: 'GBP',
                        child: Text('GBP - British Pound (£)'),
                      ),
                      DropdownMenuItem(
                        value: 'EUR',
                        child: Text('EUR - Euro (€)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCurrency = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: Colors.white70,
                    ),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(
                      Icons.lock_outline,
                      color: Colors.white70,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                      ),
                    ),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading ? null : resetPassword,
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 25),
                if (!isLogin) ...[
                  ElevatedButton(
                    onPressed: isLoading || accountCreated ? null : verifyEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF121826),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Verify Email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (isVerificationSent)
                  TextButton(
                    onPressed: isLoading ? null : resendVerificationEmail,
                    child: const Text(
                      'Resend Verification Email',
                      style: TextStyle(color: Color(0xFF38BDF8)),
                    ),
                  ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : isLogin
                          ? authenticate
                          : isEmailVerified
                              ? completeRegistration
                              : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: backgroundColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          isLogin ? 'Login' : 'Register',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      children: [
                        TextSpan(
                          text: isLogin
                              ? "Don't have an account yet? "
                              : "Already have an account? ",
                        ),
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: isLoading
                                ? null
                                : () {
                                    verificationTimer?.cancel();
                                    registrationPending = false;
                                    setState(() {
                                      usernameController.clear();
                                      emailController.clear();
                                      passwordController.clear();

                                      isVerificationSent = false;
                                      isEmailVerified = false;
                                      accountCreated = false;
                                      selectedCurrency = null;

                                      isLogin = !isLogin;
                                    });
                                  },
                            child: Text(
                              isLogin ? 'Register' : 'Login',
                              style: const TextStyle(
                                color: Color(0xFF38BDF8),
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
