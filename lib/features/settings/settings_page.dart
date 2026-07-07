import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/services/music_api.dart';
import '../../l10n/app_strings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiController;
  late final TextEditingController _resolverController;
  late final TextEditingController _serverController;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _apiController = TextEditingController(text: appState.apiBaseUrl);
    _resolverController = TextEditingController(text: appState.resolverBaseUrl);
    _serverController = TextEditingController(text: appState.serverBaseUrl);
  }

  @override
  void dispose() {
    _apiController.dispose();
    _resolverController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final strings = AppStrings.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        Text(
          strings.settings,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            appState.isSignedIn
                ? Icons.verified_user_rounded
                : Icons.account_circle_rounded,
          ),
          title: Text(appState.currentUser?.label ?? strings.signedOut),
          subtitle: Text(
            appState.isSignedIn
                ? appState.currentUser!.email
                : strings.authRequired,
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => appState.isSignedIn
              ? _showAccountSheet(context, appState, strings)
              : _showAuthSheet(context, appState, strings),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.language_rounded),
          title: Text(strings.language),
          subtitle: Text(AppState.localeLabel(context, appState.locale)),
          trailing: DropdownButton<Locale?>(
            value: appState.locale,
            underline: const SizedBox.shrink(),
            items: [
              DropdownMenuItem<Locale?>(
                value: null,
                child: Text(strings.followSystem),
              ),
              DropdownMenuItem<Locale?>(
                value: const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hans',
                ),
                child: Text(strings.simplifiedChinese),
              ),
              DropdownMenuItem<Locale?>(
                value: const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hant',
                ),
                child: Text(strings.traditionalChinese),
              ),
              DropdownMenuItem<Locale?>(
                value: const Locale('en'),
                child: Text(strings.english),
              ),
            ],
            onChanged: appState.setLocale,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: strings.apiBaseUrl,
            prefixIcon: const Icon(Icons.dns),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _resolverController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: strings.resolverUrl,
            helperText: strings.resolverHelper,
            prefixIcon: const Icon(Icons.hub),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _serverController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: strings.serverBaseUrl,
            helperText: strings.serverHelper,
            prefixIcon: const Icon(Icons.cloud_sync_rounded),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () async {
                await appState.setApiBaseUrl(_apiController.text);
                await appState.setResolverBaseUrl(_resolverController.text);
                await appState.setServerBaseUrl(_serverController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.musicServicesUpdated)),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: Text(strings.save),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                _apiController.text = MusicApi.defaultBaseUrl;
                _resolverController.text = MusicApi.defaultResolverBaseUrl;
                _serverController.text = appState.serverBaseUrl;
              },
              child: Text(strings.reset),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.favorite),
          title: Text(strings.favoriteSongs),
          subtitle: Text(strings.savedLocally(appState.favoriteIds.length)),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.phone_android),
          title: Text(strings.mobileRebuild),
          subtitle: Text(strings.mobileRebuildBody),
        ),
      ],
    );
  }

  void _showAccountSheet(
    BuildContext context,
    AppState appState,
    AppStrings strings,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appState.currentUser?.label ?? strings.account,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(appState.currentUser?.email ?? strings.accountServerHint),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await appState.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.signedOutMessage)),
                  );
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(strings.signOut),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuthSheet(
    BuildContext context,
    AppState appState,
    AppStrings strings,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AuthSheet(appState: appState, strings: strings),
    );
  }
}

class _AuthSheet extends StatefulWidget {
  const _AuthSheet({
    required this.appState,
    required this.strings,
  });

  final AppState appState;
  final AppStrings strings;

  @override
  State<_AuthSheet> createState() => _AuthSheetState();
}

class _AuthSheetState extends State<_AuthSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isRegister = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final strings = widget.strings;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isRegister ? strings.createAccount : strings.signIn,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(strings.accountServerHint),
            const SizedBox(height: 16),
            if (_isRegister) ...[
              TextField(
                controller: _displayNameController,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: '${strings.displayName} (${strings.optional})',
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: strings.email,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: strings.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isRegister
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                          ),
                    label: Text(
                      _isRegister ? strings.createAccount : strings.signIn,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _isRegister = !_isRegister;
                            _error = null;
                          }),
                  child: Text(
                    _isRegister ? strings.signIn : strings.createAccount,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() =>
          _error = '${widget.strings.email} / ${widget.strings.password}');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await widget.appState.register(
          email: email,
          password: password,
          displayName: _displayNameController.text,
        );
      } else {
        await widget.appState.login(email: email, password: password);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.strings.authSuccess)),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
