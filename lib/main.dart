import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skripsie/constants.dart';
import 'package:skripsie/providers/bluetooth_provider.dart';
import 'package:skripsie/providers/location_provider.dart';
import 'package:skripsie/screens/qr_scan_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LocationProvider()),
        ChangeNotifierProvider(create: (context) => BluetoothProvider(latitude: null, longitude: null)),
      ],
      child: Consumer<LocationProvider>(
        builder: (context, locationProvider, child) {
          // Update BluetoothProvider with new location data
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final bluetoothProvider = Provider.of<BluetoothProvider>(context, listen: false);
            bluetoothProvider.updateMyLocation(locationProvider.currentLocation?.latitude, locationProvider.currentLocation?.longitude);
          });
          
          return MaterialApp(
            title: 'LoRa Chat',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme:
                  ColorScheme.fromSeed(
                    seedColor: PRIMARY_COLOR, // Vibrant purple
                    secondary: SECONDARY_COLOR, // Teal accent
                    brightness: Brightness.light,
                    primary: PRIMARY_COLOR_DARK,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                    background: Colors.white,
                    error: ERROR_COLOR,
                  ).copyWith(
                    primaryContainer: const Color(
                      0xFFE8DEF8,
                    ), // Light purple for containers
                    secondaryContainer: const Color(
                      0xFFCEFAF8,
                    ), // Light teal for containers
                  ),
              appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
              snackBarTheme: const SnackBarThemeData(
                actionBackgroundColor: Color(0xFF03DAC6),
                backgroundColor: Color(0xFF6200EE),
                behavior: SnackBarBehavior.floating,
                actionTextColor: Color(0xFF03DAC6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                contentTextStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                elevation: 6,
              ),
            ),
            home: const QRScanPage(),
          );
        },
      ),
    );
  }
}
