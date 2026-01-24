import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Model for a task
class Task {
  final String id;
  final String title;
  final String description;
  final bool isDone;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.isDone,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isDone: data['isDone'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'isDone': isDone,
    };
  }
}


class ProfessionalScreen extends StatefulWidget {
  const ProfessionalScreen({super.key});

  @override
  State<ProfessionalScreen> createState() => _ProfessionalScreenState();
}

class _ProfessionalScreenState extends State<ProfessionalScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  // Function to show a dialog for adding/editing a task
  void _showTaskDialog({Task? task}) {
    final _titleController = TextEditingController(text: task?.title);
    final _descriptionController = TextEditingController(text: task?.description);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(task == null ? 'Add New Task' : 'Edit Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = _titleController.text.trim();
                final description = _descriptionController.text.trim();

                if (title.isNotEmpty) {
                  if (task == null) {
                    // Add new task
                    _firestore
                        .collection('users')
                        .doc(_currentUser.uid)
                        .collection('tasks')
                        .add({
                      'title': title,
                      'description': description,
                      'isDone': false,
                      'createdAt': Timestamp.now(),
                    });
                  } else {
                    // Update existing task
                    _firestore
                        .collection('users')
                        .doc(_currentUser.uid)
                        .collection('tasks')
                        .doc(task.id)
                        .update({
                      'title': title,
                      'description': description,
                    });
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // Function to toggle the 'isDone' status of a task
  void _toggleTaskStatus(Task task) {
    _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .collection('tasks')
        .doc(task.id)
        .update({'isDone': !task.isDone});
  }

  // Function to delete a task
  void _deleteTask(Task task) {
     _firestore
        .collection('users')
        .doc(_currentUser.uid)
        .collection('tasks')
        .doc(task.id)
        .delete();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Management'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_currentUser.uid)
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_add_check_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No tasks yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('Press the + button to add a new task.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final tasks = snapshot.data!.docs.map((doc) => Task.fromFirestore(doc)).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Checkbox(
                    value: task.isDone,
                    onChanged: (bool? value) {
                      _toggleTaskStatus(task);
                    },
                  ),
                  title: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone ? Colors.grey : Colors.black87,
                    ),
                  ),
                  subtitle: task.description.isNotEmpty 
                    ? Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          decoration: task.isDone ? TextDecoration.lineThrough : null,
                        ),
                      )
                    : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showTaskDialog(task: task),
                        tooltip: 'Edit Task',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _deleteTask(task),
                        tooltip: 'Delete Task',
                      ),
                    ],
                  ),
                  onTap: () => _toggleTaskStatus(task),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskDialog(),
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }
}
