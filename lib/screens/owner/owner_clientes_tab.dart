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

  // ============================================================
  // FUNÇÕES ORIGINAIS — INTACTAS
  // ============================================================

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
            final int weekday = dataEscolhida.weekday;
            List<int> diasTrabalho = [];
            if (barbeiroDados!['dias_trabalho'] != null) {
              diasTrabalho = (barbeiroDados!['dias_trabalho'] as List<dynamic>)
                  .map((e) => int.tryParse(e.toString()) ?? 1)
                  .toList();
            } else {
              diasTrabalho = [1, 2, 3, 4, 5, 6];
            }
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
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
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

// >>> CONTINUA NA PARTE 2/3 <<<

  // ============================================================
  // MODAL EDITAR CLIENTE — REESTILIZADO (visual novo)
  // ============================================================

  void _abrirModalCliente({String? clienteId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final telefoneCtrl = TextEditingController(text: dadosAtuais?['telefone']?.toString() ?? '');
    final aniversarioCtrl = TextEditingController(text: dadosAtuais?['data_aniversario']?.toString() ?? '');
    final obsCtrl = TextEditingController(text: dadosAtuais?['observacoes']?.toString() ?? '');
    String planoIdSelecionado = dadosAtuais?['plano_id']?.toString() ?? 'nenhum';
    String planoNomeSelecionado = dadosAtuais?['plano_nome']?.toString() ?? '';
    double planoPrecoSelecionado = (dadosAtuais?['plano_preco'] as num?)?.toDouble() ?? 0.0;
    String vencimentoPlano = dadosAtuais?['plano_vencimento']?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now().add(const Duration(days: 30)));

    final editando = clienteId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header (só em edição)
                  if (editando) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF2A2A2A),
                          child: const Icon(Icons.person_outline, color: Colors.white70, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomeCtrl.text.isEmpty ? 'Cliente' : nomeCtrl.text,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _mascararTelefone(telefoneCtrl.text),
                                style: const TextStyle(fontSize: 14, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  Text(
                    editando ? 'Editar cliente' : 'Novo cliente',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Campo Nome
                  _buildCampoNovo(
                    label: 'Nome',
                    controller: nomeCtrl,
                  ),
                  const SizedBox(height: 12),

                  // Campo WhatsApp
                  _buildCampoNovo(
                    label: 'WhatsApp com DDD',
                    controller: telefoneCtrl,
                    keyboardType: TextInputType.phone,
                    icon: Icons.chat_bubble_outline,
                  ),
                  const SizedBox(height: 12),

                  // Campo Aniversário
                  _buildCampoNovo(
                    label: 'Aniversário',
                    controller: aniversarioCtrl,
                    icon: Icons.cake_outlined,
                    hint: 'dd/mm',
                  ),
                  const SizedBox(height: 20),

                  // Planos como chips
                  const Text(
                    'Plano de assinatura',
                    style: TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                  const SizedBox(height: 10),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('barbearias')
                        .doc(widget.barbeariaId)
                        .collection('planos')
                        .snapshots(),
                    builder: (context, snap) {
                      final planosDocs = snap.data?.docs ?? [];
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChipPlano(
                            label: 'Sem plano (avulso)',
                            selecionado: planoIdSelecionado == 'nenhum',
                            onTap: () {
                              setModalState(() {
                                planoIdSelecionado = 'nenhum';
                                planoNomeSelecionado = '';
                                planoPrecoSelecionado = 0.0;
                              });
                            },
                          ),
                          ...planosDocs.map((pDoc) {
                            final pData = pDoc.data() as Map<String, dynamic>;
                            final pNome = pData['nome']?.toString() ?? 'Plano';
                            final pPreco = (pData['preco_mensal'] as num?)?.toDouble() ?? 0.0;
                            return _buildChipPlano(
                              label: pNome,
                              selecionado: planoIdSelecionado == pDoc.id,
                              onTap: () {
                                setModalState(() {
                                  planoIdSelecionado = pDoc.id;
                                  planoNomeSelecionado = pNome;
                                  planoPrecoSelecionado = pPreco;
                                });
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),

                  if (planoIdSelecionado != 'nenhum') ...[
                    const SizedBox(height: 12),
                    _buildCampoNovo(
                      label: 'Vencimento do plano',
                      controller: TextEditingController(text: vencimentoPlano),
                      icon: Icons.event_outlined,
                      onChanged: (val) => vencimentoPlano = val,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Observações
                  _buildCampoNovo(
                    label: 'Observações',
                    controller: obsCtrl,
                    icon: Icons.sticky_note_2_outlined,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 24),

                  // Botões
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (nomeCtrl.text.trim().isEmpty || telefoneCtrl.text.trim().isEmpty) return;

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
                          },
                          child: const Text('Salvar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPERS VISUAIS
  // ============================================================

  Widget _buildCampoNovo({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    IconData? icon,
    String? hint,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white54, size: 20) : null,
        filled: true,
        fillColor: const Color(0xFF232323),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0A96D), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildChipPlano({
    required String label,
    required bool selecionado,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selecionado ? Colors.white : const Color(0xFF232323),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selecionado ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  String _mascararTelefone(String telefone) {
    final digits = telefone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return telefone;

    // Formato: (62) 9••••-4475
    if (digits.length == 11) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 3)}••••-${digits.substring(7)}';
    }
    // Fixo: (62) 3•••-4475
    if (digits.length == 10) {
      return '(${digits.substring(0, 2)}) ${digits.substring(2, 3)}•••-${digits.substring(6)}';
    }
    return telefone;
  }

  // ============================================================
  // EXCLUIR CLIENTE
  // ============================================================

  Future<void> _excluirCliente(String clienteId, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir cliente'),
        content: Text('Tem certeza que deseja excluir "$nome"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('barbearias')
          .doc(widget.barbeariaId)
          .collection('clientes')
          .doc(clienteId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente excluído.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }

  // ============================================================
  // MENU DE AÇÕES (bottom sheet)
  // ============================================================

  void _abrirMenuAcoes({
    required String id,
    required Map<String, dynamic> cliente,
  }) {
    final nome = cliente['nome']?.toString() ?? 'Cliente';
    final telefone = cliente['telefone']?.toString() ?? '';
    final planoId = cliente['plano_id']?.toString() ?? 'nenhum';
    final planoNome = cliente['plano_nome']?.toString() ?? '';
    final planoPreco = (cliente['plano_preco'] as num?)?.toDouble() ?? 0.0;
    final temPlano = planoId != 'nenhum' && planoNome.isNotEmpty;
    final precisaRetorno = _clientePrecisaRetorno(cliente);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF2A2A2A),
                    child: const Icon(Icons.person_outline, color: Colors.white70, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _mascararTelefone(telefone),
                          style: const TextStyle(fontSize: 14, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Ações
            _buildMenuAction(
              icon: Icons.edit_outlined,
              label: 'Editar cliente',
              onTap: () {
                Navigator.pop(ctx);
                _abrirModalCliente(clienteId: id, dadosAtuais: cliente);
              },
            ),
            _buildMenuAction(
              icon: Icons.calendar_month_outlined,
              label: 'Agendar atendimento',
              onTap: () {
                Navigator.pop(ctx);
                _abrirModalAgendamentoParaCliente(nome, telefone);
              },
            ),
            if (temPlano)
              _buildMenuAction(
                icon: Icons.monetization_on_outlined,
                label: 'Receber mensalidade',
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirModalReceberMensalidadeCliente(id, nome, planoNome, planoPreco);
                },
              ),
            _buildMenuAction(
              icon: Icons.chat_bubble_outline,
              label: 'Enviar mensagem',
              onTap: () {
                Navigator.pop(ctx);
                _abrirWhatsApp(telefone, alertaRetorno: precisaRetorno, nomeCliente: nome);
              },
            ),
            _buildMenuAction(
              icon: Icons.history,
              label: 'Ver histórico',
              onTap: () {
                Navigator.pop(ctx);
                _abrirHistoricoCliente(context, nome);
              },
            ),

            const Divider(color: Colors.white12, height: 1),

            _buildMenuAction(
              icon: Icons.delete_outline,
              label: 'Excluir cliente',
              corTexto: Colors.redAccent,
              corIcone: Colors.redAccent,
              onTap: () {
                Navigator.pop(ctx);
                _excluirCliente(id, nome);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color corIcone = Colors.white70,
    Color corTexto = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: corIcone, size: 24),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(color: corTexto, fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

// >>> CONTINUA NA PARTE 3/3 <<<

  // ============================================================
  // LÓGICA DE "ATENÇÃO"
  // ============================================================

  bool _clientePrecisaRetorno(Map<String, dynamic> c) {
    final planoId = c['plano_id']?.toString() ?? 'nenhum';
    final temPlano = planoId != 'nenhum' && (c['plano_nome']?.toString() ?? '').isNotEmpty;
    if (temPlano) return false;

    final dataLimite = c['data_limite_retorno']?.toString() ?? '';
    if (dataLimite.isEmpty) return false;

    final hojeStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return dataLimite.compareTo(hojeStr) <= 0;
  }

  int _diasSemVoltar(Map<String, dynamic> c) {
    final dataLimite = c['data_limite_retorno']?.toString() ?? '';
    if (dataLimite.isEmpty) return 0;

    try {
      final limite = DateTime.parse(dataLimite);
      final hoje = DateTime.now();
      final diff = hoje.difference(limite).inDays;
      return diff < 0 ? 0 : diff;
    } catch (_) {
      return 0;
    }
  }

  bool _ehAniversarioHoje(Map<String, dynamic> c) {
    final aniversario = c['data_aniversario']?.toString() ?? '';
    if (aniversario.isEmpty) return false;

    final hojeStrDiaMes = DateFormat('dd/MM').format(DateTime.now());
    return aniversario == hojeStrDiaMes;
  }

  // ============================================================
  // WHATSAPP — ORIGINAL
  // ============================================================

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

  // ============================================================
  // HISTÓRICO — ORIGINAL
  // ============================================================

  void _abrirHistoricoCliente(BuildContext context, String nomeCliente) {
    Future<Map<String, dynamic>> buscarHistoricoCompleto() async {
      final db = FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId);

      final snapAgendamentos = await db.collection('agendamentos').where('cliente_nome', isEqualTo: nomeCliente).get();
      final snapMensalidades = await db.collection('mensalidades').where('cliente_nome', isEqualTo: nomeCliente).get();

      List<Map<String, dynamic>> listaMista = [];
      double totalServicos = 0.0;
      double totalProdutos = 0.0;
      double totalPlanos = 0.0;

      for (var doc in snapAgendamentos.docs) {
        final data = doc.data();

        final double precoGeral = (data['preco'] as num?)?.toDouble() ?? 0.0;
        final double valorProdutos = (data['preco_produtos'] as num?)?.toDouble() ?? 0.0;
        final double valorServico = (data['preco_servico'] as num?)?.toDouble() ?? (precoGeral - valorProdutos);

        totalServicos += valorServico;
        totalProdutos += valorProdutos;

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
                                backgroundColor: (item['cor_icone'] as Color).withValues(alpha: 0.2),
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

  // ============================================================
  // WIDGET DE ITEM DA LISTA (visual novo)
  // ============================================================

  Widget _buildClienteItem({
    required String id,
    required Map<String, dynamic> cliente,
  }) {
    final nome = cliente['nome']?.toString() ?? 'Cliente';
    final telefone = cliente['telefone']?.toString() ?? '';
    final ehAniversario = _ehAniversarioHoje(cliente);
    final precisaRetorno = _clientePrecisaRetorno(cliente);
    final diasSemVoltar = _diasSemVoltar(cliente);

    // Define cor do badge circular do avatar
    Color corBadge;
    IconData iconeBadge;
    if (ehAniversario) {
      corBadge = Colors.blue;
      iconeBadge = Icons.cake;
    } else if (precisaRetorno) {
      corBadge = Colors.orange;
      iconeBadge = Icons.access_time_filled;
    } else {
      corBadge = Colors.transparent;
      iconeBadge = Icons.person;
    }

    return InkWell(
      onTap: () => _abrirMenuAcoes(id: id, cliente: cliente),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar com badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF2A2A2A),
                  child: const Icon(Icons.person_outline, color: Colors.white70, size: 24),
                ),
                if (ehAniversario || precisaRetorno)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: corBadge,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF121212), width: 2),
                      ),
                      child: Icon(iconeBadge, size: 11, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Nome + telefone + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _mascararTelefone(telefone),
                    style: const TextStyle(fontSize: 13, color: Colors.white54),
                  ),
                  if (precisaRetorno && !ehAniversario) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 13, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Sem voltar há $diasSemVoltar dias',
                          style: const TextStyle(fontSize: 12, color: Colors.orangeAccent, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ] else if (ehAniversario) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.card_giftcard, size: 13, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Aniversário é hoje 🎉',
                          style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Ação à direita: WhatsApp (aniversário) OU menu ⋮
            if (ehAniversario && telefone.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.chat_bubble, color: Colors.blue),
                tooltip: 'Enviar parabéns',
                onPressed: () => _abrirWhatsApp(telefone, alertaAniversario: true, nomeCliente: nome),
              )
            else
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                tooltip: 'Mais opções',
                onPressed: () => _abrirMenuAcoes(id: id, cliente: cliente),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: const Text('Gestão de Clientes & Assinaturas'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirModalCliente(),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          // Barra de busca
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            color: const Color(0xFF121212),
            child: TextField(
              controller: _buscaCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou WhatsApp',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                suffixIcon: _termoBusca.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54),
                        onPressed: () {
                          _buscaCtrl.clear();
                          setState(() => _termoBusca = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E1E1E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _termoBusca = val.toLowerCase().trim()),
            ),
          ),

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('barbearias')
                  .doc(widget.barbeariaId)
                  .collection('clientes')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE0A96D)));
                }

                final todosClientes = snapshot.data?.docs ?? [];

                final clientesFiltrados = todosClientes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = data['nome']?.toString().toLowerCase() ?? '';
                  final telefone = data['telefone']?.toString().toLowerCase() ?? '';
                  if (_termoBusca.isEmpty) return true;
                  return nome.contains(_termoBusca) || telefone.contains(_termoBusca);
                }).toList();

                // Separa em "precisam atenção" e "todos"
                final precisamAtencao = <QueryDocumentSnapshot>[];
                final demais = <QueryDocumentSnapshot>[];

                for (final doc in clientesFiltrados) {
                  final c = doc.data() as Map<String, dynamic>;
                  if (_clientePrecisaRetorno(c) || _ehAniversarioHoje(c)) {
                    precisamAtencao.add(doc);
                  } else {
                    demais.add(doc);
                  }
                }

                if (clientesFiltrados.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('Nenhum cliente cadastrado.', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }

                return ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    // Seção: Precisam de atenção
                    if (precisamAtencao.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          'Precisam de atenção · ${precisamAtencao.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ...precisamAtencao.map((doc) {
                        final c = doc.data() as Map<String, dynamic>;
                        return _buildClienteItem(id: doc.id, cliente: c);
                      }),
                      const Divider(color: Colors.white10, height: 24, indent: 16, endIndent: 16),
                    ],

                    // Seção: Todos os clientes
                    if (demais.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          'Todos os clientes',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      ...demais.map((doc) {
                        final c = doc.data() as Map<String, dynamic>;
                        return _buildClienteItem(id: doc.id, cliente: c);
                      }),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}