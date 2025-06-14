import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class TraitementObjets extends StatefulWidget {
  const TraitementObjets({super.key});

  @override
  State<TraitementObjets> createState() => _TraitementObjetsState();
}

class _TraitementObjetsState extends State<TraitementObjets> {
  File? _image;
  List<Map<String, dynamic>>? _output;
  late Interpreter interpreter;
  List<String>? labels;
  int imgHeight = 224;
  int imgWidth = 224;
  ModelIs modelIs = ModelIs.notReady;
  String command = '';

  String resultOne = '';
  String resultTwo = '';
  String resultThree = '';

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  Future<void> loadModel() async {
    try {
      if (!mounted) return;
      setState(() {
        modelIs = ModelIs.loading;
        command = 'Chargement du modèle...';
      });
      await Future.delayed(const Duration(seconds: 3));
      interpreter = await Interpreter.fromAsset('assets/model/mobilenet_v1_1.0_224.tflite');
      labels = await _loadLabels('assets/model/labels.txt');
      if (!mounted) return;
      setState(() {
        modelIs = ModelIs.ready;
        command = 'Sélectionnez ou prenez une photo d\'un objet';
      });
    } catch (e) {
      debugPrint("Échec du chargement du modèle: $e");
      if (!mounted) return;
      setState(() {
        modelIs = ModelIs.error;
        command = 'Erreur lors du chargement du modèle';
      });
    }
  }

  Future<List<String>> _loadLabels(String path) async {
    final labelFile = await rootBundle.loadString(path);
    return labelFile.split('\n');
  }

  Future<void> pickImage(ImageSource source, {CameraDevice? preferredCameraDevice}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
        preferredCameraDevice: preferredCameraDevice ?? CameraDevice.rear,
      );
      
      if (image == null) return;

      if (!mounted) return;
      setState(() {
        _image = File(image.path);
      });

      await _classifyImage(_image!);
    } catch (e) {
      debugPrint("Erreur lors de la sélection d'image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection d\'image: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: () {
                // Réessayer avec camera arrière par défaut
                if (source == ImageSource.camera) {
                  pickImage(source, preferredCameraDevice: CameraDevice.rear);
                }
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _classifyImage(File image) async {
    if (!mounted) return;
    setState(() {
      modelIs = ModelIs.thinking;
      command = 'Analyse de l\'objet en cours...';
    });

    await Future.delayed(const Duration(seconds: 2));

    try {
      // Lire les bytes du fichier image
      final imageBytes = await image.readAsBytes();
      img.Image? inputImage = img.decodeImage(imageBytes);
      
      if (inputImage == null) {
        throw Exception("Impossible de décoder l'image");
      }

      // Corriger l'orientation de l'image si nécessaire
      inputImage = img.bakeOrientation(inputImage);

      var input = imageToArray(inputImage);
      var output = List.filled(1 * 1001, 0.0).reshape([1, 1001]);

      interpreter.run(input, output);

      var probabilities = output[0];
      var prediction = List<Map<String, dynamic>>.generate(
        probabilities.length,
        (i) => {
          'index': i,
          'label': labels![i],
          'confidence': probabilities[i]
        },
      );

      prediction.sort((a, b) => b['confidence'].compareTo(a['confidence']));

      if (!mounted) return;
      setState(() {
        _output = prediction.sublist(0, 3);
        resultOne = "Il s'agit probablement d'un(e) ${_output![0]['label']} avec une confiance de ${formatConfidence(_output![0]['confidence'] * 100)}.";
        resultTwo = "Deuxième hypothèse : ${_output![1]['label']} avec ${formatConfidence(_output![1]['confidence'] * 100)}.";
        resultThree = "Enfin, cela pourrait être un(e) ${_output![2]['label']} avec ${formatConfidence(_output![2]['confidence'] * 100)}.";
        modelIs = ModelIs.done;
      });
    } catch (e) {
      debugPrint("Erreur lors de la classification: $e");
      if (!mounted) return;
      setState(() {
        modelIs = ModelIs.error;
        command = "Une erreur s'est produite lors de l'analyse. Veuillez réessayer.";
      });
    }
  }

  String formatConfidence(double confidence) {
    if (confidence < 1) {
      return "<1% de confiance";
    }
    return "${confidence.toStringAsFixed(2)}% de confiance";
  }

  List<dynamic> imageToArray(img.Image inputImage) {
    img.Image resizedImage = img.copyResize(inputImage, width: imgWidth, height: imgHeight);
    List<double> flattenedList = resizedImage.data!.expand((channel) => [channel.r, channel.g, channel.b]).map((value) => value.toDouble()).toList();
    Float32List float32Array = Float32List.fromList(flattenedList);
    int channels = 3;
    int height = imgHeight;
    int width = imgWidth;
    Float32List reshapedArray = Float32List(1 * height * width * channels);
    for (int c = 0; c < channels; c++) {
      for (int h = 0; h < height; h++) {
        for (int w = 0; w < width; w++) {
          int index = c * height * width + h * width + w;
          reshapedArray[index] =
              (float32Array[c * height * width + h * width + w] - 127.5) / 127.5;
        }
      }
    }
    return reshapedArray.reshape([1, imgWidth, imgHeight, 3]);
  }

  void showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sélectionner la source', style: TextStyle(color: Colors.orange.shade800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.orange.shade600),
                title: Text('Galerie', style: TextStyle(color: Colors.orange.shade800)),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.orange.shade600),
                title: Text('Appareil photo (arrière)', style: TextStyle(color: Colors.orange.shade800)),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera, preferredCameraDevice: CameraDevice.rear);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: Colors.orange.shade600),
                title: Text('Appareil photo (avant)', style: TextStyle(color: Colors.orange.shade800)),
                onTap: () {
                  Navigator.pop(context);
                  pickImage(ImageSource.camera, preferredCameraDevice: CameraDevice.front);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Traitement des objets',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: Text('À propos', style: TextStyle(color: Colors.orange.shade800)),
                    content: Text(
                      'Cette application analyse et identifie les objets dans vos images en utilisant '
                      'l\'intelligence artificielle. Elle utilise un modèle MobileNet pré-entraîné '
                      'pour fournir des prédictions avec des scores de confiance. '
                      'Sélectionnez simplement une image ou prenez une photo pour obtenir des résultats.',
                      style: TextStyle(color: Colors.orange.shade900),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('OK', style: TextStyle(color: Colors.orange.shade600)),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Analyse d\'objets par IA',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.orange.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                height: 300,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _image!,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.science,
                                size: 80,
                                color: Colors.orange.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucune image sélectionnée',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                    if (modelIs == ModelIs.thinking)
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    if (modelIs == ModelIs.thinking)
                      Positioned(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Analyse en cours...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (modelIs != ModelIs.done)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    command,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: modelIs == ModelIs.error ? Colors.red : Colors.orange.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              if (modelIs == ModelIs.done) ...[
                Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
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
                    Text(
                      'Résultats de l\'analyse',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            resultOne,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.orange.shade200, thickness: 1),
                    Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.orange.shade600, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            resultTwo,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(color: Colors.orange.shade200, thickness: 1),
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade500, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            resultThree,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Avertissement : Les résultats sont des prédictions et peuvent ne pas être précis à 100%. Veuillez vérifier si nécessaire.",
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: Colors.orange.shade400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                ),
              ],
              const SizedBox(height: 30),
              PickImageButton(
                onPressed: (modelIs == ModelIs.error || modelIs == ModelIs.loading)
                    ? null
                    : showImageSourceDialog,
                isLoading: (modelIs == ModelIs.thinking),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class PickImageButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const PickImageButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: isLoading ? 0 : 5,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              )
            : const Text(
                'Sélectionner une image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

enum ModelIs {
  notReady,
  loading,
  ready,
  thinking,
  done,
  error
}