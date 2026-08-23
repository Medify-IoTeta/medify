/// Tolerant parse for backend LocalDateTime fields — Jackson may serialize them as an ISO string
/// or as a [year, month, day, hour, minute, second?, nano?] array depending on config. Shared with
/// home_screen.dart for parsing an Intake's scheduledTime.
DateTime? parseBackendDateTime(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  if (value is List && value.length >= 5) {
    // Jackson default: [year, month, day, hour, minute, second?, nano?]
    return DateTime(
      value[0] as int, value[1] as int, value[2] as int,
      value[3] as int, value[4] as int,
    );
  }
  return null;
}

enum MedicationStatus { taken, pending, missed, dispensing, dispensed, incomplete, postponed }

enum DosageUnit { pills, mg, ml, drops, units }

enum TimePeriod { morning, noon, evening, other }

enum InstructionOption { none, afterFood, emptyStomach, other }

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
  final DateTime? disabledUntil;

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
    this.disabledUntil,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    // Backend uses 'timing' (MORNING/NOON/EVENING), Flutter uses 'timePeriod' (morning/noon/evening)
    final String timingRaw =
        (json['timing'] as String? ?? json['timePeriod'] as String? ?? 'morning').toLowerCase();

    // Backend stores instruction as description field value
    final String desc = json['description'] as String? ?? '';
    InstructionOption instructionOpt;
    String? customInstructions;
    switch (desc.toLowerCase()) {
      case 'afterfood':
        instructionOpt = InstructionOption.afterFood;
      case 'emptystomach':
        instructionOpt = InstructionOption.emptyStomach;
      default:
        if (desc.isNotEmpty) {
          instructionOpt = InstructionOption.other;
          customInstructions = desc;
        } else {
          instructionOpt = InstructionOption.none;
        }
    }

    return Medicine(
      // Backend returns Long id — convert to String
      id: json['id'].toString(),
      name: json['name'] as String,
      // dosageAmount/dosageUnit not stored in backend — use defaults
      dosageAmount: (json['dosageAmount'] as num?)?.toDouble() ?? 1.0,
      dosageUnit: DosageUnit.values.firstWhere(
        (e) => e.name == (json['dosageUnit'] as String? ?? '').toLowerCase(),
        orElse: () => DosageUnit.pills,
      ),
      timePeriod: TimePeriod.values.firstWhere(
        (e) => e.name == timingRaw,
        orElse: () => TimePeriod.morning,
      ),
      time: json['time'] as String? ?? '',
      status: MedicationStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'pending').toLowerCase(),
        orElse: () => MedicationStatus.pending,
      ),
      instructionOption: instructionOpt,
      instructions: customInstructions,
      // Backend uses 'active', Flutter uses 'enabled'
      enabled: json['active'] as bool? ?? json['enabled'] as bool? ?? true,
      disabledUntil: parseBackendDateTime(json['disabledUntil']),
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
    DateTime? disabledUntil,
    bool clearDisabledUntil = false,
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
      disabledUntil: clearDisabledUntil ? null : (disabledUntil ?? this.disabledUntil),
    );
  }
}
