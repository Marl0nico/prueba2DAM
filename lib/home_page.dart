import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';
import 'tareas_page.dart';
import 'detalle_page.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final supabase = Supabase.instance.client;
  String? username;
  bool loadingProfile = true;
  bool loadingTasks = true;
  bool compartidas=false;
  List<dynamic> tasks = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await fetchUserProfile();
    await fetchTasks();
  }

  Future<void> fetchUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      return;
    }

    try{
      final response =
        await supabase.from('users').select('username').eq('id', user.id).maybeSingle();

      if (response==null){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil de usuario no encontrado.')),
        );
        await supabase.auth.signOut();
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
        return;
      }
      setState(() {
        username = response['username'];
        loadingProfile = false;
      });
    } catch (e){
      setState(() {
        loadingProfile = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar el perfil: $e')),
      );
    }
  }

  Future<void> fetchTasks() async {
  try {
    final userId = supabase.auth.currentUser?.id;
    final data = compartidas
        ? await supabase
            .from('tareas')
            .select('*')
            .eq('compartida', true)
            .order('timestamp', ascending: false)
        : await supabase
            .from('tareas')
            .select('*')
            .eq('user_id', userId!)
            .order('timestamp', ascending: false);

    setState(() {
      tasks = data;
      loadingTasks = false;
    });
  } catch (e) {
    setState(() {
      loadingTasks = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al cargar tareas: $e')),
    );
  }
}




  Future<void> toggleTaskEstado(String taskId, String currentEstado) async {
    try {
      final nuevoEstado = currentEstado == 'pendiente' ? 'completada' : 'pendiente';
      await supabase.from('tareas').update({'estado': nuevoEstado}).eq('id', taskId);
      await fetchTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar estado: $e')),
      );
    }
    
  }

  Future<void> logout() async {
    await supabase.auth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(loadingProfile ? 'Cargando…' : 'Hola, $username'),
        actions: [
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
          IconButton(icon: const Icon(Icons.group),
            tooltip: 'Ver tareas compartidas',
            onPressed: () async {
              compartidas =! !compartidas;
              await fetchTasks();
            },
          ),
        ],
      ),
      body: loadingProfile || loadingTasks
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchTasks,
              child: tasks.isEmpty
                  ? const Center(child: Text('No hay tareas registradas.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Card(
                          child: ListTile(
                            leading: task['foto'] != null && task['foto'].toString().startsWith('http')
                                ? Image.network(task['foto'], width: 60, fit: BoxFit.cover)
                                : const Icon(Icons.image_not_supported),
                            title: Text(task['titulo']),
                            subtitle: Text('Estado: ${task['estado']}'),
                            trailing: IconButton(
                              icon: Icon(
                                task['estado'] == 'completada'
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
                              ),
                              onPressed: () =>
                                  toggleTaskEstado(task['id'], task['estado']),
                            ),
                            onTap: () {
                              Navigator.push(context,
                              MaterialPageRoute(builder: (_)=>DetalleTareaPage(tarea: task)));
                            }
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTaskPage()),
          );
          await fetchTasks();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}
