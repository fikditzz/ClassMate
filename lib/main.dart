import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'data/backend.dart';
import 'data/demo/demo_backend.dart';
import 'data/supabase/supabase_backend.dart';
import 'supabase_options.dart';

/// `flutter run --dart-define=DEMO=true` memaksa mode demo.
const _paksaDemo = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(ClassMateApp(backend: await _siapkanBackend()));
}

Future<BackendClassMate> _siapkanBackend() async {
  if (_paksaDemo) return DemoBackend();
  if (!SupabaseOptions.sudahLengkap) {
    debugPrint(
      'Konfigurasi Supabase di lib/supabase_options.dart belum lengkap. '
      'Aplikasi berjalan dalam mode demo.',
    );
    return DemoBackend();
  }
  await Supabase.initialize(
    url: SupabaseOptions.url,
    publishableKey: SupabaseOptions.publishableKey,
  );
  return SupabaseBackend(Supabase.instance.client);
}
