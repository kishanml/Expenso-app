import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/services/app_lock_service.dart';
import 'state/app_state.dart';
import 'ui/screens/lock/lock_screen.dart';
import 'ui/screens/shell/app_shell.dart';
import 'ui/screens/splash/splash_screen.dart';
import 'ui/screens/welcome/welcome_screen.dart';

class ExpensoApp extends StatelessWidget {
  const ExpensoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'Expenso',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state.themeMode,
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Decides what the app opens on.
///
/// A fresh install sees the splash, then first-time setup. Once setup is done
/// the splash is gone for good — Home opens directly, which is what a tracker
/// you log into several times a day should do. The app lock, when on, sits in
/// front of all of it.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  final _lock = AppLockService();

  var _showWelcome = false;
  var _unlocked = false;
  var _failed = false;
  var _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptIfLocked());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Re-lock whenever the app leaves the foreground, so the records are not
    // sitting open in the task switcher.
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      if (mounted && _unlocked) setState(() => _unlocked = false);
    } else if (lifecycle == AppLifecycleState.resumed) {
      _promptIfLocked();
    }
  }

  Future<void> _promptIfLocked() async {
    if (!mounted || _prompting) return;

    final state = context.read<AppState>();
    if (!state.appLock || !state.setupComplete || _unlocked) return;

    _prompting = true;
    final passed = await _lock.authenticate(reason: 'Unlock Expenso');
    _prompting = false;

    if (!mounted) return;
    setState(() {
      _unlocked = passed;
      _failed = !passed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.setupComplete && state.appLock && !_unlocked) {
      return LockScreen(failed: _failed, onUnlock: _promptIfLocked);
    }

    if (state.setupComplete) return const AppShell();

    if (_showWelcome) {
      return WelcomeScreen(
        today: state.today,
        onSaved: state.completeSetup,
      );
    }

    return SplashScreen(
      onGetStarted: () => setState(() => _showWelcome = true),
    );
  }
}
