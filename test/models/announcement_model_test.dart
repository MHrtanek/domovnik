import 'package:flutter_test/flutter_test.dart';
import 'package:domovnik/features/announcements/models/announcement_model.dart';

void main() {
  test('fromJson parses fields and photo urls', () {
    final a = AnnouncementModel.fromJson({
      'id': 'a1',
      'title': 'Odstávka',
      'content': 'Text',
      'is_urgent': true,
      'created_by': 'u1',
      'building_id': 'b1',
      'created_at': '2026-01-01T10:00:00.000Z',
      'photo_urls': ['https://a/1.jpg'],
    });

    expect(a.title, 'Odstávka');
    expect(a.isUrgent, isTrue);
    expect(a.photoUrls, ['https://a/1.jpg']);
  });

  test('is_urgent defaults to false and photo_urls to empty', () {
    final a = AnnouncementModel.fromJson({
      'id': 'a2',
      'title': 'x',
      'content': 'y',
      'created_by': 'u1',
      'building_id': 'b1',
      'created_at': '2026-01-01T10:00:00.000Z',
    });

    expect(a.isUrgent, isFalse);
    expect(a.photoUrls, isEmpty);
  });

  test('toJson round-trips key fields', () {
    final json = AnnouncementModel(
      id: 'a3',
      title: 'T',
      content: 'C',
      isUrgent: false,
      createdBy: 'u1',
      buildingId: 'b1',
      createdAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
    ).toJson();

    expect(json['title'], 'T');
    expect(json['is_urgent'], false);
    expect(json['photo_urls'], isEmpty);
  });
}
