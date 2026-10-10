import '../models/ussd_entry.dart';

/// Illustrative UI seed data only. These records are intentionally unverified.
/// Replace with individually source-checked entries before a public release.
const seedCatalogue = <UssdEntry>[
  UssdEntry(
    id: 'demo-gh-data',
    name: 'Data bundles',
    description: 'Find your network’s data bundle options.',
    countryCode: 'GH',
    provider: 'Choose your network',
    category: 'Data & airtime',
    dialString: '',
    instructions: ['Choose your provider first.', 'Check official provider instructions before continuing.'],
  ),
  UssdEntry(
    id: 'demo-gh-balance',
    name: 'Check balance',
    description: 'Find instructions for checking your available balance.',
    countryCode: 'GH',
    provider: 'Choose your network',
    category: 'Account & balance',
    dialString: '',
    instructions: ['Select your provider.', 'Confirm the code with an official source.'],
  ),
  UssdEntry(
    id: 'demo-ng-data',
    name: 'Data bundles',
    description: 'Find your network’s data bundle options.',
    countryCode: 'NG',
    provider: 'Choose your network',
    category: 'Data & airtime',
    dialString: '',
    instructions: ['Choose your provider first.', 'Check official provider instructions before continuing.'],
  ),
  UssdEntry(
    id: 'demo-ng-balance',
    name: 'Check balance',
    description: 'Find instructions for checking your available balance.',
    countryCode: 'NG',
    provider: 'Choose your network',
    category: 'Account & balance',
    dialString: '',
    instructions: ['Select your provider.', 'Confirm the code with an official source.'],
  ),
];
