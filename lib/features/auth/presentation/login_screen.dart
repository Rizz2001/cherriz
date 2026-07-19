import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../pos/presentation/pos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  // Datos dinámicos desde Supabase
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> employees = [];

  Map<String, dynamic>? selectedCompany;
  Map<String, dynamic>? selectedEmployee;

  String pin = '';
  bool isLoading = false;
  bool hasError = false;

  bool isLoadingCompanies = true;
  bool isLoadingEmployees = false;

  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fetchCompanies();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanies() async {
    try {
      final response = await supabase.from('companies').select();
      if (!mounted) return;
      setState(() {
        companies = List<Map<String, dynamic>>.from(response);
        isLoadingCompanies = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingCompanies = false;
      });
      _showErrorSnackBar('Error al cargar empresas: $e');
    }
  }

  Future<void> _fetchEmployees(Map<String, dynamic> company) async {
    setState(() {
      selectedCompany = company;
      isLoadingEmployees = true;
    });

    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('company_id', company['id']);
      if (!mounted) return;
      setState(() {
        employees = List<Map<String, dynamic>>.from(response);
        isLoadingEmployees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        selectedCompany = null; // Revertir selección en caso de error
        isLoadingEmployees = false;
      });
      _showErrorSnackBar('Error al cargar usuarios: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: const Color(0xFF1E1336).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  void _onPinKeyPressed(String value) {
    if (isLoading || pin.length >= 4) return;

    setState(() {
      hasError = false;
      pin += value;
    });

    if (pin.length == 4) {
      _validatePin();
    }
  }

  void _onPinBackspace() {
    if (isLoading || pin.isEmpty) return;

    setState(() {
      hasError = false;
      pin = pin.substring(0, pin.length - 1);
    });
  }

  Future<void> _validatePin() async {
    setState(() {
      isLoading = true;
    });

    // Pequeño delay artificial para sentir el feedback visual de progreso
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Asumimos que el PIN viene como String o int, lo parseamos a String
    final realPin = selectedEmployee?['pin_hash']?.toString() ?? '';

    if (pin == realPin && realPin.isNotEmpty) {
      // Éxito: Navegar a POSScreen
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const POSScreen()));
    } else {
      // Error: Vaciar PIN y mostrar animación
      setState(() {
        isLoading = false;
        hasError = true;
        pin = '';
      });
      _shakeController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E1336), // Deep rich purple
              Color(0xFF281E59), // Mid deep purple/blue
              Color(0xFF121B2A), // Dark slate/blue
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.05, 0.0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                    child: _buildCurrentState(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentState() {
    if (selectedCompany == null) {
      return _buildCompaniesList();
    } else if (selectedEmployee == null) {
      return _buildEmployeesList();
    } else {
      return _buildPinScreen();
    }
  }

  Widget _buildCompaniesList() {
    return Column(
      key: const ValueKey('companies'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Seleccionar Empresa',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        if (isLoadingCompanies)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: CircularProgressIndicator(color: Colors.white),
          )
        else if (companies.isEmpty)
          const Text(
            'No hay empresas registradas.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ...companies.map(
            (company) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildGlassButton(
                text: company['name'] ?? 'Empresa Desconocida',
                onTap: () {
                  _fetchEmployees(company);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeesList() {
    return Column(
      key: const ValueKey('employees'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.white70,
              ),
              onPressed: () {
                setState(() {
                  selectedCompany = null;
                });
              },
            ),
            Expanded(
              child: Text(
                selectedCompany?['name'] ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Seleccionar Usuario',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 16),
        if (isLoadingEmployees)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: CircularProgressIndicator(color: Colors.white),
          )
        else if (employees.isEmpty)
          const Text(
            'No hay usuarios configurados.',
            style: TextStyle(color: Colors.white70),
          )
        else
          ...employees.map(
            (employee) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildGlassButton(
                text: employee['full_name'] ?? employee['name'] ?? 'Usuario',
                onTap: () {
                  setState(() {
                    selectedEmployee = employee;
                  });
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPinScreen() {
    final employeeName =
        selectedEmployee?['full_name'] ??
        selectedEmployee?['name'] ??
        'Usuario';
    return Column(
      key: const ValueKey('pinScreen'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.white70,
              ),
              onPressed: () {
                setState(() {
                  selectedEmployee = null;
                  pin = '';
                  hasError = false;
                });
              },
            ),
            Expanded(
              child: Text(
                employeeName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Ingresa tu PIN',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 24),

        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final sineValue = math.sin(_shakeController.value * 4 * math.pi);
            final dx = hasError ? sineValue * 15 : 0.0;

            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              final isFilled = index < pin.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFilled
                      ? (hasError ? Colors.redAccent : Colors.white)
                      : Colors.transparent,
                  border: Border.all(
                    color: hasError ? Colors.redAccent : Colors.white,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 32),

        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: CircularProgressIndicator(color: Colors.white),
          )
        else
          _buildNumpad(),
      ],
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['1', '2', '3'].map((n) => _buildNumpadButton(n)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['4', '5', '6'].map((n) => _buildNumpadButton(n)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['7', '8', '9'].map((n) => _buildNumpadButton(n)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 70), // Spacer
            _buildNumpadButton('0'),
            _buildNumpadButton('<', isAction: true),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadButton(String text, {bool isAction = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isAction) {
            _onPinBackspace();
          } else {
            _onPinKeyPressed(text);
          }
        },
        customBorder: const CircleBorder(),
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.05),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Center(
            child: isAction
                ? const Icon(
                    Icons.backspace_outlined,
                    color: Colors.white,
                    size: 28,
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
