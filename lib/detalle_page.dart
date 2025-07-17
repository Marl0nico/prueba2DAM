import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetalleTareaPage extends StatelessWidget {
  final Map<String, dynamic> tarea;

  const DetalleTareaPage({super.key, required this.tarea});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de Tarea')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tarea['foto'] != null)
              Image.network(tarea['foto']),
            const SizedBox(height: 16),
            Text('Título: ${tarea['titulo']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Descripción: ${tarea['descripcion'] ?? "Sin descripción"}'),
            const SizedBox(height: 8),
            Text('Estado: ${tarea['estado']}'),
            const SizedBox(height: 8),
            if (tarea['timestamp'] != null)
              Text('Fecha: ${tarea['timestamp']}'),
          ],
        ),
      ),
    );
  }
}
