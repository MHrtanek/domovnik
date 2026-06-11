import 'package:flutter_test/flutter_test.dart';
import 'package:domovnik/features/tickets/models/ticket_model.dart';

void main() {
  group('TicketCategory / TicketStatus enums', () {
    test('fromString maps Slovak labels', () {
      expect(TicketCategory.fromString('Výťah'), TicketCategory.vytah);
      expect(TicketStatus.fromString('V riešení'), TicketStatus.vRieseni);
    });

    test('fromString falls back on unknown values', () {
      expect(TicketCategory.fromString('neznáme'), TicketCategory.ine);
      expect(TicketStatus.fromString('xxx'), TicketStatus.prijate);
    });
  });

  group('TicketModel.fromJson', () {
    test('parses core fields, enums and nested creator name', () {
      final t = TicketModel.fromJson({
        'id': 't1',
        'title': 'Pokazený výťah',
        'description': 'popis',
        'category': 'Výťah',
        'status': 'V riešení',
        'photo_url': null,
        'created_by': 'u1',
        'building_id': 'b1',
        'created_at': '2026-01-01T10:00:00.000Z',
        'updated_at': '2026-01-02T10:00:00.000Z',
        'creator': {'full_name': 'Ján Novák'},
      });

      expect(t.id, 't1');
      expect(t.title, 'Pokazený výťah');
      expect(t.category, TicketCategory.vytah);
      expect(t.status, TicketStatus.vRieseni);
      expect(t.createdByName, 'Ján Novák');
      expect(t.createdAt, DateTime.parse('2026-01-01T10:00:00.000Z'));
    });

    test('collects photo urls from the ticket_photos join', () {
      final t = TicketModel.fromJson({
        'id': 't2',
        'title': 'x',
        'category': 'Iné',
        'status': 'Prijaté',
        'created_by': 'u1',
        'building_id': 'b1',
        'created_at': '2026-01-01T10:00:00.000Z',
        'updated_at': '2026-01-01T10:00:00.000Z',
        'ticket_photos': [
          {'photo_url': 'https://a/1.jpg'},
          {'photo_url': 'https://a/2.jpg'},
        ],
      });

      expect(t.photoUrls, ['https://a/1.jpg', 'https://a/2.jpg']);
      expect(t.allPhotoUrls, hasLength(2));
    });
  });

  group('TicketModel.toJson', () {
    test('serialises enums back to their Slovak labels', () {
      final t = TicketModel(
        id: 't3',
        title: 'Test',
        category: TicketCategory.elektrina,
        status: TicketStatus.ukoncene,
        createdBy: 'u1',
        buildingId: 'b1',
        createdAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-01-01T10:00:00.000Z'),
      );

      final json = t.toJson();
      expect(json['category'], 'Elektrina');
      expect(json['status'], 'Ukončené');
      expect(json['title'], 'Test');
    });
  });
}
