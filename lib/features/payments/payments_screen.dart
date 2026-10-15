import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/cx_notification_service.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/theme/cx_theme.dart';
import '../../core/widgets/cx_components.dart';
import 'post_payment_benefits_view.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  final String? initialPaymentId;

  const PaymentsScreen({super.key, this.initialPaymentId});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String _selectedFilter = 'PENDING APPROVAL';
  String _searchQuery = '';
  bool _isActionLoading = false;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _hasCheckedInitialPayment = false;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Listen to real-time incoming payment push notifications
    CxNotificationService.onPaymentNotificationReceived = (paymentId) {
      if (mounted) {
        ref.invalidate(paymentsDashboardProvider);
        ref.invalidate(bootstrapProvider);
        if (paymentId != null && paymentId.isNotEmpty) {
          _checkAndOpenPaymentById(paymentId);
        }
      }
    };
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    if (CxNotificationService.onPaymentNotificationReceived != null) {
      CxNotificationService.onPaymentNotificationReceived = null;
    }
    super.dispose();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _syncRemainingTime(String? expiresAtStr) {
    if (expiresAtStr == null) return;
    final expiresAt = DateTime.tryParse(expiresAtStr);
    if (expiresAt == null) return;
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    if (diff > 0 && _remainingSeconds == 0) {
      setState(() => _remainingSeconds = diff);
    }
  }

  void _checkAndOpenPaymentById(String targetId) {
    final payAsync = ref.read(paymentsDashboardProvider);
    payAsync.whenData((data) {
      if (data != null && data['isManagement'] == true) {
        final raw = (data['payments'] as List<dynamic>?) ?? [];
        final items = raw
            .map((p) => ManagementPaymentItem.fromJson(p))
            .toList();
        final match = items
            .where((it) => it.id == targetId || it.referenceId == targetId)
            .firstOrNull;
        if (match != null && mounted) {
          _openPaymentReviewDialog(
            context,
            match,
            data['canApprove'] == true,
            data['canApproveCash'] == true,
          );
        }
      }
    });
  }

  // ─── 1. INTERN UPI PAYMENT LAUNCH ───
  Future<void> _startUpiPayment(BuildContext context, String method) async {
    setState(() => _isActionLoading = true);

    try {
      final api = CxApiClient();
      final res = await api.dio.post(
        '/api/mobile/payments/start',
        data: {'method': method},
      );
      setState(() => _isActionLoading = false);

      if (res.data != null && res.data['ok'] == true) {
        final upiUrl = res.data['upiUrl'] ?? res.data['universalUri'];
        final expiresAt = res.data['expiresAt'];
        final paymentId = res.data['paymentId'];
        _syncRemainingTime(expiresAt);

        if (upiUrl != null && upiUrl.toString().isNotEmpty) {
          final uri = Uri.parse(upiUrl.toString());
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {}
        }

        ref.invalidate(paymentsDashboardProvider);

        if (context.mounted) {
          _openScreenshotPickerSheet(context, paymentId);
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.data?['error']?['message'] ??
                    'Could not start UPI session.',
              ),
              backgroundColor: CxColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isActionLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CxApiClient.parseError(e)),
            backgroundColor: CxColors.error,
          ),
        );
      }
    }
  }

  // ─── 2. INTERN CASH REQUEST ───
  Future<void> _requestCashPayment(BuildContext context) async {
    setState(() => _isActionLoading = true);

    try {
      final api = CxApiClient();
      final res = await api.dio.post('/api/mobile/payments/cash-request');
      setState(() => _isActionLoading = false);

      if (res.data != null && res.data['ok'] == true) {
        final whatsappUrl = res.data['coFounder']?['whatsappUrl'];
        if (whatsappUrl != null) {
          final uri = Uri.parse(whatsappUrl);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }

        ref.invalidate(paymentsDashboardProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cash request submitted. Direct message sent to Co-Founder.',
              ),
              backgroundColor: CxColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isActionLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CxApiClient.parseError(e)),
            backgroundColor: CxColors.error,
          ),
        );
      }
    }
  }

  // ─── 3. SCREENSHOT UPLOAD MODAL (REAL IMAGE PICKER) ───
  void _openScreenshotPickerSheet(BuildContext context, String? paymentId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'UPLOAD PAYMENT SCREENSHOT',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please upload the payment confirmation receipt from your UPI or bank app showing ₹450 transfer.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.blue,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.inter(
                    color: CxColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Pick screenshot from phone storage (PNG, JPG, WebP)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadScreenshot(
                    context,
                    paymentId,
                    ImageSource.gallery,
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.amber,
                  ),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.inter(
                    color: CxColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Capture transaction screen with camera',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadScreenshot(
                    context,
                    paymentId,
                    ImageSource.camera,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadScreenshot(
    BuildContext context,
    String? paymentId,
    ImageSource source,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 2400,
      imageQuality: 90,
    );

    if (pickedFile == null) return;

    if (!context.mounted) return;

    // Show preview and upload confirmation dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) {
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              backgroundColor: CxColors.cardElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'CONFIRM SCREENSHOT',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selected: ${pickedFile.name}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CxColors.borderSubtle),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: CxColors.brightRed,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Screenshot Ready',
                            style: GoogleFonts.orbitron(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Tap Submit to send for Founder review',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: CxColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your screenshot will be securely stored and reviewed by the Founder or Co-Founder. Payment becomes successful only upon independent receipt confirmation.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: CxColors.textMuted),
                  ),
                ),
                CxButton(
                  label: 'SUBMIT PROOF',
                  width: 140,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDlgState(() => isSubmitting = true);
                          try {
                            final api = CxApiClient();
                            final formData = FormData.fromMap({
                              'screenshot': await MultipartFile.fromFile(
                                pickedFile.path,
                                filename: pickedFile.name,
                              ),
                              if (paymentId != null) 'paymentId': paymentId,
                            });

                            final res = await api.dio.post(
                              '/api/mobile/payments/proof',
                              data: formData,
                            );

                            if (dlgCtx.mounted) Navigator.pop(dlgCtx);

                            ref.invalidate(paymentsDashboardProvider);
                            ref.invalidate(bootstrapProvider);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    res.data?['message'] ?? 'Payment screenshot submitted and is awaiting CodeXa management approval.',
                                  ),
                                  backgroundColor: CxColors.success,
                                ),
                              );
                            }
                          } catch (err) {
                            setDlgState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(CxApiClient.parseError(err)),
                                  backgroundColor: CxColors.error,
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── 4. FOUNDER/CO-FOUNDER MANAGEMENT DECISION ───
  Future<void> _handleManagementDecision(
    BuildContext context,
    String paymentId,
    String action, {
    String? reason,
    String? notes,
    bool confirmation = false,
  }) async {
    setState(() => _isActionLoading = true);

    try {
      final api = CxApiClient();
      final res = await api.dio.post(
        '/api/mobile/payments/decision',
        data: {
          'paymentId': paymentId,
          'action': action,
          'reason': reason,
          'notes': notes,
          'confirmation': confirmation,
        },
      );
      setState(() => _isActionLoading = false);

      if (res.data != null && res.data['ok'] == true) {
        ref.invalidate(paymentsDashboardProvider);
        ref.invalidate(bootstrapProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                res.data['message'] ?? 'Action recorded successfully.',
              ),
              backgroundColor: CxColors.success,
            ),
          );
        }
      }
    } on DioException catch (dioErr) {
      setState(() => _isActionLoading = false);
      ref.invalidate(paymentsDashboardProvider);

      final status = dioErr.response?.statusCode;
      final errCode = dioErr.response?.data?['error']?['code'];
      final errMsg =
          dioErr.response?.data?['error']?['message'] ?? dioErr.message;

      if (context.mounted) {
        if (status == 409 || errCode == 'PAYMENT_ALREADY_REVIEWED') {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: CxColors.cardElevated,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'PAYMENT ALREADY REVIEWED',
                style: GoogleFonts.orbitron(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: CxColors.warning,
                ),
              ),
              content: Text(
                'This payment has already been reviewed by another manager. The record has been refreshed with the canonical status.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: CxColors.brightRed),
                  ),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errMsg ?? 'Operation failed'),
              backgroundColor: CxColors.error,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isActionLoading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(CxApiClient.parseError(e)),
            backgroundColor: CxColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payAsync = ref.watch(paymentsDashboardProvider);

    return Scaffold(
      backgroundColor: CxColors.background,
      appBar: CxAppBar(
        title: 'PAYMENTS',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: CxColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        color: CxColors.brightRed,
        backgroundColor: CxColors.cardElevated,
        onRefresh: () async {
          ref.invalidate(paymentsDashboardProvider);
          ref.invalidate(bootstrapProvider);
        },
        child: payAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: CxColors.brightRed),
          ),
          error: (err, _) => Center(
            child: CxEmptyState(
              icon: Icons.error_outline,
              title: 'UNABLE TO LOAD PAYMENTS',
              message: CxApiClient.parseError(err),
            ),
          ),
          data: (data) {
            if (data == null) {
              return const CxEmptyState(
                icon: Icons.receipt_long,
                title: 'NO PAYMENT REQUIRED',
                message: 'All payment records are settled.',
              );
            }

            final isManagement = data['isManagement'] == true;

            // Handle deep linked payment if present
            if (isManagement &&
                widget.initialPaymentId != null &&
                !_hasCheckedInitialPayment) {
              _hasCheckedInitialPayment = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkAndOpenPaymentById(widget.initialPaymentId!);
              });
            }

            if (isManagement) {
              return _buildManagementView(context, data);
            } else {
              return _buildInternPersonalView(context, data['payment']);
            }
          },
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // MANAGEMENT VIEW (FOUNDER & CO-FOUNDER APPROVAL WORKSPACE)
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildManagementView(BuildContext context, Map<String, dynamic> data) {
    final metrics = data['metrics'] ?? {};
    final rawPayments = (data['payments'] as List<dynamic>?) ?? [];
    final canApprove = data['canApprove'] == true;
    final canApproveCash = data['canApproveCash'] == true;

    final payments = rawPayments
        .map((p) => ManagementPaymentItem.fromJson(p))
        .toList();

    // Compute live pending approvals count
    final pendingCount = payments
        .where(
          (p) =>
              p.status == 'PENDING_APPROVAL' ||
              p.status == 'PENDING_VERIFICATION' ||
              p.status == 'VERIFYING' ||
              p.status == 'REVIEW_REQUIRED' ||
              p.status == 'AWAITING_SCREENSHOT',
        )
        .length;

    // Filter payments
    final filtered = payments.where((p) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match =
            p.userName.toLowerCase().contains(q) ||
            p.internId.toLowerCase().contains(q) ||
            p.referenceId.toLowerCase().contains(q) ||
            p.domain.toLowerCase().contains(q) ||
            (p.utrNumber?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }

      final isPaid =
          p.status == 'PAID' || p.status == 'APPROVED' || p.status == 'SUCCESS';
      final isPending =
          p.status == 'PENDING_APPROVAL' ||
          p.status == 'PENDING_VERIFICATION' ||
          p.status == 'VERIFYING' ||
          p.status == 'REVIEW_REQUIRED';
      final isCashPending =
          p.cashStatus == 'PENDING_CASH_APPROVAL' || p.status == 'CASH_PENDING';
      final isRejected = p.status == 'REJECTED';

      if (_selectedFilter == 'PENDING APPROVAL') return isPending;
      if (_selectedFilter == 'PAID') return isPaid;
      if (_selectedFilter == 'NOT PAID') return !isPaid;
      if (_selectedFilter == 'CASH PENDING') return isCashPending;
      if (_selectedFilter == 'REJECTED') return isRejected;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(CxSpacing.lg),
      children: [
        // 1. Executive Summary Metrics
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'PENDING REVIEW',
                '$pendingCount',
                pendingCount > 0
                    ? const Color(0xFFFFB703)
                    : CxColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'PAID',
                '${metrics['paidCount'] ?? 0}',
                CxColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'CASH PENDING',
                '${metrics['cashPendingCount'] ?? 0}',
                const Color(0xFFFB8500),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                'TOTAL INTERNS',
                '${metrics['totalInterns'] ?? 0}',
                CxColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'COLLECTED',
                '₹${(metrics['totalCollectedAmount'] as num?)?.toInt() ?? 0}',
                CxColors.success,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricTile(
                'PENDING',
                '₹${(metrics['pendingAmount'] as num?)?.toInt() ?? 0}',
                CxColors.brightRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: CxSpacing.lg),

        // 2. Search Field
        CxTextField(
          hint: 'Search intern name, ID, reference, domain...',
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: CxColors.textSecondary,
          ),
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
        ),
        const SizedBox(height: CxSpacing.md),

        // 3. Filter Tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTabChip('PENDING APPROVAL', badgeCount: pendingCount),
              _buildTabChip('ALL'),
              _buildTabChip('PAID'),
              _buildTabChip('NOT PAID'),
              _buildTabChip('CASH PENDING'),
              _buildTabChip('REJECTED'),
            ],
          ),
        ),
        const SizedBox(height: CxSpacing.lg),

        // 4. Payment Items List
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: CxEmptyState(
              icon: Icons.search_off,
              title: 'NO RECORDS FOUND',
              message: 'No payment submissions match the selected filter.',
            ),
          )
        else
          ...filtered.map(
            (item) => _buildManagementPaymentCard(
              context,
              item,
              canApprove,
              canApproveCash,
            ),
          ),
      ],
    );
  }

  Widget _buildMetricTile(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: CxColors.cardElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CxColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: CxColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, {int badgeCount = 0}) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = label),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? CxColors.brightRed : CxColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? CxColors.brightRed : CxColors.borderSubtle,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : CxColors.textSecondary,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : const Color(0xFFFFB703),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? CxColors.brightRed : Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementPaymentCard(
    BuildContext context,
    ManagementPaymentItem item,
    bool canApprove,
    bool canApproveCash,
  ) {
    final isPaid =
        item.status == 'PAID' ||
        item.status == 'APPROVED' ||
        item.status == 'SUCCESS';
    final isPending =
        item.status == 'PENDING_APPROVAL' ||
        item.status == 'PENDING_VERIFICATION' ||
        item.status == 'VERIFYING' ||
        item.status == 'REVIEW_REQUIRED';
    final isCashPending =
        item.cashStatus == 'PENDING_CASH_APPROVAL' ||
        item.status == 'CASH_PENDING';
    final isRejected = item.status == 'REJECTED';

    final Color statusColor;
    final String statusLabel;

    if (isPaid) {
      statusColor = CxColors.success;
      statusLabel = 'PAID';
    } else if (isPending) {
      statusColor = const Color(0xFFFFB703);
      statusLabel = 'PENDING APPROVAL';
    } else if (isCashPending) {
      statusColor = const Color(0xFFFB8500);
      statusLabel = 'CASH PENDING';
    } else if (isRejected) {
      statusColor = CxColors.brightRed;
      statusLabel = 'REJECTED';
    } else {
      statusColor = CxColors.textMuted;
      statusLabel = 'DUE';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: CxSpacing.md),
      child: CxCard(
        onTap: () =>
            _openPaymentReviewDialog(context, item, canApprove, canApproveCash),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CxAvatar(
                  name: item.userName,
                  imageUrl: item.userPfp,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.userName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CxColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${item.internId} • ${item.domain}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CxSpacing.sm),
            const Divider(color: CxColors.borderSubtle, height: 1),
            const SizedBox(height: CxSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${item.amount.toInt()} • ${item.paymentMethod}',
                  style: GoogleFonts.orbitron(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: CxColors.textPrimary,
                  ),
                ),
                Text(
                  item.referenceId,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textMuted,
                  ),
                ),
              ],
            ),
            if (isPending && canApprove) ...[
              const SizedBox(height: CxSpacing.md),
              SizedBox(
                width: double.infinity,
                child: CxButton(
                  label: 'REVIEW PAYMENT',
                  backgroundColor: const Color(0xFFD90429),
                  onPressed: () => _openPaymentReviewDialog(
                    context,
                    item,
                    canApprove,
                    canApproveCash,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 5. PAYMENT APPROVAL REVIEW SCREEN / MODAL ───
  void _openPaymentReviewDialog(
    BuildContext context,
    ManagementPaymentItem item,
    bool canApprove,
    bool canApproveCash,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PaymentReviewSheetContent(
        item: item,
        canApprove: canApprove,
        canApproveCash: canApproveCash,
        onApprove: (notes, confirmation) async {
          Navigator.pop(ctx);
          await _handleManagementDecision(
            context,
            item.id,
            'APPROVE',
            notes: notes,
            confirmation: confirmation,
          );
        },
        onReject: (reason) async {
          Navigator.pop(ctx);
          await _handleManagementDecision(
            context,
            item.id,
            'REJECT',
            reason: reason,
          );
        },
        onConfirmCash: () async {
          Navigator.pop(ctx);
          await _handleManagementDecision(
            context,
            item.id,
            'CONFIRM_CASH',
            confirmation: true,
          );
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // INTERN PERSONAL VIEW (BILL ₹450, TIMED ATTEMPT, PROOF STATUS, BENEFITS)
  // ═════════════════════════════════════════════════════════════════════════════
  Widget _buildInternPersonalView(
    BuildContext context,
    Map<String, dynamic>? payment,
  ) {
    if (payment == null) {
      return const CxEmptyState(
        icon: Icons.check_circle_outline,
        title: 'NO PENDING BILLS',
        message: 'All internship bills and service charges are up to date.',
      );
    }

    final total = (payment['totalAmount'] as num?)?.toInt() ?? 450;
    final status = (payment['status'] ?? 'PENDING_PAYMENT')
        .toString()
        .toUpperCase();
    final isApproved =
        status == 'SUCCESSFUL' ||
        status == 'APPROVED' ||
        status == 'PAID' ||
        status == 'SUCCESS';
    final isPendingApproval =
        status == 'PENDING_APPROVAL' ||
        status == 'PENDING_VERIFICATION' ||
        status == 'VERIFYING' ||
        status == 'REVIEW_REQUIRED';
    final isCashPending =
        status == 'PENDING_CASH_APPROVAL' ||
        payment['cashStatus'] == 'PENDING_CASH_APPROVAL';
    final isRejected = status == 'REJECTED';
    final activeAttempt = payment['activeAttempt'] as Map<String, dynamic>?;

    if (activeAttempt != null && activeAttempt['expiresAt'] != null) {
      _syncRemainingTime(activeAttempt['expiresAt']);
    }

    return ListView(
      padding: const EdgeInsets.all(CxSpacing.lg),
      children: [
        // 1. Bill Card
        CxCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'INTERNSHIP SERVICE BILL',
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: CxColors.textPrimary,
                    ),
                  ),
                  CxStatusChip(
                    label: isApproved
                        ? 'APPROVED'
                        : isCashPending
                        ? 'CASH PENDING'
                        : isPendingApproval
                        ? 'PENDING APPROVAL'
                        : isRejected
                        ? 'REJECTED'
                        : 'DUE',
                  ),
                ],
              ),
              const SizedBox(height: CxSpacing.md),
              Text(
                'Total Payable Amount',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '₹$total',
                style: GoogleFonts.orbitron(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isApproved
                      ? CxColors.success
                      : (isCashPending || isPendingApproval)
                      ? const Color(0xFFFFB703)
                      : CxColors.brightRed,
                ),
              ),

              // 5-Minute Timer countdown if active
              if (_remainingSeconds > 0 && !isApproved) ...[
                const SizedBox(height: CxSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: CxColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Payment Window: ${_remainingSeconds ~/ 60}:${(_remainingSeconds % 60).toString().padLeft(2, '0')} remaining',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: CxColors.warning,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: CxSpacing.lg),
              const Divider(color: CxColors.borderSubtle),
              const SizedBox(height: CxSpacing.sm),

              // Canonical items breakdown
              _buildBillItemRow('1. Mandatory Student ID Card', 150),
              const SizedBox(height: 6),
              _buildBillItemRow('2. AI Development Tools Pack', 300),
            ],
          ),
        ),
        const SizedBox(height: CxSpacing.xl),

        // 2. Actions & States
        if (isApproved) ...[
          Container(
            padding: const EdgeInsets.all(CxSpacing.lg),
            decoration: BoxDecoration(
              color: CxColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CxColors.success.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: CxColors.success, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT SETTLED',
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CxColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Official CodeXa Service Receipt verified. ID Card issuance and AI Tools access unlocked.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CxSpacing.xl),
          const PostPaymentBenefitsView(),
        ] else if (isPendingApproval) ...[
          Container(
            padding: const EdgeInsets.all(CxSpacing.lg),
            decoration: BoxDecoration(
              color: CxColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFFB703).withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFFFFB703),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PAYMENT PROOF SUBMITTED',
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFB703),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your payment screenshot has been submitted and is waiting for CodeXa Founder/Co-Founder manual approval.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textPrimary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: CxColors.borderSubtle, height: 1),
                const SizedBox(height: 8),
                Text(
                  'Reference: ${payment['referenceId'] ?? 'CXA-PAY-450'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                ),
                Text(
                  'Expected: ₹450 INR',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  icon: const Icon(
                    Icons.upload_file,
                    size: 16,
                    color: CxColors.textSecondary,
                  ),
                  label: const Text(
                    'RE-UPLOAD DIFFERENT SCREENSHOT',
                    style: TextStyle(
                      fontSize: 11,
                      color: CxColors.textSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: CxColors.borderSubtle),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () =>
                      _openScreenshotPickerSheet(context, payment['id']),
                ),
              ],
            ),
          ),
        ] else if (isRejected) ...[
          Container(
            padding: const EdgeInsets.all(CxSpacing.lg),
            decoration: BoxDecoration(
              color: CxColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CxColors.brightRed.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      color: CxColors.brightRed,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'PAYMENT PROOF NOT ACCEPTED',
                        style: GoogleFonts.orbitron(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: CxColors.brightRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Reason: ${payment['rejectionReason'] ?? 'Transaction could not be confirmed in CodeXa receiving account.'}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'If you completed the transfer, please upload a new clear transaction screenshot showing the full receipt with date and transaction ID.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: CxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                CxButton(
                  label: 'UPLOAD NEW SCREENSHOT',
                  onPressed: () =>
                      _openScreenshotPickerSheet(context, payment['id']),
                ),
              ],
            ),
          ),
        ] else if (isCashPending) ...[
          Container(
            padding: const EdgeInsets.all(CxSpacing.lg),
            decoration: BoxDecoration(
              color: CxColors.cardElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFFB8500).withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.handshake_outlined,
                      color: Color(0xFFFB8500),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'CASH HANDOVER PENDING',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFB8500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Please hand over the exact ₹450 cash amount to B. Sanjay (Co-Founder). Your status will automatically update upon physical confirmation.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Standard Unpaid Bill Options
          CxButton(
            label: 'PAY ₹$total NOW',
            isLoading: _isActionLoading,
            onPressed: _isActionLoading
                ? null
                : () => _showUpiAppSelector(context),
          ),
          const SizedBox(height: CxSpacing.md),
          Row(
            children: [
              Expanded(
                child: CxButton(
                  label: 'SCAN QR CODE',
                  backgroundColor: CxColors.surface,
                  textColor: CxColors.textPrimary,
                  onPressed: () => _openQrPaymentModal(context, payment),
                ),
              ),
              const SizedBox(width: CxSpacing.md),
              Expanded(
                child: CxButton(
                  label: 'PAY WITH CASH',
                  backgroundColor: CxColors.surface,
                  textColor: CxColors.textPrimary,
                  onPressed: () => _requestCashPayment(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: CxSpacing.md),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: CxColors.borderSubtle),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => _openScreenshotPickerSheet(context, payment['id']),
            child: Center(
              child: Text(
                'I HAVE ALREADY PAID • UPLOAD SCREENSHOT',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBillItemRow(String title, int amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 12, color: CxColors.textPrimary),
        ),
        Text(
          '₹$amount',
          style: GoogleFonts.orbitron(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CxColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showUpiAppSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: CxColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CxSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CHOOSE UPI PAYMENT APP',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CxColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Payable: ₹450 to CodeXa Agency',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: CxColors.textSecondary,
                ),
              ),
              const SizedBox(height: CxSpacing.lg),
              _buildUpiOption(
                'PhonePe',
                Icons.account_balance_wallet,
                const Color(0xFF5F259F),
                () {
                  Navigator.pop(ctx);
                  _startUpiPayment(context, 'PHONEPE');
                },
              ),
              const SizedBox(height: 8),
              _buildUpiOption(
                'Google Pay',
                Icons.payment,
                const Color(0xFF4285F4),
                () {
                  Navigator.pop(ctx);
                  _startUpiPayment(context, 'GPAY');
                },
              ),
              const SizedBox(height: 8),
              _buildUpiOption(
                'Paytm',
                Icons.account_balance,
                const Color(0xFF00BAF2),
                () {
                  Navigator.pop(ctx);
                  _startUpiPayment(context, 'PAYTM');
                },
              ),
              const SizedBox(height: 8),
              _buildUpiOption(
                'Other UPI App / Chooser',
                Icons.qr_code,
                CxColors.brightRed,
                () {
                  Navigator.pop(ctx);
                  _startUpiPayment(context, 'OTHER_UPI');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpiOption(
    String name,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CxColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CxColors.borderSubtle),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CxColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 13,
              color: CxColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _openQrPaymentModal(BuildContext context, Map<String, dynamic> payment) {
    final refId = payment['referenceId'] ?? 'CXA-PAY-450';
    final amount = payment['totalAmount'] ?? 450;
    final upiId = payment['settings']?['defaultUpiId'] ?? 'shaikashu33@fam';
    final receiverName =
        payment['settings']?['receiverName'] ?? 'CodeXa Agency';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CxColors.cardElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'SCAN QR TO PAY',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: CxColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2, size: 160, color: Colors.black),
                  const SizedBox(height: 6),
                  Text(
                    '₹$amount • $receiverName',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CxSpacing.md),
            Text(
              'UPI ID: $upiId',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: CxColors.textSecondary,
              ),
            ),
            Text(
              'Ref: $refId',
              style: GoogleFonts.inter(fontSize: 11, color: CxColors.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: CxColors.textMuted),
            ),
          ),
          CxButton(
            label: 'UPLOAD PROOF',
            width: 140,
            onPressed: () {
              Navigator.pop(ctx);
              _openScreenshotPickerSheet(context, payment['id']);
            },
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PAYMENT REVIEW DETAIL SHEET COMPONENT (WITH PINCH-TO-ZOOM PROOF VIEWER)
// ═════════════════════════════════════════════════════════════════════════════
class _PaymentReviewSheetContent extends StatefulWidget {
  final ManagementPaymentItem item;
  final bool canApprove;
  final bool canApproveCash;
  final Future<void> Function(String? notes, bool confirmation) onApprove;
  final Future<void> Function(String reason) onReject;
  final Future<void> Function() onConfirmCash;

  const _PaymentReviewSheetContent({
    required this.item,
    required this.canApprove,
    required this.canApproveCash,
    required this.onApprove,
    required this.onReject,
    required this.onConfirmCash,
  });

  @override
  State<_PaymentReviewSheetContent> createState() =>
      _PaymentReviewSheetContentState();
}

class _PaymentReviewSheetContentState
    extends State<_PaymentReviewSheetContent> {
  bool _confirmedReceipt = false;
  final _notesController = TextEditingController();
  bool _isSubmitting = false;
  String? _sessionToken;

  @override
  void initState() {
    super.initState();
    _loadSessionToken();
  }

  Future<void> _loadSessionToken() async {
    final token = await CxStorage.getToken();
    if (mounted) setState(() => _sessionToken = token);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _openFullScreenViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
          title: Text(
            'PAYMENT PROOF SCREENSHOT',
            style: GoogleFonts.orbitron(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 5.0,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                child: Text(
                  'Unable to load full screenshot',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRejectionDialog(BuildContext context) {
    String selectedReason = 'Payment not received in account';
    final reasonController = TextEditingController();

    final reasons = [
      'Payment not received in account',
      'Screenshot unclear / truncated',
      'Wrong receiving account or UPI ID',
      'Unable to identify transaction',
      'Duplicate proof submitted',
      'Other',
    ];

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: CxColors.cardElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'REJECT PAYMENT PROOF',
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: CxColors.brightRed,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select the rejection reason provided to the intern:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: CxColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...reasons.map(
                  (r) => RadioListTile<String>(
                    title: Text(
                      r,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    value: r,
                    groupValue: selectedReason,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: CxColors.brightRed,
                    onChanged: (val) => setDlgState(
                      () => selectedReason = val ?? selectedReason,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CxTextField(
                  label: 'ADDITIONAL NOTES (OPTIONAL)',
                  hint: 'Explain discrepancy...',
                  controller: reasonController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text(
                'CANCEL',
                style: TextStyle(color: CxColors.textMuted),
              ),
            ),
            CxButton(
              label: 'CONFIRM REJECT',
              backgroundColor: CxColors.crimson,
              width: 140,
              onPressed: () {
                final fullReason = reasonController.text.trim().isNotEmpty
                    ? '$selectedReason: ${reasonController.text.trim()}'
                    : selectedReason;
                Navigator.pop(dlgCtx);
                widget.onReject(fullReason);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isPending =
        item.status == 'PENDING_APPROVAL' ||
        item.status == 'PENDING_VERIFICATION' ||
        item.status == 'VERIFYING' ||
        item.status == 'REVIEW_REQUIRED';
    final isCashPending = item.cashStatus == 'PENDING_CASH_APPROVAL';

    // Build signed proof image URL
    final proofUrl = item.id.isNotEmpty
        ? '${CxApiClient().baseUrl}/api/payments/${item.id}/proof-image${_sessionToken != null ? '?token=$_sessionToken' : ''}'
        : null;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          controller: scrollController,
          children: [
            // Center drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT APPROVAL REVIEW',
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CxColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Independent Settlement Verification',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: CxColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${item.amount.toInt()}',
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CxColors.brightRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: CxColors.borderSubtle),
            const SizedBox(height: 10),

            // Intern details card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CxColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CxColors.borderSubtle),
              ),
              child: Column(
                children: [
                  _buildReviewRow('Intern Name', item.userName),
                  _buildReviewRow('Intern ID', item.internId),
                  _buildReviewRow('Domain', item.domain),
                  _buildReviewRow('Payment Ref', item.referenceId),
                  _buildReviewRow('Method', item.paymentMethod),
                  _buildReviewRow('Status', item.status),
                  if (item.submittedAt != null)
                    _buildReviewRow(
                      'Submitted At',
                      item.submittedAt!.toLocal().toString().split('.')[0],
                    ),
                  if (item.verifiedByName != null)
                    _buildReviewRow('Verified By', item.verifiedByName!),
                  if (item.rejectionReason != null)
                    _buildReviewRow('Rejection Reason', item.rejectionReason!),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment proof screenshot viewer
            Text(
              'PAYMENT SCREENSHOT PROOF',
              style: GoogleFonts.orbitron(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CxColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),

            if (proofUrl != null) ...[
              Container(
                height: 280,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CxColors.borderSubtle),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.network(
                          proofUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: CxColors.brightRed,
                              ),
                            );
                          },
                          errorBuilder: (ctx, err, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.broken_image_outlined,
                                    color: CxColors.textMuted,
                                    size: 36,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Screenshot not accessible or cash workflow',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: CxColors.textMuted,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.fullscreen, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                        ),
                        onPressed: () =>
                            _openFullScreenViewer(context, proofUrl),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pinch to zoom or tap fullscreen to inspect UTR and timestamps.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: CxColors.textMuted,
                ),
              ),
            ] else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CxColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'No uploaded screenshot on record (e.g. Cash payment request).',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: CxColors.textMuted,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Management Action Buttons (Founder / Co-Founder only)
            if (widget.canApproveCash && isCashPending) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFB8500).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFB8500).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.handshake_outlined,
                      color: Color(0xFFFB8500),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Intern requested Cash Payment. Only confirm after actual physical receipt of ₹450.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CxButton(
                label: 'CONFIRM CASH RECEIVED',
                backgroundColor: CxColors.success,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        await widget.onConfirmCash();
                      },
              ),
            ] else if (widget.canApprove && isPending) ...[
              // Mandatory independent confirmation checkbox
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _confirmedReceipt
                      ? CxColors.success.withOpacity(0.12)
                      : CxColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _confirmedReceipt
                        ? CxColors.success
                        : CxColors.borderSubtle,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _confirmedReceipt,
                      activeColor: CxColors.success,
                      onChanged: (val) =>
                          setState(() => _confirmedReceipt = val ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'I have independently confirmed that ₹450 was actually received in the official CodeXa receiving account.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              CxTextField(
                label: 'REVIEWER NOTES (OPTIONAL)',
                hint: 'e.g. Verified in receiving account statement',
                controller: _notesController,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CxButton(
                      label: 'CONFIRM & APPROVE',
                      backgroundColor: CxColors.success,
                      isLoading: _isSubmitting,
                      onPressed: (!_confirmedReceipt || _isSubmitting)
                          ? null
                          : () async {
                              setState(() => _isSubmitting = true);
                              await widget.onApprove(
                                _notesController.text.trim(),
                                true,
                              );
                            },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CxButton(
                      label: 'REJECT PROOF',
                      backgroundColor: CxColors.crimson,
                      isLoading: _isSubmitting,
                      onPressed: _isSubmitting
                          ? null
                          : () => _showRejectionDialog(context),
                    ),
                  ),
                ],
              ),
            ] else if (!widget.canApprove) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CxColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'READ-ONLY VIEW (Review actions restricted to Founder/Co-Founder)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: CxColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: CxColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CxColors.textPrimary,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
