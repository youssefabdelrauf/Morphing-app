import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_editor_plus/image_editor_plus.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

// ---------------------------------------------------------------------------
// 🚀 1. INITIALIZATION & ENTRY POINT
// ---------------------------------------------------------------------------

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint("Camera Error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateManager()),
      ],
      child: const MorphyApp(),
    ),
  );
}

class MorphyApp extends StatelessWidget {
  const MorphyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateManager>(context);

    return MaterialApp(
      title: 'Morphy',
      debugShowCheckedModeBanner: false,
      theme: state.currentThemeData,
      home: state.isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// 🧠 2. APP STATE MANAGER
// ---------------------------------------------------------------------------

enum AppThemeType { joyful, galaxy, cyberpunk, liquid }

class ShopItem {
  final String id;
  final String name;
  final int cost;
  final IconData icon;
  final String type; // 'avatar' or 'bg_pack'
  final List<IconData>? bgIcons;

  ShopItem(
      {required this.id,
      required this.name,
      required this.cost,
      required this.icon,
      required this.type,
      this.bgIcons});
}

class AppStateManager extends ChangeNotifier {
  bool isLoggedIn = false;
  String username = "Guest";
  String nickname = "Morphy Fan";
  String email = "";

  int xp = 700;
  int level = 5;
  int coins = 1000;

  Set<String> ownedItems = {'default_avatar', 'default_bg'};
  String equippedAvatarId = 'default_avatar';
  String equippedBgPackId = 'default_bg';

  // Active Colors (Global)
  List<Color> activeIconColors = [
    Colors.orange,
    Colors.pink,
    Colors.blueAccent
  ];

  // Temporary Colors (For Studio Preview)
  final List<Color> _tempColors = [
    Colors.orange,
    Colors.pink,
    Colors.blueAccent
  ];
  List<Color> get tempColors => _tempColors;

  AppThemeType _currentTheme = AppThemeType.joyful;
  AppThemeType get currentTheme => _currentTheme;

  final List<ShopItem> shopCatalog = [
    ShopItem(
        id: 'robot_avatar',
        name: 'Robo Bot',
        cost: 100,
        icon: Icons.smart_toy,
        type: 'avatar'),
    ShopItem(
        id: 'alien_avatar',
        name: 'Alien Head',
        cost: 150,
        icon: Icons.face_retouching_natural,
        type: 'avatar'),
    ShopItem(
        id: 'ninja_avatar',
        name: 'Ninja',
        cost: 200,
        icon: Icons.masks,
        type: 'avatar'),
    ShopItem(
        id: 'king_avatar',
        name: 'King',
        cost: 250,
        icon: Icons.emoji_events,
        type: 'avatar'),
    ShopItem(
        id: 'food_bg',
        name: 'Yummy Pack',
        cost: 120,
        icon: Icons.fastfood,
        type: 'bg_pack',
        bgIcons: [
          Icons.fastfood,
          Icons.local_pizza,
          Icons.icecream,
          Icons.local_cafe
        ]),
    ShopItem(
        id: 'nature_bg',
        name: 'Nature Pack',
        cost: 120,
        icon: Icons.forest,
        type: 'bg_pack',
        bgIcons: [Icons.forest, Icons.wb_sunny, Icons.water_drop, Icons.eco]),
    ShopItem(
        id: 'music_bg',
        name: 'Party Pack',
        cost: 120,
        icon: Icons.music_note,
        type: 'bg_pack',
        bgIcons: [Icons.music_note, Icons.headset, Icons.speaker, Icons.mic]),
    ShopItem(
        id: 'space_bg',
        name: 'Space Pack',
        cost: 150,
        icon: Icons.rocket_launch,
        type: 'bg_pack',
        bgIcons: [
          Icons.rocket_launch,
          Icons.public,
          Icons.star,
          Icons.satellite_alt
        ]),
    ShopItem(
        id: 'sports_bg',
        name: 'Sports Pack',
        cost: 150,
        icon: Icons.sports_soccer,
        type: 'bg_pack',
        bgIcons: [
          Icons.sports_soccer,
          Icons.sports_basketball,
          Icons.sports_tennis,
          Icons.emoji_events
        ]),
    ShopItem(
        id: 'magic_bg',
        name: 'Magic Pack',
        cost: 180,
        icon: Icons.auto_fix_high,
        type: 'bg_pack',
        bgIcons: [
          Icons.auto_fix_high,
          Icons.auto_awesome,
          Icons.color_lens,
          Icons.psychology
        ]),
    ShopItem(
        id: 'tech_bg',
        name: 'Tech Pack',
        cost: 180,
        icon: Icons.computer,
        type: 'bg_pack',
        bgIcons: [Icons.computer, Icons.smartphone, Icons.memory, Icons.wifi]),
    ShopItem(
        id: 'spooky_bg',
        name: 'Spooky Pack',
        cost: 200,
        icon: Icons.bakery_dining,
        type: 'bg_pack',
        bgIcons: [Icons.adb, Icons.bug_report, Icons.dangerous, Icons.warning]),
  ];

  IconData get currentAvatar {
    if (equippedAvatarId == 'default_avatar') return Icons.person;
    return shopCatalog
        .firstWhere((e) => e.id == equippedAvatarId,
            orElse: () => shopCatalog[0])
        .icon;
  }

  List<IconData> get currentBgIcons {
    if (equippedBgPackId == 'default_bg') {
      return [Icons.face, Icons.emoji_emotions, Icons.star, Icons.camera_alt];
    }
    return shopCatalog.firstWhere((e) => e.id == equippedBgPackId).bgIcons!;
  }

  void login(String user, String mail) {
    isLoggedIn = true;
    username = user;
    email = mail;
    notifyListeners();
  }

  void logout() {
    isLoggedIn = false;
    username = "Guest";
    notifyListeners();
  }

  void updateNickname(String newName) {
    nickname = newName;
    notifyListeners();
  }

  void addCoins(int amount) {
    coins += amount;
    notifyListeners();
  }

  // --- NEW COLOR LOGIC ---
  void toggleTempColor(Color c) {
    if (_tempColors.contains(c)) {
      if (_tempColors.length > 1) _tempColors.remove(c);
    } else {
      _tempColors.add(c);
    }
    notifyListeners(); // Updates preview in Studio immediately
  }

  void applyColors() {
    activeIconColors = List.from(_tempColors); // Commit changes
    notifyListeners(); // Updates Home Screen
  }

  String buyItem(String itemId) {
    if (ownedItems.contains(itemId)) return "Already owned!";
    final item = shopCatalog.firstWhere((e) => e.id == itemId);
    if (coins >= item.cost) {
      coins -= item.cost;
      ownedItems.add(itemId);
      notifyListeners();
      return "Purchased ${item.name}!";
    } else {
      return "Not enough coins!";
    }
  }

  void equipItem(String itemId, String type) {
    if (!ownedItems.contains(itemId)) return;
    if (type == 'avatar') equippedAvatarId = itemId;
    if (type == 'bg_pack') equippedBgPackId = itemId;
    notifyListeners();
  }

  void switchTheme(AppThemeType type) {
    _currentTheme = type;
    notifyListeners();
  }

  ThemeData get currentThemeData {
    switch (_currentTheme) {
      case AppThemeType.joyful:
        return ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFFFF3E0),
          primaryColor: Colors.orangeAccent,
          colorScheme: const ColorScheme.light(
              primary: Colors.orange, secondary: Colors.pinkAccent),
          textTheme: GoogleFonts.fredokaTextTheme(ThemeData.light().textTheme),
        );
      case AppThemeType.liquid:
        return ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFE1F5FE),
          primaryColor: Colors.cyan,
          colorScheme: const ColorScheme.light(
              primary: Colors.cyan, secondary: Colors.blueAccent),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        );
      case AppThemeType.galaxy:
        return ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F0B29),
          primaryColor: Colors.deepPurple,
          colorScheme: const ColorScheme.dark(
              primary: Colors.deepPurpleAccent, secondary: Colors.amber),
          textTheme: GoogleFonts.orbitronTextTheme(ThemeData.dark().textTheme),
        );
      case AppThemeType.cyberpunk:
      default:
        return ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF050505),
          primaryColor: const Color(0xFF00FFCC),
          colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00FFCC), secondary: Color(0xFFFF0099)),
          textTheme: GoogleFonts.vt323TextTheme(ThemeData.dark().textTheme),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// 🎨 3. DYNAMIC BACKGROUND ENGINE
// ---------------------------------------------------------------------------

class DynamicBackground extends StatelessWidget {
  final Widget child;
  // If previewColors is passed, use those (for Studio), otherwise use active (Global)
  final List<Color>? previewColors;
  const DynamicBackground({super.key, required this.child, this.previewColors});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateManager>(context);
    // Use preview if available, else use applied global colors
    final colorsToUse = previewColors ?? state.activeIconColors;

    return Stack(
      children: [
        Positioned.fill(
            child: _buildAnimation(state.currentTheme, state, colorsToUse)),
        child,
      ],
    );
  }

  Widget _buildAnimation(
      AppThemeType theme, AppStateManager state, List<Color> colors) {
    switch (theme) {
      case AppThemeType.joyful:
        return IconFloatingAnimation(
          icons: state.currentBgIcons,
          colors: colors,
        );
      case AppThemeType.galaxy:
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF0F0B29), Colors.black],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
          ),
          child: ParticleAnimation(count: 50, colors: colors, speed: 0.2),
        );
      case AppThemeType.liquid:
        return Container(
          color: const Color(0xFFE1F5FE),
          child: ParticleAnimation(
              count: 20, colors: colors, size: 20, speed: 0.5),
        );
      case AppThemeType.cyberpunk:
        return CyberGridAnimation(colors: colors);
    }
  }
}

// --- Animation Components ---

class IconFloatingAnimation extends StatefulWidget {
  final List<IconData> icons;
  final List<Color> colors;
  const IconFloatingAnimation(
      {super.key, required this.icons, required this.colors});
  @override
  State<IconFloatingAnimation> createState() => _IconFloatingAnimationState();
}

class _IconFloatingAnimationState extends State<IconFloatingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_FloatingItem> _items = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _initItems();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..repeat()
          ..addListener(() {
            setState(() {
              for (var i in _items) {
                i.update();
              }
            });
          });
  }

  @override
  void didUpdateWidget(covariant IconFloatingAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.icons != widget.icons ||
        !listEquals(oldWidget.colors, widget.colors)) {
      _initItems();
    }
  }

  void _initItems() {
    _items.clear();
    if (widget.colors.isEmpty) return;
    for (int i = 0; i < 15; i++) {
      _items.add(_FloatingItem(
        x: _rng.nextDouble(),
        y: _rng.nextDouble(),
        icon: widget.icons[_rng.nextInt(widget.icons.length)],
        color: widget.colors[_rng.nextInt(widget.colors.length)],
        speed: 0.001 + _rng.nextDouble() * 0.002,
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: _items
          .map((item) => Positioned(
                left: item.x * MediaQuery.of(context).size.width,
                top: item.y * MediaQuery.of(context).size.height,
                child: Opacity(
                    opacity: 0.4,
                    child: Icon(item.icon, color: item.color, size: 35)),
              ))
          .toList(),
    );
  }
}

class _FloatingItem {
  double x, y, speed;
  IconData icon;
  Color color;
  _FloatingItem(
      {required this.x,
      required this.y,
      required this.speed,
      required this.icon,
      required this.color});
  void update() {
    y -= speed;
    if (y < -0.1) y = 1.1;
  }
}

class ParticleAnimation extends StatefulWidget {
  final int count;
  final List<Color> colors;
  final double speed;
  final double size;
  const ParticleAnimation(
      {super.key,
      required this.count,
      required this.colors,
      this.speed = 1.0,
      this.size = 3.0});
  @override
  State<ParticleAnimation> createState() => _ParticleAnimationState();
}

class _ParticleAnimationState extends State<ParticleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Dot> _dots = [];
  final Random _rng = Random();
  @override
  void initState() {
    super.initState();
    _initDots();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat()
          ..addListener(() {
            setState(() {
              for (var d in _dots) {
                d.update();
              }
            });
          });
  }

  @override
  void didUpdateWidget(covariant ParticleAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.colors, widget.colors)) _initDots();
  }

  void _initDots() {
    _dots.clear();
    if (widget.colors.isEmpty) return;
    for (int i = 0; i < widget.count; i++) {
      _dots.add(_Dot(_rng, widget.speed,
          widget.colors[_rng.nextInt(widget.colors.length)]));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _DotPainter(_dots, widget.size), child: Container());
  }
}

class _Dot {
  double x, y, s;
  Color c;
  _Dot(Random r, double speed, this.c)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        s = speed * (0.001 + r.nextDouble() * 0.002);
  void update() {
    y -= s;
    if (y < 0) y = 1;
  }
}

class _DotPainter extends CustomPainter {
  final List<_Dot> dots;
  final double s;
  _DotPainter(this.dots, this.s);
  @override
  void paint(Canvas canvas, Size size) {
    for (var d in dots) {
      final p = Paint()..color = d.c.withOpacity(0.5);
      canvas.drawCircle(Offset(d.x * size.width, d.y * size.height), s, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class CyberGridAnimation extends StatelessWidget {
  final List<Color> colors;
  const CyberGridAnimation({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final gridColor = colors.isNotEmpty ? colors.first : Colors.purpleAccent;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF1a0033)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
      ),
      child: CustomPaint(painter: _GridPainter(gridColor), child: Container()),
    );
  }
}

class _GridPainter extends CustomPainter {
  final Color c;
  _GridPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = c.withOpacity(0.2)
      ..strokeWidth = 1;
    double h = size.height * 0.4;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(size.width / 2, h),
          Offset((i - size.width / 2) * 5 + size.width / 2, size.height), p);
    }
    for (double i = h; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ---------------------------------------------------------------------------
// 🔐 4. LOGIN SCREEN
// ---------------------------------------------------------------------------

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController userCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();

    return Scaffold(
      body: DynamicBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: _GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.face_retouching_natural,
                      size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  Text("Morphy",
                      style: GoogleFonts.fredoka(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const Text("Joyful Face Morphing",
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 30),
                  TextField(
                    controller: userCtrl,
                    decoration: _inputDeco("Username"),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: emailCtrl,
                    decoration: _inputDeco("Email (Gmail only)"),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () {
                      final email = emailCtrl.text.trim();
                      final user = userCtrl.text.trim();

                      if (user.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Please enter a username"),
                                backgroundColor: Colors.red));
                        return;
                      }
                      if (email.isEmpty || !email.endsWith("@gmail.com")) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(
                          content: Text(
                              "Access Denied! Only @gmail.com is allowed."),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ));
                        return;
                      }
                      Provider.of<AppStateManager>(context, listen: false)
                          .login(user, email);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text("Enter Morphy World",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: Colors.white10,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }
}

// ---------------------------------------------------------------------------
// 🏠 5. HOME SCREEN
// ---------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateManager>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Icon(Icons.face_outlined),
          const SizedBox(width: 10),
          Text("Morphy",
              style: GoogleFonts.fredoka(fontWeight: FontWeight.bold))
        ]),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Center(
                child: Text("🪙 ${state.coins}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),
          ),
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: DynamicBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              // AVATAR DISPLAY
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white24,
                child: Icon(state.currentAvatar, size: 40, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text("Hi, ${state.nickname}!",
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor)),
              const Text("Ready to get weird?",
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const Spacer(),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MorphCameraScreen(cameras: cameras))),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary
                      ]),
                      boxShadow: [
                        BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 5)
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt, size: 60, color: Colors.white),
                        SizedBox(height: 10),
                        Text("START",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                        child: _FeatureCard(
                            icon: Icons.store,
                            title: "Theme Shop",
                            color: Colors.purpleAccent,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const RewardsScreen())))),
                    const SizedBox(width: 15),
                    Expanded(
                        child: _FeatureCard(
                            icon: Icons.support_agent,
                            title: "Support",
                            color: Colors.blue,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SupportScreen())))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _FeatureCard(
      {required this.icon,
      required this.title,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 5),
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 📷 6. MORPHING CAMERA SCREEN
// ---------------------------------------------------------------------------

class MorphCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const MorphCameraScreen({super.key, required this.cameras});

  @override
  State<MorphCameraScreen> createState() => _MorphCameraScreenState();
}

class _MorphCameraScreenState extends State<MorphCameraScreen> {
  CameraController? controller;
  double _morphVal = 0.5;
  String? _selectedCat;
  FilterAsset? _selectedAsset;
  int _selectedCameraIndex = 0;
  bool _isVideoMode = false;
  bool _isRecording = false;
  double _zoomLevel = 1.0;
  int _timerCount = 0;

  // API-loaded data
  List<String> _categories = [];
  List<FilterAsset> _assets = [];
  bool _loadingCategories = true;
  bool _loadingAssets = false;

  // Gender Detection
  String _detectedGender = "Detect";
  double _genderConfidence = 0.0;
  bool _isDetectingGender = false;

  // Live Filter Streaming
  Uint8List? _processedFrame;
  Timer? _streamTimer;
  bool _isProcessingFrame = false;

  // Web Audio
  dynamic _audioElement;
  bool _isAudioPlaying = false;

  @override
  void initState() {
    super.initState();
    _initCamera(_selectedCameraIndex);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await ApiService.getCategories();
    if (mounted) {
      setState(() {
        // Filter out Male and Female - they will appear after gender detection
        _categories =
            categories.where((c) => c != 'Male' && c != 'Female').toList();
        _loadingCategories = false;
        if (_categories.isNotEmpty) {
          _selectedCat = _categories.first;
          _loadAssets(_categories.first);
        }
      });
    }
  }

  Future<void> _loadAssets(String category) async {
    setState(() => _loadingAssets = true);
    final assets = await ApiService.getCategoryAssets(category);
    if (mounted) {
      setState(() {
        _assets = assets;
        _loadingAssets = false;
        _selectedAsset = null;
      });
    }
  }

  void _initCamera(int index) {
    if (widget.cameras.isEmpty) return;
    controller = CameraController(widget.cameras[index], ResolutionPreset.high,
        enableAudio: true);
    controller!.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _toggleCamera() {
    if (widget.cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex == 0) ? 1 : 0;
    _initCamera(_selectedCameraIndex);
  }

  void _setZoom(double zoom) {
    setState(() => _zoomLevel = zoom);
    controller?.setZoomLevel(zoom);
  }

  @override
  void dispose() {
    _stopStreaming();
    controller?.dispose();
    super.dispose();
  }

  void _startStreaming() {
    if (_streamTimer != null) return;
    _streamTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _processLiveFrame();
    });
  }

  void _stopStreaming() {
    _streamTimer?.cancel();
    _streamTimer = null;
    if (mounted) {
      setState(() => _processedFrame = null);
    }
  }

  Future<void> _processLiveFrame() async {
    if (_isProcessingFrame ||
        controller == null ||
        !controller!.value.isInitialized ||
        _selectedAsset == null) return;

    _isProcessingFrame = true;
    try {
      final image = await controller!.takePicture();
      final bytes = await image.readAsBytes();
      final b64 = ApiService.bytesToBase64(bytes);

      final result = await ApiService.processFrame(
        frameBase64: b64,
        assetId: _selectedAsset!.id,
        opacity: _morphVal,
      );

      if (result != null && mounted) {
        setState(() {
          _processedFrame = ApiService.base64ToBytes(result['frame']);
        });

        // --- Audio Logic ---
        if (_selectedAsset!.hasSound && _selectedAsset!.soundFile != null) {
          bool isMouthOpen = result['mouth_open'] ?? false;
          if (isMouthOpen) {
            _playFilterSound(_selectedAsset!.soundFile!);
          } else {
            _stopFilterSound();
          }
        }
      }
    } catch (e) {
      debugPrint("Frame processing error: $e");
    } finally {
      _isProcessingFrame = false;
    }
  }

  // Pure Web Audio Logic (since we are in Chrome)

  void _playFilterSound(String filename) {
    if (!kIsWeb) return;
    if (_isAudioPlaying) return; // Already playing, don't create new audio

    final url =
        "${ApiService.baseUrl}/sounds/${_selectedAsset!.folder}/$filename";

    try {
      debugPrint("[DEBUG] Playing Sound: $url");
      _stopFilterSound(); // Stop any previous audio first
      _audioElement = web.HTMLAudioElement();
      (_audioElement as web.HTMLAudioElement).src = url;
      (_audioElement as web.HTMLAudioElement).loop = true;
      (_audioElement as web.HTMLAudioElement).play();
      _isAudioPlaying = true;
    } catch (e) {
      debugPrint("Audio Play Error: $e");
    }
  }

  void _stopFilterSound() {
    if (!kIsWeb) return;
    try {
      if (_audioElement != null) {
        (_audioElement as web.HTMLAudioElement).pause();
        (_audioElement as web.HTMLAudioElement).currentTime = 0;
        _audioElement = null;
      }
      _isAudioPlaying = false;
    } catch (e) {
      debugPrint("Audio Stop Error: $e");
    }
  }

  Future<void> _detectGender() async {
    if (controller == null ||
        !controller!.value.isInitialized ||
        _isDetectingGender) return;

    debugPrint("Starting gender detection...");
    setState(() => _isDetectingGender = true);

    try {
      final image = await controller!.takePicture();
      // FIX: Use readAsBytes() directly on XFile for Web compatibility
      final bytes = await image.readAsBytes();
      final b64 = ApiService.bytesToBase64(bytes);

      debugPrint("Sending frame to backend...");
      final result = await ApiService.detectGender(b64);
      debugPrint("Gender result: $result");

      if (mounted) {
        if (result.containsKey("error") && result['error'] != null) {
          debugPrint("Gender error: ${result['error']}");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("Error: ${result['error']}"),
              backgroundColor: Colors.red));
        } else {
          final gender = result["gender"];
          setState(() {
            _detectedGender = gender;
            _genderConfidence = result["confidence"];

            // Auto-trigger category selection - show only detected gender
            if (gender == "Male" || gender == "Female") {
              // Remove both Male and Female first
              _categories.remove("Male");
              _categories.remove("Female");
              // Add only the detected gender
              _categories.insert(0, gender);
              _selectedCat = gender;
            }
          });

          if (gender == "Male" || gender == "Female") {
            _loadAssets(gender);
          }
        }
      }
    } catch (e) {
      debugPrint("Gender detection error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Detection Failed: $e"),
            backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isDetectingGender = false);
    }
  }

  Future<void> _capture() async {
    if (controller == null || !controller!.value.isInitialized) return;

    if (_timerCount == 0 && !_isRecording) {
      _timerCount = 3;
      Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (mounted) setState(() => _timerCount--);
        if (_timerCount <= 0) {
          timer.cancel();
          _performCapture();
        }
      });
    } else {
      _performCapture();
    }
  }

  // --- WEB DOWNLOAD HELPER ---
  void _downloadOnWeb(Uint8List bytes, String filename) {
    // Basic anchor download for Web
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    web.URL.revokeObjectURL(url);
  }

  Future<void> _performCapture() async {
    try {
      if (_isVideoMode) {
        if (_isRecording) {
          // STOP RECORDING
          final videoBase64 = await ApiService.stopRecording();
          setState(() => _isRecording = false);
          _stopStreaming(); // Stop stream after recording to save resources? Or keep it? keeping it is better UX.

          if (videoBase64 != null) {
            final bytes = ApiService.base64ToBytes(videoBase64);

            if (kIsWeb) {
              _downloadOnWeb(bytes, "morphy_video.avi");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Video Downloaded!"),
                    backgroundColor: Colors.green));
              }
            } else {
              // MOBILE / DESKTOP
              final directory = await Directory.systemTemp.createTemp();
              final file = File('${directory.path}/morphy_video.avi');
              await file.writeAsBytes(bytes);
              await _saveVideoToGallery(file.path);
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Recording failed or empty"),
                  backgroundColor: Colors.red));
            }
          }
        } else {
          // START RECORDING
          // Ensure stream is running even if no asset is selected
          if (_selectedAsset == null && _streamTimer == null) {
            _startStreaming();
          }

          final success = await ApiService.startRecording();
          if (success) {
            setState(() => _isRecording = true);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Failed to start recording"),
                  backgroundColor: Colors.red));
            }
          }
        }
      } else {
        // PICTURE MODE

        // Pause streaming to free up camera from the timer loop (if running)
        _stopStreaming();

        // Short delay to ensure any pending camera operation completes
        await Future.delayed(const Duration(milliseconds: 500));

        try {
          // Take high res picture
          final image = await controller!.takePicture();
          final bytes = await image.readAsBytes();

          // Send to backend for processing
          final b64 = ApiService.bytesToBase64(bytes);
          // Use current asset
          final assetId = _selectedAsset?.id ?? "";

          final result = await ApiService.processFrame(
              frameBase64: b64, assetId: assetId, opacity: _morphVal);

          if (result != null && result['frame'] != null) {
            final processedBytes = ApiService.base64ToBytes(result['frame']);

            if (!mounted) return;

            if (kIsWeb) {
              // Web: Download directly, skip Editor for now as it relies on File path
              _downloadOnWeb(processedBytes, "morphy_capture.jpg");
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Image Downloaded!"),
                  backgroundColor: Colors.green));
            } else {
              // Mobile: Use Temp File and Editor
              final directory = await Directory.systemTemp.createTemp();
              final file = File('${directory.path}/morphy_capture.jpg');
              await file.writeAsBytes(processedBytes);

              // Open Editor
              final Uint8List? editedBytes = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          PhotoEditorScreen(imagePath: file.path)));

              if (editedBytes != null) {
                await _saveBytesToGallery(editedBytes);
              }
            }
          } else {
            debugPrint("Processing failed for capture");
          }
        } catch (e) {
          debugPrint("Capture Error: $e");
        } finally {
          // Resume streaming
          if (mounted && _selectedAsset != null) _startStreaming();
        }
      }
    } catch (e) {
      debugPrint("General Capture Error: $e");
    }
  }

  Future<void> _saveVideoToGallery(String path) async {
    if (kIsWeb) return; // Handled by download logic
    try {
      await Gal.putVideo(path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Video Exported to Gallery!"),
          backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  Future<void> _saveBytesToGallery(Uint8List bytes) async {
    if (kIsWeb) return; // Handled by download logic
    try {
      await Gal.putImageBytes(bytes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Image Exported to Gallery!"),
          backgroundColor: Colors.green));
    } catch (e) {
      debugPrint("Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(child: CameraPreview(controller!)),
          // Processed frame overlay when filter is active
          if (_processedFrame != null)
            SizedBox.expand(
              child: Image.memory(
                _processedFrame!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          if (_timerCount > 0)
            Center(
                child: Text("$_timerCount",
                    style: const TextStyle(
                        fontSize: 100,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(blurRadius: 10, color: Colors.black)
                        ]))),
          Positioned(
            right: 10,
            top: 100,
            bottom: 150,
            child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                    value: _zoomLevel,
                    min: 1.0,
                    max: 8.0,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: _setZoom)),
          ),
          Positioned(
            top: 50,
            right: 20,
            left: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    IconButton(
                        icon: Icon(Icons.camera_alt,
                            color:
                                !_isVideoMode ? Colors.yellow : Colors.white),
                        onPressed: () => setState(() => _isVideoMode = false)),
                    IconButton(
                        icon: Icon(Icons.videocam,
                            color: _isVideoMode ? Colors.red : Colors.white),
                        onPressed: () => setState(() => _isVideoMode = true)),
                  ]),
                ),
                GestureDetector(
                  onTap: _detectGender,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(
                          _detectedGender == "Female"
                              ? Icons.female
                              : (_detectedGender == "Male"
                                  ? Icons.male
                                  : Icons.question_mark),
                          color: _detectedGender == "Female"
                              ? Colors.pink
                              : (_detectedGender == "Male"
                                  ? Colors.blue
                                  : Colors.grey),
                          size: 16),
                      const SizedBox(width: 5),
                      Text(
                          _isDetectingGender
                              ? "Detecting..."
                              : "$_detectedGender ${(_genderConfidence * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10))
                    ]),
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.cameraswitch,
                        color: Colors.white, size: 30),
                    onPressed: _toggleCamera),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Colors.black54,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Opacity Slider
                  Row(children: [
                    const Text("Opacity",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Expanded(
                        child: Slider(
                            value: _morphVal,
                            onChanged: (v) => setState(() => _morphVal = v),
                            activeColor:
                                Theme.of(context).colorScheme.secondary)),
                    Text("${(_morphVal * 100).toInt()}%",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12))
                  ]),
                  const SizedBox(height: 10),
                  // Categories
                  if (_loadingCategories)
                    const Center(child: CircularProgressIndicator())
                  else
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                            children: _categories
                                .map((k) => Padding(
                                    padding: const EdgeInsets.only(right: 10),
                                    child: ChoiceChip(
                                        label: Text(k),
                                        selected: _selectedCat == k,
                                        onSelected: (b) {
                                          setState(() => _selectedCat = k);
                                          _loadAssets(k);
                                        },
                                        selectedColor: Theme.of(context)
                                            .colorScheme
                                            .primary)))
                                .toList())),
                  const SizedBox(height: 10),
                  // Assets (Filter Thumbnails)
                  if (_loadingAssets)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(),
                    ))
                  else if (_assets.isNotEmpty)
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _assets.length + 1, // +1 for "None" option
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // "None" option - no filter
                            return GestureDetector(
                              onTap: () {
                                _stopFilterSound();
                                _stopStreaming();
                                setState(() => _selectedAsset = null);
                              },
                              child: Container(
                                width: 60,
                                height: 60,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade800,
                                  border: Border.all(
                                    color: _selectedAsset == null
                                        ? Colors.green
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(Icons.block,
                                    color: Colors.white54, size: 30),
                              ),
                            );
                          }
                          final asset = _assets[index - 1];
                          final isSelected = _selectedAsset?.id == asset.id;
                          return GestureDetector(
                            onTap: () {
                              _stopFilterSound();
                              setState(() => _selectedAsset = asset);
                              _startStreaming();
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.green
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: asset.thumbnail.isNotEmpty
                                    ? Image.memory(
                                        ApiService.base64ToBytes(
                                            asset.thumbnail),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey.shade700,
                                          child: const Icon(Icons.face,
                                              color: Colors.white54),
                                        ),
                                      )
                                    : Container(
                                        color: Colors.grey.shade700,
                                        child: const Icon(Icons.face,
                                            color: Colors.white54),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _capture,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _isRecording ? Colors.red : Colors.white,
                              width: 3)),
                      child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                              color: _isRecording ? Colors.red : Colors.white,
                              shape: _isVideoMode && _isRecording
                                  ? BoxShape.rectangle
                                  : BoxShape.circle),
                          child: _isRecording
                              ? const Icon(Icons.stop, color: Colors.white)
                              : (_isVideoMode
                                  ? const Icon(Icons.videocam,
                                      color: Colors.black)
                                  : null)),
                    ),
                  )
                ],
              ),
            ),
          ),
          Positioned(
              top: 40,
              left: 20,
              child: BackButton(
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🏆 7. REWARDS & SHOP SCREEN (Theme Studio)
// ---------------------------------------------------------------------------

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateManager>(context);

    return Scaffold(
      appBar: AppBar(
          title: const Text("Shop & Studio"),
          backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: DynamicBackground(
        // Pass temporary colors here so user can see changes instantly
        previewColors: state.tempColors,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _GlassCard(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(children: [
                      const Icon(Icons.emoji_events,
                          size: 40, color: Colors.amber),
                      Text("Lvl ${state.level}",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white))
                    ]),
                    Column(children: [
                      const Icon(Icons.monetization_on,
                          size: 40, color: Colors.yellowAccent),
                      Text("${state.coins} Coins",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white))
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- THEME STUDIO ---
              const Text("🎨 Theme Studio",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 5),
              const Text("Pick colors to customize your theme:",
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [
                  Colors.orange,
                  Colors.pink,
                  Colors.blue,
                  Colors.green,
                  Colors.purple,
                  Colors.red,
                  Colors.teal,
                  Colors.amber
                ].map((c) {
                  bool isActive = state.tempColors.contains(c);
                  return GestureDetector(
                    onTap: () => state.toggleTempColor(c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: isActive
                              ? Border.all(color: Colors.white, width: 3)
                              : null),
                      child: isActive
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // APPLY BUTTON (Persist Changes)
              ElevatedButton(
                onPressed: () {
                  state.applyColors();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Theme Applied!"),
                      backgroundColor: Colors.green));
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50)),
                child: const Text("APPLY THEME",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),

              // MATH CHALLENGE
              _GlassCard(
                child: ListTile(
                  leading: const Icon(Icons.calculate,
                      size: 40, color: Colors.blueAccent),
                  title: const Text("Math for Coins",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text("Solve & Spin to buy items!",
                      style: TextStyle(color: Colors.white70)),
                  trailing: ElevatedButton(
                      onPressed: () => _showMathDialog(context),
                      child: const Text("PLAY")),
                ),
              ),

              const SizedBox(height: 20),

              // SHOP SECTION
              const Text("Item Shop",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 10),
              ...state.shopCatalog.map((item) {
                bool isOwned = state.ownedItems.contains(item.id);
                bool isEquipped = (item.type == 'avatar' &&
                        state.equippedAvatarId == item.id) ||
                    (item.type == 'bg_pack' &&
                        state.equippedBgPackId == item.id);

                return Card(
                  color: Colors.white10,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: Icon(item.icon, size: 30, color: Colors.white),
                    title: Text(item.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(isOwned ? "Owned" : "${item.cost} Coins",
                        style: TextStyle(
                            color:
                                isOwned ? Colors.greenAccent : Colors.amber)),
                    trailing: isOwned
                        ? ElevatedButton(
                            onPressed: isEquipped
                                ? null
                                : () => state.equipItem(item.id, item.type),
                            style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isEquipped ? Colors.grey : Colors.green),
                            child: Text(isEquipped ? "Equipped" : "Equip"),
                          )
                        : ElevatedButton(
                            onPressed: () {
                              String result = state.buyItem(item.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result)));
                            },
                            child: const Text("Buy"),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showMathDialog(BuildContext context) {
    int a = Random().nextInt(20) + 1;
    int b = Random().nextInt(20) + 1;
    int ans = a + b;
    TextEditingController ansCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Math Challenge"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("What is $a + $b?",
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            TextField(controller: ansCtrl, keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (ansCtrl.text == ans.toString()) {
                Navigator.pop(ctx);
                _spinWheel(context);
              } else {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Wrong answer! Try again."),
                    backgroundColor: Colors.red));
              }
            },
            child: const Text("Submit"),
          )
        ],
      ),
    );
  }

  void _spinWheel(BuildContext context) {
    int reward = (Random().nextInt(5) + 1) * 50;
    Provider.of<AppStateManager>(context, listen: false).addCoins(reward);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("🎉 WINNER!"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.casino, size: 60, color: Colors.purpleAccent),
            const SizedBox(height: 20),
            Text("You won $reward Coins!",
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Awesome!"))
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🆘 8. SUPPORT SCREEN
// ---------------------------------------------------------------------------

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Support Center"),
          backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: DynamicBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildSection("⭐ Rate Us", [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      5,
                      (index) => IconButton(
                            icon: Icon(
                                index < _rating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 30),
                            onPressed: () =>
                                setState(() => _rating = index + 1),
                          )),
                ),
                Center(
                    child: Text(
                        _rating > 0 ? "Thanks for rating!" : "Tap a star",
                        style: const TextStyle(color: Colors.white70))),
              ]),
              const SizedBox(height: 20),
              _buildSection("📞 Contact Us", [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white70,
                            hintText: "Your Email (Gmail only)"),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return "Please enter email";
                          }
                          if (!v.endsWith("@gmail.com")) {
                            return "Must be a Gmail address";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _msgCtrl,
                        decoration: const InputDecoration(
                            filled: true,
                            fillColor: Colors.white70,
                            hintText: "Describe your issue..."),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text("Send Report"),
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("Support request sent!")));
                            _emailCtrl.clear();
                            _msgCtrl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 🎨 9. PHOTO EDITOR SCREEN
// ---------------------------------------------------------------------------

class PhotoEditorScreen extends StatefulWidget {
  final String imagePath;
  const PhotoEditorScreen({super.key, required this.imagePath});
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  Uint8List? imageData;
  @override
  void initState() {
    super.initState();
    File(widget.imagePath)
        .readAsBytes()
        .then((bytes) => setState(() => imageData = bytes));
  }

  @override
  Widget build(BuildContext context) {
    if (imageData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ImageEditor(image: imageData!);
  }
}

// ---------------------------------------------------------------------------
// ⚙️ 10. SETTINGS SCREEN
// ---------------------------------------------------------------------------

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateManager>(context);
    final TextEditingController nickCtrl =
        TextEditingController(text: state.nickname);

    return Scaffold(
      appBar: AppBar(
          title: const Text("Settings"), backgroundColor: Colors.transparent),
      extendBodyBehindAppBar: true,
      body: DynamicBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _GlassCard(
                child: Column(
                  children: [
                    const CircleAvatar(
                        radius: 40, child: Icon(Icons.person, size: 40)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nickCtrl,
                      decoration: const InputDecoration(
                          labelText: "Nickname", border: OutlineInputBorder()),
                      onSubmitted: (v) => state.updateNickname(v),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        state.logout();
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: const Text("Log Out",
                          style: TextStyle(color: Colors.redAccent)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(height: 30),
              const Text("Backend Connection",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final msg = await ApiService.getMessage();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  }
                },
                child: const Text("Test Python API"),
              ),
              const SizedBox(height: 30),
              const Text("Backend IP Address (For Tablet)",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                    hintText: "e.g. 192.168.1.5",
                    filled: true,
                    fillColor: Colors.white70,
                    border: OutlineInputBorder()),
                onChanged: (v) => ApiService.setBaseUrl(v),
              ),
              const SizedBox(height: 30),
              const Text("Select Theme",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppThemeType.values
                    .map((t) => ChoiceChip(
                          label: Text(t.name.toUpperCase()),
                          selected: state.currentTheme == t,
                          onSelected: (b) {
                            if (b) state.switchTheme(t);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper Widget
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          color: Colors.black.withOpacity(0.3),
          child: child,
        ),
      ),
    );
  }
}
