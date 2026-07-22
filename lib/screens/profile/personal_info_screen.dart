import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import '../../widgets/connect_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isLoading = false;

  final List<String> _allPaymentMethods = [
    'Transferencia bancaria',
    'Criptomonedas',
    'Tarjeta de Crédito',
    'Efectivo',
    'Nequi / Daviplata',
    'PayPal / Zelle',
  ];

  Future<void> _updateField(String field, dynamic value) async {
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({field: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddItemDialog(String title, String field, String currentValue) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Escribe aquí...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                String newValue = controller.text.trim();
                if (currentValue.isNotEmpty) {
                  newValue = '$currentValue\n${controller.text.trim()}';
                }
                _updateField(field, newValue);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _deleteItem(String field, String currentValue, int index) {
    List<String> items = currentValue
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    items.removeAt(index);
    _updateField(field, items.join('\n'));
  }

  Future<void> _pickResume(Map<String, dynamic> data) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _isLoading = true);
        File file = File(result.files.single.path!);
        String fileName = result.files.single.name;

        final ref = FirebaseStorage.instance
            .ref()
            .child('resumes')
            .child('${user!.uid}_${DateTime.now().millisecondsSinceEpoch}.pdf');

        await ref.putFile(file);
        String resumeUrl = await ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({'resumeUrl': resumeUrl, 'resumeName': fileName});
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hoja de vida subida exitosamente')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir hoja de vida: $e')),
        );
      }
    }
  }

  void _showPaymentMethodsDialog(List<String> currentMethods) {
    List<String> selected = List.from(currentMethods);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return AlertDialog(
              title: const Text(
                'Métodos de pago',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allPaymentMethods.map((method) {
                  final isSelected = selected.contains(method);
                  return FilterChip(
                    label: Text(
                      method,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.black87,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (bool sel) {
                      setStateSB(() {
                        if (sel) {
                          selected.add(method);
                        } else {
                          selected.remove(method);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF0094FF),
                    checkmarkColor: Colors.white,
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateField('paymentMethods', selected);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0094FF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String field,
    required String currentValue,
    required String addLabel,
  }) {
    List<String> items = currentValue
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF0094FF), size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No hay información agregada.',
                style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              int idx = entry.key;
              String text = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F6F6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () => _deleteItem(field, currentValue, idx),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () =>
                  _showAddItemDialog('Agregar $title', field, currentValue),
              icon: const Icon(Icons.add, size: 18),
              label: Text(
                addLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0094FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumeSection(Map<String, dynamic> data) {
    String? resumeName = data['resumeName'];
    String? resumeUrl = data['resumeUrl'];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_ind_outlined,
                color: Color(0xFF0094FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Hoja de vida',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    resumeName ?? 'No has subido tu hoja de vida',
                    style: TextStyle(
                      color: resumeName != null ? Colors.black87 : Colors.grey,
                      fontFamily: 'Poppins',
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (resumeUrl != null)
                  IconButton(
                    icon: const Icon(
                      Icons.open_in_new,
                      size: 20,
                      color: Colors.blue,
                    ),
                    onPressed: () => launchUrl(Uri.parse(resumeUrl)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _pickResume(data),
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(
                resumeUrl != null
                    ? 'Actualizar hoja de vida'
                    : 'Subir hoja de vida',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0094FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsSection(List<String> currentMethods) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: Color(0xFF0094FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Métodos de pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (currentMethods.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No hay métodos de pago agregados.',
                style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currentMethods.map((method) {
                return Chip(
                  label: Text(
                    method,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  backgroundColor: const Color(0xFFF6F6F6),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => _showPaymentMethodsDialog(currentMethods),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text(
                'Editar métodos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0094FF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Muestra un dialogo para editar la firma personal del usuario.
  void _showEditSignatureDialog(String currentValue) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Firma Personal',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu firma personal aparece en tu perfil publico y representa tu lema, proposito o descripcion profesional.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Ej: Conectando oportunidades con pasion...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0094FF)),
                ),
                counterText: '',
              ),
              maxLines: 4,
              maxLength: 300,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateField('signature', controller.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0094FF),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  /// Construye la seccion de firma personal con visualizacion estilizada
  /// y opciones para editar o eliminar la firma.
  Widget _buildSignatureSection({required String currentValue}) {
    final hasSignature = currentValue.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.history_edu_outlined,
                color: Color(0xFF0094FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Firma Personal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Poppins',
                ),
              ),
              const Spacer(),
              if (hasSignature)
                IconButton(
                  icon: const Icon(
                    Icons.copy_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  tooltip: 'Copiar firma',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: currentValue.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Firma copiada al portapapeles'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasSignature)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'No has agregado una firma personal. Tu firma aparece en tu perfil publico.',
                style: TextStyle(color: Colors.grey, fontFamily: 'Poppins'),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0094FF).withValues(alpha: 0.05),
                    const Color(0xFF0094FF).withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFF0094FF).withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '"',
                    style: TextStyle(
                      fontSize: 28,
                      color: Color(0xFF0094FF),
                      fontWeight: FontWeight.bold,
                      height: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      currentValue.trim(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      '"',
                      style: TextStyle(
                        fontSize: 28,
                        color: Color(0xFF0094FF),
                        fontWeight: FontWeight.bold,
                        height: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _showEditSignatureDialog(currentValue),
                icon: Icon(
                  hasSignature ? Icons.edit : Icons.add,
                  size: 18,
                ),
                label: Text(
                  hasSignature ? 'Editar firma' : 'Agregar firma',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0094FF),
                ),
              ),
              if (hasSignature) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text(
                          'Eliminar firma',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        content: const Text(
                          'Se eliminara tu firma personal del perfil publico.',
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      _updateField('signature', '');
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Error: No autenticado')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ConnectAppBar(
        showSearch: false,
        showSettings: false,
        showBack: true,
      ),
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Error al cargar datos'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                children: [
                  const Text(
                    'Información Personal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completa tu perfil profesional para generar más confianza en la comunidad.',
                    style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Poppins',
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildSection(
                    title: 'Especialidades',
                    icon: Icons.star_outline,
                    field: 'specialties',
                    currentValue: data['specialties'] ?? '',
                    addLabel: 'Agregar especialidad',
                  ),

                  _buildSection(
                    title: 'Experiencia',
                    icon: Icons.emoji_events_outlined,
                    field: 'experience',
                    currentValue: data['experience'] ?? '',
                    addLabel: 'Agregar experiencia',
                  ),

                  _buildSection(
                    title: 'Educación',
                    icon: Icons.school_outlined,
                    field: 'education',
                    currentValue: data['education'] ?? '',
                    addLabel: 'Agregar educación',
                  ),

                  _buildPaymentMethodsSection(
                    List<String>.from(data['paymentMethods'] ?? []),
                  ),

                  _buildResumeSection(data),

                  _buildSignatureSection(
                    currentValue: data['signature'] ?? '',
                  ),

                  const SizedBox(height: 40),
                ],
              );
            },
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF0094FF)),
              ),
            ),
        ],
      ),
    );
  }
}
