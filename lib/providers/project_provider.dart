import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/certificate_field.dart';
import '../models/certificate_project.dart';
import '../models/generated_certificate.dart';
import '../models/participant.dart';
import '../services/brevo_email_service.dart';
import '../services/pdf_generator_service.dart';
import '../services/storage_service.dart';

class ProjectProvider extends ChangeNotifier {
  ProjectProvider(this._storage)
    : _pdfGenerator = PdfGeneratorService(_storage),
      _emailService = BrevoEmailService();
  final StorageService _storage;
  final PdfGeneratorService _pdfGenerator;
  final BrevoEmailService _emailService;
  final _uuid = const Uuid();
  List<CertificateProject> _projects = [];
  bool _isLoading = false;
  String? _error;
  List<CertificateProject> get projects => List.unmodifiable(_projects);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    try {
      _projects = await _storage.loadProjects();
      if (_projects.isEmpty) {
        final now = DateTime.now();
        _projects = [
          CertificateProject(
            id: _uuid.v4(),
            name: "DAKSHA'26",
            createdAt: now,
            updatedAt: now,
            participants: [
              Participant(
                id: _uuid.v4(),
                values: {
                  'NAME': 'Abhinav Pradeep',
                  'CLASS': 'CS-A',
                  'EMAIL': 'abhinav@example.com',
                  'EVENT': "DAKSHA'26",
                  'POSITION': '1st Place',
                },
              ),
              Participant(
                id: _uuid.v4(),
                values: {
                  'NAME': 'Rahul Kumar',
                  'CLASS': 'EC-B',
                  'EMAIL': 'rahul@example.com',
                  'EVENT': "DAKSHA'26",
                  'POSITION': 'Participant',
                },
              ),
              Participant(
                id: _uuid.v4(),
                values: {
                  'NAME': 'Anjali S',
                  'CLASS': 'EEE-A',
                  'EMAIL': 'anjali@example.com',
                  'EVENT': "DAKSHA'26",
                  'POSITION': 'Participant',
                },
              ),
            ],
          ),
        ];
        await _persist();
      }
      _error = null;
    } catch (_) {
      _error = 'Project data could not be loaded.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CertificateProject> createProject(String name) async {
    return createProjectWithTemplate(name: name);
  }

  Future<CertificateProject> createProjectWithTemplate({
    required String name,
    String? templatePath,
    String? templateName,
    int? templateWidth,
    int? templateHeight,
    List<CertificateField> fields = const [],
    String certificatePrefix = 'CERT',
  }) async {
    final now = DateTime.now();
    String? savedPath = templatePath;

    if (templatePath != null && templatePath.isNotEmpty) {
      try {
        savedPath = await _storage.storeFile(
          templatePath,
          'templates',
          templateName ??
              'template_${DateTime.now().millisecondsSinceEpoch}.png',
        );
      } catch (_) {
        // Fallback to original path if storing fails
      }
    }

    final project = CertificateProject(
      id: _uuid.v4(),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
      templatePath: savedPath,
      templateName: templateName,
      templateWidth: templateWidth,
      templateHeight: templateHeight,
      fields: fields,
      certificatePrefix: certificatePrefix,
    );
    _projects = [project, ..._projects];
    await _persist();
    notifyListeners();
    return project;
  }

  Future<String?> saveTemplateFile(String sourcePath, String name) async {
    try {
      return await _storage.storeFile(sourcePath, 'templates', name);
    } catch (_) {
      return sourcePath;
    }
  }

  Future<void> importParticipants(
    String projectId,
    List<Participant> newParticipants,
  ) async {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) return;

    final existing = _projects[index];
    final updatedParticipants = [...existing.participants, ...newParticipants];
    final updated = existing.copyWith(
      participants: updatedParticipants,
      updatedAt: DateTime.now(),
    );
    _projects[index] = updated;
    await _persist();
    notifyListeners();
  }

  Future<String?> generateSingleCertificate(
    String projectId,
    Participant participant,
  ) async {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = _projects[index];
    final certNumber = (project.certificates.length + 1).toString().padLeft(
      3,
      '0',
    );
    final certId = '${project.certificatePrefix}-$certNumber';

    try {
      final pdfPath = await _pdfGenerator.generateCertificatePdf(
        project: project,
        participant: participant,
        certificateId: certId,
      );

      final cert = GeneratedCertificate(
        participantId: participant.id,
        certificateId: certId,
        filePath: pdfPath,
      );

      final existingCerts = project.certificates
          .where((c) => c.participantId != participant.id)
          .toList();
      final updatedCerts = [...existingCerts, cert];

      final updated = project.copyWith(
        certificates: updatedCerts,
        updatedAt: DateTime.now(),
      );
      _projects[index] = updated;
      await _persist();
      notifyListeners();
      return pdfPath;
    } catch (e) {
      final cert = GeneratedCertificate(
        participantId: participant.id,
        certificateId: certId,
        generationError: e.toString(),
      );
      final existingCerts = project.certificates
          .where((c) => c.participantId != participant.id)
          .toList();
      final updated = project.copyWith(
        certificates: [...existingCerts, cert],
        updatedAt: DateTime.now(),
      );
      _projects[index] = updated;
      await _persist();
      notifyListeners();
      return null;
    }
  }

  Future<int> generateAllCertificates(String projectId) async {
    final index = _projects.indexWhere((p) => p.id == projectId);
    if (index == -1) return 0;

    final project = _projects[index];
    int count = 0;

    for (final participant in project.participants) {
      final res = await generateSingleCertificate(projectId, participant);
      if (res != null) count++;
    }
    return count;
  }

  Future<bool> sendCertificate(String projectId, String participantId) async {
    final projectIndex = _projects.indexWhere(
      (project) => project.id == projectId,
    );
    if (projectIndex == -1) return false;

    final project = _projects[projectIndex];
    final participant = project.participants.firstWhere(
      (item) => item.id == participantId,
      orElse: () => throw StateError('Participant not found.'),
    );
    final certificateIndex = project.certificates.indexWhere(
      (item) => item.participantId == participantId,
    );
    if (certificateIndex == -1) {
      throw StateError('Generate this certificate first.');
    }

    final certificate = project.certificates[certificateIndex];
    final filePath = certificate.filePath;
    if (filePath == null || !File(filePath).existsSync()) {
      throw StateError(
        'The generated PDF file is missing. Generate the certificate again.',
      );
    }

    await _setEmailStatus(
      projectIndex,
      certificateIndex,
      DeliveryStatus.sending,
    );
    try {
      await _emailService.sendCertificate(
        recipient: participant.email,
        subject: _fillEmailTokens(
          project.emailSubject,
          participant,
          certificate,
          project,
        ),
        body: _fillEmailTokens(
          project.emailBody,
          participant,
          certificate,
          project,
        ),
        attachmentPath: filePath,
        attachmentName:
            '${project.certificatePrefix}_${certificate.certificateId.replaceAll('-', '_')}.pdf',
      );
      await _setEmailStatus(
        projectIndex,
        certificateIndex,
        DeliveryStatus.sent,
      );
      return true;
    } catch (error) {
      await _setEmailStatus(
        projectIndex,
        certificateIndex,
        DeliveryStatus.failed,
        failureReason: error.toString(),
      );
      return false;
    }
  }

  Future<int> sendAllCertificates(String projectId) async {
    final project = _projects.firstWhere((item) => item.id == projectId);
    var sentCount = 0;
    for (final participant in project.participants) {
      final certificate = project.certificates.where(
        (item) =>
            item.participantId == participant.id &&
            item.filePath != null &&
            File(item.filePath!).existsSync(),
      );
      if (certificate.isEmpty) continue;
      if (await sendCertificate(projectId, participant.id)) sentCount++;
    }
    return sentCount;
  }

  Future<void> _setEmailStatus(
    int projectIndex,
    int certificateIndex,
    DeliveryStatus status, {
    String? failureReason,
  }) async {
    final project = _projects[projectIndex];
    final certificates = [...project.certificates];
    certificates[certificateIndex] = certificates[certificateIndex].copyWith(
      emailStatus: status,
      emailFailureReason: failureReason,
    );
    _projects[projectIndex] = project.copyWith(certificates: certificates);
    await _persist();
    notifyListeners();
  }

  String _fillEmailTokens(
    String text,
    Participant participant,
    GeneratedCertificate certificate,
    CertificateProject project,
  ) {
    final values = <String, String>{
      for (final entry in participant.values.entries)
        entry.key.toUpperCase(): entry.value,
      'CERTIFICATE_ID': certificate.certificateId,
      'ID': certificate.certificateId,
      'PROJECT_NAME': project.name,
    };
    return text.replaceAllMapped(
      RegExp(r'\{\{([A-Za-z0-9_-]+)\}\}'),
      (match) => values[match.group(1)!.toUpperCase()] ?? match.group(0)!,
    );
  }

  Future<void> updateProject(CertificateProject project) async {
    _projects = [
      for (final item in _projects)
        if (item.id == project.id) project else item,
    ];
    await _persist();
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    _projects = _projects.where((project) => project.id != id).toList();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _storage.saveProjects(_projects);
      _error = null;
    } catch (_) {
      _error = 'Project changes could not be saved. Check available storage.';
      rethrow;
    }
  }
}
