class QuickCommand {
  final String id;
  final String title;
  final String command;
  final int colorValue;
  final String? description;

  const QuickCommand({
    required this.id,
    required this.title,
    required this.command,
    required this.colorValue,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'command': command,
        'colorValue': colorValue,
        'description': description,
      };

  factory QuickCommand.fromJson(Map<String, dynamic> json) => QuickCommand(
        id: json['id'] as String,
        title: json['title'] as String,
        command: json['command'] as String,
        colorValue: json['colorValue'] as int? ?? 0xFF00E5FF,
        description: json['description'] as String?,
      );

  QuickCommand copyWith({
    String? id,
    String? title,
    String? command,
    int? colorValue,
    String? description,
  }) {
    return QuickCommand(
      id: id ?? this.id,
      title: title ?? this.title,
      command: command ?? this.command,
      colorValue: colorValue ?? this.colorValue,
      description: description ?? this.description,
    );
  }
}
