import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/api/api_client.dart';
import 'data/api/kudi9ja_api.dart';
import 'data/api/token_store.dart';
import 'data/services/storage_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storage = await StorageService.init();

  // The session, read back from the platform keystore before the first frame,
  // so the app knows whether it is signed in rather than flashing the sign-in
  // screen at somebody who is.
  final tokens = TokenStore();
  await tokens.load();

  late final AppState state;
  final api = Kudi9jaApi(ApiClient(
    tokens: tokens,
    // Fires when the refresh token is refused — expired, rotated away, or
    // signed out from another device. The customer has to sign in again, and
    // the app should say so rather than failing every request in silence.
    onSessionLost: () => state.handleSessionLost(),
  ));

  state = AppState(storage, api: api);

  runApp(
    ChangeNotifierProvider.value(
      value: state,
      child: const Kudi9jaApp(),
    ),
  );
}
