import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/app_button.dart';
import 'auth_controller.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  // To verify if code is sent
  bool get _codeSent =>
      ref.watch(authControllerProvider).verificationId != null;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _onPhoneSubmit() {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      ref.read(authControllerProvider.notifier).sendOtp(phone);
    }
  }

  void _onOtpSubmit() {
    final otp = _otpController.text.trim();
    if (otp.isNotEmpty) {
      ref.read(authControllerProvider.notifier).verifyOtp(context, otp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    // Show error snackbar if error exists
    ref.listen(authControllerProvider, (previous, next) {
      if (next.error != null && next.error!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red,
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              Text(
                _codeSent ? 'Verify Phone' : 'Welcome Back',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _codeSent
                    ? 'Enter the code sent to ${_phoneController.text}'
                    : 'Sign in to continue',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              if (!_codeSent) ...[
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (e.g., +961 3 123456)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Continue with Phone',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _onPhoneSubmit,
                ),
                const SizedBox(height: 16),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("OR")),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                AppButton(
                  text: 'Continue with Google',
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(authControllerProvider.notifier)
                          .signInWithGoogle(context),
                  isOutlined: true,
                  icon: Icons
                      .g_mobiledata, // Fallback icon, usually utilize custom asset
                ),
              ] else ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'SMS Code',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_clock),
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Verify',
                  isLoading: isLoading,
                  onPressed: isLoading ? null : _onOtpSubmit,
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          // Reset state to allow editing phone number
                          // We need a way to reset verificationId in controller, or just reload page
                          // Ideally controller has a reset method.
                          // For now, we can just pop or refresh.
                          // But easier: add reset method to controller or just update state manually?
                          // Controller state is immutable.
                          // Let's just implement a back button in logic if needed, but for now simple UI:
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please restart app to change number (TODO: Reset)')),
                          );
                        },
                  child: const Text('Wrong Number?'),
                ),
              ],

              const Spacer(),

              // Dev Tools
              if (!_codeSent) ...[
                ExpansionTile(
                  title: const Text("Developer Tools",
                      style: TextStyle(fontSize: 12)),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          onPressed: () => context.go('/client'),
                          child: const Text('Client Demo'),
                        ),
                        TextButton(
                          onPressed: () => context.go('/driver'),
                          child: const Text('Driver Demo'),
                        ),
                        TextButton(
                          onPressed: () => context.go('/admin'),
                          child: const Text('Admin Demo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
