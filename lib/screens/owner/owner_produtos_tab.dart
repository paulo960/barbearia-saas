import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerProdutosTab extends StatelessWidget {
  final String barbeariaId;
  const OwnerProdutosTab({super.key, required this.barbeariaId});

  void _abrirModalProduto(BuildContext context, {String? produtoId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final precoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['preco'] as num?)?.toDouble().toStringAsFixed(2) ?? '' : '');
    final custoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['custo'] as num?)?.toDouble().toStringAsFixed(2) ?? '' : '');
    final estoqueCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['estoque'] as num?)?.toInt().toString() ?? '10' : '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(produtoId == null ? 'Novo Produto' : 'Editar Produto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do Produto (Ex: Pomada Efeito Matte)')),
              const SizedBox(height: 8),
              TextField(controller: precoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço de Venda (R\$)')),
              const SizedBox(height: 8),
              TextField(controller: custoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço de Custo (Opcional)')),
              const SizedBox(height: 8),
              TextField(controller: estoqueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade em Estoque')),
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
                  'custo': double.tryParse(custoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                  'estoque': int.tryParse(estoqueCtrl.text.trim()) ?? 0,
                };

                if (produtoId == null) {
                  payload['criado_em'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(barbeariaId)
                      .collection('produtos')
                      .add(payload);
                } else {
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(barbeariaId)
                      .collection('produtos')
                      .doc(produtoId)
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
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirModalProduto(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('produtos')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final produtos = snapshot.data?.docs ?? [];

          if (produtos.isEmpty) {
            return const Center(child: Text('Nenhum produto cadastrado no estoque. Toque em + para adicionar.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: produtos.length,
            itemBuilder: (ctx, i) {
              final p = produtos[i].data() as Map<String, dynamic>? ?? {};
              final id = produtos[i].id;
              final preco = (p['preco'] as num?)?.toDouble() ?? 0.0;
              final estoque = (p['estoque'] as num?)?.toInt() ?? 0;
              final esgotado = estoque <= 0;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esgotado ? Colors.red.withOpacity(0.2) : const Color(0xFFE0A96D).withOpacity(0.2),
                    child: Icon(Icons.inventory_2, color: esgotado ? Colors.redAccent : const Color(0xFFE0A96D)),
                  ),
                  title: Text(p['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Estoque: $estoque unidades • Venda: R\$ ${preco.toStringAsFixed(2)}', style: TextStyle(color: esgotado ? Colors.redAccent : Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D)),
                        onPressed: () => _abrirModalProduto(context, produtoId: id, dadosAtuais: p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(barbeariaId)
                            .collection('produtos')
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