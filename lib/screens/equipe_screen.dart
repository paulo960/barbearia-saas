import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EquipeScreen extends StatefulWidget {
  final String barbeariaId;
  const EquipeScreen({super.key, required this.barbeariaId});

  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  void _abrirModalBarbeiro({String? barbeiroId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final telefoneCtrl = TextEditingController(text: dadosAtuais?['telefone']?.toString() ?? '');
    final comissaoCtrl = TextEditingController(text: dadosAtuais?['comissao_percentual']?.toString() ?? '50');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(barbeiroId == null ? 'Novo Profissional' : 'Editar Profissional'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeCtrl,
              decoration: const InputDecoration(labelText: 'Nome do Barbeiro', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: telefoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp / Telefone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: comissaoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Comissão (%)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
            onPressed: () async {
              final nome = nomeCtrl.text.trim();
              final telefone = telefoneCtrl.text.trim();
              final comissao = double.tryParse(comissaoCtrl.text.replaceAll(',', '.')) ?? 50.0;

              if (nome.isNotEmpty) {
                final payload = {
                  'nome': nome,
                  'telefone': telefone,
                  'comissao_percentual': comissao,
                  'atualizado_em': FieldValue.serverTimestamp(),
                };

                if (barbeiroId == null) {
                  payload['criado_em'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('barbeiros')
                      .add(payload);
                } else {
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('barbeiros')
                      .doc(barbeiroId)
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
      appBar: AppBar(title: const Text('Gestão de Equipe & Comissões')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirModalBarbeiro(),
        child: const Icon(Icons.person_add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(widget.barbeariaId)
            .collection('barbeiros')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final barbeiros = snapshot.data?.docs ?? [];

          if (barbeiros.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text('Nenhum profissional cadastrado na equipe.', style: TextStyle(color: Colors.grey)),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: barbeiros.length,
            itemBuilder: (ctx, i) {
              final bDoc = barbeiros[i];
              final b = bDoc.data() as Map<String, dynamic>;
              final id = bDoc.id;
              final nome = b['nome']?.toString() ?? 'Profissional';
              final telefone = b['telefone']?.toString() ?? '';
              final comissao = (b['comissao_percentual'] as num?)?.toDouble() ?? 50.0;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF2C2C2C),
                    child: Icon(Icons.badge, color: Color(0xFFE0A96D)),
                  ),
                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text('Comissão: ${comissao.toStringAsFixed(0)}%', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
                      if (telefone.isNotEmpty)
                        Text('Tel: $telefone', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D), size: 20),
                        tooltip: 'Editar',
                        onPressed: () => _abrirModalBarbeiro(barbeiroId: id, dadosAtuais: b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        tooltip: 'Excluir',
                        onPressed: () => FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(widget.barbeariaId)
                            .collection('barbeiros')
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
