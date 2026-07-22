import 'package:flutter/material.dart';

class BoostConfigurationScreen extends StatefulWidget {
  final String imageUrl;
  final String postId;

  const BoostConfigurationScreen({
    super.key,
    required this.imageUrl,
    required this.postId,
  });

  @override
  State<BoostConfigurationScreen> createState() =>
      _BoostConfigurationScreenState();
}

class _BoostConfigurationScreenState extends State<BoostConfigurationScreen> {
  // Audiencia
  String _selectedGender = 'Todos';
  RangeValues _ageRange = const RangeValues(18, 65);
  double _radius = 10.0; // km

  // Presupuesto
  int _durationDays = 7;
  double _dailyBudget = 5000.0; // COP

  double get _totalBudget => _durationDays * _dailyBudget;

  // Estimación ficticia basada en el presupuesto (para la UI)
  int get _minReach => (_totalBudget * 0.5).toInt();
  int get _maxReach => (_totalBudget * 1.2).toInt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Impulsar Publicación',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Alexandria',
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview de la publicación
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(widget.imageUrl, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // SECCIÓN: AUDIENCIA
            _buildSectionTitle('Audiencia Objetivo', Icons.people_outline),
            const SizedBox(height: 16),

            // Género
            const Text(
              'Género',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Todos', 'Hombres', 'Mujeres'].map((g) {
                final isSelected = _selectedGender == g;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedGender = g),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0094FF)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        g,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Edad
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Rango de Edad',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${_ageRange.start.toInt()} - ${_ageRange.end.toInt() == 65 ? "65+" : _ageRange.end.toInt()}',
                  style: const TextStyle(
                    color: Color(0xFF0094FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            RangeSlider(
              values: _ageRange,
              min: 18,
              max: 65,
              activeColor: const Color(0xFF0094FF),
              onChanged: (val) => setState(() => _ageRange = val),
            ),
            const SizedBox(height: 10),

            // Radio de Ubicación
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Radio de alcance',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${_radius.toInt()} KM',
                  style: const TextStyle(
                    color: Color(0xFF0094FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _radius,
              min: 1,
              max: 100,
              activeColor: const Color(0xFF0094FF),
              onChanged: (val) => setState(() => _radius = val),
            ),
            const SizedBox(height: 30),

            // SECCIÓN: PRESUPUESTO
            _buildSectionTitle(
              'Presupuesto y Duración',
              Icons.account_balance_wallet_outlined,
            ),
            const SizedBox(height: 16),

            // Duración
            const Text(
              'Duración (Días)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [1, 3, 7, 15, 30].map((d) {
                  final isSelected = _durationDays == d;
                  return GestureDetector(
                    onTap: () => setState(() => _durationDays = d),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.black : Colors.grey[200]!,
                        ),
                      ),
                      child: Text(
                        '$d ${d == 1 ? "día" : "días"}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 25),

            // Presupuesto diario
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Presupuesto diario',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '\$${_dailyBudget.toInt()} COP',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Slider(
              value: _dailyBudget,
              min: 2000,
              max: 50000,
              activeColor: Colors.black,
              onChanged: (val) => setState(() => _dailyBudget = val),
            ),
            const SizedBox(height: 40),

            // PANEL DE ESTIMACIÓN
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD0E8FF)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Alcance estimado',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF007AFF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_minReach.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} - ${_maxReach.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontFamily: 'Alexandria',
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                    ),
                  ),
                  const Text(
                    'personas alcazadas aproximadamente',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // BOTÓN DE ACCIÓN
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Integrar con Firebase en la siguiente fase
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Configuración guardada satisfactoriamente',
                      ),
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0094FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'CONFIRMAR IMPULSO (\$${_totalBudget.toInt()} COP)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
