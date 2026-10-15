import 'package:flutter_test/flutter_test.dart';
import 'package:codexa_mobile/core/models/models.dart';
import 'package:codexa_mobile/core/api/api_client.dart';
import 'package:dio/dio.dart';

void main() {
  group('Manual Payment Approval & Policy Tests', () {
    test('ManagementPaymentItem parses PENDING_APPROVAL and submittedAt', () {
      final json = {
        'id': 'pay_req_101',
        'referenceId': 'CXA-PAY-2026-0042',
        'userId': 'usr_intern_001',
        'userName': 'G. Anjali',
        'userEmail': 'anjali@codxa-agency.online',
        'internId': 'CXA-INT-2026-042',
        'domain': 'Full-Stack Development',
        'amount': 450.0,
        'currency': 'INR',
        'status': 'PENDING_APPROVAL',
        'paymentMethod': 'PHONEPE',
        'cashStatus': 'NONE',
        'utrNumber': null,
        'proofImageUrl': 'proofs/pay_req_101_screenshot.png',
        'submittedAt': '2026-10-09T01:30:00.000Z',
        'createdAt': '2026-10-09T01:00:00.000Z',
      };

      final item = ManagementPaymentItem.fromJson(json);

      expect(item.id, 'pay_req_101');
      expect(item.referenceId, 'CXA-PAY-2026-0042');
      expect(item.amount, 450.0);
      expect(item.status, 'PENDING_APPROVAL');
      expect(item.paymentMethod, 'PHONEPE');
      expect(item.proofImageUrl, 'proofs/pay_req_101_screenshot.png');
      expect(item.submittedAt, isNotNull);
      expect(item.submittedAt!.year, 2026);
    });

    test('ManagementPaymentItem correctly handles CASH_PENDING status', () {
      final json = {
        'id': 'pay_req_102',
        'referenceId': 'CXA-PAY-2026-0043',
        'userId': 'usr_intern_002',
        'userName': 'K. Rahul',
        'internId': 'CXA-INT-2026-043',
        'domain': 'Cybersecurity',
        'amount': 450,
        'status': 'CASH_PENDING',
        'paymentMethod': 'CASH',
        'cashStatus': 'PENDING_CASH_APPROVAL',
        'createdAt': '2026-10-09T01:00:00.000Z',
      };

      final item = ManagementPaymentItem.fromJson(json);

      expect(item.amount, 450.0);
      expect(item.cashStatus, 'PENDING_CASH_APPROVAL');
      expect(item.status, 'CASH_PENDING');
      expect(item.proofImageUrl, isNull);
    });

    test(
      'CxApiClient.parseError handles 409 PAYMENT_ALREADY_REVIEWED cleanly',
      () {
        final response = Response(
          requestOptions: RequestOptions(path: '/api/mobile/payments/decision'),
          statusCode: 409,
          data: {
            'ok': false,
            'error': {
              'code': 'PAYMENT_ALREADY_REVIEWED',
              'message': 'This payment has already been reviewed.',
            },
          },
        );

        final dioError = DioException(
          requestOptions: RequestOptions(path: '/api/mobile/payments/decision'),
          response: response,
          type: DioExceptionType.badResponse,
        );

        final parsed = CxApiClient.parseError(dioError);
        expect(
          parsed.contains('This payment has already been reviewed'),
          isTrue,
        );
      },
    );
  });
}
