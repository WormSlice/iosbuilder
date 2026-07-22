// CONNECT - Paleta de Colores del Proyecto
// ==========================================

class ConnectColors {
  // Colores Primarios
  static const Color primaryBlue = Color(0xFF0094FF); // Azul principal
  static const Color primaryBlueAlt = Color(0xFF0099FF); // Azul alternativo
  static const Color accentBlue = Color(0xFF1E88E5); // Azul de acento

  // Colores de Fondo
  static const Color backgroundWhite = Color(0xFFFFFFFF); // Fondo blanco
  static const Color backgroundGray = Color(0xFFF6F6F6); // Fondo gris claro
  static const Color backgroundLight = Color(0xFFF5F5F5); // Fondo muy claro

  // Colores de Texto
  static const Color textDark = Color(0xFF121212); // Texto oscuro
  static const Color textBlack54 = Colors.black54; // Texto secundario

  // Colores de Bordes y Divisores
  static const Color dividerGray = Color(0xFFE0E0E0); // Divisor gris
  static const Color borderGray = Color(0xFFE0E0E0); // Borde gris

  // Colores de Estado
  static const Color overlayDark = Colors.black; // Overlay oscuro
  static const Color placeholderGray = Colors.grey; // Placeholder

  // Gradientes
  static LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0094FF), Color(0xFF0099FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Uso en el proyecto:
// - primaryBlue: Botones, iconos activos, enlaces, bordes destacados
// - backgroundGray: Fondo de navegación, áreas secundarias
// - textDark: Títulos, encabezados principales
// - dividerGray: Separadores, bordes sutiles
