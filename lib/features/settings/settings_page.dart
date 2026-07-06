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

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _apiController = TextEditingController(text: appState.apiBaseUrl);
    _resolverController = TextEditingController(text: appState.resolverBaseUrl);
  }

  @override
  void dispose() {
    _apiController.dispose();
    _resolverController.dispose();
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
        Row(
          children: [
            FilledButton.icon(
              onPressed: () async {
                await appState.setApiBaseUrl(_apiController.text);
                await appState.setResolverBaseUrl(_resolverController.text);
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
}
