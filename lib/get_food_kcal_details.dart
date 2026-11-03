import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:fitness_zone_2/widgets/anim/fh_loader.dart';

class SpoonacularFoodAnalyzer extends StatefulWidget {
  @override
  _SpoonacularFoodAnalyzerState createState() => _SpoonacularFoodAnalyzerState();
}

class _SpoonacularFoodAnalyzerState extends State<SpoonacularFoodAnalyzer> {
  File? _image;
  String? _result;
  bool _loading = false;
  final picker = ImagePicker();

  Future<void> _getImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      final file = File(picked.path);
      setState(() {
        _image = file;
        _result = null;
      });
      final imageUrl = await _uploadImageAndGetUrl(file);
      if (imageUrl != null) await _analyzeImageUrl(imageUrl);
      // if (file != null) await analyzeImageFile(file);
    }
  }

  Future<String?> _uploadImageAndGetUrl(File file) async {
    // Replace this with your actual upload logic (e.g., Firebase Storage/S3)
    // For demonstration, we pretend the file is accessible at this URL:
    final fakeUrl = 'https://assets.epicurious.com/photos/5c745a108918ee7ab68daf79/1:1/w_2560%2Cc_limit/Smashburger-recipe-120219.jpg';
    return fakeUrl;
  }


  Future<void> analyzeImageFile(File imageFile) async {
    final uri = Uri.parse(
        'https://api.spoonacular.com/food/images/analyze?apiKey=${dotenv.env['SPOONACULAR_API_KEY'] ?? ''}'
    );
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    print('_SpoonacularFoodAnalyzerState._analyzeImageUrl ${response.body}');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final cat = json['category']['name'];
      final prob = (json['category']['probability'] * 100).toStringAsFixed(2);
      final kcal = json['nutrition']['calories']['value'];
      setState(() => _result = 'Detected: $cat\nConfidence: $prob%\nCalories: $kcal kcal');
    } else {
      setState(() => _result = 'Error ${response.statusCode}: ${response.body}');
    }
  }
  Future<void> _analyzeImageUrl(String imageUrl) async {
    setState(() => _loading = true);

    final uri = Uri.https(
      'api.spoonacular.com',
      '/food/images/analyze',
      {'apiKey': dotenv.env['SPOONACULAR_API_KEY'] ?? '', 'imageUrl': imageUrl},
    );

    try {
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        print('_SpoonacularFoodAnalyzerState._analyzeImageUrl ${resp.body}');
        final json = jsonDecode(resp.body);
        final cat = json['category']['name'];
        final prob = (json['category']['probability'] * 100).toStringAsFixed(2);
        final kcal = json['nutrition']['calories']['value'];
        _result = 'Detected: $cat\nConfidence: $prob%\nCalories: $kcal kcal';
      } else {
        _result = 'Error ${resp.statusCode}: ${resp.body}';
      }
    } catch (e) {
      _result = 'Error: $e';
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Food Calorie Detector')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_image != null)
              Image.file(_image!, height: 200)
            else
              Container(height: 200, color: Colors.grey[200], child: Icon(Icons.image, size: 100)),
            SizedBox(height: 20),
            if (_loading) FhLoader(),
            if (_result != null)
              Text(_result!, textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  icon: Icon(Icons.camera_alt),
                  label: Text('Camera'),
                  onPressed: () => _getImage(ImageSource.camera),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.photo_library),
                  label: Text('Gallery'),
                  onPressed: () => _getImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
