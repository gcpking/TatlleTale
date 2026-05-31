import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_usage/app_usage.dart';
import 'background_service.dart';
import 'firebase_rest.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TattletaleApp());
}

class TattletaleApp extends StatelessWidget {
  const TattletaleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tattletale Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C47FF),
        useMaterial3: true,
      ),
      home: const StartupScreen(),
    );
  }
}

// ── Startup: decide where to go ─────────────────────────────────────────────

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final familyId = prefs.getString('family_id') ?? '';
    final hasToken = (prefs.getString('refresh_token') ?? '').isNotEmpty;

    if (!mounted) return;

    if (familyId.isNotEmpty && hasToken) {
      await initBackgroundService();
      _go(const HomeScreen());
    } else {
      _go(const SetupScreen());
    }
  }

  void _go(Widget screen) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF6C47FF),
      body: Center(
          child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

// ── Setup screen ─────────────────────────────────────────────────────────────

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _codeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _save() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (code.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Fill in all fields.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    final ok = await FirebaseRest.signIn(email, pass);
    if (!ok) {
      setState(() {
        _loading = false;
        _error = 'Sign-in failed. Check the parent email and password.';
      });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('family_id', code);

    await initBackgroundService();

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C47FF),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Tattletale',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF6C47FF))),
                  const SizedBox(height: 4),
                  const Text('Set up this device',
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                        labelText: 'Family code',
                        hintText: 'e.g. LCKKBO',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  const Text('Parent account',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(_error,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
                  const SizedBox(height: 4),
                  FilledButton(
                    onPressed: _loading ? null : _save,
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C47FF),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16)),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Start',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('⚠️  One manual step required',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        SizedBox(height: 6),
                        Text(
                          'After saving, go to:\n'
                          'Settings → Apps → Special app access\n'
                          '→ Usage access → Tattletale Sync → Allow\n\n'
                          'Without this the app cannot read screen time.',
                          style: TextStyle(fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Home / status screen ──────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _lastSync = 'Checking...';
  bool _hasPermission = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await _checkPermission();
    await _loadLastSync();
  }

  Future<void> _checkPermission() async {
    try {
      final end = DateTime.now();
      final start = end.subtract(const Duration(hours: 1));
      // app_usage returns empty list if Usage Access is not granted
      final list = await AppUsage().getAppUsage(start, end);
      if (mounted) setState(() => _hasPermission = list.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _hasPermission = false);
    }
  }

  Future<void> _loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('last_sync');
    if (!mounted) return;
    if (s == null) {
      setState(() => _lastSync = 'Not yet — waiting for Usage Access');
      return;
    }
    final dt = DateTime.tryParse(s);
    if (dt == null) return;
    final diff = DateTime.now().difference(dt);
    setState(() {
      _lastSync = diff.inSeconds < 60
          ? 'Just now'
          : diff.inMinutes < 60
              ? '${diff.inMinutes}m ago'
              : '${diff.inHours}h ago';
    });
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final prefs = await SharedPreferences.getInstance();
    final familyId = prefs.getString('family_id') ?? '';

    try {
      final end = DateTime.now();
      final start = DateTime(end.year, end.month, end.day);
      final usageList = await AppUsage().getAppUsage(start, end);

      const hiddenPackages = {
        'com.android.systemui', 'com.google.android.gms',
        'com.motorola.launcher3', 'com.android.launcher3',
        'com.tattletale.sync',
      };

      final usage = usageList
          .where((u) =>
              u.usage.inMinutes > 0 &&
              !hiddenPackages.contains(u.packageName))
          .map((u) => {
                'packageName': u.packageName,
                'appName': u.appName,
                'usageMinutes': u.usage.inMinutes,
              })
          .toList();

      final ok = await FirebaseRest.pushUsage(familyId, usage);
      if (ok) {
        await prefs.setString('last_sync', DateTime.now().toIso8601String());
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _syncing = false);
      await _loadLastSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF6C47FF),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasPermission ? Icons.shield : Icons.shield_outlined,
                  size: 64,
                  color: _hasPermission
                      ? const Color(0xFF6C47FF)
                      : Colors.orange,
                ),
                const SizedBox(height: 16),
                Text(
                  _hasPermission
                      ? 'Tattletale is running'
                      : 'Usage access needed',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('Last sync: $_lastSync',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 16),
                if (!_hasPermission)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Text(
                      'Settings → Apps → Special app access\n→ Usage access → Tattletale Sync → Allow',
                      style: TextStyle(fontSize: 12, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  const Text(
                    'Screen time syncs every 15 minutes.\nYou can close this app — it keeps running.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check status'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _syncing ? null : _syncNow,
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF6C47FF)),
                      icon: _syncing
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.sync),
                      label: const Text('Sync now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
