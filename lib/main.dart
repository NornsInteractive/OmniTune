import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/database/isar_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化 Isar 数据库
  await IsarManager.initialize();
  
  runApp(const ProviderScope(child: MusicApp()));
}
