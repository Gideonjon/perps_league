import 'package:flutter_test/flutter_test.dart';
import 'package:perps_league/config.dart';
import 'package:perps_league/core/invite.dart';

void main() {
  test('no invite link on mobile without APP_URL', () {
    // Tests run on the VM (not web) with no --dart-define, so there is no
    // known web origin to link to.
    expect(AppConfig.inviteLink('K7QX2M'), isNull);
  });

  test('no pending invite outside the browser', () {
    expect(PendingInvite.peek, isNull);
    expect(PendingInvite.take(), isNull);
  });

  test('indexer defaults to the Hideki endpoint', () {
    expect(AppConfig.indexerUrl, 'https://hideki-dev.smk.somnia.host/v1/graphql');
  });
}
