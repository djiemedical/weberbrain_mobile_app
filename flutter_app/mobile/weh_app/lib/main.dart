import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:email_validator/email_validator.dart';
import 'amplifyconfiguration.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _amplifyConfigured = false;

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  void _configureAmplify() async {
    if (!mounted) return;

    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      await Amplify.configure(amplifyconfig);
      setState(() {
        _amplifyConfigured = true;
      });
    } catch (e) {
      print("Error configuring Amplify: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weber Brain App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _amplifyConfigured ? const SplashScreen() : const LoadingPage(),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    try {
      AuthSession session = await Amplify.Auth.fetchAuthSession();
      if (session.isSignedIn) {
        _navigateToMyDevices();
      } else {
        _navigateToAuth();
      }
    } catch (e) {
      print('Error checking auth status: $e');
      _navigateToAuth();
    }
  }

  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthPage()),
    );
  }

  void _navigateToMyDevices() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MyDevicesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            Text('Weber Brain App', style: TextStyle(fontSize: 24)),
          ],
        ),
      ),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  _AuthPageState createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  final _resetPasswordController = TextEditingController();
  bool _isSignIn = true;
  bool _isVerifying = false;
  bool _isResettingPassword = false;
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  void _toggleAuthMode() {
    setState(() {
      _isSignIn = !_isSignIn;
      _isVerifying = false;
      _isResettingPassword = false;
    });
  }

  bool _validateInputs() {
    if (!EmailValidator.validate(_emailController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return false;
    }
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters long.')),
      );
      return false;
    }
    return true;
  }

  Future<void> _signUp() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);
    try {
      final userAttributes = <CognitoUserAttributeKey, String>{
        CognitoUserAttributeKey.email: _emailController.text.trim(),
      };

      final result = await Amplify.Auth.signUp(
        username: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        options: SignUpOptions(
          userAttributes: userAttributes,
        ),
      );

      setState(() {
        _isVerifying = true;
        _isSignIn = false;
      });

      if (result.isSignUpComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sign up successful. Please verify your account.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please confirm your sign up.')),
        );
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing up: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An unexpected error occurred. Please try again.')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmSignUp() async {
    setState(() => _isLoading = true);
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: _emailController.text.trim(),
        confirmationCode: _verificationCodeController.text.trim(),
      );

      if (result.isSignUpComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Account verified successfully. You can now sign in.')),
        );
        setState(() {
          _isSignIn = true;
          _isVerifying = false;
        });
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error confirming sign up: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isLoading = true);
    try {
      await Amplify.Auth.resendSignUpCode(
          username: _emailController.text.trim());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Verification code resent. Please check your email.')),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resending code: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (!_validateInputs()) return;

    setState(() => _isLoading = true);
    try {
      final result = await Amplify.Auth.signIn(
        username: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (result.isSignedIn) {
        // Store the user's email securely
        await _storage.write(
            key: 'user_email', value: _emailController.text.trim());
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (context) => const MyDevicesPage()));
      }
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    setState(() {
      _isResettingPassword = true;
    });
  }

  Future<void> _resetPassword() async {
    if (!EmailValidator.validate(_resetPasswordController.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Amplify.Auth.resetPassword(
        username: _resetPasswordController.text.trim(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Password reset instructions sent to your email.')),
      );
      setState(() {
        _isResettingPassword = false;
      });
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resetting password: ${e.message}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignIn
            ? 'Sign In'
            : (_isVerifying ? 'Verify Account' : 'Sign Up')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isVerifying && !_isResettingPassword) ...[
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isSignIn ? _signIn : _signUp,
                      child: Text(_isSignIn ? 'Sign In' : 'Sign Up'),
                    ),
                    TextButton(
                      onPressed: _toggleAuthMode,
                      child: Text(_isSignIn
                          ? 'Create an account'
                          : 'Already have an account? Sign in'),
                    ),
                    if (_isSignIn)
                      TextButton(
                        onPressed: _showForgotPasswordDialog,
                        child: const Text('Forgot Password?'),
                      ),
                  ] else if (_isVerifying) ...[
                    const Text('A verification code has been sent to your email.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _verificationCodeController,
                      decoration:
                          const InputDecoration(labelText: 'Verification Code'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _confirmSignUp,
                      child: const Text('Verify Account'),
                    ),
                    TextButton(
                      onPressed: _resendCode,
                      child: const Text('Resend verification code'),
                    ),
                  ] else if (_isResettingPassword) ...[
                    TextField(
                      controller: _resetPasswordController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _resetPassword,
                      child: const Text('Reset Password'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isResettingPassword = false;
                        });
                      },
                      child: const Text('Back to Sign In'),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class MyDevicesPage extends StatefulWidget {
  const MyDevicesPage({super.key});

  @override
  _MyDevicesPageState createState() => _MyDevicesPageState();
}

class _MyDevicesPageState extends State<MyDevicesPage> {
  List<String> unpairedDevices = [];
  List<String> pairedDevices = [];

  @override
  void initState() {
    super.initState();
    _generateDummyDevices();
  }

  void _generateDummyDevices() {
    List<String> newUnpairedDevices = [];
    List<String> newPairedDevices = [];
    // Generate 3 unpaired devices
    for (int i = 0; i < 3; i++) {
      newUnpairedDevices.add('WEH-678-${_generateRandomDigits()}');
    }
    // Generate 2 paired devices
    for (int i = 0; i < 2; i++) {
      newPairedDevices.add('WEH-678-${_generateRandomDigits()}');
    }
    setState(() {
      unpairedDevices = newUnpairedDevices;
      pairedDevices = newPairedDevices;
    });
  }

  String _generateRandomDigits() {
    Random random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  void _pairDevice(String deviceName) {
    setState(() {
      unpairedDevices.remove(deviceName);
      pairedDevices.add(deviceName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Paired with $deviceName')),
    );
  }

  void _unpairDevice(String deviceName) {
    setState(() {
      pairedDevices.remove(deviceName);
      unpairedDevices.add(deviceName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unpaired from $deviceName')),
    );
  }

  Future<void> _signOut() async {
    try {
      await Amplify.Auth.signOut();
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const AuthPage()));
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: ${e.message}')),
      );
    }
  }

  Widget _buildDeviceList(List<String> devices, bool isPaired) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: Icon(Icons.bluetooth,
              color: isPaired ? Colors.blue : Colors.grey),
          title: Text(devices[index]),
          subtitle: Text(isPaired ? 'Paired' : 'Tap to pair'),
          trailing: ElevatedButton(
            child: Text(isPaired ? 'Unpair' : 'Pair'),
            onPressed: () {
              if (isPaired) {
                _unpairDevice(devices[index]);
              } else {
                _pairDevice(devices[index]);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(seconds: 1)); // Simulate network delay
    if (mounted) {
      _generateDummyDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unpaired Devices',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDeviceList(unpairedDevices, false),
                const SizedBox(height: 24),
                const Text('Paired Devices',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildDeviceList(pairedDevices, true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
