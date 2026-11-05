import 'package:fitness_zone_2/helper/notification_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved bell items of every shape load without crashing', () {
    final saved = <Map<String, dynamic>>[
      {'id': '-1234567', 'serverId': null, 'title': 'Push', 'body': 'b'}, // the crash
      {'id': '987', 'title': 'Text id', 'body': 'b'},
      {'id': 55, 'title': 'Old server item', 'body': 'b'},
      {'serverId': 12, 'id': '12', 'title': 'New', 'body': 'b', 'data': '{"a":1}'},
      {'title': null, 'body': 3, 'sentAt': 5},
    ];
    final list = saved.map(NotificationMessage.fromJson).toList();
    expect(list[0].serverId, isNull);
    expect(list[1].serverId, isNull);
    expect(list[2].serverId, 55);
    expect(list[3].serverId, 12);
    expect(list[3].data, {'a': 1});
    expect(list[4].title, '');
    expect(NotificationMessage.fromServer({'id': '77', 'title': 't', 'body': 'b'}).serverId, 77);
  });
}
