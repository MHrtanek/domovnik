import 'package:flutter_test/flutter_test.dart';
import 'package:domovnik/features/polls/models/poll_model.dart';

void main() {
  Map<String, dynamic> pollJson() => {
        'id': 'p1',
        'question': 'Otázka?',
        'building_id': 'b1',
        'created_by': 'u1',
        'expires_at': null,
        'created_at': '2026-01-01T10:00:00.000Z',
        'poll_options': [
          {'id': 'o1', 'poll_id': 'p1', 'option_text': 'Áno', 'vote_count': 3},
          {'id': 'o2', 'poll_id': 'p1', 'option_text': 'Nie', 'vote_count': 1},
        ],
      };

  test('fromJson parses question and nested options', () {
    final p = PollModel.fromJson(pollJson());
    expect(p.question, 'Otázka?');
    expect(p.options, hasLength(2));
    expect(p.options.first.optionText, 'Áno');
    expect(p.options.first.voteCount, 3);
  });

  test('totalVotes sums option vote counts', () {
    expect(PollModel.fromJson(pollJson()).totalVotes, 4);
  });

  test('votePercentage computes the fraction and handles zero total', () {
    final p = PollModel.fromJson(pollJson());
    expect(p.votePercentage(p.options.first), closeTo(0.75, 1e-9));

    final empty = PollModel(
      id: 'p',
      question: 'q',
      buildingId: 'b',
      createdBy: 'u',
      createdAt: DateTime(2026),
    );
    const opt = PollOptionModel(id: 'o', pollId: 'p', optionText: 'x');
    expect(empty.votePercentage(opt), 0);
  });

  test('isExpired reflects the expires_at timestamp', () {
    final expired = PollModel(
      id: 'p',
      question: 'q',
      buildingId: 'b',
      createdBy: 'u',
      createdAt: DateTime(2026),
      expiresAt: DateTime(2020),
    );
    final active = PollModel(
      id: 'p',
      question: 'q',
      buildingId: 'b',
      createdBy: 'u',
      createdAt: DateTime(2026),
      expiresAt: DateTime(2999),
    );
    expect(expired.isExpired, isTrue);
    expect(active.isExpired, isFalse);
  });

  test('toJson round-trips key fields', () {
    final json = PollModel.fromJson(pollJson()).toJson();
    expect(json['question'], 'Otázka?');
    expect(json['building_id'], 'b1');
  });
}
