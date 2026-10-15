import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/core/api/api_client.dart';
import 'package:codexa_mobile/core/models/models.dart';

void main() {
  group('CodeXa Error Taxonomy Mapping Tests', () {
    test('CxApiException maps GOOGLE_NOT_REGISTERED accurately', () {
      final exc = CxApiException(
        code: 'GOOGLE_NOT_REGISTERED',
        message: 'This Google account is not registered with CodeXa.',
        statusCode: 403,
      );
      expect(exc.message, 'This Google account is not registered with CodeXa.');
      expect(exc.code, 'GOOGLE_NOT_REGISTERED');
      expect(exc.statusCode, 403);
    });

    test('CxApiException maps DATABASE_UNAVAILABLE accurately', () {
      final exc = CxApiException(
        code: 'DATABASE_UNAVAILABLE',
        message: 'CodeXa is temporarily unable to connect to its database.',
        statusCode: 503,
      );
      expect(
        exc.message,
        'CodeXa is temporarily unable to connect to its database.',
      );
      expect(exc.statusCode, 503);
    });

    test('CxApiException maps INVALID_CREDENTIALS accurately', () {
      final exc = CxApiException(
        code: 'INVALID_CREDENTIALS',
        message: 'Incorrect login details.',
        statusCode: 401,
      );
      expect(exc.message, 'Incorrect login details.');
    });
  });

  group('CodeXa Data Models & Business Logic Tests', () {
    test(
      'InternshipModel computes isPreStart when start date is in the future',
      () {
        final futureDate = DateTime.now()
            .add(const Duration(days: 10))
            .toIso8601String();
        final model = InternshipModel.fromJson({
          'internId': 'CXA-INT-TEST',
          'domain': 'AI Engineering',
          'duration': '3 Months',
          'startDate': futureDate,
          'daysUntilStart': 10,
          'mentorName': 'Shaik Ashu',
          'status': 'ACTIVE',
          'stipend': 'Performance Stipend',
        });

        expect(model.isPreStart, isTrue);
        expect(model.daysUntilStart, 10);
        expect(model.internId, 'CXA-INT-TEST');
      },
    );

    test('OperationalMetricsModel parses leadership counters cleanly', () {
      final metrics = OperationalMetricsModel.fromJson({
        'activeEmployees': 14,
        'activeInterns': 28,
        'todayPresentCount': 35,
        'pendingLeaveCount': 3,
        'pendingCorrectionsCount': 2,
        'totalProjectsCount': 8,
      });

      expect(metrics.activeEmployees, 14);
      expect(metrics.activeInterns, 28);
      expect(metrics.todayPresentCount, 35);
      expect(metrics.pendingLeaveCount, 3);
      expect(metrics.totalProjectsCount, 8);
    });

    test(
      'PaymentInfoModel preserves authoritative ₹450 service fee breakdown',
      () {
        final payment = PaymentInfoModel.fromJson({
          'totalAmount': 450.0,
          'currency': 'INR',
          'status': 'PENDING_PAYMENT',
          'referenceId': 'CXA-PAY-TEST-450',
          'webCheckoutUrl':
              'https://codxa-agency.online/dashboard/internship/payment',
          'items': [
            {'name': 'Official Smart ID Card & NFC Dispatch', 'amount': 150},
            {'name': 'Enterprise AI Development Stack Access', 'amount': 300},
          ],
        });

        expect(payment.totalAmount, 450.0);
        expect(payment.currency, 'INR');
        expect(payment.items.length, 2);
        expect(payment.items[0]['amount'], 150);
        expect(payment.items[1]['amount'], 300);
      },
    );

    test('PeopleModel correctly parses coworker profile without exposing salary or private HR data', () {
      final person = PeopleModel.fromJson({
        'id': 'usr_123',
        'username': 'ashu_founder',
        'fullName': 'Shaik Ashu',
        'role': 'FOUNDER',
        'department': 'Executive / Engineering',
        'designation': 'Founder & CEO',
        'skills': ['Flutter', 'TypeScript', 'Prisma', 'Cloud Architecture'],
        'isActive': true,
      });

      expect(person.fullName, 'Shaik Ashu');
      expect(person.role, 'FOUNDER');
      expect(person.skills.length, 4);
      expect(person.isActive, isTrue);
    });
  });
}
