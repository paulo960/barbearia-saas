import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgendaScreen extends StatefulWidget {
  final String barbeariaId;
  const AgendaScreen({super.key, required this.barbeariaId});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  String _filtroDataTipo = 'hoje';
  DateTime _dataEspecifica = DateTime.now();
  String _filtroServico = 'todos';

  Future<void> _selecionarDataCustomizada() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataEspecifica,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE0A96D),
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dataEspecifica = picked;
        _filtroDataTipo = 'custom';
      });
    }
  }

  void _abrirModalConclusaoPagamento(String agendamentoId, String clienteNome, String clienteTelefone, String servicoOriginal, double valorServicoPadrao) async {
    String planoIdCliente = 'nenhum';
    String planoNomeCliente = '';
    List<String> servicosCobertos = [];

    try {
      final qCliente = await FirebaseFirestore.instance
          .collection('barbearias')
          .doc(widget.barbeariaId)
          .collection('clientes')
          .where('telefone', isEqualTo: clienteTelefone)
          .limit(1)
          .get();

      if (qCliente.docs.isNotEmpty) {
        final cData = qCliente.docs.first.data();
        planoIdCliente = cData['plano_id']?.toString() ?? 'nenhum';
        planoNomeCliente = cData['plano_nome']?.toString() ?? '';

        if (planoIdCliente != 'nenhum') {
          final pDoc = await FirebaseFirestore.instance
              .collection('barbearias')
              .doc(widget.barbeariaId)
              .collection('planos')
              .doc(planoIdCliente)
              .get();

          if (pDoc.exists) {
            servicosCobertos = (pDoc.data()?['servicos_cobertos'] as List<dynamic>?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
          }
        }
      }
    } catch (_) {}

    String formaPagamento = 'pix';
    Set<String> servicosSelecionadosIds = {};
    Map<String, Map<String, dynamic>> servicosDocsMap = {};
    Map<String, int> produtosSelecionadosQtd = {};
    Map<String, Map<String, dynamic>> produtosDocsMap = {};
    String? produtoParaAdicionar;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('servicos').snapshots(),
            builder: (context, servSnap) {
              final servDocs = servSnap.data?.docs ?? [];
              for (var sDoc in servDocs) {
                servicosDocsMap[sDoc.id] = sDoc.data() as Map<String, dynamic>;
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('produtos').snapshots(),
                builder: (context, prodSnap) {
                  final prodDocs = prodSnap.data?.docs ?? [];
                  double valorServicosTotal = 0.0;
                  double valorProdutosTotal = 0.0;
                  bool algumServicoCoberto = false;

                  for (var pDoc in prodDocs) {
                    final p = pDoc.data() as Map<String, dynamic>;
                    produtosDocsMap[pDoc.id] = p;
                    final qtd = produtosSelecionadosQtd[pDoc.id] ?? 0;
                    final preco = (p['preco'] as num?)?.toDouble() ?? 0.0;
                    valorProdutosTotal += (preco * qtd);
                  }

                  if (servicosSelecionadosIds.isEmpty) {
                    valorServicosTotal = valorServicoPadrao;
                  } else {
                    for (var sId in servicosSelecionadosIds) {
                      final sData = servicosDocsMap[sId];
                      if (sData != null) {
                        final sNome = (sData['nome']?.toString() ?? '').toLowerCase();
                        final sPreco = (sData['preco'] as num?)?.toDouble() ?? 0.0;

                        bool coberto = false;
                        if (servicosCobertos.isNotEmpty) {
                          coberto = servicosCobertos.any((c) => sNome.contains(c) || c.contains(sNome));
                        } else if (planoIdCliente != 'nenhum') {
                          if (planoNomeCliente.toLowerCase().contains('corte') && sNome.contains('corte')) coberto = true;
                          if (planoNomeCliente.toLowerCase().contains('barba') && sNome.contains('barba')) coberto = true;
                        }

                        if (coberto) {
                          algumServicoCoberto = true;
                        } else {
                          valorServicosTotal += sPreco;
                        }
                      }
                    }
                  }

                  final valorFinalTotal = valorServicosTotal + valorProdutosTotal;

                  return AlertDialog(
                    title: const Text('Concluir Atendimento'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cliente: $clienteNome', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 10),
                            const Text('Serviços do Atendimento:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade800),
                              ),
                              child: Column(
                                children: servDocs.map((sDoc) {
                                  final sId = sDoc.id;
                                  final sData = sDoc.data() as Map<String, dynamic>;
                                  final sNome = sData['nome']?.toString() ?? 'Serviço';
                                  final sPreco = (sData['preco'] as num?)?.toDouble() ?? 0.0;
                                  final selecionado = servicosSelecionadosIds.contains(sId);

                                  return CheckboxListTile(
                                    title: Text(sNome, style: const TextStyle(fontSize: 13)),
                                    subtitle: Text('R\$ ${sPreco.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Color(0xFFE0A96D))),
                                    value: selecionado,
                                    activeColor: const Color(0xFFE0A96D),
                                    checkColor: Colors.black,
                                    dense: true,
                                    onChanged: (bool? val) {
                                      setModalState(() {
                                        if (val == true) {
                                          servicosSelecionadosIds.add(sId);
                                        } else {
                                          servicosSelecionadosIds.remove(sId);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            if (algumServicoCoberto) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFFE0A96D).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: Text('★ SERVIÇO COBERTO PELO PLANO ($planoNomeCliente)', style: const TextStyle(color: Color(0xFFE0A96D), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total a Cobrar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('R\$ ${valorFinalTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontSize: 18, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Text('Adicionar Produto da Barbearia:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: produtoParaAdicionar,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Selecione um Produto',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.shopping_bag_outlined, color: Color(0xFFE0A96D)),
                              ),
                              hint: const Text('Toque para escolher um produto'),
                              items: [
                                ...prodDocs.map((pDoc) {
                                  final p = pDoc.data() as Map<String, dynamic>;
                                  final pNome = p['nome']?.toString() ?? 'Produto';
                                  final pPreco = (p['preco'] as num?)?.toDouble() ?? 0.0;
                                  final pEstoque = (p['estoque'] as num?)?.toInt() ?? 0;
                                  final esgotado = pEstoque <= 0;

                                  return DropdownMenuItem<String>(
                                    value: pDoc.id,
                                    enabled: !esgotado,
                                    child: Text(
                                      esgotado ? '$pNome (Esgotado)' : '$pNome - R\$ ${pPreco.toStringAsFixed(2)} (Est: $pEstoque)',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: esgotado ? Colors.grey : Colors.white),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (novoProdId) {
                                if (novoProdId != null) {
                                  setModalState(() {
                                    final qtdAtual = produtosSelecionadosQtd[novoProdId] ?? 0;
                                    final pEstoque = (produtosDocsMap[novoProdId]?['estoque'] as num?)?.toInt() ?? 0;
                                    if (pEstoque > qtdAtual) {
                                      produtosSelecionadosQtd[novoProdId] = qtdAtual + 1;
                                    }
                                    produtoParaAdicionar = null;
                                  });
                                }
                              },
                            ),
                            if (produtosSelecionadosQtd.values.any((q) => q > 0)) ...[
                              const SizedBox(height: 12),
                              const Text('Itens Selecionados:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 6),
                              ...produtosSelecionadosQtd.entries.where((e) => e.value > 0).map((entry) {
                                final p = produtosDocsMap[entry.key];
                                final pNome = p?['nome']?.toString() ?? 'Produto';
                                final pPreco = (p?['preco'] as num?)?.toDouble() ?? 0.0;
                                final pEstoque = (p?['estoque'] as num?)?.toInt() ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262626),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey.shade800),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(pNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            Text('R\$ ${(pPreco * entry.value).toStringAsFixed(2)} (${entry.value}x)', style: const TextStyle(fontSize: 11, color: Color(0xFFE0A96D))),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.redAccent),
                                            onPressed: () {
                                              setModalState(() {
                                                if (entry.value > 1) {
                                                  produtosSelecionadosQtd[entry.key] = entry.value - 1;
                                                } else {
                                                  produtosSelecionadosQtd.remove(entry.key);
                                                }
                                              });
                                            },
                                          ),
                                          Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF00C853)),
                                            onPressed: (pEstoque > entry.value)
                                                ? () {
                                                    setModalState(() {
                                                      produtosSelecionadosQtd[entry.key] = entry.value + 1;
                                                    });
                                                  }
                                                : null,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                            onPressed: () {
                                              setModalState(() {
                                                produtosSelecionadosQtd.remove(entry.key);
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                            const SizedBox(height: 16),
                            const Text('Forma de Pagamento:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              value: formaPagamento,
                              decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                              items: const [
                                DropdownMenuItem(value: 'pix', child: Text('⚡ Pix')),
                                DropdownMenuItem(value: 'dinheiro', child: Text('💵 Dinheiro')),
                                DropdownMenuItem(value: 'cartao', child: Text('💳 Cartão')),
                                DropdownMenuItem(value: 'plano_mensal', child: Text('👑 Plano Mensal (Sem Cobrança)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setModalState(() => formaPagamento = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black),
                        onPressed: () async {
                          Navigator.pop(ctx);

                          List<String> nomesServicosSelecionados = [];
                          if (servicosSelecionadosIds.isEmpty) {
                            nomesServicosSelecionados.add(servicoOriginal);
                          } else {
                            for (var sId in servicosSelecionadosIds) {
                              final sInfo = servicosDocsMap[sId];
                              if (sInfo != null) {
                                nomesServicosSelecionados.add(sInfo['nome']?.toString() ?? 'Serviço');
                              }
                            }
                          }

                          List<String> nomesProdutosVendidos = [];
                          for (var entry in produtosSelecionadosQtd.entries) {
                            if (entry.value > 0) {
                              final prodInfo = produtosDocsMap[entry.key];
                              final nome = prodInfo?['nome'] ?? 'Produto';
                              final estoqueAtual = (prodInfo?['estoque'] as num?)?.toInt() ?? 0;
                              nomesProdutosVendidos.add('${entry.value}x $nome');

                              await FirebaseFirestore.instance
                                  .collection('barbearias')
                                  .doc(widget.barbeariaId)
                                  .collection('produtos')
                                  .doc(entry.key)
                                  .update({
                                'estoque': (estoqueAtual - entry.value).clamp(0, 999999),
                              });
                            }
                          }

                          await FirebaseFirestore.instance
                              .collection('barbearias')
                              .doc(widget.barbeariaId)
                              .collection('agendamentos')
                              .doc(agendamentoId)
                              .update({
                            'status': 'concluido',
                            'servico': nomesServicosSelecionados.join(', '),
                            'servicos_lista': nomesServicosSelecionados,
                            'preco': valorFinalTotal,
                            'preco_servico': valorServicosTotal,
                            'preco_tabela_original': valorServicoPadrao,
                            'preco_produtos': valorProdutosTotal,
                            'coberto_por_plano': algumServicoCoberto,
                            'forma_pagamento': algumServicoCoberto && valorProdutosTotal == 0 ? 'plano_mensal' : formaPagamento,
                            'produtos_extras': nomesProdutosVendidos,
                            'repasse_liquidado': false,
                            'concluido_em': FieldValue.serverTimestamp(),
                          });

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Atendimento de R\$ ${valorFinalTotal.toStringAsFixed(2)} finalizado com sucesso!'),
                                backgroundColor: Colors.green.shade800,
                              ),
                            );
                          }
                        },
                        child: const Text('Finalizar e Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hojeStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(DateTime.now());
    final amanhaStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(DateTime.now().add(const Duration(days: 1)));
    final customStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(_dataEspecifica);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('servicos').snapshots(),
      builder: (context, servicosSnap) {
        final servicosDocs = servicosSnap.data?.docs ?? [];

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF1A1A1A),
              child: Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Hoje'),
                          selected: _filtroDataTipo == 'hoje',
                          selectedColor: const Color(0xFFE0A96D),
                          labelStyle: TextStyle(color: _filtroDataTipo == 'hoje' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                          onSelected: (s) => setState(() => _filtroDataTipo = 'hoje'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Amanhã'),
                          selected: _filtroDataTipo == 'amanha',
                          selectedColor: const Color(0xFFE0A96D),
                          labelStyle: TextStyle(color: _filtroDataTipo == 'amanha' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                          onSelected: (s) => setState(() => _filtroDataTipo = 'amanha'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: _filtroDataTipo == 'todos',
                          selectedColor: const Color(0xFFE0A96D),
                          labelStyle: TextStyle(color: _filtroDataTipo == 'todos' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                          onSelected: (s) => setState(() => _filtroDataTipo = 'todos'),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.calendar_month, size: 16, color: Color(0xFFE0A96D)),
                          label: Text(_filtroDataTipo == 'custom' ? customStr : 'Outra Data'),
                          backgroundColor: _filtroDataTipo == 'custom' ? const Color(0xFFE0A96D).withOpacity(0.2) : const Color(0xFF2C2C2C),
                          side: BorderSide(color: _filtroDataTipo == 'custom' ? const Color(0xFFE0A96D) : Colors.transparent),
                          onPressed: _selecionarDataCustomizada,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _filtroServico,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por Serviço',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: 'todos', child: Text('Todos os Serviços')),
                      ...servicosDocs.map((sDoc) {
                        final sData = sDoc.data() as Map<String, dynamic>;
                        final sNome = sData['nome']?.toString() ?? 'Serviço';
                        return DropdownMenuItem(value: sNome, child: Text(sNome));
                      }),
                    ],
                    onChanged: (val) => setState(() => _filtroServico = val ?? 'todos'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('barbearias')
                    .doc(widget.barbeariaId)
                    .collection('agendamentos')
                    .where('status', isEqualTo: 'pendente')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final ags = snapshot.data?.docs ?? [];

                  final agendamentosFiltrados = ags.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final dHora = d['data_hora']?.toString() ?? '';
                    final servicoNome = d['servico']?.toString() ?? '';

                    if (_filtroServico != 'todos' && !servicoNome.contains(_filtroServico)) {
                      return false;
                    }

                    if (_filtroDataTipo == 'todos') return true;
                    if (_filtroDataTipo == 'hoje') return dHora.contains(hojeStr) || dHora.toLowerCase().contains('hoje');
                    if (_filtroDataTipo == 'amanha') return dHora.contains(amanhaStr);
                    if (_filtroDataTipo == 'custom') return dHora.contains(customStr);
                    return true;
                  }).toList();

                  if (agendamentosFiltrados.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('Nenhum agendamento pendente nesta data/filtro.', style: TextStyle(color: Colors.grey)),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: agendamentosFiltrados.length,
                    itemBuilder: (ctx, i) {
                      final ag = agendamentosFiltrados[i].data() as Map<String, dynamic>? ?? {};
                      final id = agendamentosFiltrados[i].id;
                      final clienteNome = ag['cliente_nome']?.toString() ?? 'Cliente';
                      final clienteTelefone = ag['cliente_telefone']?.toString() ?? '';
                      final servicoNome = ag['servico']?.toString() ?? 'Serviço';
                      final preco = (ag['preco'] as num?)?.toDouble() ?? 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(clienteNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('R\$ ${preco.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text('$servicoNome • ${ag['barbeiro_nome']}', style: const TextStyle(color: Colors.grey)),
                              Text('Horário: ${ag['data_hora'] ?? '-'}', style: const TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold)),
                              if (clienteTelefone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.greenAccent),
                                    const SizedBox(width: 4),
                                    Text(clienteTelefone, style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
                                      icon: const Icon(Icons.close, size: 16),
                                      label: const Text('Cancelar'),
                                      onPressed: () {
                                        FirebaseFirestore.instance
                                            .collection('barbearias')
                                            .doc(widget.barbeariaId)
                                            .collection('agendamentos')
                                            .doc(id)
                                            .update({'status': 'cancelado'});
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black),
                                      icon: const Icon(Icons.check, size: 16),
                                      label: const Text('Concluir', style: TextStyle(fontWeight: FontWeight.bold)),
                                      onPressed: () => _abrirModalConclusaoPagamento(id, clienteNome, clienteTelefone, servicoNome, preco),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
