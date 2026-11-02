/// The Florkverse catalogue: apps of the Flork ecosystem that open in the in-app browser.
class FlorkApp {
  const FlorkApp({
    required this.name,
    required this.tagline,
    required this.about,
    required this.url,
    required this.category,
    required this.art,
    this.official = true,
  });
  final String name;
  final String tagline;
  final String about;
  final String url;
  final String category;
  final String art;
  final bool official;
}

const categories = ['All', 'Launch', 'Earn', 'Tools', 'Social'];

const florkApps = [
  FlorkApp(
    name: 'Flork Family',
    tagline: 'Launch coins, build apps, join clans',
    about: 'The home of the Flork ecosystem: launch a coin on Solana, build an app from a template, '
        'join a clan and claim your creator fees from every launchpad in one place.',
    url: 'https://flork.family',
    category: 'Launch',
    art: 'assets/art/meet_flork.png',
  ),
  FlorkApp(
    name: 'Earn FLORK',
    tagline: 'Quests that pay in FLORK',
    about: 'Complete tasks on flork.family and stack Flork for the launch.',
    url: 'https://flork.family/earn',
    category: 'Earn',
    art: 'assets/art/flork_celular.png',
  ),
  FlorkApp(
    name: 'flork.fun',
    tagline: 'Multichain meme launchpad',
    about: 'Create and trade meme coins on bonding curves across Solana and EVM chains.',
    url: 'https://flork.fun',
    category: 'Launch',
    art: 'assets/art/logo_flork.png',
  ),
  FlorkApp(
    name: 'Florkcoin',
    tagline: 'Meme maker and Flork AI',
    about: 'Generate Flork memes and chat with Flork AI. Holding FLORK unlocks the chat.',
    url: 'https://florkcoin.com',
    category: 'Tools',
    art: 'assets/art/flork_acostado.png',
  ),
  FlorkApp(
    name: 'Clans',
    tagline: 'Find your Flork crew',
    about: 'Clans with their own chat, ranks and coins, shared across the Flork apps.',
    url: 'https://flork.family/clans',
    category: 'Social',
    art: 'assets/art/meet_flork.png',
  ),
];
