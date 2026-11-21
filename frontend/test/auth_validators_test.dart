import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/auth_validators.dart';

void main() {
  group('ERP', () {
    test('5 digits is valid', () => expect(AuthValidators.erp('12345'), isNull));
    test('4 digits rejected (TC_AUTH_NEG_03)',
        () => expect(AuthValidators.erp('1234'), AuthMessages.badErp));
    test('6 digits rejected (TC_AUTH_NEG_03)',
        () => expect(AuthValidators.erp('123456'), AuthMessages.badErp));
    test('letters rejected',
        () => expect(AuthValidators.erp('12a45'), AuthMessages.badErp));
  });

  group('IBA email', () {
    test('khi.iba.edu.pk is valid',
        () => expect(AuthValidators.ibaEmail('ali@khi.iba.edu.pk'), isNull));
    test('upper case still valid',
        () => expect(AuthValidators.ibaEmail('ALI@KHI.IBA.EDU.PK'), isNull));
    test('gmail rejected (TC_AUTH_NEG_02)', () {
      expect(AuthValidators.ibaEmail('student@gmail.com'), AuthMessages.badEmail);
    });
    test('domain alone rejected', () {
      expect(AuthValidators.ibaEmail('@khi.iba.edu.pk'), AuthMessages.badEmail);
    });
  });

  group('Password (SCRUM-7)', () {
    test('8 chars is valid', () => expect(AuthValidators.password('abcd1234'), isNull));
    test('7 chars rejected', () {
      expect(AuthValidators.password('abc1234'), AuthMessages.shortPassword);
    });
    test('confirm must match', () {
      expect(AuthValidators.confirmPassword('abcd1234', 'abcd1235'),
          AuthMessages.passwordsDontMatch);
      expect(AuthValidators.confirmPassword('abcd1234', 'abcd1234'), isNull);
    });
  });
}
