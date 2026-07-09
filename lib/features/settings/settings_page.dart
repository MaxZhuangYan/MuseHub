import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/build_info.dart';
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
    final topPad = MediaQuery.paddingOf(context).top;
    final appState = context.watch<AppState>();
    final strings = AppStrings.of(context);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 160),
      children: [
        // ── Page title ──
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
          child: Text(
            strings.settings,
            style: GoogleFonts.sora(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
              letterSpacing: -0.8,
            ),
          ),
        ),

        // ── Appearance section ──
        _SectionLabel(strings.account),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: appState.isSignedIn
                  ? Icons.verified_user_rounded
                  : Icons.account_circle_rounded,
              title: appState.currentUser?.label ?? strings.signedOut,
              subtitle: appState.isSignedIn
                  ? appState.currentUser!.email
                  : strings.authRequired,
              onTap: () => appState.isSignedIn
                  ? _showAccountSheet(context, appState, strings)
                  : _showAuthSheet(context, appState, strings),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Appearance section ──
        _SectionLabel(strings.appearance),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.language_rounded,
              title: strings.language,
              subtitle: AppState.localeLabel(context, appState.locale),
              onTap: () => _showLanguagePicker(context, appState, strings),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Music services section ──
        _SectionLabel(strings.musicServices),
        _SettingsCard(
          children: [
            _SettingsTextField(
              controller: _apiController,
              icon: Icons.dns_rounded,
              label: strings.apiBaseUrl,
            ),
            _Divider(),
            _ResolverField(
              controller: _resolverController,
              label: strings.resolverUrl,
              helper: strings.resolverHelper,
            ),
            _Divider(),
            _SettingsTextField(
              controller: _serverController,
              icon: Icons.cloud_sync_rounded,
              label: strings.serverBaseUrl,
              helper: strings.serverHelper,
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.check_rounded,
                label: strings.save,
                isPrimary: true,
                onPressed: () async {
                  await appState.setApiBaseUrl(_apiController.text);
                  await appState.setResolverBaseUrl(_resolverController.text);
                  await appState.setServerBaseUrl(_serverController.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(strings.musicServicesUpdated),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: scheme.surfaceContainerHigh,
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            _ActionButton(
              icon: Icons.refresh_rounded,
              label: strings.reset,
              isPrimary: false,
              onPressed: () {
                _apiController.text = MusicApi.defaultBaseUrl;
                _resolverController.text = MusicApi.defaultResolverBaseUrl;
                _serverController.text = appState.serverBaseUrl;
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Library section ──
        _SectionLabel(strings.library),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.favorite_rounded,
              title: strings.favoriteSongs,
              subtitle: strings.savedLocally(appState.favoriteIds.length),
            ),
            _Divider(),
            _SettingsRow(
              icon: Icons.phone_android_rounded,
              title: strings.mobileRebuild,
              subtitle: strings.mobileRebuildBody,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── About section ──
        _SectionLabel(strings.about),
        _SettingsCard(
          children: [
            _SettingsRow(
              icon: Icons.info_outline_rounded,
              title: strings.appName,
              subtitle: BuildInfo.label,
              onTap: () {
                Clipboard.setData(ClipboardData(text: BuildInfo.label));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.buildInfoCopied),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: scheme.surfaceContainerHigh,
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  void _showAccountSheet(
    BuildContext context,
    AppState appState,
    AppStrings strings,
  ) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appState.currentUser?.label ?? strings.account,
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              appState.currentUser?.email ?? strings.accountServerHint,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _ActionButton(
                icon: Icons.logout_rounded,
                label: strings.signOut,
                isPrimary: false,
                onPressed: () async {
                  await appState.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(strings.signedOutMessage),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  );
                },
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
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _AuthSheet(appState: appState, strings: strings),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    AppState appState,
    AppStrings strings,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final options = <Locale?, String>{
      null: strings.followSystem,
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'):
          strings.simplifiedChinese,
      const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'):
          strings.traditionalChinese,
      const Locale('en'): strings.english,
    };

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.language,
                style: GoogleFonts.sora(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              for (final entry in options.entries) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    appState.setLocale(entry.key);
                    Navigator.of(context).pop();
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.value,
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: appState.locale == entry.key
                                  ? scheme.primaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (appState.locale == entry.key)
                          Icon(Icons.check_rounded,
                              color: scheme.primaryContainer, size: 20),
                      ],
                    ),
                  ),
                ),
                if (entry.key != options.keys.last)
                  Divider(
                    height: 1,
                    color: scheme.onSurface.withValues(alpha: 0.06),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.hankenGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 52,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final widget = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: scheme.primaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                size: 18, color: scheme.onSurfaceVariant),
        ],
      ),
    );

    if (onTap == null) return widget;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: widget,
    );
  }
}

class _SettingsTextField extends StatelessWidget {
  const _SettingsTextField({
    required this.controller,
    required this.icon,
    required this.label,
    this.helper,
  });
  final TextEditingController controller;
  final IconData icon;
  final String label;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: scheme.primaryContainer),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            style: GoogleFonts.hankenGrotesk(
              fontSize: 13,
              color: scheme.onSurface,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: scheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: scheme.primaryContainer, width: 1.5),
              ),
            ),
            keyboardType: TextInputType.url,
          ),
          if (helper != null) ...[
            const SizedBox(height: 6),
            Text(
              helper!,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ResolverTestState { idle, testing, success, failure }

/// Resolver URL field with a one-tap "test connection" action — hits the
/// resolver's /health endpoint directly from the phone so the user knows
/// immediately whether a locally- or LAN-hosted `tools/alger_resolver`
/// instance is actually reachable, instead of only finding out when a
/// VIP-locked song silently fails to play.
class _ResolverField extends StatefulWidget {
  const _ResolverField({
    required this.controller,
    required this.label,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final String? helper;

  @override
  State<_ResolverField> createState() => _ResolverFieldState();
}

class _ResolverFieldState extends State<_ResolverField> {
  _ResolverTestState _state = _ResolverTestState.idle;
  String? _resultMessage;
  bool _discovering = false;

  Future<void> _discoverResolver() async {
    final strings = AppStrings.of(context);
    setState(() {
      _discovering = true;
      _resultMessage = null;
    });

    try {
      final foundUrl =
          await context.read<AppState>().discoverResolverFromWifi();

      if (!mounted) return;
      if (foundUrl == null) {
        setState(() {
          _discovering = false;
          _state = _ResolverTestState.failure;
          _resultMessage = strings.resolverDiscoverNotFound;
        });
        return;
      }

      widget.controller.text = foundUrl;
      setState(() => _discovering = false);
      await _testConnection();
    } on Object {
      if (!mounted) return;
      setState(() {
        _discovering = false;
        _state = _ResolverTestState.failure;
        _resultMessage = strings.resolverDiscoverNotFound;
      });
    }
  }

  Future<void> _testConnection() async {
    final strings = AppStrings.of(context);
    final raw = widget.controller.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _state = _ResolverTestState.failure;
        _resultMessage = strings.resolverTestEmpty;
      });
      return;
    }

    setState(() {
      _state = _ResolverTestState.testing;
      _resultMessage = null;
    });

    try {
      final base = MusicApi.normalizeOptionalBaseUrl(raw);
      final uri = Uri.parse('$base/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _state = _ResolverTestState.failure;
          _resultMessage = strings.resolverTestBadStatus(response.statusCode);
        });
        return;
      }
      final decoded = jsonDecode(response.body);
      // tools/alger_resolver returns a flat list of source-id strings;
      // musehub-server returns a list of {id, capabilities} objects. Accept
      // either shape.
      final sources = decoded is Map<String, dynamic>
          ? ((decoded['sources'] as List?)
                  ?.map((s) => s is Map ? '${s['id']}' : '$s')
                  .where((s) => s.isNotEmpty && s != 'null')
                  .toList() ??
              const <String>[])
          : const <String>[];
      setState(() {
        _state = _ResolverTestState.success;
        _resultMessage = sources.isEmpty
            ? strings.resolverTestOk
            : strings.resolverTestOkWithSources(sources.join(', '));
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _state = _ResolverTestState.failure;
        _resultMessage = strings.resolverTestTimeout;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _state = _ResolverTestState.failure;
        _resultMessage = strings.resolverTestUnreachable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hub_rounded, size: 16, color: scheme.primaryContainer),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _discovering ? null : _discoverResolver,
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primaryContainer,
                side: BorderSide(
                    color: scheme.primaryContainer.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: _discovering
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primaryContainer,
                      ),
                    )
                  : const Icon(Icons.wifi_find_rounded, size: 16),
              label: Text(
                _discovering
                    ? strings.resolverDiscovering
                    : strings.resolverDiscoverOnWifi,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: scheme.primaryContainer, width: 1.5),
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    if (_state != _ResolverTestState.idle) {
                      setState(() {
                        _state = _ResolverTestState.idle;
                        _resultMessage = null;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: OutlinedButton(
                  onPressed: _state == _ResolverTestState.testing
                      ? null
                      : _testConnection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.primaryContainer,
                    side: BorderSide(
                        color: scheme.primaryContainer.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _state == _ResolverTestState.testing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.primaryContainer,
                          ),
                        )
                      : Text(
                          strings.testConnection,
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (widget.helper != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.helper!,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 11,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (_resultMessage != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _state == _ResolverTestState.success
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  size: 14,
                  color: _state == _ResolverTestState.success
                      ? const Color(0xFF4CAF7D)
                      : scheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _resultMessage!,
                    style: GoogleFonts.hankenGrotesk(
                      fontSize: 11,
                      color: _state == _ResolverTestState.success
                          ? const Color(0xFF4CAF7D)
                          : scheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (isPrimary) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.hankenGrotesk(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.15)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.hankenGrotesk(
            fontSize: 14, fontWeight: FontWeight.w500),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
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
    final scheme = Theme.of(context).colorScheme;
    final strings = widget.strings;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isRegister ? strings.createAccount : strings.signIn,
              style: GoogleFonts.sora(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              strings.accountServerHint,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            if (_isRegister) ...[
              _AuthField(
                controller: _displayNameController,
                icon: Icons.badge_outlined,
                label: '${strings.displayName} (${strings.optional})',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
            ],
            _AuthField(
              controller: _emailController,
              icon: Icons.mail_outline_rounded,
              label: strings.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            _AuthField(
              controller: _passwordController,
              icon: Icons.lock_outline_rounded,
              label: strings.password,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 12,
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isRegister
                                ? Icons.person_add_alt_1_rounded
                                : Icons.login_rounded,
                            size: 16,
                          ),
                    label: Text(
                      _isRegister ? strings.createAccount : strings.signIn,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: _isRegister ? strings.signIn : strings.createAccount,
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _isRegister = !_isRegister;
                            _error = null;
                          }),
                  icon: Icon(
                    _isRegister
                        ? Icons.login_rounded
                        : Icons.person_add_alt_1_rounded,
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
        SnackBar(
          content: Text(widget.strings.authSuccess),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        ),
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

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.icon,
    required this.label,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String label;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      style: GoogleFonts.hankenGrotesk(
        fontSize: 14,
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18),
        labelText: label,
      ),
    );
  }
}
