import 'package:ai_image_compare/src/dashboard/dashboard.dart';
import 'package:ai_image_compare/src/splashScreen/splash_screen.dart';
import 'package:ai_image_compare/utils/route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Selfie Tracker',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Color(0xFF2986CC)),
        primaryColor: const Color(0xFF2986CC),
        dialogTheme: const DialogTheme(
          backgroundColor: Colors.white,
        ),
      ),
      initialRoute: ROUT_SPLASH,
      onGenerateRoute: (setting){
        switch(setting.name){
          case ROUT_SPLASH:
            return MaterialPageRoute(builder: (BuildContext context){
              return SafeArea(top: false, child: SplashScreen());
            });
          case ROUT_DASHBOARD:
            return MaterialPageRoute(builder: (BuildContext context) {
              return const SafeArea(top: true, child: Dashboard());
            });
        }
        return null;
      },
    );
  }
}