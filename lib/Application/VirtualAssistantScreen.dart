import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class VirtualAssistantScreen extends StatefulWidget {
  const VirtualAssistantScreen({super.key});

  @override
  _VirtualAssistantScreenState createState() => _VirtualAssistantScreenState();
}

class _VirtualAssistantScreenState extends State<VirtualAssistantScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isListening = false;
  bool _isSpeaking = false;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _speakingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _speakingAnimation;

  // API Gemini
  static final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
  static const String _geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  // Speech to Text
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _recognizedWords = '';
  String _lastRecognizedWords = '';

  // Text to Speech
  final FlutterTts _flutterTts = FlutterTts();
  bool _ttsEnabled = false;
  bool _autoPlayResponses = true;
  String? _currentSpeakingMessageId;

  // Image picker
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;

  // Suggestions prédéfinies
  final List<String> _suggestions = [
    "Comment puis-je optimiser mes objets ?",
    "Quelles sont les dernières nouveautés ?",
    "Aide-moi avec les paramètres",
    "Comment fonctionne le traitement ?",
    "Montre-moi mon profil",
    "Quels sont mes derniers projets ?",
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeSpeech();
    _initializeTts();
    _addWelcomeMessage();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _speakingController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.easeOut));

    _speakingAnimation = Tween<double>(
      begin: 0.5,
      end: 1.5,
    ).animate(CurvedAnimation(parent: _speakingController, curve: Curves.easeInOut));
  }

  void _addWelcomeMessage() {
    final user = FirebaseAuth.instance.currentUser;
    final welcomeMessage =
        'Bonjour ${user?.email?.split('@')[0] ?? 'utilisateur'} ! 👋\n\nJe suis votre assistant virtuel alimenté par Gemini AI. Comment puis-je vous aider aujourd\'hui ?';

    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          text: welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );
    });

    // Lire le message de bienvenue si l'auto-play est activé
    if (_autoPlayResponses && _ttsEnabled) {
      _speakText(welcomeMessage, DateTime.now().millisecondsSinceEpoch.toString());
    }
  }

  void _initializeSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
        debugLogging: false,
      );
      
      if (!_speechEnabled) {
        _showErrorSnackBar('La reconnaissance vocale n\'est pas disponible sur cet appareil');
      }
      
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      print('Erreur lors de l\'initialisation de la reconnaissance vocale: $e');
      _showErrorSnackBar('Erreur lors de l\'initialisation de la reconnaissance vocale');
      if (!mounted) return;
      setState(() {
        _speechEnabled = false;
      });
    }
  }

  void _initializeTts() async {
    try {
      // Configuration TTS
      await _flutterTts.setLanguage("fr-FR");
      await _flutterTts.setSpeechRate(0.8);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Gestionnaires d'événements TTS
      _flutterTts.setStartHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = true;
        });
        _speakingController.repeat();
      });

      _flutterTts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _currentSpeakingMessageId = null;
        });
        _speakingController.stop();
        _speakingController.reset();
      });

      _flutterTts.setErrorHandler((msg) {
        if (!mounted) return;
        setState(() {
          _isSpeaking = false;
          _currentSpeakingMessageId = null;
        });
        _speakingController.stop();
        _speakingController.reset();
        print('Erreur TTS: $msg');
      });

      // Vérifier la disponibilité TTS
      final languages = await _flutterTts.getLanguages;
      _ttsEnabled = languages.isNotEmpty;
      
      if (!_ttsEnabled) {
        _showErrorSnackBar('La synthèse vocale n\'est pas disponible sur cet appareil');
      }

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      print('Erreur lors de l\'initialisation TTS: $e');
      if (!mounted) return;
        setState(() {
        _ttsEnabled = false;
      });
    }
  }

  Future<void> _speakText(String text, String messageId) async {
    if (!_ttsEnabled) return;
    
    try {
      // Arrêter la lecture en cours si nécessaire
      await _flutterTts.stop();
      
      if (!mounted) return;
      setState(() {
        _currentSpeakingMessageId = messageId;
      });
      
      // Nettoyer le texte des emojis et caractères spéciaux pour une meilleure lecture
      String cleanText = text
          .replaceAll(RegExp(r'[👋🔥💡📱💻🎯🚀📊⚡🌟🎉]'), '')
          .replaceAll(RegExp(r'\*\*(.*?)\*\*'), r'\1') // Supprimer le markdown gras
          .replaceAll(RegExp(r'\*(.*?)\*'), r'\1') // Supprimer le markdown italique
          .trim();
      
      if (cleanText.isNotEmpty) {
        await _flutterTts.speak(cleanText);
      }
    } catch (e) {
      print('Erreur lors de la lecture: $e');
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _currentSpeakingMessageId = null;
      });
    }
  }

  Future<void> _stopSpeaking() async {
    if (_ttsEnabled) {
      await _flutterTts.stop();
      if (!mounted) return;
      setState(() {
        _isSpeaking = false;
        _currentSpeakingMessageId = null;
      });
    }
  }

  void _onSpeechError(error) {
    print('Erreur de reconnaissance vocale: $error');
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
    _waveController.stop();
    
    String errorMessage = 'Erreur de reconnaissance vocale';
    switch (error.errorMsg) {
      case 'error_network_timeout':
        errorMessage = 'Délai d\'attente réseau dépassé';
        break;
      case 'error_network':
        errorMessage = 'Erreur de connexion réseau';
        break;
      case 'error_audio':
        errorMessage = 'Erreur audio';
        break;
      case 'error_server':
        errorMessage = 'Erreur serveur';
        break;
      case 'error_client':
        errorMessage = 'Erreur client';
        break;
      case 'error_speech_timeout':
        errorMessage = 'Délai d\'attente de parole dépassé';
        break;
      case 'error_no_match':
        errorMessage = 'Aucune correspondance trouvée';
        break;
      case 'error_busy':
        errorMessage = 'Service occupé';
        break;
      case 'error_insufficient_permissions':
        errorMessage = 'Permissions insuffisantes pour le microphone';
        break;
    }
    
    _showErrorSnackBar(errorMessage);
  }

  void _onSpeechStatus(String status) {
    print('Statut de reconnaissance vocale: $status');
    if (!mounted) return;
    setState(() {
      _isListening = status == 'listening';
    });
    
    if (status == 'listening') {
      _waveController.repeat();
    } else {
      _waveController.stop();
    }
    
    if (status == 'done' && _recognizedWords.isNotEmpty && _recognizedWords != _lastRecognizedWords) {
      _fillTextFieldWithRecognizedText();
    }
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _showErrorSnackBar('La reconnaissance vocale n\'est pas disponible');
      return;
    }

    // Arrêter la lecture TTS si en cours
    if (_isSpeaking) {
      await _stopSpeaking();
    }

    try {
      if (!mounted) return;
      setState(() {
        _recognizedWords = '';
      });

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'fr_FR',
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );
      
      if (!mounted) return;
      setState(() {
        _isListening = true;
      });
      
    } catch (e) {
      print('Erreur lors du démarrage de l\'écoute: $e');
      _showErrorSnackBar('Erreur lors du démarrage de l\'écoute');
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
    }
  }

  void _stopListening() async {
    try {
      await _speechToText.stop();
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
      _waveController.stop();
      
      if (_recognizedWords.isNotEmpty && _recognizedWords != _lastRecognizedWords) {
        _fillTextFieldWithRecognizedText();
      }
    } catch (e) {
      print('Erreur lors de l\'arrêt de l\'écoute: $e');
      if (!mounted) return;
      setState(() {
        _isListening = false;
      });
    }
  }

  void _onSpeechResult(result) {
    if (!mounted) return;
    setState(() {
      _recognizedWords = result.recognizedWords;
    });
    
    if (result.finalResult && _recognizedWords.isNotEmpty) {
      _fillTextFieldWithRecognizedText();
    }
  }

  void _fillTextFieldWithRecognizedText() {
    if (_recognizedWords.isNotEmpty && _recognizedWords.trim().isNotEmpty) {
      _lastRecognizedWords = _recognizedWords;
      if (!mounted) return;
      setState(() {
        _messageController.text = _recognizedWords;
        _recognizedWords = '';
      });
    }
  }

  void _toggleListening() {
    if (!_speechEnabled) {
      _showErrorSnackBar('La reconnaissance vocale n\'est pas disponible');
      return;
    }

    if (_speechToText.isListening) {
      _stopListening();
    } else {
      _startListening();
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        if (!mounted) return;
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      print('Erreur lors de la sélection d\'image: $e');
      _showErrorSnackBar('Erreur lors de la sélection d\'image');
    }
  }

  void _removeSelectedImage() {
    if (!mounted) return;
    setState(() {
      _selectedImage = null;
    });
  }

  Future<String> _imageToBase64(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      print('Erreur lors de la conversion de l\'image: $e');
      throw Exception('Erreur lors de la conversion de l\'image');
    }
  }

  void _sendMessage(String message) async {
    if (message.trim().isEmpty && _selectedImage == null) return;

    // Arrêter la lecture TTS si en cours
    if (_isSpeaking) {
      await _stopSpeaking();
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(
          text: message.isNotEmpty ? message : "📷 Image envoyée",
          isUser: true,
          timestamp: DateTime.now(),
          image: _selectedImage,
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );
      _isTyping = true;
    });

    _messageController.clear();
    XFile? currentImage = _selectedImage;
    if (!mounted) return;
    setState(() {
      _selectedImage = null;
    });
    _scrollToBottom();

    try {
      String response;
      if (currentImage != null) {
        response = await _sendMessageWithImageToGemini(message, currentImage);
      } else {
        response = await _sendMessageToGemini(message);
      }

      final responseMessageId = DateTime.now().millisecondsSinceEpoch.toString();
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
            id: responseMessageId,
          ),
        );
        _isTyping = false;
      });

      // Lire automatiquement la réponse si l'auto-play est activé
      if (_autoPlayResponses && _ttsEnabled) {
        await Future.delayed(const Duration(milliseconds: 500));
        _speakText(response, responseMessageId);
      }

    } catch (e) {
      final errorMessageId = DateTime.now().millisecondsSinceEpoch.toString();
      const errorMessage = 'Désolé, une erreur s\'est produite lors de la génération de la réponse. Veuillez réessayer.';
      
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
            id: errorMessageId,
          ),
        );
        _isTyping = false;
      });
      
      if (_autoPlayResponses && _ttsEnabled) {
        _speakText(errorMessage, errorMessageId);
      }
      
      print('Erreur Gemini: $e');
    }

    _scrollToBottom();
  }

  Future<String> _sendMessageToGemini(String message) async {
    try {
      final url = Uri.parse('$_geminiBaseUrl/gemini-2.0-flash:generateContent?key=$_geminiApiKey');
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': message}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          return 'Désolé, je n\'ai pas pu générer une réponse.';
        }
      } else {
        print('Erreur HTTP: ${response.statusCode}');
        print('Corps de la réponse: ${response.body}');
        return 'Erreur de connexion au service AI.';
      }
    } catch (e) {
      print('Erreur lors de l\'envoi à Gemini: $e');
      return 'Erreur lors de la communication avec le service AI.';
    }
  }

  Future<String> _sendMessageWithImageToGemini(String message, XFile imageFile) async {
    try {
      final url = Uri.parse('$_geminiBaseUrl/gemini-2.0-flash:generateContent?key=$_geminiApiKey');
      final imageBase64 = await _imageToBase64(imageFile);
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              if (message.isNotEmpty) {'text': message},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': imageBase64
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 1024,
        }
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          return 'Désolé, je n\'ai pas pu analyser cette image.';
        }
      } else {
        print('Erreur HTTP: ${response.statusCode}');
        print('Corps de la réponse: ${response.body}');
        return 'Erreur de connexion au service AI.';
      }
    } catch (e) {
      print('Erreur lors de l\'envoi de l\'image à Gemini: $e');
      return 'Erreur lors de l\'analyse de l\'image.';
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Réessayer',
          textColor: Colors.white,
          onPressed: () {
            if (!_speechEnabled) {
              _initializeSpeech();
            }
            if (!_ttsEnabled) {
              _initializeTts();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistant Virtuel'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          // Indicateur TTS
          if (_ttsEnabled && _isSpeaking)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message: 'Lecture en cours...',
                child: AnimatedBuilder(
                  animation: _speakingAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _speakingAnimation.value,
                      child: Icon(
                        Icons.volume_up,
                        color: Colors.green.shade300,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ),
          // Bouton toggle auto-play
          if (_ttsEnabled)
            IconButton(
              icon: Icon(
                _autoPlayResponses ? Icons.volume_up : Icons.volume_off,
                color: _autoPlayResponses ? Colors.white : Colors.white70,
              ),
              tooltip: _autoPlayResponses 
                  ? 'Lecture automatique activée' 
                  : 'Lecture automatique désactivée',
              onPressed: () {
                if (!mounted) return;
                setState(() {
                  _autoPlayResponses = !_autoPlayResponses;
                });
                if (!_autoPlayResponses && _isSpeaking) {
                  _stopSpeaking();
                }
              },
            ),
          // Indicateurs Speech
          if (!_speechEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message: 'Reconnaissance vocale non disponible',
                child: Icon(Icons.mic_off, color: Colors.red.shade300, size: 20),
              ),
            ),
          if (_speechEnabled && _isListening)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Tooltip(
                message: 'Écoute en cours...',
                child: Icon(Icons.mic, color: Colors.green.shade300, size: 20),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Nouvelle conversation',
            onPressed: () {
              _stopSpeaking();
              if (!mounted) return;
              setState(() {
                _messages.clear();
                _recognizedWords = '';
                _lastRecognizedWords = '';
                _selectedImage = null;
              });
              _addWelcomeMessage();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),

            if (_isListening) _buildListeningIndicator(),

            if (_selectedImage != null) _buildSelectedImagePreview(),

            if (_messages.length <= 2 && !_isListening && _selectedImage == null) 
              _buildSuggestions(),

            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          FutureBuilder<Uint8List>(
            future: _selectedImage!.readAsBytes(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    snapshot.data!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                );
              } else {
                return Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Image sélectionnée',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _removeSelectedImage,
            tooltip: 'Supprimer l\'image',
          ),
        ],
      ),
    );
  }

  Widget _buildListeningIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _waveAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _recognizedWords.isNotEmpty
                          ? _recognizedWords
                          : 'Écoute en cours... Parlez maintenant',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isCurrentlySpeaking = _currentSpeakingMessageId == message.id;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue.shade600 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: isCurrentlySpeaking 
                    ? Border.all(color: Colors.green.shade400, width: 2)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.image != null) ...[
                    FutureBuilder<Uint8List>(
                      future: message.image!.readAsBytes(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              snapshot.data!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          );
                        } else {
                          return Container(
                            height: 200,
                            color: Colors.grey[300],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        }
                      },
                    ),
                    if (message.text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? Colors.white : Colors.black87,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          color: message.isUser 
                              ? Colors.white70 
                              : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      if (!message.isUser && _ttsEnabled && message.text.isNotEmpty)
                        Row(
                          children: [
                            if (isCurrentlySpeaking)
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green.shade600,
                                  ),
                                ),
                              )
                            else
                              GestureDetector(
                                onTap: () => _speakText(message.text, message.id),
                                child: Icon(
                                  Icons.volume_up,
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            const SizedBox(width: 4),
                            if (_isSpeaking && isCurrentlySpeaking)
                              GestureDetector(
                                onTap: _stopSpeaking,
                                child: Icon(
                                  Icons.stop,
                                  size: 16,
                                  color: Colors.red.shade600,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade600, Colors.grey.shade400],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person, color: Colors.white, size: 24),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Assistant réfléchit...',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions :',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((suggestion) {
              return GestureDetector(
                onTap: () {
                  _messageController.text = suggestion;
                  _sendMessage(suggestion);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Bouton image
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: Icon(
                  Icons.image,
                  color: _selectedImage != null 
                      ? Colors.blue.shade600 
                      : Colors.grey.shade600,
                ),
                onPressed: _pickImage,
                tooltip: 'Ajouter une image',
              ),
            ),
            const SizedBox(width: 8),
            
            // Champ de texte
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: _isListening 
                        ? 'Parlez maintenant...' 
                        : 'Tapez votre message...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty || _selectedImage != null) {
                      _sendMessage(text);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Bouton microphone
            if (_speechEnabled)
              Container(
                decoration: BoxDecoration(
                  color: _isListening 
                      ? Colors.red.shade100 
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedBuilder(
                  animation: _isListening ? _pulseAnimation : _waveAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isListening ? _pulseAnimation.value : 1.0,
                      child: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening 
                              ? Colors.red.shade600 
                              : Colors.grey.shade600,
                        ),
                        onPressed: _toggleListening,
                        tooltip: _isListening 
                            ? 'Arrêter l\'écoute' 
                            : 'Commencer l\'écoute',
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(width: 8),

            // Bouton envoi
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () {
                  final text = _messageController.text;
                  if (text.trim().isNotEmpty || _selectedImage != null) {
                    _sendMessage(text);
                  }
                },
                tooltip: 'Envoyer le message',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _speakingController.dispose();
    _speechToText.cancel();
    _flutterTts.stop();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final XFile? image;
  final String id;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.image,
    required this.id,
  });
}