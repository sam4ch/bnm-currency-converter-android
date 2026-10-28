import 'package:flutter/material.dart';

import 'data/bnm_client.dart';
import 'data/rate_repository.dart';
import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CurrencyApp(repository: RateRepository(BnmClient(), AndroidCache())));
}
