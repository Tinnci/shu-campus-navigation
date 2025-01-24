import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  static const String route = '/settings';
  final Function(ThemeMode) onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  ThemeMode _selectedThemeMode = ThemeMode.system;
  bool _receiveNotifications = true;
  String _appName = '';
  String _version = '';
  String _buildNumber = '';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appName = packageInfo.appName;
      _version = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8.0 : 16.0,
              vertical: isSmallScreen ? 8.0 : 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildSectionTitle(context, 'Theme'),
                _buildThemeSelection(context),
                _divider(context),
                _buildSectionTitle(context, 'Notifications'),
                _buildNotificationSwitch(),
                _divider(context),
                _buildAppInfo(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }

  Widget _buildThemeSelection(BuildContext context) {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('Light Mode'),
            value: ThemeMode.light,
            groupValue: _selectedThemeMode,
            onChanged: (ThemeMode? value) {
              setState(() {
                _selectedThemeMode = value!;
              });
              widget.onThemeChanged(value!);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark Mode'),
            value: ThemeMode.dark,
            groupValue: _selectedThemeMode,
            onChanged: (ThemeMode? value) {
              setState(() {
                _selectedThemeMode = value!;
              });
              widget.onThemeChanged(value!);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            value: ThemeMode.system,
            groupValue: _selectedThemeMode,
            onChanged: (ThemeMode? value) {
              setState(() {
                _selectedThemeMode = value!;
              });
              widget.onThemeChanged(value!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSwitch() {
    return SwitchListTile(
      title: const Text('Receive Notifications'),
      value: _receiveNotifications,
      onChanged: (bool value) {
        setState(() {
          _receiveNotifications = value;
        });
      },
      secondary: Icon(
        Icons.notifications,
        color: Theme.of(context).colorScheme.primary,
        size: 28,
      ),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      thickness: 1,
      height: 32,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  Widget _buildAppInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_appName v$_version (Build $_buildNumber)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Built in SHU with love ❤️',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.secondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
