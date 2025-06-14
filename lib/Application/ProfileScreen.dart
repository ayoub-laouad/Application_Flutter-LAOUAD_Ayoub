import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 54,
                backgroundImage: user?.photoURL != null && user!.photoURL!.isNotEmpty
                    ? NetworkImage(user.photoURL!)
                    : const AssetImage('assets/profile_placeholder.png') as ImageProvider,
                backgroundColor: Colors.grey.shade300,
              ),
              const SizedBox(height: 20),
              Text(
                user?.displayName ?? 'Nom inconnu',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                user?.email ?? 'Email inconnu',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.edit, color: Colors.blue.shade800),
                        title: const Text('Modifier le profil'),
                        onTap: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => _EditProfileDialog(user: user),
                          );
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.lock, color: Colors.blue.shade800),
                        title: const Text('Changer le mot de passe'),
                        onTap: () async {
                          if (user?.email != null) {
                            await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Email de réinitialisation envoyé'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      Divider(),
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.red.shade700),
                        title: const Text('Se déconnecter'),
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            Navigator.pushReplacementNamed(context, '/signIn');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final User? user;
  const _EditProfileDialog({Key? key, required this.user}) : super(key: key);

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _photoController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.displayName ?? '');
    _emailController = TextEditingController(text: widget.user?.email ?? '');
    _photoController = TextEditingController(text: widget.user?.photoURL ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_nameController.text != widget.user?.displayName) {
        await widget.user?.updateDisplayName(_nameController.text.trim());
      }
      if (_photoController.text != widget.user?.photoURL) {
        await widget.user?.updatePhotoURL(_photoController.text.trim());
      }
      if (_emailController.text != widget.user?.email) {
        await widget.user?.updateEmail(_emailController.text.trim());
      }
      if (context.mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier le profil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _photoController,
              decoration: const InputDecoration(labelText: 'URL de la photo'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _save,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
}