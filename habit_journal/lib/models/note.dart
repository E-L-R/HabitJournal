// --- Note Model ---
class Note {
  int? id;
  String title;
  String? content;
  int timestamp; // Unix timestamp

  Note({this.id, required this.title, this.content, required this.timestamp});

  // Convert a Note object into a Map for database insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'timestamp': timestamp,
    };
  }

  // Convert a Map (from database) into a Note object
  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      timestamp: map['timestamp'],
    );
  }

  @override
  String toString() {
    return 'Note(id: $id, title: $title, content: $content, timestamp: $timestamp)';
  }
}
