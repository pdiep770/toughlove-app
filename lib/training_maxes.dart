class TrainingMaxes {
  final double? squat;
  final double? bench;
  final double? deadlift;

  const TrainingMaxes({this.squat, this.bench, this.deadlift});

  factory TrainingMaxes.fromJson(Map<String, dynamic> json) {
    return TrainingMaxes(
      squat: (json['squat'] as num?)?.toDouble(),
      bench: (json['bench'] as num?)?.toDouble(),
      deadlift: (json['deadlift'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'squat': squat,
      'bench': bench,
      'deadlift': deadlift,
    };
  }

  bool get isEmpty => squat == null && bench == null && deadlift == null;

  TrainingMaxes mergedWith(TrainingMaxes updates) {
    return TrainingMaxes(
      squat: updates.squat ?? squat,
      bench: updates.bench ?? bench,
      deadlift: updates.deadlift ?? deadlift,
    );
  }
}
