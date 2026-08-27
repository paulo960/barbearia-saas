import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerServicosTab extends StatelessWidget {
  final String barbeariaId;
  const OwnerServicosTab({required this.barbeariaId});

  void _abrirModalServico(BuildContext context, {String? servicoId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final precoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['preco'] as num?)?.toDouble().toStringAsFixed(2) ?? '' : '');
    final tempoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['duracao_minutos'] ?? 30).toString() : '30');
    final retornoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['dias_retorno'] ?? 0).toString() : '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(servicoId == null ? 'Novo Serviço' : 'Editar Serviço'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome (Ex: Barba Terapia)')),
              TextField(controller: precoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço (R\$)')),
              TextField(controller: tempoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duração (minutos)')),
              TextField(
                controller: retornoCtrl, 
                keyboardType: TextInputType.number, 
                decoration: const InputDecoration(
                  labelText: 'Prazo p/ Retorno (Dias)',
                  helperText: 'Deixe 0 para não gerar alerta',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
            onPressed: () async {
              if (nomeCtrl.text.trim().isNotEmpty && precoCtrl.text.trim().isNotEmpty) {
                final payload = {
                  'nome': nomeCtrl.text.trim(),
                  'preco': double.tryParse(precoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                  'duracao_minutos': int.tryParse(tempoCtrl.text.trim()) ?? 30,
                  'dias_retorno': int.tryParse(retornoCtrl.text.trim()) ?? 0,
                };

                if (servicoId == null) {
                  payload['criado_em'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('servicos').add(payload);
                } else {
                  await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('servicos').doc(servicoId).update(payload);
                }
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirModalServico(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('servicos')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final servicos = snapshot.data?.docs ?? [];

          if (servicos.isEmpty) {
            return const Center(child: Text('Nenhum serviço cadastrado. Toque em + para adicionar.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: servicos.length,
            itemBuilder: (ctx, i) {
              final s = servicos[i].data() as Map<String, dynamic>? ?? {};
              final id = servicos[i].id;
              final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;
              final diasRetorno = s['dias_retorno'] ?? 0;

              return Card(
                child: ListTile(
                  title: Text(s['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${s['duracao_minutos'] ?? 30} min' + (diasRetorno > 0 ? ' • Retorno: $diasRetorno dias' : '')),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('R\$ ${preco.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Color(0xFFE0A96D), fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D)),
                        onPressed: () => _abrirModalServico(context, servicoId: id, dadosAtuais: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(barbeariaId)
                            .collection('servicos')
                            .doc(id)
                            .delete(),
                      ),
                    ],
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