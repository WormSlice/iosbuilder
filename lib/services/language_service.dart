import 'package:flutter/material.dart';

class LanguageProvider with ChangeNotifier {
  Locale _currentLocale = const Locale('es');
  
  Locale get currentLocale => _currentLocale;
  String get currentLanguage => _currentLocale.languageCode == 'es' ? 'Español' : 'English';

  void setLanguage(String language) {
    if (language == 'Español') {
      _currentLocale = const Locale('es');
    } else {
      _currentLocale = const Locale('en');
    }
    notifyListeners();
  }

  // Traducciones rápidas
  static final Map<String, Map<String, String>> _localizedValues = {
    'es': {
      'inicio': 'Inicio',
      'lo_tienes': 'Lo Tienes',
      'publicar': 'Publicar',
      'chats': 'Chats',
      'perfil': 'Perfil',
      'configuracion': 'Configuración',
      'idioma': 'Idioma',
      'ajustes_notificaciones': 'Ajustes de Notificaciones',
      'seguridad': 'Seguridad',
      'centro_actividad': 'Centro de Actividad',
      'editar_perfil': 'Editar Perfil',
      'informacion_personal': 'Información Personal',
      'cerrar_sesion': 'Cerrar Sesión',
      'soporte': 'Soporte Técnico',
      'reportar_problema': 'Reportar un Problema',
      'contactar_soporte': 'Contactar Soporte',
      'postularse': 'Postularse',
      'enviar_msj': 'Enviar Mensaje',
      'valor_mercado': 'Valor de Mercado',
      'fecha_ingreso': 'Fecha Ingreso',
      'descripcion': 'Descripción',
      'caracteristicas': 'Características',
      'ubicacion': 'Ubicación',
      'podria_interesarte': 'Podría interesarte',
      'ver_perfil': 'Ver perfil',
      'publicado_por': 'Publicado por',
    },
    'en': {
      'inicio': 'Home',
      'lo_tienes': 'Wants',
      'publicar': 'Post',
      'chats': 'Chats',
      'perfil': 'Profile',
      'configuracion': 'Settings',
      'idioma': 'Language',
      'ajustes_notificaciones': 'Notification Settings',
      'seguridad': 'Security',
      'centro_actividad': 'Activity Center',
      'editar_perfil': 'Edit Profile',
      'informacion_personal': 'Personal Information',
      'cerrar_sesion': 'Sign Out',
      'soporte': 'Technical Support',
      'reportar_problema': 'Report a Problem',
      'contactar_soporte': 'Contact Support',
      'postularse': 'Apply Now',
      'enviar_msj': 'Send Message',
      'valor_mercado': 'Market Value',
      'fecha_ingreso': 'Date Posted',
      'descripcion': 'Description',
      'caracteristicas': 'Features',
      'ubicacion': 'Location',
      'podria_interesarte': 'You might like',
      'ver_perfil': 'View Profile',
      'publicado_por': 'Posted by',
    },
  };

  String translate(String key) {
    return _localizedValues[_currentLocale.languageCode]?[key] ?? key;
  }
}
