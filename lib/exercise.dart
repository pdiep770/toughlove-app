class Exercise {
  final String name;
  final int sets;
  final int repsLow;
  final int repsHigh;
  final double weight;

  Exercise({
    required this.name,
    required this.sets,
    required this.repsLow,
    required this.repsHigh,
    required this.weight,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      name: json['name'],
      sets: json['sets'],
      repsLow: json['repsLow'],
      repsHigh: json['repsHigh'],
      weight: (json['weight'] as num).toDouble(),
    );
  }
}
