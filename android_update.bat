@echo off
echo Actualizando proyecto para Android 15+ y páginas de 16KB...

echo.
echo 1. Limpiando caché de Flutter...
flutter clean

echo.
echo 2. Obteniendo dependencias...
flutter pub get

echo.
echo 3. Limpiando proyecto Android...
cd android
call gradlew clean
cd ..

echo.
echo 4. Reconstruyendo proyecto...
flutter build apk --release

echo.
echo ✅ Proyecto actualizado exitosamente!
echo.
echo Cambios realizados:
echo - ✅ APIs obsoletas reemplazadas por SystemUiMode.edgeToEdge
echo - ✅ Soporte para páginas de 16KB agregado
echo - ✅ Configuración de Java actualizada a versión 17
echo - ✅ Optimizaciones de rendimiento habilitadas
echo.
echo Tu app ahora es compatible con Android 15+ y dispositivos de 16KB.
pause 