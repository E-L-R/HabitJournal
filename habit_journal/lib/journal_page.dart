import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:habit_journal/menu_drawer.dart';
import 'package:habit_journal/services/firestore.dart';

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
  void openNoteBox({String? doID}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: TextField(controller: textController),
        actions: [
          // button to save
          ElevatedButton(
            onPressed: () {
              // add a new note
              if (doID == null) {
                firestoreService.addNote(textController.text);
              }
              // update an existing note
              else {
                firestoreService.updateNote(doID, textController.text);
              }
              // clear the text controller
              textController.clear();
              // close the dialog box
              Navigator.pop(context);
            },
            child: Text('save'),
          ),

          ElevatedButton(
            onPressed: () {
              // cancel

              // clear the text controller
              textController.clear();
              // close the dialog box
              Navigator.pop(context);
            },
            child: Text('cancel'),
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
                    children: [
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Icon(Icons.one_x_mobiledata),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getNotesStream(FirebaseAuth.instance.currentUser!.uid),
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
                String noteTime = data['timestamp'].toString();

                // display as a list tile
                return Padding(
                  padding: const EdgeInsets.all(150.0),
                  child: ListTile(
                  
                    title: Text(noteText),
                    subtitle: Text(noteTime),
                    trailing: Card(
                      color: Colors.amber,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // update button
                          IconButton(
                            onPressed: () => openNoteBox(doID: docID),
                            icon: Icon(Icons.settings),
                          ),
                          // delete button
                          IconButton(
                            onPressed: () => firestoreService.deleteNote(docID),
                            icon: Icon(Icons.delete),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }
          //if there is no data return
          else {
            return const Text('No notes..');
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
