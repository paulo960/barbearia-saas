import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BarberDashboard extends StatelessWidget {
  final String barbeariaId;
  final String barberId;
  const BarberDashboard({super.key, required this.barbeariaId, required this.barberId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Barbeiro'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('agendamentos')
            .where('barbeiro_id', isEqualTo: barberId)
            .where('status', isEqualTo: 'pendente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ags = snapshot.data?.docs ?? [];

          if (ags.isEmpty) {
            return const Center(child: Text('Nenhum atendimento na sua fila.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ags.length,
            itemBuilder: (ctx, i) {
              final ag = ags[i].data() as Map<String, dynamic>? ?? {};
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFFE0A96D)),
                  title: Text(ag['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${ag['servico']} - ${ag['data_hora']}'),
                  trailing: const Text('Pendente', style: TextStyle(color: Colors.orangeAccent)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
