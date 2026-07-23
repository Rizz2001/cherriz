import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/state/app_state.dart';
import '../../../core/utils/responsive_layout.dart';
import '../../admin/presentation/admin_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool isLoading = false;
  bool hasError = false;
  bool _obscurePassword = true;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorSnackBar('Por favor ingresa tu correo y contraseña.');
      _shakeController.forward(from: 0.0);
      setState(() => hasError = true);
      return;
    }

    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      // 1. Authenticate with Supabase
      final AuthResponse res = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      if (user == null) throw Exception('No se pudo autenticar el usuario.');

      // 2. Fetch Employee Profile
      final profileResponse = await supabase
          .from('employee_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) {
        throw Exception('El perfil de empleado no fue encontrado en la base de datos.');
      }
      
      if (profileResponse['is_active'] == false) {
        throw Exception('Tu cuenta está desactivada. Contacta al administrador.');
      }

      // 3. Save to Global State
      AppState.currentUserProfile = profileResponse;

      if (!mounted) return;
      
      // 4. Navigate to Dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
      _shakeController.forward(from: 0.0);
      _showErrorSnackBar('Credenciales inválidas: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        hasError = true;
      });
      _shakeController.forward(from: 0.0);
      _showErrorSnackBar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1336),
      body: ResponsiveBuilder(
        mobile: _buildMobileLayout(),
        tablet: _buildSplitLayout(isTablet: true),
        desktop: _buildSplitLayout(isTablet: false),
      ),
    );
  }

  /// Single column layout centered for mobile devices
  Widget _buildMobileLayout() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1336),
            Color(0xFF281E59),
            Color(0xFF121B2A),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: _buildLoginFormCard(isMobile: true),
          ),
        ),
      ),
    );
  }

  /// Split-screen layout for Tablet and Desktop
  Widget _buildSplitLayout({required bool isTablet}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1336),
            Color(0xFF281E59),
            Color(0xFF121B2A),
          ],
        ),
      ),
      child: Row(
        children: [
          // Left Side: Brand & Hero Panel
          Expanded(
            flex: isTablet ? 4 : 5,
            child: Container(
              padding: EdgeInsets.all(isTablet ? 32.0 : 64.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7E57C2), Color(0xFF512DA8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E57C2).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Cherriz ERP',
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Plataforma integral de gestión empresarial y punto de venta para tu negocio.',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildFeatureBadge(Icons.analytics_outlined, 'Métricas y reportes en tiempo real'),
                  const SizedBox(height: 12),
                  _buildFeatureBadge(Icons.point_of_sale, 'Punto de venta multi-cajero'),
                  const SizedBox(height: 12),
                  _buildFeatureBadge(Icons.inventory_2_outlined, 'Control inteligente de inventario'),
                ],
              ),
            ),
          ),

          // Right Side: Login Form Card
          Expanded(
            flex: isTablet ? 6 : 5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _buildLoginFormCard(isMobile: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFFB39DDB)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Glassmorphism Login Form Card widget used in both mobile and split screens
  Widget _buildLoginFormCard({required bool isMobile}) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final sineValue = math.sin(_shakeController.value * 4 * math.pi);
        final dx = hasError ? sineValue * 15 : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(isMobile ? 28.0 : 40.0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withValues(alpha: hasError ? 0.6 : 0.2),
                width: hasError ? 2.0 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Only show logo inside card on Mobile or standalone)
                if (isMobile) ...[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7E57C2), Color(0xFF512DA8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7E57C2).withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Text(
                  isMobile ? 'Cherriz ERP' : 'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: isMobile ? 26 : 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresa tus credenciales para acceder',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // EMAIL
                _buildTextField(
                  controller: _emailController,
                  hintText: 'Correo Electrónico',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                
                // PASSWORD
                _buildTextField(
                  controller: _passwordController,
                  hintText: 'Contraseña',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  isPassword: true,
                ),
                const SizedBox(height: 32),
                
                // BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E1336),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFF1E1336),
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'Acceder',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: Colors.white70),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}
