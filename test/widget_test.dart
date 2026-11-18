import 'package:flutter_test/flutter_test.dart';
import 'package:playbox/api.dart';

void main() {
  test('server url is normalised and stream url built', () {
    final api = PlayboxApi('http://example:9998///');
    expect(api.baseUrl, 'http://example:9998');
    expect(api.streamUrl('12'), 'http://example:9998/scene/12/stream');
  });
}
