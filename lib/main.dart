import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:open_filex/open_filex.dart';
import 'package:page_transition/page_transition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();

  // Generate recovery code if not exists
  const storage = FlutterSecureStorage();
  final recoveryCode = await storage.read(key: 'recovery_code');
  if (recoveryCode == null) {
    final code = _generateRecoveryCode();
    await storage.write(key: 'recovery_code', value: code);
  }
  runApp(FileHiderApp());
}

String _generateRecoveryCode() {
  final random = Random.secure();
  final code = List.generate(12, (i) => random.nextInt(16).toRadixString(16)).join();
  return code.toUpperCase();
}

Future<void> _requestPermissions() async {
  await Permission.storage.request();
  if (await Permission.manageExternalStorage.isDenied) {
    await Permission.manageExternalStorage.request();
  }
}

class FileHiderApp extends StatelessWidget {
  const FileHiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'File Ghost',
      theme: _buildPurpleTheme(),
      home: const SplashScreen(),
    );
  }

  ThemeData _buildPurpleTheme() {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: Colors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        iconTheme: IconThemeData(color: Colors.deepPurpleAccent),
      ),
      colorScheme: const ColorScheme.dark(
        primary: Colors.deepPurpleAccent,
        secondary: Colors.purpleAccent,
        surface: Color(0xFF1A1A1A),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.deepPurple.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurpleAccent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurpleAccent),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward().then((_) {
      Navigator.pushReplacement(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          duration: const Duration(milliseconds: 800),
          child: const AuthScreen(),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: const Icon(Icons.lock, size: 100, color: Colors.deepPurpleAccent),
                );
              },
            ),
            const SizedBox(height: 30),
            TweenAnimationBuilder(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    'FileGhost',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurpleAccent.withOpacity(value),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController pinController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isAuthenticating = false;
  bool _isBiometricsEnabled = false;
  String? _savedPin;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedPin = await _storage.read(key: 'app_pin');
    final biometricsEnabled = await _storage.read(key: 'biometrics_enabled');

    setState(() {
      _savedPin = savedPin;
      _isBiometricsEnabled = biometricsEnabled == 'true';
    });

    if (_isBiometricsEnabled && _savedPin != null) {
      _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;

    setState(() => _isAuthenticating = true);

    try {
      final canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!canAuthenticate) {
        _showAuthError('Biometrics not available');
        return;
      }

      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to access FileGhost',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (didAuthenticate) {
        _navigateToHome();
      } else {
        _showAuthError('Authentication failed');
      }
    } on PlatformException catch (e) {
      _showAuthError('Error: ${e.message}');
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  Future<void> _authenticateWithPin() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final enteredPin = pinController.text;
      if (enteredPin.isEmpty) {
        _showAuthError('Please enter a PIN');
        return;
      }

      if (_savedPin == null) {
        await _storage.write(key: 'app_pin', value: enteredPin);
        await _storage.write(key: 'biometrics_enabled', value: 'true');
        _navigateToHome();
      } else if (enteredPin == _savedPin) {
        _navigateToHome();
      } else {
        _showAuthError('Incorrect PIN');
      }
    } finally {
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeftWithFade,
        duration: const Duration(milliseconds: 500),
        child: const HomeScreen(),
      ),
    );
  }

  void _showAuthError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Update the _showRecoveryDialog method in _AuthScreenState
  Future<void> _showRecoveryDialog() async {
    final recoveryCode = await _storage.read(key: 'recovery_code');
    final TextEditingController recoveryController = TextEditingController();

    final enteredCode = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enter Recovery Code'),
          content: TextField(
            controller: recoveryController,
            decoration: const InputDecoration(labelText: 'Recovery Code'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, recoveryController.text),
              child: const Text('Recover'),
            ),
          ],
        );
      },
    );

    if (enteredCode == null) return; // User cancelled

    if (enteredCode == recoveryCode) {
      final TextEditingController newPinController = TextEditingController();
      final TextEditingController confirmPinController = TextEditingController();

      final newPin = await showDialog<String>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Set New PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: newPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New 4-digit PIN'),
                ),
                TextField(
                  controller: confirmPinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm New PIN'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  if (newPinController.text.length != 4) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
                    return;
                  }
                  if (newPinController.text != confirmPinController.text) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('PINs do not match')));
                    return;
                  }
                  Navigator.pop(context, newPinController.text);
                },
                child: const Text('Set PIN'),
              ),
            ],
          );
        },
      );

      if (newPin != null && newPin.length == 4) {
        await _storage.write(key: 'app_pin', value: newPin);
        pinController.text = newPin; // Update the current PIN field
        _navigateToHome();
      }
    } else {
      _showAuthError('Invalid recovery code');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.deepPurple.shade900],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, size: 80, color: Colors.deepPurpleAccent),
                  const SizedBox(height: 20),
                  const Text(
                    'FileGhost',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (_isBiometricsEnabled && _savedPin != null) ...[
                    IconButton(
                      icon: const Icon(Icons.fingerprint, size: 48),
                      color: Colors.deepPurpleAccent,
                      onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                    ),
                    const SizedBox(height: 16),
                    const Text('Use Biometrics', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 30),
                    const Text('or', style: TextStyle(color: Colors.white54)),
                    const SizedBox(height: 30),
                  ],

                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Enter PIN',
                      labelStyle: const TextStyle(color: Colors.deepPurpleAccent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.deepPurpleAccent),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.deepPurpleAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isAuthenticating ? null : _authenticateWithPin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.deepPurpleAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child:
                          _isAuthenticating
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                                _savedPin == null ? 'Set PIN' : 'Authenticate',
                                style: const TextStyle(fontSize: 16, color: Colors.white),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton:
          _savedPin != null
              ? FloatingActionButton(
                onPressed: _showRecoveryDialog,
                tooltip: 'Forgot PIN',
                child: const Icon(Icons.lock_reset),
              )
              : null,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _fileService = FileHiderService();
  late Future<List<FileSystemEntity>> _filesFuture;
  final _selectedFiles = <FileSystemEntity>{};
  final _storage = FlutterSecureStorage();
  bool _biometricsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _filesFuture = _fileService.loadFiles();
    _loadBiometricsSetting();
  }

  Future<void> _loadBiometricsSetting() async {
    final enabled = await _storage.read(key: 'biometrics_enabled');
    setState(() {
      _biometricsEnabled = enabled == 'true';
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App goes to background
      _logout();
    }
  }

  Future<void> _logout() async {
    Navigator.pushAndRemoveUntil(
      context,
      PageTransition(type: PageTransitionType.fade, child: const AuthScreen()),
      (route) => false,
    );
  }

  Future<void> _refreshFiles() async {
    setState(() {
      _filesFuture = _fileService.loadFiles();
    });
  }

  Future<void> _handleFilePick() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null) {
      for (var file in result.files) {
        if (file.path != null) {
          await _fileService.hideFile(File(file.path!));
        }
      }
      await _refreshFiles();
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm Delete'),
            content: Text('Delete ${_selectedFiles.length} files permanently?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _fileService.deleteFiles(_selectedFiles.toList());
      await _refreshFiles();
      _selectedFiles.clear();
    }
  }

  Future<void> _openFile(File file) async {
    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Ghost'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: 'Logout'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshFiles, tooltip: 'Refresh'),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => SettingsScreen(
                          biometricsEnabled: _biometricsEnabled,
                          onBiometricsChanged: (value) async {
                            await _storage.write(
                              key: 'biometrics_enabled',
                              value: value.toString(),
                            );
                            setState(() => _biometricsEnabled = value);
                          },
                        ),
                  ),
                ),
          ),
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _handleDelete,
              tooltip: 'Delete Selected',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _handleFilePick,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<FileSystemEntity>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurpleAccent),
              ),
            );
          }

          final files = snapshot.data ?? [];
          return files.isEmpty
              ? Center(
                child: Text('No files hidden yet!', style: TextStyle(color: Colors.grey[400])),
              )
              : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: files.length,
                itemBuilder: (context, index) {
                  final file = files[index];
                  return FileCard(
                    file: file,
                    isSelected: _selectedFiles.contains(file),
                    onSelectionChanged: (selected) {
                      setState(() {
                        selected ? _selectedFiles.add(file) : _selectedFiles.remove(file);
                      });
                    },
                    onTap: () => _openFile(File(file.path)),
                  );
                },
              );
        },
      ),
    );
  }
}

class FileHiderService {
  late Directory _hiddenDir;
  static const String _nomedia = '.nomedia';

  FileHiderService() {
    _initializeDir();
  }

  Future<void> _initializeDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    _hiddenDir = Directory('${appDir.path}/FileGhost');
    if (!await _hiddenDir.exists()) {
      await _hiddenDir.create(recursive: true);
      await File('${_hiddenDir.path}/$_nomedia').create();
    }
  }

  Future<List<FileSystemEntity>> loadFiles() async {
    await _initializeDir();
    return _hiddenDir
        .listSync()
        .whereType<File>()
        .where((file) => !file.path.endsWith(_nomedia))
        .toList();
  }

  Future<void> hideFile(File file) async {
    final newPath = '${_hiddenDir.path}/${file.uri.pathSegments.last}';
    await file.copy(newPath);
  }

  Future<void> deleteFiles(List<FileSystemEntity> files) async {
    for (final file in files) {
      await file.delete();
    }
  }
}

class FileCard extends StatelessWidget {
  final FileSystemEntity file;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;
  final VoidCallback onTap;

  const FileCard({
    super.key,
    required this.file,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => onSelectionChanged(!isSelected),
      child: Card(
        clipBehavior: Clip.antiAlias,
        color: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side:
              isSelected
                  ? const BorderSide(color: Colors.deepPurpleAccent, width: 2)
                  : BorderSide.none,
        ),
        child: Column(
          children: [
            Expanded(
              child: Icon(Icons.insert_drive_file, size: 64, color: Colors.deepPurpleAccent),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                file.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassMorphismCard extends StatelessWidget {
  final Widget child;

  const GlassMorphismCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepPurple.withOpacity(0.2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.3), width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PurpleBackgroundPainter extends CustomPainter {
  final double value;

  _PurpleBackgroundPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..shader = SweepGradient(
            colors: const [Colors.deepPurple, Colors.purpleAccent, Colors.deepPurpleAccent],
            transform: GradientRotation(value * 2 * pi),
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: size.width / 2,
            ),
          );

    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.8, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RecoveryCodeScreen extends StatelessWidget {
  final String recoveryCode;

  const RecoveryCodeScreen({super.key, required this.recoveryCode});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery Code')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save this recovery code in a safe place:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.deepPurpleAccent),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                recoveryCode,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'If you forget your PIN, you can use this code to recover access.',
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I have saved my recovery code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final bool biometricsEnabled;
  final ValueChanged<bool> onBiometricsChanged;

  const SettingsScreen({
    super.key,
    required this.biometricsEnabled,
    required this.onBiometricsChanged,
  });

  final storage = const FlutterSecureStorage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable Biometric Authentication'),
            value: biometricsEnabled,
            onChanged: onBiometricsChanged,
            activeColor: Colors.deepPurpleAccent,
          ),
          ListTile(
            title: const Text('Change PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Implement PIN change functionality
              Navigator.pop(context); // Close settings first
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChangePinScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('View Recovery Code'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final recoveryCode = await storage.read(key: 'recovery_code');
              if (recoveryCode != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecoveryCodeScreen(recoveryCode: recoveryCode),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  _ChangePinScreenState createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _storage = const FlutterSecureStorage();
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  Future<void> _changePin() async {
    final oldPin = await _storage.read(key: 'app_pin');

    if (_oldPinController.text != oldPin) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect current PIN')));
      return;
    }

    if (_newPinController.text.length != 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('New PINs do not match')));
      return;
    }

    await _storage.write(key: 'app_pin', value: _newPinController.text);
    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN changed successfully')));

    if (!_formKey.currentState!.validate()) return;
  }

  final _formKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextField(
                controller: _oldPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Current PIN'),
              ),
              TextField(
                controller: _newPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'New PIN'),
              ),
              TextField(
                controller: _confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(labelText: 'Confirm New PIN'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _changePin, child: const Text('Change PIN')),
            ],
          ),
        ),
      ),
    );
  }
}
