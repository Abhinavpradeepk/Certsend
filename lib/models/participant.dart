class Participant {
  const Participant({required this.id, required this.values, this.issues = const []});
  final String id;
  final Map<String, String> values;
  final List<String> issues;
  String get name => values['NAME'] ?? '';
  String get email => values['EMAIL'] ?? '';
  bool get isValid => issues.isEmpty;

  Participant copyWith({Map<String, String>? values, List<String>? issues}) => Participant(id: id, values: values ?? this.values, issues: issues ?? this.issues);
  Map<String, dynamic> toJson() => {'id': id, 'values': values, 'issues': issues};
  factory Participant.fromJson(Map<String, dynamic> json) => Participant(id: json['id'] as String, values: Map<String, String>.from(json['values'] as Map? ?? {}), issues: List<String>.from(json['issues'] as List? ?? []));
}