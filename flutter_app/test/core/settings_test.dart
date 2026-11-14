import 'package:flutter_test/flutter_test.dart';
import 'package:my_hours/core/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('首次欢迎标记默认未完成，写入后可持久化读取', () async {
    SharedPreferences.setMockInitialValues({});

    final settings = await AppSettings.load();
    expect(settings.welcomeSeen, isFalse);
    expect(settings.brandWelcomeSeen, isFalse);

    await settings.setWelcomeSeen();
    expect(settings.welcomeSeen, isTrue);
    expect(settings.brandWelcomeSeen, isTrue);

    final reloaded = await AppSettings.load();
    expect(reloaded.welcomeSeen, isTrue);
    expect(reloaded.brandWelcomeSeen, isTrue);
  });
}
