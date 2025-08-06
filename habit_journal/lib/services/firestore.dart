import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  // Get the current user's UID
  String getCurrentUserUid() {
    return FirebaseAuth.instance.currentUser!.uid;
  }

  // get collection of users
  CollectionReference get users => FirebaseFirestore.instance.collection('users');

  // get collection of notes
  CollectionReference userNotesCollection(String userId) => FirebaseFirestore.instance.collection('notes/$userId/userNotes');

  // CREATE: add a new note
  Future<void> addNote(String note) async {
    try {
      await userNotesCollection(getCurrentUserUid()).add({
      'note': note,
      'timestamp': FieldValue.serverTimestamp(),
      // 'userId': getCurrentUserUid(), // Include the user ID in the document
    });
    } catch (e) {
      print(e);
    }
  }

  // READ: get notes from database
  Stream<QuerySnapshot> getNotesStream(String userId) {
    final notesStream = userNotesCollection(userId)
    .orderBy('timestamp', descending: true)
    .snapshots();
    return notesStream;
  }

  // UPDATE: update notes given a doc id
  Future<void> updateNote(String docID, String newNote) {
    String userId = getCurrentUserUid();

    return userNotesCollection(userId).doc(docID).update({
      'note': newNote,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': userId,
    });
  }

  // DELETE: delete notes given a doc id
  Future<void> deleteNote(String docID) {
    String userId = getCurrentUserUid();

    return userNotesCollection(userId).doc(docID).delete();
  }
}
