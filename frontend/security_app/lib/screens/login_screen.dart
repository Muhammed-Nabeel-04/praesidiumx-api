import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Form Controllers ─────────────────────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _aliasController = TextEditingController();
  final _deptController = TextEditingController();

  bool _loading = false;
  bool _isLogin = true;
  bool _obscure = true;
  String? _error;
  String? _successMsg;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _aliasController.dispose();
    _deptController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Switch Mode ──────────────────────────────────────────────
  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _error = null;
      _successMsg = null;
      _emailController.clear();
      _passwordController.clear();
      _aliasController.clear();
      _deptController.clear();
    });
    _animController.reset();
    _animController.forward();
  }

  // ── Submit ───────────────────────────────────────────────────
  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final dept = _deptController.text.trim();

    // Base validation for both modes
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = "Mandatory credentials missing.");
      return;
    }

    if (!_isLogin) {
      if (dept.isEmpty) {
        setState(
          () => _error = "Department / Unit Code is required for clearance.",
        );
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
      _successMsg = null;
    });

    try {
      if (_isLogin) {
        // ── Login Flow ─────────────────────────────────────────
        final token = await AuthService.login(email, password);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(token: token)),
        );
      } else {
        // ── Register Flow ──────────────────────────────────────
        await AuthService.register(email, password);
        if (!mounted) return;
        setState(() {
          _successMsg = "Clearance granted! Please sign in.";
          _isLogin = true;
          _emailController.clear();
          _passwordController.clear();
          _aliasController.clear();
          _deptController.clear();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // ── Background Gradient & Grid ────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.appBar, AppColors.surfaceHigh],
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // ── Ambient Glow ──────────────────────────────
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.02),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // ── Login Form ────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: 360,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.cardBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bg.withOpacity(0.8),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.05),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Icon ────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDim.withOpacity(0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.5),
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/inside_logo.png',
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Title ───────────────────────────────────
                        Text(
                          _isLogin ? "SYSTEM ACCESS" : "SECURE REGISTRATION",
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isLogin
                              ? "Authenticate to enter SOC terminal"
                              : "Establish credentials to proceed",
                          style: const TextStyle(
                            color: AppColors.textSecond,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 32),

                        if (!_isLogin) ...[
                          _buildField(
                            controller: _aliasController,
                            hint: "Operator Alias (Optional)",
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.name,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: _deptController,
                            hint: "Department / Unit Code",
                            icon: Icons.account_balance_outlined,
                            keyboardType: TextInputType.text,
                          ),
                          const SizedBox(height: 16),
                          const Divider(
                            color: AppColors.cardBorder,
                            height: 20,
                          ),
                          const SizedBox(height: 8),
                        ],

                        // ── Email Field ─────────────────────────────
                        _buildField(
                          controller: _emailController,
                          hint: "Operator ID (Email)",
                          icon: Icons.person_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // ── Password Field ──────────────────────────
                        _buildField(
                          controller: _passwordController,
                          hint: "Security Passcode",
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textSecond,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Error Message ───────────────────────────
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.dangerDim,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.danger.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppColors.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: AppColors.danger,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Success Message ─────────────────────────
                        if (_successMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.successDim,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.success.withOpacity(0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  color: AppColors.success,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _successMsg!,
                                    style: const TextStyle(
                                      color: AppColors.success,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── Submit Button ───────────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.bg,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 8,
                              shadowColor: AppColors.primary.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.bg,
                                    ),
                                  )
                                : Text(
                                    _isLogin
                                        ? "INITIALIZE CONNECTION"
                                        : "REQUEST CLEARANCE",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Toggle Login / Register ──────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLogin
                                  ? "Unregistered operator? "
                                  : "Clearance acquired? ",
                              style: const TextStyle(
                                color: AppColors.textSecond,
                                fontSize: 12,
                              ),
                            ),
                            GestureDetector(
                              onTap: _toggleMode,
                              child: Text(
                                _isLogin ? "Request Access" : "Sign In",
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: const Icon(
                Icons.settings_rounded,
                color: AppColors.textSecond,
                size: 24,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable Input Field ─────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecond, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.textSecond, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceHigh,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
  );
}

// ── Background Grid Painter ──────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.03)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
