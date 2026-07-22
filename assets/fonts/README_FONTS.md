# Fuentes personalizadas para CONNECT

Este directorio está destinado a las fuentes personalizadas que usaremos en los nuevos diseños.

IMPORTANTE: Algunas de estas fuentes son propietarias y requieren licencia válida.

## Fuentes solicitadas

- Eurostile Extended
- SF Pro Rounded
- SF Pro Display Bold
- SF Pro Display
- SF Pro Text Regular

## Obtención legal de las fuentes

- SF Pro (Rounded / Display / Text): disponibles desde Apple, requieren aceptar la licencia.
  - Página oficial: https://developer.apple.com/fonts/
- Eurostile Extended: fuente comercial (Monotype/Linotype). Requiere compra/licencia.
  - Ejemplo de proveedor: https://www.myfonts.com/

No subas ni descargues fuentes desde sitios no oficiales si la licencia no lo permite.

## Nombres de archivo recomendados

Coloca los archivos (TTF/OTF) aquí y usa estos nombres sugeridos para mantener consistencia:

- `EurostileExtended-Regular.ttf`
- `EurostileExtended-Bold.ttf`
- `SFProRounded-Regular.ttf`
- `SFProRounded-Bold.ttf`
- `SFProDisplay-Regular.ttf`
- `SFProDisplay-Bold.ttf`
- `SFProText-Regular.ttf`

## Registro en Flutter

1) Asegúrate de que los archivos existan en este directorio.
2) En `pubspec.yaml`, descomenta y ajusta el bloque de `fonts` dentro de la sección `flutter:`.
3) Usa los nombres de familia en tu tema (por ejemplo, `fontFamily: 'SFProDisplay'`).

## Ejemplo de uso en ThemeData

```dart
ThemeData(
  fontFamily: 'SFProDisplay',
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontFamily: 'SFProText'),
    titleLarge: TextStyle(fontFamily: 'SFProDisplay', fontWeight: FontWeight.bold),
  ),
);
```

## Nota

El repositorio no incluye los archivos de fuentes por temas de licencia. Añádelos localmente y compártelos sólo con quienes tengan derecho de uso.