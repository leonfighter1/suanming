import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'application/providers.dart';

void main() => runApp(const ProviderScope(retry: retryAdmin, child: AdminApp()));
