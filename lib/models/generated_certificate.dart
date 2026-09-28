enum DeliveryStatus { pending, generated, sending, sent, failed }

class GeneratedCertificate {
  const GeneratedCertificate({required this.participantId, required this.certificateId, this.filePath, this.generationError, this.emailStatus = DeliveryStatus.pending, this.emailFailureReason});
  final String participantId;
  final String certificateId;
  final String? filePath;
  final String? generationError;
  final DeliveryStatus emailStatus;
  final String? emailFailureReason;

  GeneratedCertificate copyWith({String? filePath, String? generationError, DeliveryStatus? emailStatus, String? emailFailureReason}) => GeneratedCertificate(
        participantId: participantId,
        certificateId: certificateId,
        filePath: filePath ?? this.filePath,
        generationError: generationError,
        emailStatus: emailStatus ?? this.emailStatus,
        emailFailureReason: emailFailureReason,
      );
  Map<String, dynamic> toJson() => {'participantId': participantId, 'certificateId': certificateId, 'filePath': filePath, 'generationError': generationError, 'emailStatus': emailStatus.name, 'emailFailureReason': emailFailureReason};
  factory GeneratedCertificate.fromJson(Map<String, dynamic> json) => GeneratedCertificate(
        participantId: json['participantId'] as String,
        certificateId: json['certificateId'] as String,
        filePath: json['filePath'] as String?,
        generationError: json['generationError'] as String?,
        emailStatus: DeliveryStatus.values.firstWhere((status) => status.name == json['emailStatus'], orElse: () => DeliveryStatus.pending),
        emailFailureReason: json['emailFailureReason'] as String?,
      );
}