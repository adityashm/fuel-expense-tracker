import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Configure google_fonts to work in test environment
  GoogleFonts.config.allowRuntimeFetching = false;
  
  // Run the tests
  await testMain();
}
