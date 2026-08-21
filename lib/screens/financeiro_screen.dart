import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FinanceiroScreen extends StatelessWidget {
  final String barbeariaId;
  const FinanceiroScreen({super.key, required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Financeiro & Repasses')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('financeiro')
            .orderBy('data', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final movimentos = snapshot.data?.docs ?? [];

          if (movimentos.isEmpty) {
            return const Center(child: Text('Nenhuma movimentação financeira registrada.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: movimentos.length,
            itemBuilder: (ctx, i) {
              final m = movimentos[i].data() as Map<String, dynamic>;
              final valor = (m['valor'] as num?)?.toDouble() ?? 0.0;
              final isEntrada = m['tipo'] == 'entrada';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isEntrada ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Icon(
                      isEntrada ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isEntrada ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(m['descricao']?.toString() ?? 'Movimentação'),
                  subtitle: Text(m['data']?.toString() ?? ''),
                  trailing: Text(
                    '${isEntrada ? '+' : '-'} R\$ ${valor.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isEntrada ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
