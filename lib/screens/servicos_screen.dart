import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServicosScreen extends StatefulWidget {
  final String barbeariaId;
  const ServicosScreen({super.key, required this.barbeariaId});

  @override
  State<ServicosScreen> createState() => _ServicosScreenState();
}

class _ServicosScreenState extends State<ServicosScreen> {
  void _abrirModalServico({String? servicoId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final precoCtrl = TextEditingController(text: dadosAtuais?['preco']?.toString() ?? '');
    final duracaoCtrl = TextEditingController(text: dadosAtuais?['duracao_minutos']?.toString() ?? '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(servicoId == null ? 'Novo Serviço' : 'Editar Serviço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome do Serviço', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: precoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Preço (R\$)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: duracaoCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Duração (minutos)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
            onPressed: () async {
              final nome = nomeCtrl.text.trim();
              final preco = double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final duracao = int.tryParse(duracaoCtrl.text) ?? 30;

              if (nome.isNotEmpty) {
                final payload = {
                  'nome': nome,
                  'preco': preco,
                  'duracao_minutos': duracao,
                  'atualizado_em': FieldValue.serverTimestamp(),
                };

                if (servicoId == null) {
                  payload['criado_em'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('servicos')
                      .add(payload);
                } else {
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('servicos')
                      .doc(servicoId)
                      .update(payload);
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
      appBar: AppBar(title: const Text('Gestão de Serviços')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirModalServico(),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(widget.barbeariaId)
            .collection('servicos')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final servicos = snapshot.data?.docs ?? [];

          if (servicos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Nenhum serviço cadastrado.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: servicos.length,
            itemBuilder: (ctx, i) {
              final sDoc = servicos[i];
              final s = sDoc.data() as Map<String, dynamic>;
              final id = sDoc.id;
              final nome = s['nome']?.toString() ?? 'Serviço';
              final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;
              final duracao = (s['duracao_minutos'] as num?)?.toInt() ?? 30;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2C2C2C),
                    child: Icon(Icons.content_cut, color: Color(0xFFE0A96D)),
                  ),
                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text('Preço: R\$ ${preco.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
                      Text('Duração: $duracao minutos', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D), size: 20),
                        tooltip: 'Editar',
                        onPressed: () => _abrirModalServico(servicoId: id, dadosAtuais: s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Excluir',
                        onPressed: () => FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(widget.barbeariaId)
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
