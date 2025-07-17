import 'dart:io' as io;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key});

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final supabase = Supabase.instance.client;
  final picker = ImagePicker();
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String estado = 'pendiente';
  bool isSaving = false;

  Uint8List? webImage;
  io.File? localImage;
  static const int maxSize = 2 * 1024 * 1024; // 2 MB

  Future<void> pickImage(ImageSource source) async {
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null) return;

    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > maxSize) {
        _showError('Imagen > 2 MB – elige otra.');
        return;
      }
      setState(() => webImage = bytes);
    } else {
      final file = io.File(picked.path);
      final size = await file.length();
      if (size > maxSize) {
        _showError('Imagen > 2 MB – elige otra.');
        return;
      }
      setState(() => localImage = file);
    }
  }

  Future<bool> checkCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  void showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () async {
                Navigator.pop(context);
                if (await checkCameraPermission()) {
                  pickImage(ImageSource.camera);
                } else {
                  _showError('Permiso de cámara denegado');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Elegir de galería'),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> uploadImage() async {
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  final uuid = const Uuid().v4();
  final fileName = '$uuid.jpg';
  final filePath = '${user.id}/$fileName';

  Uint8List? bytes;

  
  if (kIsWeb && webImage != null) {
    bytes = webImage;
  } else if (!kIsWeb && localImage != null) {
    bytes = await localImage!.readAsBytes();
  }

  if (bytes == null) return null;

  try {
    final response = await supabase.storage.from('tareas').uploadBinary(
      filePath,
      bytes,
      fileOptions: const FileOptions(
        contentType: 'image/jpeg',
        upsert: true,
      ),
    );

    if (response.isEmpty) {
      // Upload falló
      return null;
    }

    return supabase.storage.from('tareas').getPublicUrl(filePath);
  } catch (e) {
    debugPrint('Error al subir imagen: $e');
    return null;
  }
}


  Future<void> saveTask() async {
    final titulo = titleController.text.trim();
    if (titulo.isEmpty) {
      _showError('El título es obligatorio');
      return;
    }

    setState(() => isSaving = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      String? imageUrl = await uploadImage();

      await supabase.from('tareas').insert({
        'user_id': user.id,
        'titulo': titulo,
        'estado': estado,
        'foto': imageUrl,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Error al guardar: $e');
    } finally {
      setState(() => isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    Widget? imagePreview;
    if (kIsWeb && webImage != null) {
      imagePreview = Image.memory(webImage!, height: 200, fit: BoxFit.cover);
    } else if (!kIsWeb && localImage != null) {
      imagePreview = Image.file(localImage!, height: 200, fit: BoxFit.cover);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Tarea')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Título de la tarea'),
            ),
            const SizedBox(height: 12),
            TextField(controller: descriptionController,
            decoration: const InputDecoration(labelText: 'Descripción'),
            maxLines: 3,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField(
              value: estado,
              items: const [
                DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                DropdownMenuItem(value: 'completada', child: Text('Completada')),
              ],
              onChanged: (value) => setState(() => estado = value!),
              decoration: const InputDecoration(labelText: 'Estado'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: showImageSourcePicker,
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Subir imagen'),
            ),
            const SizedBox(height: 12),
            if (imagePreview != null) imagePreview,
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: isSaving ? null : saveTask,
              icon: const Icon(Icons.save),
              label: Text(isSaving ? 'Guardando...' : 'Guardar tarea'),
            ),
          ],
        ),
      ),
    );
  }
}
