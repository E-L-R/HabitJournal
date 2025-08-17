import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Import your DatabaseHelper and Note model
import 'package:habit_journal/models/note.dart'; // Assuming this path for your Note model
import 'package:habit_journal/services/database_service.dart'; // Assuming this path for your DatabaseHelper

// Note: You would typically pass the DatabaseHelper instance or use a service locator
// For simplicity in this example, we'll use the singleton instance directly.

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

// Database helper instance
final DatabaseHelper dbHelper = DatabaseHelper.instance;

// text controller
final TextEditingController textController = TextEditingController();

class _JournalPageState extends State<JournalPage> {
  // A future to hold notes, to be used with FutureBuilder
  late Future<List<Note>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _refreshNotes(); // Load notes when the widget initializes
  }

  // Method to refresh the list of notes
  void _refreshNotes() {
    setState(() {
      _notesFuture = dbHelper.getNotes();
    });
  }

  // open a dialog box to add a note
  void openNoteBox({Note? existingNote}) {
    // If we are editing, pre-fill the text field
    if (existingNote != null) {
      textController.text = existingNote.content ?? ''; // Use content field
    } else {
      textController.clear(); // Clear for new notes
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existingNote == null ? 'Add Note' : 'Edit Note'),
        content: SizedBox(
          // Give the text field a larger, fixed size.
          height: 250,
          width: MediaQuery.of(context).size.width,
          child: TextField(
            controller: textController,
            autofocus: true,
            maxLines: null, // Required for expands to work.
            expands: true, // Makes the TextField fill the SizedBox.
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top, // Aligns text to the top.
            decoration: const InputDecoration(
              hintText: 'Enter your journal entry...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
        ),
        actions: [
          // button to cancel
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          // button to save
          ElevatedButton(
            onPressed: () async {
              if (existingNote == null) {
                // Add a new note
                final newNote = Note(
                  title: textController.text.split('\n').first.trim(), // Use first line as title or default
                  content: textController.text,
                  timestamp: DateTime.now().millisecondsSinceEpoch,
                );
                await dbHelper.insertNote(newNote);
              } else {
                // Update an existing note
                existingNote.content = textController.text;
                existingNote.title = textController.text.split('\n').first.trim(); // Update title
                existingNote.timestamp = DateTime.now().millisecondsSinceEpoch; // Update timestamp on edit
                await dbHelper.updateNote(existingNote);
              }
              // Refresh the notes list
              _refreshNotes();
              // close the dialog box
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) {
      // Ensure the controller is cleared when the dialog is closed
      textController.clear();
    });
  }

  // show a dialog box to confirm note deletion
  void _showDeleteConfirmationDialog(int noteId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
        ),
        actions: [
          // button to cancel
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // button to delete
          ElevatedButton(
            onPressed: () async {
              await dbHelper.deleteNote(noteId);
              _refreshNotes(); // Refresh the notes list
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Note: Removed Firebase imports and FirebaseUIAuth dependencies
    // You'll need to handle authentication separately if you still require it
    // and are moving away from Firebase Auth for other parts of your app.
    // The MenuDrawer and ProfileScreen imports are commented out as they rely on external files.

    return Scaffold(
      // drawer: HabitJournalMenuDrawer(), // Commented out due to external dependency
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text('Journal'),
        // leading: Builder( // Commented out due to external dependency
        //   builder: (context) {
        //     return IconButton(
        //       icon: const Icon(Icons.menu),
        //       onPressed: () {
        //         Scaffold.of(context).openDrawer();
        //       },
        //     );
        //   },
        // ),
        // actions: [ // Commented out due to external dependency
        //   IconButton(
        //     icon: const Icon(Icons.person),
        //     onPressed: () {
        //       Navigator.push(
        //         context,
        //         MaterialPageRoute<ProfileScreen>(
        //           builder: (context) => ProfileScreen(
        //             appBar: AppBar(title: const Text('User Profile')),
        //             actions: [
        //               SignedOutAction((context) {
        //                 Navigator.of(context).pop();
        //               }),
        //             ],
        //             children: [const Divider()],
        //           ),
        //         ),
        //       );
        //     },
        //   ),
        // ],
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<Note>>(
        future: _notesFuture, // Use the Future from SQFlite
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No notes yet. Tap the + button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          } else {
            List<Note> notesList = snapshot.data!;
            return ListView.builder(
              itemCount: notesList.length,
              itemBuilder: (context, index) {
                Note note = notesList[index]; // Get Note object directly

                String noteTime = DateFormat.yMMMd().add_jm().format(
                    DateTime.fromMillisecondsSinceEpoch(note.timestamp));

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  elevation: 4.0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title, // Use note.title
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          note.content ?? '', // Use note.content
                          style: Theme.of(context).textTheme.bodyMedium, // Changed from bodySmall for better readability
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          noteTime,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // update button
                            IconButton(
                              onPressed: () => openNoteBox(
                                existingNote: note, // Pass the Note object
                              ),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            // delete button
                            IconButton(
                              onPressed: () =>
                                  _showDeleteConfirmationDialog(note.id!), // Pass note.id
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => openNoteBox(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
