import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/services/music_api.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _apiController;

  @override
  void initState() {
    super.initState();
    _apiController = TextEditingController(text: context.read<AppState>().apiBaseUrl);
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
      children: [
        Text(
          'Settings',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _apiController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'API base URL',
            prefixIcon: Icon(Icons.dns),
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () async {
                await appState.setApiBaseUrl(_apiController.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('API server updated')),
                  );
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _apiController.text = MusicApi.defaultBaseUrl,
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.favorite),
          title: const Text('Favorite songs'),
          subtitle: Text('${appState.favoriteIds.length} saved locally'),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.phone_android),
          title: Text('Mobile rebuild'),
          subtitle: Text('Flutter shell inspired by AlgerMusicPlayer desktop workflows'),
        ),
      ],
    );
  }
}
