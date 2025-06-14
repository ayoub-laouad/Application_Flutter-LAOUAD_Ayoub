import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ProfileScreen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  String _language = 'Français';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Paramètres de l\'application',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            
            // Section Compte
            _buildSettingsSection(
              'Compte',
              [
                _buildSettingsTile(
                  Icons.person,
                  'Informations personnelles',
                  'Voir et modifier vos données',
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  },
                ),
                _buildSettingsTile(
                  Icons.security,
                  'Sécurité',
                  'Réinitialiser le mot de passe',
                  () async {
                    // Utilise FirebaseAuth pour envoyer l'email de reset si possible
                    final user = FirebaseAuth.instance.currentUser;
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
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Section Notifications
            _buildSettingsSection(
              'Notifications',
              [
                SwitchListTile(
                  secondary: Icon(Icons.notifications, color: Colors.grey.shade600),
                  title: const Text('Notifications push'),
                  subtitle: const Text('Activer/désactiver les alertes'),
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                  },
                ),
                _buildSettingsTile(
                  Icons.email,
                  'Notifications email',
                  'Paramètres d\'email',
                  () {},
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Section Application
            _buildSettingsSection(
              'Application',
              [
                SwitchListTile(
                  secondary: Icon(Icons.palette, color: Colors.grey.shade600),
                  title: const Text('Thème'),
                  subtitle: Text(_darkMode ? 'Mode sombre' : 'Mode clair'),
                  value: _darkMode,
                  onChanged: (val) {
                    setState(() => _darkMode = val);
                  },
                ),
                _buildSettingsTile(
                  Icons.language,
                  'Langue',
                  _language,
                  () async {
                    final selected = await showDialog<String>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('Choisir la langue'),
                        children: [
                          SimpleDialogOption(
                            child: const Text('Français'),
                            onPressed: () => Navigator.pop(context, 'Français'),
                          ),
                          SimpleDialogOption(
                            child: const Text('English'),
                            onPressed: () => Navigator.pop(context, 'English'),
                          ),
                        ],
                      ),
                    );
                    if (selected != null) setState(() => _language = selected);
                  },
                ),
                _buildSettingsTile(
                  Icons.info,
                  'À propos',
                  'Version 1.0.0',
                  () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Formulaire Flutter',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(Icons.info),
                      children: [
                        const Text("Application développer par des étudiants de Master M2SI: ELFATINE M'barka et Ayoub Laouad, pour faire un démonstration Flutter avec IA, Firebase, et plus."),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade600),
      title: Text(title),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}