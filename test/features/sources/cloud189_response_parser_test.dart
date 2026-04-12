import 'package:flutter_test/flutter_test.dart';

import 'package:music/features/sources/data/cloud189/cloud189_api_client.dart';

void main() {
  test('parses Cloud189 JSON object responses returned as text', () {
    final data = cloud189MapFromResponseData(
      '{"result":0,"data":{"pre":"{NRP}","pubKey":"key"}}',
      'Cloud189 encryptConf',
    );

    expect(data['result'], 0);
    expect(data['data'], isA<Map<String, dynamic>>());
    expect((data['data'] as Map<String, dynamic>)['pre'], '{NRP}');
  });

  test('rejects non-object Cloud189 JSON responses', () {
    expect(
      () => cloud189MapFromResponseData('[1,2,3]', 'Cloud189 encryptConf'),
      throwsStateError,
    );
  });

  test('extracts PC login lt without matching QR image alt text', () {
    const html = '''
      <img src="/code/icon-success.png" alt="二维码登录成功" />
      <script>
        var lt = "7D7C3695B132DB8CE2814FCB1E64C400";
      </script>
    ''';

    expect(cloud189ExtractPcLoginLt(html), '7D7C3695B132DB8CE2814FCB1E64C400');
  });
}
