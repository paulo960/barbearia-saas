// 1. Os Imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;

class ClientesScreen extends StatefulWidget {
  final String barbeariaId;
  const ClientesScreen({super.key, required this.barbeariaId});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _buscaCtrl = TextEditingController();
  String _termoBusca = '';

  void _abrirModalAgendamentoParaCliente(String clienteNome, String clienteTelefone) {
    String? barbeiroId;
    String? barbeiroNome;
    Map<String, dynamic>? barbeiroDados;
    List<String> servsEscolhidos = [];
    double precoTotal = 0.0;
    DateTime dataEscolhida = DateTime.now();
    String horaEscolhida = ''; 

    final listaHorarios = [
      '08:00', '08:30', '09:00', '09:30', '10:00', '10:30',
      '11:00', '11:30', '12:00', '12:30', '13:00', '13:30',
      '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
      '17:00', '17:30', '18:00', '18:30', '19:00', '19:30',
      '20:00', '20:30', '21:00', '21:30'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
         bool barbeiroTrabalhaNesteDia() {
            if (barbeiroDados == null) return true;
            
            // O Dart entende os dias assim: 1 = Segunda ... 6 = Sábado, 7 = Domingo
            final int weekday = dataEscolhida.weekday; 
            
            List<int> diasTrabalho = [];
            
            // Lê exatamente a chave 'dias_trabalho' que a tela de Equipe salva (como números)
            if (barbeiroDados!['dias_trabalho'] != null) {
              diasTrabalho = (barbeiroDados!['dias_trabalho'] as List<dynamic>)
                  .map((e) => int.tryParse(e.toString()) ?? 1)
                  .toList();
            } else {
              // Padrão caso não esteja salvo: segunda a sábado
              diasTrabalho = [1, 2, 3, 4, 5, 6];
            }

            // Verifica se o número do dia escolhido está na lista de dias do barbeiro
            return diasTrabalho.contains(weekday);
          }

          final trabalhaNoDia = barbeiroTrabalhaNesteDia();

          return AlertDialog(
            title: Text('Agendar: $clienteNome', style: const TextStyle(fontSize: 18, color: Color(0xFFE0A96D))),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. Escolha os Serviços:', style: TextStyle(fontWeight: FontWeight.bold)),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('servicos').snapshots(),
                      builder: (ctx, snap) {
                        final servicos = snap.data?.docs ?? [];
                        if (servicos.isEmpty) return const Text('Nenhum serviço cadastrado.');
                        return Column(
                          children: servicos.map((doc) {
                            final s = doc.data() as Map<String, dynamic>;
                            final sNome = s['nome'] ?? '';
                            final sPreco = (s['preco'] as num?)?.toDouble() ?? 0.0;
                            final isSel = servsEscolhidos.contains(sNome);
                            return CheckboxListTile(
                              dense: true,
                              activeColor: const Color(0xFFE0A96D),
                              contentPadding: EdgeInsets.zero,
                              title: Text(sNome),
                              subtitle: Text('R\$ ${sPreco.toStringAsFixed(2)}'),
                              value: isSel,
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    servsEscolhidos.add(sNome);
                                    precoTotal += sPreco;
                                  } else {
                                    servsEscolhidos.remove(sNome);
                                    precoTotal -= sPreco;
                                  }
                                });
                              },
                            );
                          }).toList(),
                        );
                      },
                    ),
                    const Divider(height: 24),
                    const Text('2. Escolha o Barbeiro:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').snapshots(),
                      builder: (ctx, snap) {
                        final barbeiros = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          value: barbeiroId,
                          decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                          items: barbeiros.map((bDoc) {
                            final bData = bDoc.data() as Map<String, dynamic>;
                            return DropdownMenuItem(value: bDoc.id, child: Text(bData['nome'] ?? 'Barbeiro'));
                          }).toList(),
                          onChanged: (val) async {
                            if (val != null) {
                              final docB = await FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').doc(val).get();
                              setModalState(() {
                                barbeiroId = val;
                                barbeiroDados = docB.data() as Map<String, dynamic>?;
                                barbeiroNome = barbeiroDados?['nome'];
                                horaEscolhida = ''; 
                              });
                            }
                          },
                        );
                      },
                    ),
                    const Divider(height: 24),
                    const Text('3. Data:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE0A96D), 
                        side: const BorderSide(color: Color(0xFFE0A96D)),
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(dataEscolhida)),
                      onPressed: () async {
                        final d = await showDatePicker(context: context, initialDate: dataEscolhida, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime(2030), locale: const Locale('pt', 'BR'));
                        if (d != null) {
                          setModalState(() {
                            dataEscolhida = d;
                            horaEscolhida = ''; 
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text('4. Horários Disponíveis:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    
                    if (barbeiroId == null)
                      const Text('Selecione um barbeiro acima.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                    else if (!trabalhaNoDia)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text('🚫 O barbeiro selecionado NÃO atende neste dia da semana (Folga).', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      )
                    else
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(widget.barbeariaId)
                            .collection('agendamentos')
                            .where('barbeiro_id', isEqualTo: barbeiroId)
                            .where('data_iso', isEqualTo: DateFormat('yyyy-MM-dd').format(dataEscolhida))
                            .snapshots(),
                        builder: (ctx, agendSnap) {
                          if (agendSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          List<String> ocupados = [];
                          if (agendSnap.hasData) {
                            for (var doc in agendSnap.data!.docs) {
                              final d = doc.data() as Map<String, dynamic>;
                              if (d['status'] != 'cancelado' && d['horario'] != null) {
                                ocupados.add(d['horario'].toString());
                              }
                            }
                          }

                          final agora = DateTime.now();
                          final isHoje = dataEscolhida.year == agora.year && dataEscolhida.month == agora.month && dataEscolhida.day == agora.day;

                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: listaHorarios.map((hora) {
                              bool isPassadoOuMuitoProximo = false;

                              if (isHoje) {
                                final partes = hora.split(':');
                                final h = int.tryParse(partes[0]) ?? 0;
                                final m = int.tryParse(partes[1]) ?? 0;
                                final dataHoraSlot = DateTime(agora.year, agora.month, agora.day, h, m);

                                if (dataHoraSlot.isBefore(agora)) {
                                  isPassadoOuMuitoProximo = true;
                                }
                              }

                              final isOcupado = ocupados.contains(hora) || isPassadoOuMuitoProximo;
                              final isSelected = horaEscolhida == hora;

                              return ChoiceChip(
                                label: Text(hora),
                                selected: isSelected,
                                selectedColor: const Color(0xFFE0A96D),
                                disabledColor: const Color(0xFF1E1E1E),
                                backgroundColor: const Color(0xFF2C2C2C),
                                labelStyle: TextStyle(
                                  color: isOcupado
                                      ? Colors.grey.shade700
                                      : (isSelected ? Colors.black : Colors.white),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  decoration: isOcupado ? TextDecoration.lineThrough : null,
                                ),
                                onSelected: isOcupado
                                    ? null
                                    : (selected) {
                                        setModalState(() {
                                          horaEscolhida = selected ? hora : '';
                                        });
                                      },
                              );
                            }).toList(),
                          );
                        },
                      ),
                    
                    const SizedBox(height: 16),
                    Text('Total: R\$ ${precoTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
                onPressed: (!trabalhaNoDia || barbeiroId == null || servsEscolhidos.isEmpty || horaEscolhida.isEmpty)
                    ? null
                    : () async {
                        final dataStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(dataEscolhida);
                        final dataHoraCompleta = '$dataStr às $horaEscolhida';

                        await FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('agendamentos').add({
                          'cliente_nome': clienteNome,
                          'cliente_telefone': clienteTelefone,
                          'servico': servsEscolhidos.join(' + '),
                          'preco': precoTotal,
                          'preco_servico': precoTotal,
                          'preco_tabela_original': precoTotal,
                          'preco_produtos': 0.0,
                          'barbeiro_id': barbeiroId,
                          'barbeiro_nome': barbeiroNome,
                          'data_iso': DateFormat('yyyy-MM-dd').format(dataEscolhida),
                          'horario': horaEscolhida,
                          'data_hora': dataHoraCompleta,
                          'status': 'pendente',
                          'repasse_liquidado': false,
                          'criado_em': FieldValue.serverTimestamp(),
                        });

                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agendamento criado com sucesso!'), backgroundColor: Color(0xFF00C853)));
                        }
                      },
                child: const Text('Confirmar Agendamento', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirModalReceberMensalidadeCliente(String clienteId, String clienteNome, String planoNome, double valorPlano) {
    String formaPagamento = 'pix';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Receber Mensalidade • $clienteNome'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Plano: $planoNome', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Valor: R\$ ${valorPlano.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontSize: 18, fontWeight: FontWeight.bold)),
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
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => formaPagamento = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black),
              onPressed: () async {
                final hoje = DateTime.now();
                final novoVencimento = DateFormat('dd/MM/yyyy', 'pt_BR').format(hoje.add(const Duration(days: 30)));

                await FirebaseFirestore.instance
                    .collection('barbearias')
                    .doc(widget.barbeariaId)
                    .collection('mensalidades')
                    .add({
                  'cliente_id': clienteId,
                  'cliente_nome': clienteNome,
                  'plano_nome': planoNome,
                  'valor': valorPlano,
                  'forma_pagamento': formaPagamento,
                  'data_iso': DateFormat('yyyy-MM-dd').format(hoje),
                  'data_formatada': DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(hoje),
                  'criado_em': FieldValue.serverTimestamp(),
                });

                await FirebaseFirestore.instance
                    .collection('barbearias')
                    .doc(widget.barbeariaId)
                    .collection('clientes')
                    .doc(clienteId)
                    .update({
                  'plano_vencimento': novoVencimento,
                });

                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Mensalidade de R\$ ${valorPlano.toStringAsFixed(2)} recebida! Vencimento renovado para $novoVencimento'),
                      backgroundColor: Colors.green.shade800,
                    ),
                  );
                }
              },
              child: const Text('Confirmar Recebimento', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalCliente({String? clienteId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final telefoneCtrl = TextEditingController(text: dadosAtuais?['telefone']?.toString() ?? '');
    final aniversarioCtrl = TextEditingController(text: dadosAtuais?['data_aniversario']?.toString() ?? '');
    final obsCtrl = TextEditingController(text: dadosAtuais?['observacoes']?.toString() ?? '');
    String planoIdSelecionado = dadosAtuais?['plano_id']?.toString() ?? 'nenhum';
    String planoNomeSelecionado = dadosAtuais?['plano_nome']?.toString() ?? '';
    double planoPrecoSelecionado = (dadosAtuais?['plano_preco'] as num?)?.toDouble() ?? 0.0;
    String vencimentoPlano = dadosAtuais?['plano_vencimento']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 30)));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(clienteId == null ? 'Novo Cliente' : 'Editar Cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome do Cliente *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: telefoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp com DDD *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: aniversarioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Data de Aniversário (dd/mm)', 
                    border: OutlineInputBorder(),
                    hintText: 'Ex: 15/05',
                    prefixIcon: Icon(Icons.cake, color: Color(0xFFE0A96D)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Plano de Assinatura Mensal:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 6),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('planos').snapshots(),
                  builder: (context, snap) {
                    final planosDocs = snap.data?.docs ?? [];

                    return DropdownButtonFormField<String>(
                      value: planoIdSelecionado,
                      isExpanded: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: [
                        const DropdownMenuItem(value: 'nenhum', child: Text('Sem Plano (Avulso)')),
                        ...planosDocs.map((pDoc) {
                          final pData = pDoc.data() as Map<String, dynamic>;
                          final pNome = pData['nome']?.toString() ?? 'Plano';
                          final pPreco = (pData['preco_mensal'] as num?)?.toDouble() ?? 0.0;
                          return DropdownMenuItem(
                            value: pDoc.id,
                            child: Text('👑 $pNome (R\$ ${pPreco.toStringAsFixed(2)}/mês)', overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            planoIdSelecionado = val;
                            if (val == 'nenhum') {
                              planoNomeSelecionado = '';
                              planoPrecoSelecionado = 0.0;
                            } else {
                              final docMatch = planosDocs.firstWhere((d) => d.id == val, orElse: () => planosDocs.first);
                              final pData = docMatch.data() as Map<String, dynamic>;
                              planoNomeSelecionado = pData['nome']?.toString() ?? 'Plano';
                              planoPrecoSelecionado = (pData['preco_mensal'] as num?)?.toDouble() ?? 0.0;
                            }
                          });
                        }
                      },
                    );
                  },
                ),
                if (planoIdSelecionado != 'nenhum') ...[
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Data de Vencimento (dd/mm/aaaa)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event, color: Color(0xFFE0A96D)),
                    ),
                    controller: TextEditingController(text: vencimentoPlano),
                    onChanged: (val) => vencimentoPlano = val,
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observações / Preferências', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
              onPressed: () async {
                if (nomeCtrl.text.trim().isNotEmpty && telefoneCtrl.text.trim().isNotEmpty) {
                  final payload = {
                    'nome': nomeCtrl.text.trim(),
                    'telefone': telefoneCtrl.text.trim(),
                    'data_aniversario': aniversarioCtrl.text.trim(),
                    'plano_id': planoIdSelecionado,
                    'plano_nome': planoNomeSelecionado,
                    'plano_preco': planoPrecoSelecionado,
                    'plano_vencimento': planoIdSelecionado != 'nenhum' ? vencimentoPlano : null,
                    'observacoes': obsCtrl.text.trim(),
                    'atualizado_em': FieldValue.serverTimestamp(),
                  };

                  if (clienteId == null) {
                    payload['criado_em'] = FieldValue.serverTimestamp();
                    await FirebaseFirestore.instance
                        .collection('barbearias')
                        .doc(widget.barbeariaId)
                        .collection('clientes')
                        .add(payload);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('barbearias')
                        .doc(widget.barbeariaId)
                        .collection('clientes')
                        .doc(clienteId)
                        .update(payload);
                  }

                  if (context.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirWhatsApp(String telefone, {bool alertaRetorno = false, bool alertaAniversario = false, String nomeCliente = ''}) {
    final cleanPhone = telefone.replaceAll(RegExp(r'\D'), '');
    final urlBase = cleanPhone.startsWith('55') ? 'https://wa.me/$cleanPhone' : 'https://wa.me/55$cleanPhone';
    
    String urlFinal = urlBase;
    
    if (alertaRetorno) {
      final msg = 'Olá $nomeCliente, tudo bem? Aqui é da barbearia. Notamos que já faz um tempinho desde o seu último atendimento com a gente. Que tal agendar um horário para dar aquele trato no visual?';
      urlFinal = '$urlBase?text=${Uri.encodeComponent(msg)}';
    } else if (alertaAniversario) {
      final msg = 'Parabéns, $nomeCliente! 🎂 Toda a equipe da barbearia deseja um feliz aniversário! Para comemorar essa data em grande estilo, que tal dar um trato no visual com a gente?';
      urlFinal = '$urlBase?text=${Uri.encodeComponent(msg)}';
    }
    
    html.window.open(urlFinal, '_blank');
  }

 void _abrirHistoricoCliente(BuildContext context, String nomeCliente) {
    Future<Map<String, dynamic>> buscarHistoricoCompleto() async {
      final db = FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId);

      final snapAgendamentos = await db.collection('agendamentos').where('cliente_nome', isEqualTo: nomeCliente).get();
      final snapMensalidades = await db.collection('mensalidades').where('cliente_nome', isEqualTo: nomeCliente).get();

      List<Map<String, dynamic>> listaMista = [];
      double totalServicos = 0.0;
      double totalProdutos = 0.0;
      double totalPlanos = 0.0;

      // 1. Processa Agendamentos separando Serviço e Produto
      for (var doc in snapAgendamentos.docs) {
        final data = doc.data();
        
        final double precoGeral = (data['preco'] as num?)?.toDouble() ?? 0.0;
        final double valorProdutos = (data['preco_produtos'] as num?)?.toDouble() ?? 0.0;
        // Garante compatibilidade com agendamentos antigos que não tinham o campo preco_servico
        final double valorServico = (data['preco_servico'] as num?)?.toDouble() ?? (precoGeral - valorProdutos);

        totalServicos += valorServico;
        totalProdutos += valorProdutos;

        // Adiciona o card exclusivo do Serviço (se houver valor ou nome)
        if (valorServico > 0 || precoGeral > 0) {
          listaMista.add({
            'titulo': data['servico'] ?? 'Serviço',
            'data_sort': data['data_iso'] ?? '',
            'data_exibicao': data['data_hora'] ?? 'Sem data',
            'valor': valorServico,
            'icone': Icons.content_cut,
            'cor_icone': Colors.white70,
          });
        }

        // Adiciona o card exclusivo dos Produtos (se existirem nesta mesma data)
        if (data['produtos_extras'] != null) {
          List<dynamic> extras = data['produtos_extras'];
          if (extras.isNotEmpty) {
            listaMista.add({
              'titulo': 'Produto(s): ${extras.join(', ')}',
              'data_sort': data['data_iso'] ?? '', 
              'data_exibicao': data['data_hora'] ?? 'Sem data',
              'valor': valorProdutos,
              'icone': Icons.shopping_bag,
              'cor_icone': Colors.blueAccent,
            });
          }
        }
      }

      // 2. Processa Mensalidades (Planos)
      for (var doc in snapMensalidades.docs) {
        final data = doc.data();
        final double valor = (data['valor'] as num?)?.toDouble() ?? 0.0;
        totalPlanos += valor;

        listaMista.add({
          'titulo': 'Assinatura: ${data['plano_nome'] ?? 'Plano'}',
          'data_sort': data['data_iso'] ?? '',
          'data_exibicao': data['data_formatada'] ?? 'Sem data',
          'valor': valor,
          'icone': Icons.workspace_premium,
          'cor_icone': const Color(0xFFE0A96D),
        });
      }

      listaMista.sort((a, b) => b['data_sort'].toString().compareTo(a['data_sort'].toString()));

      return {
        'lista': listaMista,
        'totalGasto': totalServicos + totalProdutos + totalPlanos,
        'totalServicos': totalServicos,
        'totalProdutos': totalProdutos,
        'totalPlanos': totalPlanos,
      };
    }

    final futuroHistorico = buscarHistoricoCompleto();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: FutureBuilder<Map<String, dynamic>>(
            future: futuroHistorico,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE0A96D)));
              }

              final dados = snapshot.data;
              final lista = dados?['lista'] as List<Map<String, dynamic>>? ?? [];
              final totalGasto = dados?['totalGasto'] as double? ?? 0.0;
              final totalServ = dados?['totalServicos'] as double? ?? 0.0;
              final totalProd = dados?['totalProdutos'] as double? ?? 0.0;
              final totalPlan = dados?['totalPlanos'] as double? ?? 0.0;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Histórico: $nomeCliente', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 6),
                              Text('Total Investido: R\$ ${totalGasto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                              const SizedBox(height: 4),
                              // Detalhamento dos gastos
                              Text(
                                'Serviços: R\$ ${totalServ.toStringAsFixed(2)} | Produtos: R\$ ${totalProd.toStringAsFixed(2)}' + 
                                (totalPlan > 0 ? ' | Planos: R\$ ${totalPlan.toStringAsFixed(2)}' : ''),
                                style: const TextStyle(fontSize: 11, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1),
                  
                  if (lista.isEmpty)
                    const Expanded(child: Center(child: Text('Nenhum histórico registrado para este cliente.', style: TextStyle(color: Colors.white70))))
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        itemCount: lista.length,
                        itemBuilder: (context, index) {
                          var item = lista[index];
                          return Card(
                            color: Colors.black38,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: item['cor_icone'].withOpacity(0.2),
                                child: Icon(item['icone'], color: item['cor_icone'], size: 20),
                              ),
                              title: Text(item['titulo'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(item['data_exibicao'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              trailing: Text('R\$ ${item['valor'].toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestão de Clientes & Assinaturas')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirModalCliente(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E1E1E),
            child: TextField(
              controller: _buscaCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar cliente por nome ou WhatsApp...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFE0A96D)),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _buscaCtrl.clear();
                          setState(() => _termoBusca = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onChanged: (val) => setState(() => _termoBusca = val.toLowerCase().trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('barbearias')
                  .doc(widget.barbeariaId)
                  .collection('clientes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todosClientes = snapshot.data?.docs ?? [];
                final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                final hojeStrDiaMes = DateFormat('dd/MM').format(DateTime.now());

                final clientesFiltrados = todosClientes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = data['nome']?.toString().toLowerCase() ?? '';
                  final telefone = data['telefone']?.toString().toLowerCase() ?? '';
                  if (_termoBusca.isEmpty) return true;
                  return nome.contains(_termoBusca) || telefone.contains(_termoBusca);
                }).toList();

                clientesFiltrados.sort((a, b) {
                  final dataA = a.data() as Map<String, dynamic>;
                  final dataB = b.data() as Map<String, dynamic>;
                  
                  bool aPrecisa = (dataA['plano_id'] == 'nenhum' || dataA['plano_id'] == null) && 
                                  dataA['data_limite_retorno'] != null && 
                                  dataA['data_limite_retorno'].toString().compareTo(hojeStr) <= 0;
                                  
                  bool bPrecisa = (dataB['plano_id'] == 'nenhum' || dataB['plano_id'] == null) && 
                                  dataB['data_limite_retorno'] != null && 
                                  dataB['data_limite_retorno'].toString().compareTo(hojeStr) <= 0;

                  if (aPrecisa && !bPrecisa) return -1;
                  if (!aPrecisa && bPrecisa) return 1;
                  return 0;
                });

                if (clientesFiltrados.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('Nenhum cliente cadastrado.', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: clientesFiltrados.length,
                  itemBuilder: (ctx, i) {
                    final cDoc = clientesFiltrados[i];
                    final c = cDoc.data() as Map<String, dynamic>;
                    final id = cDoc.id;
                    final nome = c['nome']?.toString() ?? 'Cliente';
                    final telefone = c['telefone']?.toString() ?? '';
                    final aniversario = c['data_aniversario']?.toString() ?? '';
                    final planoId = c['plano_id']?.toString() ?? 'nenhum';
                    final planoNome = c['plano_nome']?.toString() ?? '';
                    final planoPreco = (c['plano_preco'] as num?)?.toDouble() ?? 0.0;
                    final vencimento = c['plano_vencimento']?.toString() ?? '';
                    final obs = c['observacoes']?.toString() ?? '';
                    final temPlano = planoId != 'nenhum' && planoNome.isNotEmpty;
                    
                    final dataLimite = c['data_limite_retorno']?.toString() ?? '';
                    final precisaRetorno = !temPlano && dataLimite.isNotEmpty && dataLimite.compareTo(hojeStr) <= 0;

                    final ehAniversarioHoje = aniversario.isNotEmpty && aniversario == hojeStrDiaMes;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: (ehAniversarioHoje || precisaRetorno) 
                          ? RoundedRectangleBorder(
                              side: BorderSide(
                                color: ehAniversarioHoje ? Colors.pinkAccent : Colors.orangeAccent, 
                                width: 1.5,
                              ), 
                              borderRadius: BorderRadius.circular(10),
                            ) 
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: temPlano ? const Color(0xFFE0A96D) : const Color(0xFF333333),
                          child: Icon(
                            temPlano ? Icons.workspace_premium : Icons.person,
                            color: temPlano ? Colors.black : Colors.white,
                          ),
                        ),
                        onTap: () => _abrirHistoricoCliente(context, nome),
                        title: Row(
                          children: [
                            Flexible(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                            if (ehAniversarioHoje) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.pink.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.pinkAccent)),
                                child: const Text('🎂 ANIVERSÁRIO HOJE!', style: TextStyle(color: Colors.pinkAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ] else if (temPlano) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0A96D).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE0A96D)),
                                ),
                                child: Text(
                                  planoNome.toUpperCase(),
                                  style: const TextStyle(color: Color(0xFFE0A96D), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (precisaRetorno)
                              const Padding(
                                padding: EdgeInsets.only(top: 4, bottom: 2),
                                child: Text('⚠️ Tempo esgotado! Oferecer retorno.', style: TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                              ),
                            if (telefone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 13, color: Colors.greenAccent),
                                  const SizedBox(width: 4),
                                  Text(telefone, style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                ],
                              ),
                            ],
                            if (temPlano && vencimento.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('Vencimento: $vencimento', style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                            ],
                            if (obs.isNotEmpty)
                              Text('Obs: $obs', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (ehAniversarioHoje && telefone.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.cake, color: Colors.pinkAccent, size: 22),
                                tooltip: 'Enviar Parabéns no WhatsApp',
                                onPressed: () => _abrirWhatsApp(telefone, alertaAniversario: true, nomeCliente: nome),
                              ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month, color: Colors.blueAccent, size: 22),
                              tooltip: 'Agendar Horário para este cliente',
                              onPressed: () => _abrirModalAgendamentoParaCliente(nome, telefone),
                            ),
                            if (temPlano)
                              IconButton(
                                icon: const Icon(Icons.monetization_on, color: Color(0xFF00C853), size: 22),
                                tooltip: 'Receber Mensalidade',
                                onPressed: () => _abrirModalReceberMensalidadeCliente(id, nome, planoNome, planoPreco),
                              ),
                            if (telefone.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.chat, color: precisaRetorno ? Colors.orangeAccent : Colors.greenAccent, size: 20),
                                tooltip: precisaRetorno ? 'Avisar Retorno no WhatsApp' : 'Chamar no WhatsApp',
                                onPressed: () => _abrirWhatsApp(telefone, alertaRetorno: precisaRetorno, nomeCliente: nome),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D), size: 20),
                              tooltip: 'Editar',
                              onPressed: () => _abrirModalCliente(clienteId: id, dadosAtuais: c),
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
      ),
    );
  }
}


  
