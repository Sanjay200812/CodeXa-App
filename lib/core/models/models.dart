/// Core CodeXa User Model
class UserModel {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String? orgRole;
  final String? department;
  final String? designation;
  final String? employeeId;
  final String? profileMediaUrl;
  final String? bio;
  final List<String> skills;
  final String? githubUrl;
  final String? linkedinUrl;
  final String? portfolioUrl;
  final bool mustChangePassword;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.orgRole,
    this.department,
    this.designation,
    this.employeeId,
    this.profileMediaUrl,
    this.bio,
    this.skills = const [],
    this.githubUrl,
    this.linkedinUrl,
    this.portfolioUrl,
    this.mustChangePassword = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? json['username'] ?? '',
      role: (json['role'] ?? 'EMPLOYEE').toString().toUpperCase(),
      orgRole: json['orgRole'],
      department: json['department'],
      designation: json['designation'],
      employeeId: json['employeeId'],
      profileMediaUrl:
          json['profileMediaUrl'] ?? json['avatarUrl'] ?? json['mediaUrl'],
      bio: json['bio'],
      skills:
          (json['skills'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      githubUrl: json['githubUrl'],
      linkedinUrl: json['linkedinUrl'],
      portfolioUrl: json['portfolioUrl'],
      mustChangePassword: json['mustChangePassword'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'fullName': fullName,
    'role': role,
    'orgRole': orgRole,
    'department': department,
    'designation': designation,
    'employeeId': employeeId,
    'profileMediaUrl': profileMediaUrl,
    'bio': bio,
    'skills': skills,
    'githubUrl': githubUrl,
    'linkedinUrl': linkedinUrl,
    'portfolioUrl': portfolioUrl,
    'mustChangePassword': mustChangePassword,
  };
}

/// App Configuration Model
class AppConfigModel {
  final String appName;
  final String currentVersion;
  final String minimumVersion;
  final bool forceUpdate;
  final bool maintenanceMode;
  final String maintenanceMessage;

  AppConfigModel({
    required this.appName,
    required this.currentVersion,
    required this.minimumVersion,
    this.forceUpdate = false,
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      appName: json['appName'] ?? 'CodeXa',
      currentVersion: json['currentVersion'] ?? '1.0.0',
      minimumVersion: json['minimumVersion'] ?? '1.0.0',
      forceUpdate: json['forceUpdate'] ?? false,
      maintenanceMode: json['maintenanceMode'] ?? false,
      maintenanceMessage: json['maintenanceMessage'] ?? '',
    );
  }
}

/// Internship Details Model
class InternshipModel {
  final String internId;
  final String domain;
  final String duration;
  final String? startDate;
  final String? endDate;
  final int daysUntilStart;
  final String mentorName;
  final String status;
  final String stipend;
  final bool isPreStart;

  InternshipModel({
    required this.internId,
    required this.domain,
    required this.duration,
    this.startDate,
    this.endDate,
    required this.daysUntilStart,
    required this.mentorName,
    required this.status,
    required this.stipend,
    this.isPreStart = false,
  });

  factory InternshipModel.fromJson(Map<String, dynamic> json) {
    final startStr = json['startDate'];
    bool preStart = false;
    if (startStr != null) {
      final s = DateTime.tryParse(startStr);
      if (s != null && s.isAfter(DateTime.now())) {
        preStart = true;
      }
    }
    return InternshipModel(
      internId: json['internId'] ?? '',
      domain: json['domain'] ?? 'Full Stack Development',
      duration: json['duration'] ?? '3 Months',
      startDate: json['startDate'],
      endDate: json['endDate'],
      daysUntilStart: json['daysUntilStart'] ?? 0,
      mentorName: json['mentorName'] ?? 'Shaik Ashu (Founder)',
      status: json['status'] ?? 'ACTIVE',
      stipend: json['stipend'] ?? 'Not Assigned',
      isPreStart: json['isPreStart'] ?? preStart,
    );
  }
}

/// Operational Metrics for Higher-Authority Dashboards
class OperationalMetricsModel {
  final int activeEmployees;
  final int activeInterns;
  final int todayPresentCount;
  final int pendingLeaveCount;
  final int pendingCorrectionsCount;
  final int totalProjectsCount;

  OperationalMetricsModel({
    required this.activeEmployees,
    required this.activeInterns,
    required this.todayPresentCount,
    required this.pendingLeaveCount,
    required this.pendingCorrectionsCount,
    required this.totalProjectsCount,
  });

  factory OperationalMetricsModel.fromJson(Map<String, dynamic> json) {
    return OperationalMetricsModel(
      activeEmployees: json['activeEmployees'] ?? 0,
      activeInterns: json['activeInterns'] ?? 0,
      todayPresentCount: json['todayPresentCount'] ?? 0,
      pendingLeaveCount: json['pendingLeaveCount'] ?? 0,
      pendingCorrectionsCount: json['pendingCorrectionsCount'] ?? 0,
      totalProjectsCount: json['totalProjectsCount'] ?? 0,
    );
  }
}

/// Attendance State Model
class AttendanceStateModel {
  final String lifecycleStatus; // PRE_START | COMING_SOON | WINDOW_ACTIVE | WINDOW_CLOSED | COMPLETED
  final bool canMark;
  final bool isPreStart;
  final String? message;
  final String? startDate;
  final Map<String, dynamic>? currentWindow;
  final Map<String, dynamic>? todayRecord;
  final AttendanceStatsModel? stats;

  AttendanceStateModel({
    required this.lifecycleStatus,
    this.canMark = false,
    this.isPreStart = false,
    this.message,
    this.startDate,
    this.currentWindow,
    this.todayRecord,
    this.stats,
  });

  factory AttendanceStateModel.fromJson(Map<String, dynamic> json) {
    final status = json['lifecycleStatus'] ?? 'COMING_SOON';
    final preStart =
        json['isPreStart'] == true ||
        status == 'PRE_START' ||
        status == 'COMING_SOON';
    return AttendanceStateModel(
      lifecycleStatus: status,
      canMark: json['canMark'] ?? false,
      isPreStart: preStart,
      message: json['message'],
      startDate: json['startDate'],
      currentWindow: json['currentWindow'],
      todayRecord: json['todayRecord'],
      stats: json['stats'] != null
          ? AttendanceStatsModel.fromJson(json['stats'])
          : null,
    );
  }
}

class AttendanceStatsModel {
  final int month;
  final int year;
  final int present;
  final int absent;
  final int late;
  final int leave;
  final double attendanceRate;

  AttendanceStatsModel({
    required this.month,
    required this.year,
    required this.present,
    required this.absent,
    required this.late,
    required this.leave,
    required this.attendanceRate,
  });

  factory AttendanceStatsModel.fromJson(Map<String, dynamic> json) {
    return AttendanceStatsModel(
      month: json['month'] ?? 1,
      year: json['year'] ?? 2026,
      present: json['present'] ?? 0,
      absent: json['absent'] ?? 0,
      late: json['late'] ?? 0,
      leave: json['leave'] ?? 0,
      attendanceRate: (json['attendanceRate'] as num?)?.toDouble() ?? 100.0,
    );
  }
}

/// Task Item Model
class TaskItemModel {
  final String id;
  final String title;
  final String status; // TODO, IN_PROGRESS, BLOCKED, REVIEW, DONE
  final String priority;
  final String? dueDate;
  final String? assignee;

  TaskItemModel({
    required this.id,
    required this.title,
    required this.status,
    this.priority = 'Medium',
    this.dueDate,
    this.assignee,
  });

  factory TaskItemModel.fromJson(Map<String, dynamic> json) {
    return TaskItemModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      status: json['status'] ?? 'TODO',
      priority: json['priority'] ?? 'Medium',
      dueDate: json['dueDate'],
      assignee: json['assignee'],
    );
  }
}

/// Project Item Model
class ProjectItemModel {
  final String id;
  final String title;
  final String slug;
  final String myRole;
  final String status;
  final String category;
  final double progressPercentage;
  final String? shortDesc;
  final String? overview;
  final List<Map<String, dynamic>> collaborators;
  final List<TaskItemModel> tasks;

  ProjectItemModel({
    required this.id,
    required this.title,
    required this.slug,
    required this.myRole,
    required this.status,
    required this.category,
    required this.progressPercentage,
    this.shortDesc,
    this.overview,
    this.collaborators = const [],
    this.tasks = const [],
  });

  factory ProjectItemModel.fromJson(Map<String, dynamic> json) {
    return ProjectItemModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      myRole: json['myRole'] ?? json['roleTitle'] ?? 'Contributor',
      status: json['status'] ?? 'Active',
      category: json['category'] ?? 'Engineering',
      progressPercentage:
          (json['progressPercentage'] as num?)?.toDouble() ?? 75.0,
      shortDesc: json['shortDesc'],
      overview: json['overview'],
      collaborators:
          (json['collaborators'] as List<dynamic>?)
              ?.map((c) => Map<String, dynamic>.from(c))
              .toList() ??
          [],
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((t) => TaskItemModel.fromJson(t))
              .toList() ??
          [],
    );
  }
}

/// Payment Information Model
class PaymentInfoModel {
  final double totalAmount;
  final String currency;
  final String
  status; // PENDING_PAYMENT | PENDING_VERIFICATION | APPROVED | FAILED
  final String? referenceId;
  final String webCheckoutUrl;
  final List<Map<String, dynamic>> items;

  PaymentInfoModel({
    required this.totalAmount,
    required this.currency,
    required this.status,
    this.referenceId,
    required this.webCheckoutUrl,
    required this.items,
  });

  factory PaymentInfoModel.fromJson(Map<String, dynamic> json) {
    return PaymentInfoModel(
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 450.0,
      currency: json['currency'] ?? 'INR',
      status: json['status'] ?? 'PENDING_PAYMENT',
      referenceId: json['referenceId'],
      webCheckoutUrl:
          json['webCheckoutUrl'] ??
          json['paymentUrl'] ??
          'https://codxa-agency.online/dashboard/internship/payment',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => Map<String, dynamic>.from(i))
              .toList() ??
          [],
    );
  }
}

/// Payment Attempt Result Model
class PaymentAttemptModel {
  final String paymentId;
  final String attemptId;
  final String upiUrl;
  final String? payeeVpa;
  final String? payeeName;
  final double amount;
  final String? expiresAt;
  final String? referenceId;

  PaymentAttemptModel({
    required this.paymentId,
    required this.attemptId,
    required this.upiUrl,
    this.payeeVpa,
    this.payeeName,
    required this.amount,
    this.expiresAt,
    this.referenceId,
  });

  factory PaymentAttemptModel.fromJson(Map<String, dynamic> json) {
    return PaymentAttemptModel(
      paymentId: json['paymentId'] ?? '',
      attemptId: json['attemptId'] ?? '',
      upiUrl: json['upiUrl'] ?? json['universalUri'] ?? '',
      payeeVpa: json['payeeVpa'],
      payeeName: json['payeeName'],
      amount: (json['amount'] as num?)?.toDouble() ?? 450.0,
      expiresAt: json['expiresAt'],
      referenceId: json['referenceId'],
    );
  }
}

/// People / Directory Member Model
class PeopleModel {
  final String id;
  final String username;
  final String fullName;
  final String role;
  final String? department;
  final String? designation;
  final String? employeeId;
  final String? profileMediaUrl;
  final String? bio;
  final List<String> skills;
  final bool isActive;
  final Map<String, dynamic>? internship;

  PeopleModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.department,
    this.designation,
    this.employeeId,
    this.profileMediaUrl,
    this.bio,
    this.skills = const [],
    this.isActive = true,
    this.internship,
  });

  String? get internId =>
      (internship != null && internship!['internId'] != null)
      ? internship!['internId'].toString()
      : employeeId;
  String? get internshipDomain =>
      internship?['domain']?.toString() ?? department;
  String? get internshipDuration => internship?['duration']?.toString();
  int? get internshipMonths => internship?['months'] is int
      ? internship!['months']
      : (internship?['months'] != null
            ? int.tryParse(internship!['months'].toString())
            : null);
  String? get internshipStatus => internship?['status']?.toString();
  int? get internshipDaysRemaining => internship?['daysRemaining'] is int
      ? internship!['daysRemaining']
      : (internship?['daysRemaining'] != null
            ? int.tryParse(internship!['daysRemaining'].toString())
            : null);
  String? get internshipStartDate => internship?['startDate']?.toString();
  String? get internshipEndDate => internship?['endDate']?.toString();
  String? get mentorName => internship?['mentor']?.toString();

  factory PeopleModel.fromJson(Map<String, dynamic> json) {
    return PeopleModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      fullName: json['fullName'] ?? json['username'] ?? '',
      role: json['role'] ?? 'EMPLOYEE',
      department: json['department'],
      designation: json['designation'],
      employeeId: json['employeeId'],
      profileMediaUrl:
          json['profileMediaUrl'] ?? json['avatarUrl'] ?? json['mediaUrl'],
      bio: json['bio'],
      skills:
          (json['skills'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [],
      isActive: json['isActive'] ?? true,
      internship: json['internship'] is Map<String, dynamic>
          ? (json['internship'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Leave Request Model
class LeaveRequestModel {
  final String id;
  final String startDate;
  final String endDate;
  final String leaveType;
  final String reason;
  final String status;
  final String createdAt;

  LeaveRequestModel({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.leaveType,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] ?? '',
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
      leaveType: json['leaveType'] ?? 'CASUAL',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'PENDING',
      createdAt: json['createdAt'] ?? '',
    );
  }
}

/// Document Item Model
class DocumentItemModel {
  final String id;
  final String title;
  final String documentType;
  final String? documentNumber;
  final String? fileUrl;
  final String status;
  final String issuedAt;
  final String? verificationCode;

  DocumentItemModel({
    required this.id,
    required this.title,
    required this.documentType,
    this.documentNumber,
    this.fileUrl,
    required this.status,
    required this.issuedAt,
    this.verificationCode,
  });

  factory DocumentItemModel.fromJson(Map<String, dynamic> json) {
    return DocumentItemModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      documentType: json['documentType'] ?? 'DOCUMENT',
      documentNumber: json['documentNumber'],
      fileUrl: json['fileUrl'],
      status: json['status'] ?? 'ACTIVE',
      issuedAt: json['issuedAt'] ?? '',
      verificationCode: json['verificationCode'],
    );
  }
}

/// Unified Search Item Model
class SearchResultItem {
  final String category; // people | projects | posts | documents
  final String id;
  final String title;
  final String? subtitle;
  final String? meta;
  final String? route;

  SearchResultItem({
    required this.category,
    required this.id,
    required this.title,
    this.subtitle,
    this.meta,
    this.route,
  });

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      category: json['category'] ?? 'people',
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      meta: json['meta'],
      route: json['route'],
    );
  }
}

/// Aggregated Bootstrap Model
class BootstrapModel {
  final UserModel user;
  final String role;
  final List<String> permissions;
  final Map<String, dynamic> featureFlags;
  final InternshipModel? internship;
  final AttendanceStateModel attendance;
  final int unreadMessages;
  final int unreadNotifications;
  final List<ProjectItemModel> activeProjects;
  final OperationalMetricsModel? operationalMetrics;
  final PaymentInfoModel? payment;
  final AppConfigModel appConfig;
  final Map<String, dynamic>? announcement;

  BootstrapModel({
    required this.user,
    required this.role,
    required this.permissions,
    required this.featureFlags,
    this.internship,
    required this.attendance,
    required this.unreadMessages,
    required this.unreadNotifications,
    required this.activeProjects,
    this.operationalMetrics,
    this.payment,
    required this.appConfig,
    this.announcement,
  });

  factory BootstrapModel.fromJson(Map<String, dynamic> json) {
    return BootstrapModel(
      user: UserModel.fromJson(json['user'] ?? {}),
      role: (json['role'] ?? 'EMPLOYEE').toString().toUpperCase(),
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      featureFlags: Map<String, dynamic>.from(json['featureFlags'] ?? {}),
      internship: json['internship'] != null
          ? InternshipModel.fromJson(json['internship'])
          : null,
      attendance: AttendanceStateModel.fromJson(json['attendance'] ?? {}),
      unreadMessages: json['unreadMessages'] ?? 0,
      unreadNotifications: json['unreadNotifications'] ?? 0,
      activeProjects:
          (json['activeProjects'] as List<dynamic>?)
              ?.map((p) => ProjectItemModel.fromJson(p))
              .toList() ??
          [],
      operationalMetrics: json['operationalMetrics'] != null
          ? OperationalMetricsModel.fromJson(json['operationalMetrics'])
          : null,
      payment: json['payment'] != null
          ? PaymentInfoModel.fromJson(json['payment'])
          : null,
      appConfig: AppConfigModel.fromJson(json['appConfig'] ?? {}),
      announcement: json['announcement'],
    );
  }
}

/// Multi-Account Saved Profile
class SavedAccount {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String? orgRole;
  final String? department;
  final String? profileMediaUrl;
  final String accessToken;
  final DateTime lastActive;

  SavedAccount({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.orgRole,
    this.department,
    this.profileMediaUrl,
    required this.accessToken,
    required this.lastActive,
  });

  factory SavedAccount.fromUserAndToken(UserModel user, String token) {
    return SavedAccount(
      id: user.id,
      username: user.username,
      email: user.email,
      fullName: user.fullName,
      role: user.role,
      orgRole: user.orgRole,
      department: user.department,
      profileMediaUrl: user.profileMediaUrl,
      accessToken: token,
      lastActive: DateTime.now(),
    );
  }

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    return SavedAccount(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      role: json['role'] ?? 'EMPLOYEE',
      orgRole: json['orgRole'],
      department: json['department'],
      profileMediaUrl:
          json['profileMediaUrl'] ?? json['avatarUrl'] ?? json['mediaUrl'],
      accessToken: json['accessToken'] ?? '',
      lastActive: json['lastActive'] != null
          ? DateTime.tryParse(json['lastActive']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'email': email,
    'fullName': fullName,
    'role': role,
    'orgRole': orgRole,
    'department': department,
    'profileMediaUrl': profileMediaUrl,
    'accessToken': accessToken,
    'lastActive': lastActive.toIso8601String(),
  };
}

/// Workspace Stories Model
class StoryItemModel {
  final String id;
  final String type; // TEXT | IMAGE | VIDEO | PROJECT_UPDATE | ANNOUNCEMENT
  final String caption;
  final String? mediaUrl;
  final DateTime createdAt;
  final DateTime expiresAt;

  StoryItemModel({
    required this.id,
    required this.type,
    required this.caption,
    this.mediaUrl,
    required this.createdAt,
    required this.expiresAt,
  });

  factory StoryItemModel.fromJson(Map<String, dynamic> json) {
    return StoryItemModel(
      id: json['id'] ?? '',
      type: (json['type'] ?? 'TEXT').toString().toUpperCase(),
      caption: json['caption'] ?? '',
      mediaUrl: json['mediaUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }
}

class StoryGroupModel {
  final String authorId;
  final String authorName;
  final String username;
  final String? avatarUrl;
  final String role;
  final bool isOwnStory;
  final bool hasUnseen;
  final List<StoryItemModel> items;

  StoryGroupModel({
    required this.authorId,
    required this.authorName,
    required this.username,
    this.avatarUrl,
    required this.role,
    this.isOwnStory = false,
    this.hasUnseen = true,
    required this.items,
  });

  factory StoryGroupModel.fromJson(Map<String, dynamic> json) {
    return StoryGroupModel(
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? json['username'] ?? 'Teammate',
      username: json['username'] ?? '',
      avatarUrl: json['avatarUrl'],
      role: json['role'] ?? 'TEAM_MEMBER',
      isOwnStory: json['isOwnStory'] ?? false,
      hasUnseen: json['hasUnseen'] ?? true,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((item) => StoryItemModel.fromJson(item))
              .toList() ??
          [],
    );
  }
}

/// Management Payment Record
class ManagementPaymentItem {
  final String id;
  final String referenceId;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userPfp;
  final String internId;
  final String domain;
  final double amount;
  final String currency;
  final String status;
  final String paymentMethod;
  final String cashStatus;
  final String? utrNumber;
  final String? proofImageUrl;
  final DateTime? paymentDate;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final String? verifiedByName;
  final String? rejectionReason;
  final DateTime createdAt;
  final Map<String, dynamic>? latestAttempt;

  ManagementPaymentItem({
    required this.id,
    required this.referenceId,
    required this.userId,
    required this.userName,
    this.userEmail,
    this.userPfp,
    required this.internId,
    required this.domain,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    required this.cashStatus,
    this.utrNumber,
    this.proofImageUrl,
    this.paymentDate,
    this.submittedAt,
    this.verifiedAt,
    this.verifiedByName,
    this.rejectionReason,
    required this.createdAt,
    this.latestAttempt,
  });

  factory ManagementPaymentItem.fromJson(Map<String, dynamic> json) {
    return ManagementPaymentItem(
      id: json['id'] ?? '',
      referenceId: json['referenceId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Intern',
      userEmail: json['userEmail'],
      userPfp: json['userPfp'],
      internId: json['internId'] ?? 'CXA-INT-2026',
      domain: json['domain'] ?? 'Engineering',
      amount: (json['amount'] as num?)?.toDouble() ?? 450.0,
      currency: json['currency'] ?? 'INR',
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      paymentMethod: json['paymentMethod'] ?? 'UPI',
      cashStatus: json['cashStatus'] ?? 'NONE',
      utrNumber: json['utrNumber'],
      proofImageUrl:
          json['proofImageUrl'] ?? json['latestAttempt']?['proofImageUrl'],
      paymentDate: json['paymentDate'] != null
          ? DateTime.tryParse(json['paymentDate'])
          : null,
      submittedAt: json['submittedAt'] != null
          ? DateTime.tryParse(json['submittedAt'])
          : (json['paymentDate'] != null
                ? DateTime.tryParse(json['paymentDate'])
                : null),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.tryParse(json['verifiedAt'])
          : null,
      verifiedByName: json['verifiedByName'],
      rejectionReason: json['rejectionReason'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      latestAttempt: json['latestAttempt'] != null
          ? Map<String, dynamic>.from(json['latestAttempt'])
          : null,
    );
  }
}

class ManagementPaymentMetrics {
  final int totalInterns;
  final int paidCount;
  final int notPaidCount;
  final int pendingPaymentCount;
  final int upiVerifyingCount;
  final int cashPendingCount;
  final int failedCount;
  final double totalExpectedAmount;
  final double totalCollectedAmount;
  final double pendingAmount;

  ManagementPaymentMetrics({
    required this.totalInterns,
    required this.paidCount,
    required this.notPaidCount,
    required this.pendingPaymentCount,
    required this.upiVerifyingCount,
    required this.cashPendingCount,
    required this.failedCount,
    required this.totalExpectedAmount,
    required this.totalCollectedAmount,
    required this.pendingAmount,
  });

  factory ManagementPaymentMetrics.fromJson(Map<String, dynamic> json) {
    return ManagementPaymentMetrics(
      totalInterns: json['totalInterns'] ?? 0,
      paidCount: json['paidCount'] ?? 0,
      notPaidCount: json['notPaidCount'] ?? 0,
      pendingPaymentCount: json['pendingPaymentCount'] ?? 0,
      upiVerifyingCount: json['upiVerifyingCount'] ?? 0,
      cashPendingCount: json['cashPendingCount'] ?? 0,
      failedCount: json['failedCount'] ?? 0,
      totalExpectedAmount:
          (json['totalExpectedAmount'] as num?)?.toDouble() ?? 0.0,
      totalCollectedAmount:
          (json['totalCollectedAmount'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// My Work Task Model
class MyWorkTaskModel {
  final String id;
  final String projectId;
  final String projectTitle;
  final String title;
  final String description;
  final String status; // TODO | IN_PROGRESS | DONE | BLOCKED
  final String priority;
  final String? dueDate;
  final String assigneeName;

  MyWorkTaskModel({
    required this.id,
    required this.projectId,
    required this.projectTitle,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.assigneeName,
  });

  factory MyWorkTaskModel.fromJson(Map<String, dynamic> json) {
    return MyWorkTaskModel(
      id: json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      projectTitle: json['projectTitle'] ?? 'Assigned Project',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: (json['status'] ?? 'TODO').toString().toUpperCase(),
      priority: json['priority'] ?? 'MEDIUM',
      dueDate: json['dueDate'],
      assigneeName: json['assigneeName'] ?? 'Me',
    );
  }
}

/// Instagram-style 24-Hour Note Model
class NoteItemModel {
  final String id;
  final String text;
  final String authorId;
  final String authorName;
  final String authorRole;
  final String? authorAvatar;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isSelf;
  final bool hasLiked;
  final int likesCount;

  NoteItemModel({
    required this.id,
    required this.text,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    this.authorAvatar,
    required this.createdAt,
    required this.expiresAt,
    this.isSelf = false,
    this.hasLiked = false,
    this.likesCount = 0,
  });

  factory NoteItemModel.fromJson(Map<String, dynamic> json) {
    return NoteItemModel(
      id: json['id'] ?? '',
      text: json['text'] ?? '',
      authorId: json['authorId'] ?? json['userId'] ?? '',
      authorName: json['authorName'] ?? json['userName'] ?? 'CodeXa Member',
      authorRole: (json['authorRole'] ?? json['role'] ?? 'MEMBER')
          .toString()
          .toUpperCase(),
      authorAvatar: json['authorAvatar'] ?? json['avatarUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      expiresAt:
          DateTime.tryParse(json['expiresAt'] ?? '') ??
          DateTime.now().add(const Duration(hours: 24)),
      isSelf: json['isSelf'] == true,
      hasLiked: json['hasLiked'] == true,
      likesCount: json['likesCount'] is int
          ? json['likesCount']
          : (int.tryParse(json['likesCount']?.toString() ?? '0') ?? 0),
    );
  }
}

/// Remote Application Configuration & AppGate Model
class MobileRemoteConfigModel {
  final int configVersion;
  final bool maintenanceEnabled;
  final String maintenanceTitle;
  final String maintenanceMessage;
  final DateTime? maintenanceExpectedEndAt;
  final String minimumSupportedVersion;
  final String latestVersion;
  final bool forceUpdate;
  final bool optionalUpdate;
  final String updateUrl;
  final String? releaseNotes;
  final Map<String, dynamic> featureFlags;

  MobileRemoteConfigModel({
    required this.configVersion,
    required this.maintenanceEnabled,
    required this.maintenanceTitle,
    required this.maintenanceMessage,
    this.maintenanceExpectedEndAt,
    required this.minimumSupportedVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.optionalUpdate,
    required this.updateUrl,
    this.releaseNotes,
    this.featureFlags = const {},
  });

  factory MobileRemoteConfigModel.fromJson(Map<String, dynamic> json) {
    final maintenanceObj = json['maintenance'];
    final bool maintenanceEnabled;
    final String maintenanceTitle;
    final String maintenanceMessage;
    DateTime? expectedEndAt;

    if (maintenanceObj is Map<String, dynamic>) {
      maintenanceEnabled = maintenanceObj['enabled'] == true;
      maintenanceTitle = maintenanceObj['title'] ?? 'CODEXA MAINTENANCE';
      maintenanceMessage =
          maintenanceObj['message'] ??
          'CodeXa is temporarily unavailable while we make improvements.';
      if (maintenanceObj['expectedEndAt'] != null) {
        expectedEndAt = DateTime.tryParse(
          maintenanceObj['expectedEndAt'].toString(),
        );
      }
    } else {
      final appObj = json['app'] is Map<String, dynamic> ? json['app'] : null;
      maintenanceEnabled =
          (appObj != null && appObj['maintenance'] == true) ||
          json['maintenance'] == true;
      maintenanceTitle = 'CODEXA MAINTENANCE';
      maintenanceMessage =
          (appObj != null ? appObj['maintenanceMessage'] : null) ??
          json['message'] ??
          'CodeXa is temporarily unavailable while we make improvements.';
    }

    final versionObj = json['version'];
    final appObj = json['app'] is Map<String, dynamic> ? json['app'] : null;

    final String minVer = versionObj is Map
        ? (versionObj['minimumSupported'] ?? '1.0.0')
        : (appObj?['minimumVersion'] ?? '1.0.0');
    final String latestVer = versionObj is Map
        ? (versionObj['latest'] ?? '1.0.0')
        : (appObj?['version'] ?? '1.0.0');
    final bool forceUp = versionObj is Map
        ? (versionObj['forceUpdate'] == true)
        : (appObj?['forceUpdate'] == true);
    final bool optUp = versionObj is Map
        ? (versionObj['optionalUpdate'] == true)
        : (appObj?['softUpdate'] == true);
    final String updUrl =
        (versionObj is Map ? versionObj['updateUrl'] : null) ??
        (json['downloads'] is Map ? json['downloads']['apkUrl'] : null) ??
        'https://codxa-agency.online/downloads/CodeXa.apk';
    final String? relNotes = versionObj is Map
        ? versionObj['releaseNotes']
        : null;

    Map<String, dynamic> flags = {};
    if (json['featureFlags'] is Map) {
      flags = Map<String, dynamic>.from(json['featureFlags']);
    } else if (json['features'] is Map) {
      flags = Map<String, dynamic>.from(json['features']);
    }

    return MobileRemoteConfigModel(
      configVersion: json['configVersion'] ?? 100,
      maintenanceEnabled: maintenanceEnabled,
      maintenanceTitle: maintenanceTitle,
      maintenanceMessage: maintenanceMessage,
      maintenanceExpectedEndAt: expectedEndAt,
      minimumSupportedVersion: minVer,
      latestVersion: latestVer,
      forceUpdate: forceUp,
      optionalUpdate: optUp,
      updateUrl: updUrl,
      releaseNotes: relNotes,
      featureFlags: flags,
    );
  }
}
