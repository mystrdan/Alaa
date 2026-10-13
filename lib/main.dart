import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'data/catalogue_repository.dart';
import 'data/local_preferences.dart';
import 'models/ussd_entry.dart';

void main() => runApp(const AlaaApp());

const _brandGreen = Color(0xFF7ED957);
const _ink = Color(0xFF172016);

/// Displays the official logo as-is. The asset always exists in release
/// builds; widget tests cannot load assets, so the error path renders empty
/// space rather than substituting a different mark.
Widget _brandLogo(double size) => Image.asset(
      'assets/branding/alaa-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
    );

class AlaaApp extends StatefulWidget {
  const AlaaApp({this.catalogueRepository, super.key});

  /// Injectable so tests can supply a repository backed by the real catalogue
  /// files; production passes nothing and gets the bundled asset copy.
  final CatalogueRepository? catalogueRepository;

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
        home: AlaaShell(
          themeMode: _themeMode,
          onThemeChanged: (value) => setState(() => _themeMode = value),
          catalogueRepository: widget.catalogueRepository,
        ),
      );
}

class AlaaShell extends StatefulWidget {
  const AlaaShell({
    required this.themeMode,
    required this.onThemeChanged,
    this.catalogueRepository,
    super.key,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final CatalogueRepository? catalogueRepository;
  @override
  State<AlaaShell> createState() => _AlaaShellState();
}

class _AlaaShellState extends State<AlaaShell> {
  int _tab = 0;
  String _country = 'GH';
  String _query = '';
  bool _countryConfirmed = true;
  bool _catalogueLoading = true;
  String? _catalogueError;
  List<String> _catalogueWarnings = const <String>[];
  Map<String, List<UssdEntry>> _catalogueByCountry = const <String, List<UssdEntry>>{};
  final Set<String> _favourites = <String>{};
  final List<_Contribution> _contributions = <_Contribution>[];
  final LocalPreferences _localPreferences = LocalPreferences();
  late final CatalogueRepository _catalogueRepository =
      widget.catalogueRepository ?? CatalogueRepository();

  @override
  void initState() {
    super.initState();
    _restoreLocalState();
    _loadCatalogue();
  }

  Future<void> _loadCatalogue() async {
    setState(() {
      _catalogueLoading = true;
      _catalogueError = null;
      _catalogueWarnings = const <String>[];
    });
    try {
      final outcome = await _catalogueRepository.loadAll();
      if (!mounted) return;
      setState(() {
        _catalogueByCountry = outcome.byCountry;
        _catalogueWarnings = outcome.warnings;
        _catalogueError = outcome.errors.isEmpty ? null : outcome.errors.join('\n');
      });
    } on Object catch (exc) {
      if (!mounted) return;
      setState(() => _catalogueError = exc.toString());
    } finally {
      if (mounted) setState(() => _catalogueLoading = false);
    }
  }

  Future<void> _restoreLocalState() async {
    try {
      final country = await _localPreferences.readCountry();
      final favourites = await _localPreferences.readFavourites();
      final pending = await _localPreferences.readPendingContributions();
      if (!mounted) return;
      setState(() {
        if (country != null) {
          _country = country;
        } else {
          // No saved choice yet: the device locale is not proof of country,
          // so ask the user to confirm instead of silently trusting it.
          _countryConfirmed = false;
        }
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
    setState(() {
      _country = country;
      _countryConfirmed = true;
    });
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

  Future<void> _removeContribution(String id) async {
    if (!mounted) return;
    setState(() => _contributions.removeWhere((item) => item.id == id));
    await _saveContributions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local draft deleted.')),
      );
    }
  }

  List<UssdEntry> get _countryEntries => _catalogueByCountry[_country] ?? const <UssdEntry>[];

  List<UssdEntry> get _visibleEntries =>
      _countryEntries.where((entry) => entry.matches(_query)).toList();

  List<UssdEntry> get _favouriteEntries => _catalogueByCountry.values
      .expand((list) => list)
      .where((entry) => _favourites.contains(entry.id))
      .toList();

  bool get _anyUnverifiedVisible =>
      _visibleEntries.any((entry) => entry.status != VerificationStatus.verified);

  String get _catalogueSummary {
    final all = _catalogueByCountry.values.expand((list) => list).toList();
    final verified = all.where((entry) => entry.status == VerificationStatus.verified).length;
    final base = '$verified of ${all.length} entries verified against operator sources · bundled offline catalogue';
    return _catalogueWarnings.isEmpty ? base : '$base · ${_catalogueWarnings.length} entries skipped as malformed';
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[_home(), _categories(), _favouritesPage(), _contributionsPage()];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          _brandLogo(34),
          const SizedBox(width: 10),
          const Text('Alaa', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 25, letterSpacing: -1)),
        ]),
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
          if (!_countryConfirmed) ...[
            const SizedBox(height: 14),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Welcome! Which country are you in?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 6),
              Text('Your phone’s language settings don’t tell us where you are, so please choose. You can change this later in Settings.', style: TextStyle(fontSize: 12.5, color: Colors.black.withValues(alpha: .65))),
              const SizedBox(height: 12),
              Row(children: [
                FilledButton(onPressed: () => _changeCountry('GH'), child: const Text('Ghana')),
                const SizedBox(width: 10),
                OutlinedButton(onPressed: () => _changeCountry('NG'), child: const Text('Nigeria')),
              ]),
            ]))),
          ],
          const SizedBox(height: 22),
          Row(children: [const Expanded(child: Text('Services', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))), Text('${_visibleEntries.length} found', style: Theme.of(context).textTheme.bodySmall)]),
          const SizedBox(height: 10),
          if (_catalogueLoading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 34), child: Center(child: CircularProgressIndicator()))
          else if (_catalogueError != null)
            _catalogueErrorCard()
          else if (_visibleEntries.isEmpty)
            _empty('No matching services', 'Try another search or change your country.')
          else
            ..._visibleEntries.map(_entryTile),
          const SizedBox(height: 12),
          Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFEAF7E3), child: Icon(Icons.volunteer_activism_outlined, color: _ink)), title: const Text('Know a code we’re missing?', style: TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Suggest it for review.'), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => setState(() => _tab = 3))),
          const SizedBox(height: 10),
          if (!_catalogueLoading && _catalogueError == null && _anyUnverifiedVisible) const _UnverifiedNotice(),
        ],
      );

  Widget _catalogueErrorCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.error_outline_rounded, color: Color(0xFFB3261E)), SizedBox(width: 8), Expanded(child: Text('Catalogue unavailable', style: TextStyle(fontWeight: FontWeight.w800)))]),
            const SizedBox(height: 8),
            Text(_catalogueError ?? 'Unknown error', style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _loadCatalogue, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
          ]),
        ),
      );

  Widget _categories() {
    const categories = <String, IconData>{'Telecom': Icons.wifi_rounded, 'Government': Icons.account_balance_outlined, 'Education': Icons.school_outlined, 'Finance and Payments': Icons.payments_outlined, 'Health': Icons.health_and_safety_outlined, 'Utilities': Icons.bolt_outlined, 'Transport': Icons.directions_bus_outlined, 'Agriculture': Icons.agriculture_outlined, 'Insurance and Pensions': Icons.shield_outlined, 'Commerce': Icons.storefront_outlined, 'Other Services': Icons.grid_view_rounded};
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Browse categories', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('Find a service by what you want to do.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 20),
      ...categories.entries.map((item) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFEAF7E3), child: Icon(item.value, color: _ink)), title: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_right_rounded), onTap: () => setState(() { _query = item.key; _tab = 0; })))),
      if (!_catalogueLoading && _catalogueError == null && _anyUnverifiedVisible) const _UnverifiedNotice(),
    ]);
  }

  Widget _favouritesPage() {
    final entries = _favouriteEntries;
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
        FilledButton.icon(onPressed: () => _newContribution(type: 'suggestion'), icon: const Icon(Icons.add_rounded), label: const Text('Suggest a USSD code')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () => _newContribution(type: 'report'), icon: const Icon(Icons.flag_outlined), label: const Text('Report a broken code')),
        const SizedBox(height: 20),
        if (_contributions.isEmpty) _empty('No contributions yet', 'Pending contributions will appear here.') else ..._contributions.map((item) => Card(child: ListTile(leading: const Icon(Icons.schedule_rounded), title: Text(item.name), subtitle: Text('${item.type == 'report' ? 'Report' : 'Suggestion'} · ${item.country} · local prototype queue'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Chip(label: Text(_statusLabel(item.status))), IconButton(tooltip: 'Delete local draft', onPressed: () => _removeContribution(item.id), icon: const Icon(Icons.delete_outline_rounded))])))),
        const SizedBox(height: 14),
        const _UnverifiedNotice(),
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

  void _newContribution({String type = 'suggestion'}) {
    final name = TextEditingController();
    final code = TextEditingController();
    final provider = TextEditingController();
    final description = TextEditingController();
    showModalBottomSheet<void>(context: context, isScrollControlled: true, showDragHandle: true, builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(type == 'report' ? 'Report a broken code' : 'Suggest a code', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
          setState(() => _contributions.add(_Contribution(id: 'draft-${DateTime.now().microsecondsSinceEpoch}', type: type, name: serviceName, country: _country, code: code.text.trim(), provider: provider.text.trim(), description: summary, createdAt: DateTime.now().toUtc().toIso8601String())));
          _saveContributions();
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved on this device. Automatic delivery is not connected yet.')));
        }, child: const Text('Save on this device'))),
      ])),
    ));
  }

  void _openMenu() => showModalBottomSheet<void>(context: context, showDragHandle: true, builder: (sheetContext) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.settings_outlined), title: const Text('Settings'), onTap: () { Navigator.pop(sheetContext); Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsPage(themeMode: widget.themeMode, onThemeChanged: widget.onThemeChanged, country: _country, onCountryChanged: _changeCountry, catalogueSummary: _catalogueSummary))); }),
        ListTile(leading: const Icon(Icons.info_outline_rounded), title: const Text('About Alaa'), onTap: () { Navigator.pop(sheetContext); Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AboutPage(catalogueSummary: _catalogueSummary))); }),
        ListTile(leading: const Icon(Icons.share_outlined), title: const Text('Share Alaa'), subtitle: const Text('Share the project link'), onTap: () { Navigator.pop(sheetContext); Share.share('Alaa — an offline-first USSD assistant for Ghana and Nigeria. Explore the project: https://github.com/mystrdan/Alaa'); }),
      ]))));
}

class ServiceDetailPage extends StatelessWidget {
  const ServiceDetailPage({required this.entry, required this.onFavourite, super.key});
  final UssdEntry entry;
  final VoidCallback onFavourite;

  String get _statusLabel => switch (entry.effectiveStatus) {
        VerificationStatus.verified => 'Verified against source',
        VerificationStatus.corroborated => 'Corroborated by credible sources',
        VerificationStatus.stale => 'Last check is old — may have changed',
        VerificationStatus.historical => 'Historical — may be discontinued',
        VerificationStatus.disputed => 'Reported as incorrect — under review',
        VerificationStatus.retired => 'Retired by the operator — do not use',
        VerificationStatus.unverified => 'Unverified — not confirmed by a source yet',
      };

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Service details'), actions: [IconButton(tooltip: 'Toggle favourite', onPressed: onFavourite, icon: const Icon(Icons.favorite_border_rounded))]), body: ListView(padding: const EdgeInsets.all(20), children: [
        CircleAvatar(radius: 30, backgroundColor: const Color(0xFFEAF7E3), child: Icon(_categoryIcon(entry.category), size: 28, color: _ink)),
        const SizedBox(height: 16),
        Text(entry.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('${entry.countryName} · ${entry.provider}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 12),
        Center(child: Chip(
          avatar: Icon(entry.canLaunchDialer ? Icons.verified_rounded : Icons.help_outline_rounded, size: 16, color: entry.canLaunchDialer ? const Color(0xFF1B5E20) : const Color(0xFF76520A)),
          label: Text(_statusLabel, style: const TextStyle(fontSize: 12)),
          backgroundColor: entry.canLaunchDialer ? const Color(0xFFE3F3E1) : const Color(0xFFFFF3D7),
          side: BorderSide.none,
        )),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('What it does', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(entry.description),
          if (entry.networkScope != null) ...[
            const SizedBox(height: 14),
            const Text('Who it applies to', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(entry.networkScope!),
          ],
          if (entry.instructions.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text('How to use it', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ...entry.instructions.asMap().entries.map((item) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${item.key + 1}. ${item.value}'))),
          ],
          if (entry.costNote != null) ...[
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.payments_outlined, size: 16), const SizedBox(width: 6), Expanded(child: Text(entry.costNote!, style: const TextStyle(fontSize: 12.5, color: Colors.black54)))]),
          ],
        ]))),
        const SizedBox(height: 14),
        if (entry.canLaunchDialer)
          FilledButton.icon(
            onPressed: () => _launchUssd(context, entry.dialString),
            icon: const Icon(Icons.dialpad_rounded),
            label: const Text('Open USSD dialer'),
          )
        else ...[
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.dialpad_rounded),
            label: const Text('USSD code not verified'),
          ),
          const SizedBox(height: 6),
          const Text('This code is not available for dialling (historical, disputed, or retired). Copy the code and double-check with your operator instead.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ],
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
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Verification', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_statusLabel),
          if (entry.verifiedAt != null) ...[
            const SizedBox(height: 6),
            Text('Last checked: ${entry.verifiedAt!.toIso8601String().substring(0, 10)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
          if (entry.sourceUrl != null) ...[
            const SizedBox(height: 6),
            Text('Source: ${entry.sourceUrl!}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ] else
            const Padding(padding: EdgeInsets.only(top: 6), child: Text('No source recorded yet. Treat this code as unconfirmed.', style: TextStyle(fontSize: 12, color: Colors.black54))),
          const SizedBox(height: 6),
          const Text('USSD menus can change by SIM, plan, device, or date. Re-check with your operator if a code no longer matches.', style: TextStyle(fontSize: 12, color: Colors.black54)),
        ]))),
        const SizedBox(height: 12),
        const Text('USSD sessions may initiate transactions or incur charges. Alaa does not complete transactions for you and cannot see what happens in the carrier session.', style: TextStyle(fontSize: 12, color: Colors.black54)),
      ]));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.themeMode, required this.onThemeChanged, required this.country, required this.onCountryChanged, this.catalogueSummary, super.key});
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final String country;
  final ValueChanged<String> onCountryChanged;
  final String? catalogueSummary;
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
        ListTile(leading: const Icon(Icons.wifi_off_rounded), title: const Text('Offline catalogue'), subtitle: Text(catalogueSummary ?? 'Bundled offline catalogue.')),
        const ListTile(leading: Icon(Icons.cloud_off_outlined), title: Text('Catalogue updates'), subtitle: Text('Automatic catalogue updates are not enabled yet; the bundled catalogue is used.')),
        const ListTile(leading: Icon(Icons.inbox_outlined), title: Text('Contribution drafts'), subtitle: Text('Suggestion and report drafts stay on this device until delivery is connected. You can view and delete them from the Contribute tab.')),
      ]));
}

class AboutPage extends StatelessWidget {
  const AboutPage({this.catalogueSummary, super.key});
  final String? catalogueSummary;
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('About Alaa')), body: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 18),
        Center(child: _brandLogo(110)),
        const SizedBox(height: 12),
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
        ListTile(leading: const Icon(Icons.dataset_outlined), title: const Text('Catalogue'), subtitle: Text(catalogueSummary ?? 'Bundled offline catalogue with per-entry sources.')),
        const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Privacy'), subtitle: Text('Favourites and contribution drafts stay on this device. Privacy policy and terms must be published before release.')),
      ]));
}

class _UnverifiedNotice extends StatelessWidget {
  const _UnverifiedNotice();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF3D7), borderRadius: BorderRadius.circular(14)), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF76520A)), SizedBox(width: 8), Expanded(child: Text('Unverified and corroborated entries are clearly marked and can still be dialled. Codes can change by SIM, plan, or date — check with your operator before relying on one.', style: TextStyle(fontSize: 12, color: Color(0xFF76520A))))]));
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

  factory _Contribution.fromMap(Map<String, dynamic> map) {
    String stringValue(String key, [String fallback = '']) {
      final value = map[key];
      return value is String ? value : fallback;
    }

    final name = stringValue('name', 'Untitled contribution');
    final storedId = stringValue('id');
    final storedStatus = stringValue('status');
    const allowedStatuses = {'pending', 'sending', 'delivered', 'failed'};
    return _Contribution(
      id: storedId.isNotEmpty ? storedId : 'legacy-$name',
      type: stringValue('type') == 'report' ? 'report' : 'suggestion',
      name: name,
      country: stringValue('country') == 'NG' ? 'NG' : 'GH',
      code: stringValue('code'),
      provider: stringValue('provider'),
      description: stringValue('description'),
      status: allowedStatuses.contains(storedStatus) ? storedStatus : 'pending',
      createdAt: map['createdAt'] is String ? map['createdAt'] as String : null,
    );
  }
}

String _statusLabel(String status) {
  if (status.isEmpty) return 'Pending';
  return '${status[0].toUpperCase()}${status.substring(1)}';
}

IconData _categoryIcon(String category) => switch (category) {
      'Telecom' => Icons.wifi_rounded,
      'Government' => Icons.account_balance_outlined,
      'Education' => Icons.school_outlined,
      'Finance and Payments' => Icons.payments_outlined,
      'Health' => Icons.health_and_safety_outlined,
      'Utilities' => Icons.bolt_outlined,
      'Transport' => Icons.directions_bus_outlined,
      'Agriculture' => Icons.agriculture_outlined,
      'Insurance and Pensions' => Icons.shield_outlined,
      'Commerce' => Icons.storefront_outlined,
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
