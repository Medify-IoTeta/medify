enum MedicationStatus { taken, pending, missed }

enum DosageUnit { pills, mg, ml, drops, units }

enum TimePeriod { morning, noon, evening, other }

enum InstructionOption { emptyStomach, afterFood, other }

class Medicine {
  final String id;
  final String name;
  final double dosageAmount;
  final DosageUnit dosageUnit;
  final TimePeriod timePeriod;
  final String time;
  final MedicationStatus status;
  final InstructionOption instructionOption;
  final String? instructions;
  final bool enabled;

  Medicine({
    required this.id,
    required this.name,
    required this.dosageAmount,
    required this.dosageUnit,
    required this.timePeriod,
    this.time = '',
    required this.status,
    required this.instructionOption,
    this.instructions,
    this.enabled = true,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String,
      dosageAmount: (json['dosageAmount'] as num).toDouble(),
      dosageUnit: DosageUnit.values.firstWhere(
        (e) => e.name == json['dosageUnit'],
        orElse: () => DosageUnit.pills,
      ),
      timePeriod: TimePeriod.values.firstWhere(
        (e) => e.name == json['timePeriod'],
        orElse: () => TimePeriod.morning,
      ),
      time: json['time'] as String? ?? '',
      status: MedicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MedicationStatus.pending,
      ),
      instructionOption: InstructionOption.values.firstWhere(
        (e) => e.name == json['instructionOption'],
        orElse: () => InstructionOption.afterFood,
      ),
      instructions: json['instructions'] as String?,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dosageAmount': dosageAmount,
      'dosageUnit': dosageUnit.name,
      'timePeriod': timePeriod.name,
      'time': time,
      'status': status.name,
      'instructionOption': instructionOption.name,
      'instructions': instructions,
      'enabled': enabled,
    };
  }

  Medicine copyWith({
    String? id,
    String? name,
    double? dosageAmount,
    DosageUnit? dosageUnit,
    TimePeriod? timePeriod,
    String? time,
    MedicationStatus? status,
    InstructionOption? instructionOption,
    String? instructions,
    bool? enabled,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosageAmount: dosageAmount ?? this.dosageAmount,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      timePeriod: timePeriod ?? this.timePeriod,
      time: time ?? this.time,
      status: status ?? this.status,
      instructionOption: instructionOption ?? this.instructionOption,
      instructions: instructions ?? this.instructions,
      enabled: enabled ?? this.enabled,
    );
  }
}
