# Formulaire Flutter IA

## Présentation

Ce projet est une application mobile Flutter développée dans le cadre du Master M2SI par ELFATINE M'barka et Ayoub Laouad. Elle vise à démontrer l'intégration de Flutter avec l'intelligence artificielle (IA), Firebase, et d'autres technologies modernes. L'application propose un assistant virtuel alimenté par Gemini AI, la génération d'images par IA, la reconnaissance et le traitement d'objets via un modèle TensorFlow Lite, ainsi qu'une gestion complète des utilisateurs.

## Fonctionnalités principales

- **Authentification Firebase** : Inscription, connexion, réinitialisation du mot de passe, gestion du profil utilisateur.
- **Assistant Virtuel** : Chat intelligent avec Gemini AI, reconnaissance vocale (speech-to-text), synthèse vocale (text-to-speech), suggestions, gestion d’images dans les messages.
- **Générateur d’Images IA** : Génération d’images à partir de descriptions textuelles via une API externe, historique des images générées.
- **Traitement d’Objets** : Classification d’objets à partir de photos grâce à un modèle TensorFlow Lite embarqué, affichage des prédictions et gestion des images.
- **Gestion du Profil** : Modification des informations personnelles, changement de mot de passe, déconnexion.
- **Paramètres** : Notifications, thème clair/sombre, choix de la langue, informations sur l’application.

## Structure du projet

- `lib/main.dart` : Point d’entrée de l’application, initialisation de Firebase et des routes principales.
- `lib/SignIn.dart` & `lib/SignUp.dart` : Interfaces d’authentification.
- `lib/HomeScreen.dart` : Accueil avec accès rapide aux modules principaux.
- `lib/Application/VirtualAssistantScreen.dart` : Assistant virtuel avec chat IA, reconnaissance vocale et gestion d’images.
- `lib/Application/ImageGeneratorScreen.dart` : Générateur d’images IA.
- `lib/Application/TraitementObjets.dart` : Module de classification d’objets avec TFLite.
- `lib/Application/ProfileScreen.dart` : Gestion du profil utilisateur.
- `lib/Application/SettingsScreen.dart` : Paramètres de l’application.
- `assets/` : Images, modèles IA (mobilenet_v1_1.0_224.tflite, labels.txt), fichiers de configuration.

## Installation et lancement

1. **Prérequis** :
   - Flutter SDK (>=3.7.2 <4.0.0)
   - Compte Firebase (ajouter vos propres clés dans `.env` et `firebase_options.dart`)
2. **Cloner le projet** :
   ```bash
   git clone <repo-url>
   ```
3. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```
4. **Configurer Firebase** :
   - Copier vos fichiers de configuration Firebase dans le projet.
   - Renseigner les clés API nécessaires dans `.env`.
5. **Lancer l’application** :
   ```bash
   flutter run
   ```

## Dépendances principales

- `firebase_core`, `firebase_auth` : Authentification et backend.
- `speech_to_text`, `flutter_tts` : Reconnaissance et synthèse vocale.
- `image_picker`, `http`, `cross_file`, `image` : Gestion d’images et requêtes réseau.
- `tflite_flutter` : Inférence IA embarquée.
- `flutter_dotenv` : Gestion des variables d’environnement.

## Auteurs

- ELFATINE M'barka
- Ayoub Laouad

## Remarques

- Ce projet est fourni à des fins pédagogiques et de démonstration.
- L’API Gemini nécessite une clé API valide à renseigner dans `.env`.
- Certaines fonctionnalités avancées (partage, sauvegarde d’images) peuvent nécessiter des autorisations spécifiques sur l’appareil.
