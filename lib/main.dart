import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'data/seed_catalogue.dart';
import 'data/local_preferences.dart';
import 'models/ussd_entry.dart';

void main() => runApp(const AlaaApp());

const _brandGreen = Color(0xFF7ED957);
const _ink = Color(0xFF172016);

class AlaaApp extends StatefulWidget {
  const AlaaApp({super.key});
  @override
  State<AlaaApp> createState() => _AlaaAppState();
}

class _AlaaAppState extends State<AlaaApp> {
  ThemeMode _themeMode = ThemeMode.system;
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Alaa',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: _brandGreen),
          scaffoldBackgroundColor: const Color(0xFFF8FAF6),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF8FAF6), foregroundColor: _ink),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: _brandGreen, brightness: Brightness.dark)),
        home: AlaaShell(themeMode: _themeMode, onThemeChanged: (value) => setState(() => _themeMode = value)),
      );
}

class AlaaShell extends StatefulWidget {
  const AlaaShell({required this.themeMode, required this.onThemeChanged, super.key});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<AlaaShell> createState() => _AlaaShellState();
}

class _AlaaShellState extends State<AlaaShell> {
  int _tab = 0;
  String _country = 'GH';
  String _query = '';
  final Set<String> _favourites = <String>{};
  final List<_Contribution> _contributions = <_Contribution>[];
  final LocalPreferences _localPreferences = LocalPreferences();

  @override
  void initState() {
    super.initState();
    _restoreLocalState();
  }

  Future<void> _restoreLocalState() async {
    try {
      final country = await _localPreferences.readCountry();
      final favourites = await _localPreferences.readFavourites();
      final pending = await _localPreferences.readPendingContributions();
      if (!mounted) return;
      setState(() {
        if (country != null) _country = country;
        _favourites
          ..clear()
          ..addAll(favourites);
        _contributions
          ..clear()
          ..addAll(pending.map(_Contribution.fromMap));
      });
    } catch (_) {
      // Keep the app usable with defaults if local preferences cannot be read.
    }
  }

  Future<void> _changeCountry(String country) async {
    setState(() => _country = country);
    await _localPreferences.saveCountry(country);
  }

  Future<void> _toggleFavourite(String id) async {
    setState(() {
      if (_favourites.contains(id)) {
        _favourites.remove(id);
      } else {
        _favourites.add(id);
      }
    });
    await _localPreferences.saveFavourites(_favourites);
  }

  Future<void> _saveContributions() => _localPreferences.savePendingContributions(
        _contributions.map((item) => item.toMap()).toList(),
      );

  List<UssdEntry> get _entries => seedCatalogue.where((entry) => entry.countryCode == _country && entry.matches(_query)).toList();

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[_home(), _categories(), _favouritesPage(), _contributionsPage()];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Alaa', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 25, letterSpacing: -1)),
        actions: [IconButton(tooltip: 'Settings and About', onPressed: _openMenu, icon: const Icon(Icons.tune_rounded)), const SizedBox(width: 8)],
      ),
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Categories'),
          NavigationDestination(icon: Icon(Icons.favorite_border_rounded), selectedIcon: Icon(Icons.favorite_rounded), label: 'Favourites'),
          NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: 'Contribute'),
        ],
      ),
    );
  }

  Widget _home() => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: const Color(0xFFEAF7E3), borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.wifi_off_rounded, size: 15), SizedBox(width: 6), Text('Works offline', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]),
              ),
              const SizedBox(height: 18),
              const Text('What do you need to do?', style: TextStyle(fontSize: 27, height: 1.12, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 8),
              Text('Find a code. Understand it. Get connected.', style: TextStyle(fontSize: 14, color: _ink.withValues(alpha: .75))),
              const SizedBox(height: 20),
              TextField(onChanged: (value) => setState(() => _query = value), decoration: const InputDecoration(hintText: 'Search “buy data” or “check balance”', prefixIcon: Icon(Icons.search_rounded), fillColor: Colors.white)),
            ]),
          ),
          const SizedBox(height: 22),
          Row(children: [const Expanded(child: Text('Your country', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), SegmentedButton<String>(segments: const [ButtonSegment(value: 'GH', label: Text('Ghana')), ButtonSegment(value: 'NG', label: Text('Nigeria'))], selected: {_country}, onSelectionChanged: (value) => _changeCountry(value.first), showSelectedIcon: false)]),
          const SizedBox(height: 22),
          Row(children: [const Expanded(child: Text('Services', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))), Text('${_entries.length} found', style: Theme.of(context).textTheme.bodySmall)]),
          const SizedBox(height: 10),
          if (_entries.isEmpty) _empty('No matching services', 'Try another search or change your country.') else ..._entries.map(_entryTile),
          const SizedBox(height: 12),
          Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFEAF7E3), child: Icon(Icons.volunteer_activism_outlined, color: _ink)), title: const Text('Know a code we’re missing?', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Suggest it for review.'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => setState(() => _tab = 3))),
          const SizedBox(height: 10),
          const _DemoNotice(),
        ],
      );

  Widget _categories() {
    const categories = <String, IconData>{'Data & airtime': Icons.wifi_rounded, 'Account & balance': Icons.account_balance_wallet_outlined, 'Mobile money': Icons.payments_outlined, 'Banking': Icons.account_balance_outlined, 'SIM & network': Icons.sim_card_outlined, 'Customer care': Icons.support_agent_rounded};
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Browse categories', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Find a service by what you want to do.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 20),
      ...categories.entries.map((item) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFEAF7E3), child: Icon(item.value, color: _ink)), title: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => setState(() { _query = item.key; _tab = 0; })))),
      const _DemoNotice(),
    ]);
  }

  Widget _favouritesPage() {
    final entries = seedCatalogue.where((entry) => _favourites.contains(entry.id)).toList();
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Favourites', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Saved services stay on this device.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 18),
      if (entries.isEmpty) _empty('Nothing saved yet', 'Tap the heart on a service to keep it here.') else ...entries.map(_entryTile),
    ]);
  }

  Widget _contributionsPage() => ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Contribute to Alaa', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text('Suggest a missing code or report one that may have changed.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: _newContribution, icon: const Icon(Icons.add_rounded), label: const Text('Suggest a USSD code')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: _newContribution, icon: const Icon(Icons.flag_outlined), label: const Text('Report a broken code')),
        const SizedBox(height: 20),
        if (_contributions.isEmpty) _empty('No contributions yet', 'Pending contributions will appear here.') else ..._contributions.map((item) => Card(child: ListTile(leading: const Icon(Icons.schedule_rounded), title: Text(item.name), subtitle: Text('${item.country} · local prototype queue'), trailing: const Chip(label: Text('Pending'))))),
        const SizedBox(height: 14),
        const _DemoNotice(),
        const SizedBox(height: 10),
        const Text('Public GitHub issues may expose submissions. Never include phone numbers, PINs, account details, or other personal information.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]);

  Widget _entryTile(UssdEntry entry) {
    final isFavourite = _favourites.contains(entry.id);
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      leading: CircleAvatar(backgroundColor: const Color(0xFFEAF7E3), child: Icon(_categoryIcon(entry.category), color: _ink)),
      title: Text(entry.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('${entry.description}\n${entry.countryName} · ${entry.provider}', maxLines: 3)),
      isThreeLine: true,
      trailing: IconButton(tooltip: isFavourite ? 'Remove favourite' : 'Add favourite', onPressed: () => _toggleFavourite(entry.id), icon: Icon(isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: isFavourite ? Colors.redAccent : null)),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ServiceDetailPage(
            entry: entry,
            onFavourite: () => _toggleFavourite(entry.id),
          ),
        ));
      },
    ));
  }

  Widget _empty(String title, String body) => Padding(padding: const EdgeInsets.symmetric(vertical: 34), child: Column(children: [const Icon(Icons.search_off_rounded, size: 38, color: Colors.black38), const SizedBox(height: 12), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 5), Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));

  void _newContribution() {
    final name = TextEditingController();
    final code = TextEditingController();
    final provider = TextEditingController();
    final description = TextEditingController();
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Suggest a code', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Prototype form only: local persistence and GitHub delivery are not connected yet.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        TextField(controller: name, maxLength: 100, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Service name')),
        const SizedBox(height: 10),
        TextField(controller: code, maxLength: 32, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'USSD code (if known)')),
        const SizedBox(height: 10),
        TextField(controller: provider, maxLength: 80, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Network / provider')),
        const SizedBox(height: 10),
        TextField(controller: description, maxLength: 500, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What does it do?')),
        const SizedBox(height: 12),
        const Text('Do not include personal information. Submissions sent to GitHub may be public.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () {
          final serviceName = name.text.trim();
          final summary = description.text.trim();
          if (serviceName.isEmpty || summary.isEmpty) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Add a service name and explain what the code does.')));
            return;
          }
          setState(() => _contributions.add(_Contribution(id: 'draft-${DateTime.now().microsecondsSinceEpoch}', type: 'suggestion', name: serviceName, country: _country, code: code.text.trim(), provider: provider.text.trim(), description: summary, createdAt: DateTime.now().toUtc().toIso8601String())));
          _saveContributions();
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved on this device. Automatic delivery is not connected yet.')));
        }, child: const Text('Save on this device'))),
      ])),
    ));
  }

  void _openMenu() => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), onTap: () { Navigator.pop(sheetContext); Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(themeMode: widget.themeMode, onThemeChanged: widget.onThemeChanged, country: _country, onCountryChanged: _changeCountry))); }),
        ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('About Alaa'), onTap: () { Navigator.pop(sheetContext); Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutPage())); }),
        ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share Alaa'), subtitle: const Text('Share the project link'), onTap: () { Navigator.pop(sheetContext); Share.share('Alaa — an offline-first USSD assistant for Ghana and Nigeria. Explore the project: https://github.com/mystrdan/Alaa'); }),
      ]))));
}

class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({required this.entry, required this.onFavourite, super.key});
  final UssdEntry entry;
  final VoidCallback onFavourite;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Service details'), actions: [IconButton(onPressed: onFavourite, icon: const Icon(Icons.favorite_border_rounded))]), body: ListView(padding: const EdgeInsets.all(20), children: [
        CircleAvatar(radius: 30, backgroundColor: const Color(0xFFEAF7E3), child: Icon(_categoryIcon(entry.category), size: 28, color: _ink)),
        const SizedBox(height: 16),
        Text(entry.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${entry.countryName} · ${entry.provider}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 20),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('What it does', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Text(entry.description), const SizedBox(height: 18), const Text('Instructions', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), ...entry.instructions.asMap().entries.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${item.key + 1}. ${item.value}')))]))),
        const SizedBox(height: 14),
        if (entry.dialString.trim().isNotEmpty && entry.status == VerificationStatus.verified)
          FilledButton.icon(
            onPressed: () => _launchUssd(context, entry.dialString),
            icon: const Icon(Icons.dialpad_rounded),
            label: const Text('Open USSD dialer'),
          )
        else
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.dialpad_rounded),
            label: const Text('USSD code not verified'),
          ),
        if (entry.dialString.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: entry.dialString));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied to clipboard')));
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy code'),
          ),
        ],
        const SizedBox(height: 14),
        const _DemoNotice(),
        const SizedBox(height: 12),
        const Text('USSD sessions may initiate transactions or incur charges. Alaa does not complete transactions for you.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.themeMode, required this.onThemeChanged, required this.country, required this.onCountryChanged, super.key});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final String country;
  final ValueChanged<String> onCountryChanged;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Preferences', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        const Text('Default country'),
        const SizedBox(height: 8),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'GH', label: Text('Ghana')), ButtonSegment(value: 'NG', label: Text('Nigeria'))], selected: {country}, onSelectionChanged: (value) => onCountryChanged(value.first), showSelectedIcon: false),
        const SizedBox(height: 24),
        const Text('Appearance'),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.settings_suggest_outlined)),
            ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
            ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
          ],
          selected: {themeMode},
          onSelectionChanged: (value) => onThemeChanged(value.first),
          showSelectedIcon: false,
        ),
        const Divider(height: 30),
        const ListTile(leading: Icon(Icons.wifi_off_rounded), title: Text('Offline catalogue'), subtitle: Text('Automatic catalogue sync is planned.')),
        const ListTile(leading: Icon(Icons.inbox_outlined), title: Text('Pending contributions'), subtitle: Text('Persistent queue and delivery status are planned.')),
        const ListTile(leading: Icon(Icons.notifications_none_rounded), title: Text('Notifications'), subtitle: Text('Optional delivery notifications are planned.')),
      ]));
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('About Alaa')), body: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 18),
        const Text('Alaa', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
        const SizedBox(height: 10),
        const Text('Your offline-first USSD assistant', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.black54)),
        const SizedBox(height: 26),
        const Text('Find a code. Understand it. Get connected.', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        const Text('Alaa helps you discover USSD services, understand what they do, and launch them from your phone. Core catalogue features are designed to work offline.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        const ListTile(leading: Icon(Icons.public_outlined), title: Text('Initial countries'), subtitle: Text('Ghana and Nigeria')),
        const ListTile(leading: Icon(Icons.info_outline), title: Text('App version'), subtitle: Text('0.1.0 · Development preview')),
        const ListTile(leading: Icon(Icons.dataset_outlined), title: Text('Catalogue'), subtitle: Text('Demo seed data · not verified')),
        const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy'), subtitle: Text('Privacy policy and terms must be published before release.')),
      ]));
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF3D7), borderRadius: BorderRadius.circular(14)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF76520A)), SizedBox(width: 8), Expanded(child: Text('Development preview: entries are illustrative and unverified. Do not use them for real transactions.', style: TextStyle(fontSize: 12, color: Color(0xFF76520A))))]));
}

class _Contribution {
  const _Contribution({
    required this.id,
    required this.type,
    required this.name,
    required this.country,
    required this.code,
    required this.provider,
    required this.description,
    this.status = 'pending',
    this.createdAt,
  });

  final String id;
  final String type;
  final String name;
  final String country;
  final String code;
  final String provider;
  final String description;
  final String status;
  final String? createdAt;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'type': type,
        'name': name,
        'country': country,
        'code': code,
        'provider': provider,
        'description': description,
        'status': status,
        'createdAt': createdAt,
      };

  factory _Contribution.fromMap(Map<String, dynamic> map) => _Contribution(
        id: map['id'] is String && (map['id'] as String).isNotEmpty
            ? map['id'] as String
            : 'legacy-${map['name'] ?? 'draft'}',
        type: map['type'] == 'report' ? 'report' : 'suggestion',
        name: map['name'] as String? ?? 'Untitled contribution',
        country: map['country'] == 'NG' ? 'NG' : 'GH',
        code: map['code'] as String? ?? '',
        provider: map['provider'] as String? ?? '',
        description: map['description'] as String? ?? '',
        status: map['status'] is String ? map['status'] as String : 'pending',
        createdAt: map['createdAt'] as String?,
      );
}

IconData _categoryIcon(String category) => switch (category) {
      'Data & airtime' => Icons.wifi_rounded,
      'Account & balance' => Icons.account_balance_wallet_outlined,
      'Mobile money' => Icons.payments_outlined,
      'Banking' => Icons.account_balance_outlined,
      'SIM & network' => Icons.sim_card_outlined,
      'Customer care' => Icons.support_agent_rounded,
      _ => Icons.grid_view_rounded,
    };


Future<void> _launchUssd(BuildContext context, String dialString) async {
  // Launch the Android phone app; Alaa never reads the USSD session response.
  try {
    final uri = Uri(scheme: 'tel', path: dialString);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the dialer. Try copying the code instead.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This device could not open the dialer. Try copying the code instead.')));
    }
  }
}
