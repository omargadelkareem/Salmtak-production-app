import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart'; // لازم الاستيراد ده
import 'package:intl/intl.dart';

import 'core/Routing/app_router.dart';
import 'firebase_options.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GetStorage.init();

  await initializeDateFormatting('ar');

  Intl.defaultLocale = 'ar';



  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      child: MaterialApp(
        title: ' سلامتك',

        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          textTheme: const TextTheme(
            displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            bodyLarge: TextStyle(fontSize: 16),
            bodyMedium: TextStyle(fontSize: 14),
            labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ).apply(fontFamily: 'Tajawal'),
          useMaterial3: true,
        ),
        initialRoute: AppRoutes.splash, // البداية من السبلاش
        onGenerateRoute: AppRoutes.generateRoute, // الروتر البسيط بتاعنا
      ),
    );
  }
}
