class PlacementDriveModel {
  final String id;
  final String companyName;
  final String? companyLogoUrl;
  final String roleTitle;
  final String jobDescription;
  final String location;
  final String? ctcBreakdown;
  final String? stipendAmount;
  final List<String> targetBatches;
  final List<String> eligibleBranches;
  final double minCgpa;
  final int maxActiveBacklogs;
  final double minAttendancePercent;
  final String driveDate;
  final String registrationDeadline;
  final String venue;
  final String? selectionProcess;
  final String status;
  final bool isEligible;
  final List<String> ineligibilityReasons;
  final bool hasApplied;

  PlacementDriveModel({
    required this.id,
    required this.companyName,
    this.companyLogoUrl,
    required this.roleTitle,
    required this.jobDescription,
    required this.location,
    this.ctcBreakdown,
    this.stipendAmount,
    required this.targetBatches,
    required this.eligibleBranches,
    required this.minCgpa,
    required this.maxActiveBacklogs,
    required this.minAttendancePercent,
    required this.driveDate,
    required this.registrationDeadline,
    required this.venue,
    this.selectionProcess,
    required this.status,
    this.isEligible = true,
    this.ineligibilityReasons = const [],
    this.hasApplied = false,
  });

  factory PlacementDriveModel.fromJson(Map<String, dynamic> json) {
    return PlacementDriveModel(
      id: json['id']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      companyLogoUrl: json['companyLogoUrl']?.toString(),
      roleTitle: json['roleTitle']?.toString() ?? '',
      jobDescription: json['jobDescription']?.toString() ?? '',
      location: json['location']?.toString() ?? 'On-Campus',
      ctcBreakdown: json['ctcBreakdown']?.toString(),
      stipendAmount: json['stipendAmount']?.toString(),
      targetBatches: (json['targetBatches'] as List?)?.map((e) => e.toString()).toList() ?? [],
      eligibleBranches: (json['eligibleBranches'] as List?)?.map((e) => e.toString()).toList() ?? [],
      minCgpa: (json['minCgpa'] as num?)?.toDouble() ?? 0.0,
      maxActiveBacklogs: (json['maxActiveBacklogs'] as num?)?.toInt() ?? 0,
      minAttendancePercent: (json['minAttendancePercent'] as num?)?.toDouble() ?? 75.0,
      driveDate: json['driveDate']?.toString() ?? '',
      registrationDeadline: json['registrationDeadline']?.toString() ?? '',
      venue: json['venue']?.toString() ?? 'Placement Hall',
      selectionProcess: json['selectionProcess']?.toString(),
      status: json['status']?.toString() ?? 'UPCOMING',
      isEligible: json['isEligible'] == true,
      ineligibilityReasons: (json['ineligibilityReasons'] as List?)?.map((e) => e.toString()).toList() ?? [],
      hasApplied: json['hasApplied'] == true,
    );
  }
}

class OpportunityListingModel {
  final String id;
  final String sourceType;
  final String title;
  final String companyName;
  final String? companyLogoUrl;
  final String location;
  final String workMode;
  final String employmentType;
  final String experienceLevel;
  final List<String> skills;
  final String? salaryRange;
  final String description;
  final String applyUrl;
  final String? expiresAt;
  final String status;
  final bool isTracked;

  OpportunityListingModel({
    required this.id,
    required this.sourceType,
    required this.title,
    required this.companyName,
    this.companyLogoUrl,
    required this.location,
    required this.workMode,
    required this.employmentType,
    required this.experienceLevel,
    required this.skills,
    this.salaryRange,
    required this.description,
    required this.applyUrl,
    this.expiresAt,
    required this.status,
    this.isTracked = false,
  });

  factory OpportunityListingModel.fromJson(Map<String, dynamic> json) {
    return OpportunityListingModel(
      id: json['id']?.toString() ?? '',
      sourceType: json['sourceType']?.toString() ?? 'EXTERNAL',
      title: json['title']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? '',
      companyLogoUrl: json['companyLogoUrl']?.toString(),
      location: json['location']?.toString() ?? 'Remote',
      workMode: json['workMode']?.toString() ?? 'REMOTE',
      employmentType: json['employmentType']?.toString() ?? 'INTERNSHIP',
      experienceLevel: json['experienceLevel']?.toString() ?? 'INTERN',
      skills: (json['skills'] as List?)?.map((e) => e.toString()).toList() ?? [],
      salaryRange: json['salaryRange']?.toString(),
      description: json['description']?.toString() ?? '',
      applyUrl: json['applyUrl']?.toString() ?? '',
      expiresAt: json['expiresAt']?.toString(),
      status: json['status']?.toString() ?? 'ACTIVE',
      isTracked: json['isTracked'] == true,
    );
  }
}

class PlacementApplicationModel {
  final String id;
  final String studentId;
  final String? driveId;
  final String? opportunityId;
  final String applicationType;
  final String? resumeUrl;
  final String status;
  final String? adminNotes;
  final String appliedAt;
  final PlacementDriveModel? drive;
  final OpportunityListingModel? opportunity;

  PlacementApplicationModel({
    required this.id,
    required this.studentId,
    this.driveId,
    this.opportunityId,
    required this.applicationType,
    this.resumeUrl,
    required this.status,
    this.adminNotes,
    required this.appliedAt,
    this.drive,
    this.opportunity,
  });

  factory PlacementApplicationModel.fromJson(Map<String, dynamic> json) {
    return PlacementApplicationModel(
      id: json['id']?.toString() ?? '',
      studentId: json['studentId']?.toString() ?? '',
      driveId: json['driveId']?.toString(),
      opportunityId: json['opportunityId']?.toString(),
      applicationType: json['applicationType']?.toString() ?? 'ON_CAMPUS',
      resumeUrl: json['resumeUrl']?.toString(),
      status: json['status']?.toString() ?? 'APPLIED',
      adminNotes: json['adminNotes']?.toString(),
      appliedAt: json['appliedAt']?.toString() ?? '',
      drive: json['drive'] != null ? PlacementDriveModel.fromJson(json['drive']) : null,
      opportunity: json['opportunity'] != null ? OpportunityListingModel.fromJson(json['opportunity']) : null,
    );
  }
}

class ProjectModel {
  final String id;
  final String title;
  final String description;
  final List<String> techStack;
  final String? githubUrl;
  final String? liveUrl;
  final List<String> highlights;

  ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.techStack,
    this.githubUrl,
    this.liveUrl,
    this.highlights = const [],
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      techStack: (json['techStack'] as List?)?.map((e) => e.toString()).toList() ?? [],
      githubUrl: json['githubUrl']?.toString(),
      liveUrl: json['liveUrl']?.toString(),
      highlights: (json['highlights'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'techStack': techStack,
      'githubUrl': githubUrl,
      'liveUrl': liveUrl,
      'highlights': highlights,
    };
  }
}

class CertificationModel {
  final String id;
  final String title;
  final String issuer;
  final String? issueDate;
  final String? credentialUrl;
  final String? credentialId;

  CertificationModel({
    required this.id,
    required this.title,
    required this.issuer,
    this.issueDate,
    this.credentialUrl,
    this.credentialId,
  });

  factory CertificationModel.fromJson(Map<String, dynamic> json) {
    return CertificationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      issuer: json['issuer']?.toString() ?? '',
      issueDate: json['issueDate']?.toString(),
      credentialUrl: json['credentialUrl']?.toString(),
      credentialId: json['credentialId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'issuer': issuer,
      'issueDate': issueDate,
      'credentialUrl': credentialUrl,
      'credentialId': credentialId,
    };
  }
}

class AcademicRecordModel {
  final double tenthPercentage;
  final double twelfthPercentage;
  final String currentDegree;
  final double cgpa;
  final List<Map<String, dynamic>> semesters;

  AcademicRecordModel({
    this.tenthPercentage = 0.0,
    this.twelfthPercentage = 0.0,
    this.currentDegree = 'B.Tech',
    this.cgpa = 0.0,
    this.semesters = const [],
  });

  factory AcademicRecordModel.fromJson(Map<String, dynamic> json) {
    return AcademicRecordModel(
      tenthPercentage: (json['tenthPercentage'] as num?)?.toDouble() ?? 0.0,
      twelfthPercentage: (json['twelfthPercentage'] as num?)?.toDouble() ?? 0.0,
      currentDegree: json['currentDegree']?.toString() ?? 'B.Tech',
      cgpa: (json['cgpa'] as num?)?.toDouble() ?? 0.0,
      semesters: (json['semesters'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tenthPercentage': tenthPercentage,
      'twelfthPercentage': twelfthPercentage,
      'currentDegree': currentDegree,
      'cgpa': cgpa,
      'semesters': semesters,
    };
  }
}

class StudentCareerProfileModel {
  final String studentId;
  final String targetRole;
  final String bio;
  final List<String> skills;
  final List<ProjectModel> projects;
  final List<CertificationModel> certifications;
  final AcademicRecordModel? academicRecords;
  final String? resumeUrl;
  final String? resumeFilename;
  final int atsScore;
  final Map<String, dynamic> atsFeedback;
  final String? githubUrl;
  final String? linkedinUrl;
  final String? portfolioUrl;
  final double cgpa;
  final int activeBacklogs;
  final List<String> preferredRoles;

  StudentCareerProfileModel({
    required this.studentId,
    this.targetRole = 'Software Engineer',
    this.bio = '',
    required this.skills,
    this.projects = const [],
    this.certifications = const [],
    this.academicRecords,
    this.resumeUrl,
    this.resumeFilename,
    required this.atsScore,
    required this.atsFeedback,
    this.githubUrl,
    this.linkedinUrl,
    this.portfolioUrl,
    required this.cgpa,
    required this.activeBacklogs,
    required this.preferredRoles,
  });

  factory StudentCareerProfileModel.fromJson(Map<String, dynamic> json) {
    return StudentCareerProfileModel(
      studentId: json['studentId']?.toString() ?? '',
      targetRole: json['targetRole']?.toString() ?? 'Software Engineer',
      bio: json['bio']?.toString() ?? '',
      skills: (json['skills'] as List?)?.map((e) => e.toString()).toList() ?? [],
      projects: (json['projects'] as List?)?.map((e) => ProjectModel.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? [],
      certifications: (json['certifications'] as List?)?.map((e) => CertificationModel.fromJson(Map<String, dynamic>.from(e as Map))).toList() ?? [],
      academicRecords: json['academicRecords'] != null && json['academicRecords'] is Map
          ? AcademicRecordModel.fromJson(Map<String, dynamic>.from(json['academicRecords'] as Map))
          : null,
      resumeUrl: json['resumeUrl']?.toString(),
      resumeFilename: json['resumeFilename']?.toString(),
      atsScore: (json['atsScore'] as num?)?.toInt() ?? 0,
      atsFeedback: json['atsFeedback'] as Map<String, dynamic>? ?? {},
      githubUrl: json['githubUrl']?.toString(),
      linkedinUrl: json['linkedinUrl']?.toString(),
      portfolioUrl: json['portfolioUrl']?.toString(),
      cgpa: (json['cgpa'] as num?)?.toDouble() ?? 8.0,
      activeBacklogs: (json['activeBacklogs'] as num?)?.toInt() ?? 0,
      preferredRoles: (json['preferredRoles'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class CareerResourceModel {
  final String id;
  final String track;
  final String title;
  final String description;
  final String level;
  final String estimatedHours;
  final String category;
  final List<String> topics;
  final String url;
  bool isBookmarked;

  CareerResourceModel({
    required this.id,
    required this.track,
    required this.title,
    required this.description,
    required this.level,
    required this.estimatedHours,
    required this.category,
    required this.topics,
    required this.url,
    this.isBookmarked = false,
  });

  factory CareerResourceModel.fromJson(Map<String, dynamic> json) {
    return CareerResourceModel(
      id: json['id']?.toString() ?? '',
      track: json['track']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      level: json['level']?.toString() ?? 'All Levels',
      estimatedHours: json['estimatedHours']?.toString() ?? '4 hrs',
      category: json['category']?.toString() ?? 'general',
      topics: (json['topics'] as List?)?.map((e) => e.toString()).toList() ?? [],
      url: json['url']?.toString() ?? '',
      isBookmarked: json['isBookmarked'] == true,
    );
  }
}

class TechNewsModel {
  final String id;
  final String title;
  final String summary;
  final String category;
  final String source;
  final String publishedAt;
  final String readTime;
  final String url;
  final List<String> tags;

  TechNewsModel({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.source,
    required this.publishedAt,
    required this.readTime,
    required this.url,
    required this.tags,
  });

  factory TechNewsModel.fromJson(Map<String, dynamic> json) {
    return TechNewsModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
      source: json['source']?.toString() ?? 'Tech News',
      publishedAt: json['publishedAt']?.toString() ?? '',
      readTime: json['readTime']?.toString() ?? '3 min read',
      url: json['url']?.toString() ?? '',
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class CareerHubSummaryModel {
  final int activeDrivesCount;
  final int externalOpportunitiesCount;
  final int studentAtsScore;
  final int applicationsCount;
  final PlacementDriveModel? topUpcomingDrive;
  final bool hasResume;

  CareerHubSummaryModel({
    required this.activeDrivesCount,
    required this.externalOpportunitiesCount,
    required this.studentAtsScore,
    required this.applicationsCount,
    this.topUpcomingDrive,
    required this.hasResume,
  });

  factory CareerHubSummaryModel.fromJson(Map<String, dynamic> json) {
    return CareerHubSummaryModel(
      activeDrivesCount: (json['activeDrivesCount'] as num?)?.toInt() ?? 0,
      externalOpportunitiesCount: (json['externalOpportunitiesCount'] as num?)?.toInt() ?? 0,
      studentAtsScore: (json['studentAtsScore'] as num?)?.toInt() ?? 75,
      applicationsCount: (json['applicationsCount'] as num?)?.toInt() ?? 0,
      topUpcomingDrive: json['topUpcomingDrive'] != null
          ? PlacementDriveModel.fromJson(json['topUpcomingDrive'])
          : null,
      hasResume: json['hasResume'] == true,
    );
  }
}
