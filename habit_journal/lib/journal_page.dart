import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:habit_journal/menu_drawer.dart';
import 'package:habit_journal/services/firestore.dart';
import 'package:intl/intl.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

// Firestore
final FirestoreService firestoreService = FirestoreService();

// text controller
final TextEditingController textController = TextEditingController();

class _JournalPageState extends State<JournalPage> {
  // open a dialog box to add a note
  void openNoteBox({String? doID, String? existingNote}) {
    // If we are editing, pre-fill the text field
    if (existingNote != null) {
      textController.text = existingNote;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(doID == null ? 'Add Note' : 'Edit Note'),
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
              // Just close the dialog box
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          // button to save
          ElevatedButton(
            onPressed: () {
              // add a new note
              if (doID == null) {
                firestoreService.addNote(textController.text);
              } else {
                // update an existing note
                firestoreService.updateNote(doID, textController.text);
              }
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
  void _showDeleteConfirmationDialog(String docID) {
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
            onPressed: () {
              firestoreService.deleteNote(docID);
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
    return Scaffold(
      drawer: HabitJournalMenuDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.pink,
        title: const Text('Journal'),
        leading: Builder(
          builder: (context) {
            return IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<ProfileScreen>(
                  builder: (context) => ProfileScreen(
                    appBar: AppBar(title: const Text('User Profile')),
                    actions: [
                      SignedOutAction((context) {
                        Navigator.of(context).pop();
                      }),
                    ],
                    children: [const Divider()],
                  ),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getNotesStream(
          FirebaseAuth.instance.currentUser!.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            List notesList = snapshot.data!.docs;
            // display as a list
            return ListView.builder(
              itemCount: notesList.length,
              itemBuilder: (context, index) {
                // get each individual doc
                DocumentSnapshot document = notesList[index];
                String docID = document.id;

                // get note from each doc
                Map<String, dynamic> data =
                    document.data() as Map<String, dynamic>;
                String noteText = data['note'];
                String noteTime;
                if (data['timestamp'] != null) {
                  Timestamp timestamp = data['timestamp'] as Timestamp;
                  DateTime dateTime = timestamp.toDate();
                  noteTime = DateFormat.yMMMd().add_jm().format(dateTime);
                } else {
                  noteTime = 'No date';
                }

                // display as a list tile
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
                          noteText,
                          style: Theme.of(context).textTheme.titleLarge,
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
                                doID: docID,
                                existingNote: noteText,
                              ),
                              icon: Icon(
                                Icons.edit_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            // delete button
                            IconButton(
                              onPressed: () =>
                                  _showDeleteConfirmationDialog(docID),
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
          //if there is no data return
          else {
            return const Center(
              child: Text(
                'No notes yet. Tap the + button to add one!',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: openNoteBox,
        child: const Icon(Icons.add),
      ),
    );
  }
}
