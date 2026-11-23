import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/services/invitation_service.dart';

/// دعوات البائعين والموظفين: الرمز يُقبل وحده أو داخل الرابط كاملاً.
void main() {
  test('the token is taken from a full link or used as is', () {
    expect(invitationTokenFrom('https://trendsham.com/join/AbC123'), 'AbC123');
    expect(
        invitationTokenFrom(
            'http://192.168.1.106/trendsham/public/join/xyz?x=1'),
        'xyz');
    expect(invitationTokenFrom('  AbC123  '), 'AbC123');
  });

  test('a preview tells the role and whether it can be used', () {
    final p = InvitationPreview.fromJson({
      'role': 'seller',
      'role_label': 'بائع',
      'store_name': 'متجر سام',
      'usable': true,
    });
    expect(p.isSeller, isTrue);
    expect(p.storeName, 'متجر سام');
    expect(p.usable, isTrue);

    final used = InvitationPreview.fromJson(
        {'role': 'employee', 'usable': false, 'problem': 'استُعملت'});
    expect(used.isSeller, isFalse);
    expect(used.problem, 'استُعملت');
  });

  test('admin list items read the link only while usable', () {
    final i = AdminInvitation.fromJson({
      'id': 4,
      'role': 'employee',
      'role_label': 'موظف',
      'status_label': 'بانتظار القبول',
      'usable': true,
      'url': 'https://x/join/t',
      'expires_at': '2026-12-01T00:00:00Z',
    });
    expect(i.id, 4);
    expect(i.url, 'https://x/join/t');
    expect(i.expiresAt, isNotNull);
  });
}
