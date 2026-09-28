import 'certificate_field.dart';
import 'generated_certificate.dart';
import 'participant.dart';

class CertificateProject {
  CertificateProject({required this.id, required this.name, required this.createdAt, required this.updatedAt, this.templatePath, this.templateName, this.templateWidth, this.templateHeight, this.participants = const [], this.fields = const [], this.certificates = const [], this.columnMapping = const {}, this.emailSubject = 'Your certificate', this.emailBody = 'Dear {{NAME}},\n\nPlease find your certificate attached.', this.certificatePrefix = 'CERT'});
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? templatePath;
  final String? templateName;
  final int? templateWidth;
  final int? templateHeight;
  final List<Participant> participants;
  final List<CertificateField> fields;
  final List<GeneratedCertificate> certificates;
  final Map<String, String> columnMapping;
  final String emailSubject;
  final String emailBody;
  final String certificatePrefix;

  int get generatedCount => certificates.where((item) => item.filePath != null).length;
  int get sentCount => certificates.where((item) => item.emailStatus == DeliveryStatus.sent).length;
  int get failedCount => certificates.where((item) => item.generationError != null || item.emailStatus == DeliveryStatus.failed).length;

  CertificateProject copyWith({String? name, DateTime? updatedAt, String? templatePath, String? templateName, int? templateWidth, int? templateHeight, List<Participant>? participants, List<CertificateField>? fields, List<GeneratedCertificate>? certificates, Map<String, String>? columnMapping, String? emailSubject, String? emailBody, String? certificatePrefix, bool clearTemplate = false}) => CertificateProject(
        id: id,
        name: name ?? this.name,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        templatePath: clearTemplate ? null : templatePath ?? this.templatePath,
        templateName: clearTemplate ? null : templateName ?? this.templateName,
        templateWidth: clearTemplate ? null : templateWidth ?? this.templateWidth,
        templateHeight: clearTemplate ? null : templateHeight ?? this.templateHeight,
        participants: participants ?? this.participants,
        fields: fields ?? this.fields,
        certificates: certificates ?? this.certificates,
        columnMapping: columnMapping ?? this.columnMapping,
        emailSubject: emailSubject ?? this.emailSubject,
        emailBody: emailBody ?? this.emailBody,
        certificatePrefix: certificatePrefix ?? this.certificatePrefix,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String(), 'updatedAt': updatedAt.toIso8601String(), 'templatePath': templatePath, 'templateName': templateName, 'templateWidth': templateWidth, 'templateHeight': templateHeight, 'participants': participants.map((item) => item.toJson()).toList(), 'fields': fields.map((item) => item.toJson()).toList(), 'certificates': certificates.map((item) => item.toJson()).toList(), 'columnMapping': columnMapping, 'emailSubject': emailSubject, 'emailBody': emailBody, 'certificatePrefix': certificatePrefix};

  factory CertificateProject.fromJson(Map<String, dynamic> json) => CertificateProject(
        id: json['id'] as String,
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        templatePath: json['templatePath'] as String?,
        templateName: json['templateName'] as String?,
        templateWidth: json['templateWidth'] as int?,
        templateHeight: json['templateHeight'] as int?,
        participants: (json['participants'] as List<dynamic>? ?? []).map((item) => Participant.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
        fields: (json['fields'] as List<dynamic>? ?? []).map((item) => CertificateField.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
        certificates: (json['certificates'] as List<dynamic>? ?? []).map((item) => GeneratedCertificate.fromJson(Map<String, dynamic>.from(item as Map))).toList(),
        columnMapping: Map<String, String>.from(json['columnMapping'] as Map? ?? {}),
        emailSubject: json['emailSubject'] as String? ?? 'Your certificate',
        emailBody: json['emailBody'] as String? ?? '',
        certificatePrefix: json['certificatePrefix'] as String? ?? 'CERT',
      );
}