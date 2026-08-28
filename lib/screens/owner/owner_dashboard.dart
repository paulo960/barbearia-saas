import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'owner_clientes_tab.dart';
import 'owner_agenda_tab.dart';
import 'owner_servicos_tab.dart';
import 'owner_produtos_tab.dart';
import 'owner_financeiro_tab.dart';


// Importa a tela do cliente para o atalho de "Visualizar Agendamento"
import '../client/client_booking_screen.dart';


class OwnerDashboard extends StatefulWidget {
  final String barbeariaId;
  const OwnerDashboard({super.key, required this.barbeariaId});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
       OwnerAgendamentosTab(barbeariaId: widget.barbeariaId),
       OwnerServicosTab(barbeariaId: widget.barbeariaId),
       OwnerProdutosTab(barbeariaId: widget.barbeariaId),
      _OwnerBarbeirosTab(barbeariaId: widget.barbeariaId),
       OwnerFinanceiroTab(barbeariaId: widget.barbeariaId),
      _OwnerConfigAjustesTab(barbeariaId: widget.barbeariaId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão Barbearia'),
        actions: [
          IconButton(
            tooltip: 'Gestão de Clientes & Assinaturas',
            icon: const Icon(Icons.person_search, color: Color(0xFFE0A96D)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ClientesScreen(barbeariaId: widget.barbeariaId)),
              );
            },
          ),
          IconButton(
            tooltip: 'Visualizar Agendamento do Cliente',
            icon: const Icon(Icons.preview),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ClientBookingScreen(barbeariaId: widget.barbeariaId)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.content_cut), label: 'Serviços'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'Produtos'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Equipe'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Financeiro'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}


class _OwnerBarbeirosTab extends StatelessWidget {
  final String barbeariaId;
  const _OwnerBarbeirosTab({required this.barbeariaId});

  void _abrirModalBarbeiro(BuildContext context, {String? barbeiroId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final comissaoServicoCtrl = TextEditingController(text: (dadosAtuais?['comissao_porcentagem'] ?? 50).toString());
    final comissaoProdutoCtrl = TextEditingController(text: (dadosAtuais?['comissao_produtos_pct'] ?? 10).toString());
    final comissaoAssinanteCtrl = TextEditingController(text: (dadosAtuais?['comissao_assinante_pct'] ?? 30).toString());
    
    String horaInicio = dadosAtuais?['hora_inicio']?.toString() ?? '08:00';
    String horaFim = dadosAtuais?['hora_fim']?.toString() ?? '22:00';
    List<String> servicosSelecionados = (dadosAtuais?['servicos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    List<int> diasTrabalho = (dadosAtuais?['dias_trabalho'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 1).toList() ?? [1, 2, 3, 4, 5, 6];

    final List<String> horasDisponiveis = [
      '06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
      '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
      '20:00', '21:00', '22:00', '23:00'
    ];

    final nomesDias = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(barbeiroId == null ? 'Cadastrar Barbeiro' : 'Editar Barbeiro'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do Profissional *')),
                const SizedBox(height: 16),
                const Text('Percentuais de Comissão (%):', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                TextField(
                  controller: comissaoServicoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Comissão Serviços Avulsos (%)',
                    border: OutlineInputBorder(),
                    helperText: 'Ex: 50% sobre cortes e barbas avulsos',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: comissaoProdutoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Comissão sobre Produtos Vendidos (%)',
                    border: OutlineInputBorder(),
                    helperText: 'Ex: 10% sobre pomadas, cremes, etc.',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: comissaoAssinanteCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Comissão p/ Atendimento de Assinante (%)',
                    border: OutlineInputBorder(),
                    helperText: 'Ex: 30% do valor da tabela quando o cliente é do plano',
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Horário de Trabalho:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: horasDisponiveis.contains(horaInicio) ? horaInicio : '08:00',
                        decoration: const InputDecoration(labelText: 'Entrada', border: OutlineInputBorder(), isDense: true),
                        items: horasDisponiveis.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => horaInicio = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: horasDisponiveis.contains(horaFim) ? horaFim : '22:00',
                        decoration: const InputDecoration(labelText: 'Saída', border: OutlineInputBorder(), isDense: true),
                        items: horasDisponiveis.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => horaFim = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Dias de Atendimento:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: nomesDias.entries.map((entry) {
                    final isSelected = diasTrabalho.contains(entry.key);
                    return FilterChip(
                      label: Text(entry.value.substring(0, 3)),
                      selected: isSelected,
                      selectedColor: const Color(0xFFE0A96D),
                      labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      onSelected: (val) {
                        setModalState(() {
                          if (val) {
                            diasTrabalho.add(entry.key);
                          } else {
                            diasTrabalho.remove(entry.key);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text('Serviços Realizados:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('servicos').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const LinearProgressIndicator();
                    final servicos = snap.data!.docs;

                    if (servicos.isEmpty) {
                      return const Text('Nenhum serviço cadastrado.', style: TextStyle(fontSize: 12, color: Colors.grey));
                    }

                    return Column(
                      children: servicos.map((sDoc) {
                        final s = sDoc.data() as Map<String, dynamic>;
                        final sNome = s['nome']?.toString() ?? '';
                        final isChecked = servicosSelecionados.contains(sNome);

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(sNome),
                          value: isChecked,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                servicosSelecionados.add(sNome);
                              } else {
                                servicosSelecionados.remove(sNome);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
              onPressed: () async {
                if (nomeCtrl.text.trim().isEmpty) return;
                final payload = {
                  'nome': nomeCtrl.text.trim(),
                  'comissao_porcentagem': int.tryParse(comissaoServicoCtrl.text.trim()) ?? 50,
                  'comissao_produtos_pct': int.tryParse(comissaoProdutoCtrl.text.trim()) ?? 10,
                  'comissao_assinante_pct': int.tryParse(comissaoAssinanteCtrl.text.trim()) ?? 30,
                  'hora_inicio': horaInicio,
                  'hora_fim': horaFim,
                  'servicos': servicosSelecionados,
                  'dias_trabalho': diasTrabalho,
                };

                if (barbeiroId == null) {
                  payload['criado_em'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(barbeariaId)
                      .collection('barbeiros')
                      .add(payload);
                } else {
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(barbeariaId)
                      .collection('barbeiros')
                      .doc(barbeiroId)
                      .update(payload);
                }

                if (context.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirModalBarbeiro(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('barbeiros')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final barbeiros = snapshot.data?.docs ?? [];

          if (barbeiros.isEmpty) {
            return const Center(child: Text('Nenhum barbeiro cadastrado. Toque em + para adicionar.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: barbeiros.length,
            itemBuilder: (ctx, i) {
              final b = barbeiros[i].data() as Map<String, dynamic>? ?? {};
              final id = barbeiros[i].id;
              final nome = b['nome']?.toString() ?? 'Barbeiro';
              final hInicio = b['hora_inicio']?.toString() ?? '08:00';
              final hFim = b['hora_fim']?.toString() ?? '22:00';
              final comServ = b['comissao_porcentagem'] ?? 50;
              final comProd = b['comissao_produtos_pct'] ?? 10;
              final comAssin = b['comissao_assinante_pct'] ?? 30;
              final servicosList = (b['servicos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE0A96D),
                      child: Text(
                        nome.isNotEmpty ? nome[0].toUpperCase() : 'B',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Horário: $hInicio às $hFim', style: const TextStyle(color: Color(0xFFE0A96D), fontSize: 12)),
                        Text('Comissões: $comServ% (Serviço) | $comProd% (Produtos) | $comAssin% (Assinante)', style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(
                          servicosList.isEmpty ? 'Todos os serviços' : 'Faz: ${servicosList.join(", ")}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D)),
                          onPressed: () => _abrirModalBarbeiro(context, barbeiroId: id, dadosAtuais: b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => FirebaseFirestore.instance
                              .collection('barbearias')
                              .doc(barbeariaId)
                              .collection('barbeiros')
                              .doc(id)
                              .delete(),
                        ),
                      ],
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

class _OwnerConfigAjustesTab extends StatefulWidget {
  final String barbeariaId;
  const _OwnerConfigAjustesTab({required this.barbeariaId});

  @override
  State<_OwnerConfigAjustesTab> createState() => _OwnerConfigAjustesTabState();
}

class _OwnerConfigAjustesTabState extends State<_OwnerConfigAjustesTab> {
  final List<String> _horasPossiveis = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
    '20:00', '21:00', '22:00', '23:00'
  ];

  final Map<int, String> _diasNomes = {
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
    7: 'Domingo',
  };

  void _abrirModalNovoOuEditarPlano({String? planoId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final precoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['preco_mensal'] as num?)?.toDouble().toStringAsFixed(2) ?? '' : '');
    List<String> servicosCobertos = (dadosAtuais?['servicos_cobertos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text(planoId == null ? 'Novo Plano de Assinatura' : 'Editar Plano'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome do Plano (Ex: Corte VIP Ilimitado) *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: precoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor da Mensalidade (R\$) *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Serviços Cobertos pelo Plano:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('servicos').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const LinearProgressIndicator();
                    final servicos = snap.data!.docs;

                    if (servicos.isEmpty) {
                      return const Text('Cadastre serviços primeiro para vinculá-los ao plano.', style: TextStyle(fontSize: 12, color: Colors.grey));
                    }

                    return Column(
                      children: servicos.map((sDoc) {
                        final s = sDoc.data() as Map<String, dynamic>;
                        final sNome = s['nome']?.toString() ?? '';
                        final isChecked = servicosCobertos.contains(sNome);

                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(sNome),
                          value: isChecked,
                          activeColor: const Color(0xFFE0A96D),
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                servicosCobertos.add(sNome);
                              } else {
                                servicosCobertos.remove(sNome);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
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
                    'preco_mensal': double.tryParse(precoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                    'servicos_cobertos': servicosCobertos,
                  };

                  if (planoId == null) {
                    payload['criado_em'] = FieldValue.serverTimestamp();
                    await FirebaseFirestore.instance
                        .collection('barbearias')
                        .doc(widget.barbeariaId)
                        .collection('planos')
                        .add(payload);
                  } else {
                    await FirebaseFirestore.instance
                        .collection('barbearias')
                        .doc(widget.barbeariaId)
                        .collection('planos')
                        .doc(planoId)
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final horaAbertura = data['hora_abertura']?.toString() ?? '08:00';
        final horaFechamento = data['hora_fechamento']?.toString() ?? '22:00';
        final intervaloMinutos = (data['intervalo_minutos'] as num?)?.toInt() ?? 30;
        final diasFuncionamento = (data['dias_funcionamento'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 1).toList() ?? [1, 2, 3, 4, 5, 6];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: const Color(0xFF222222),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.workspace_premium, color: Color(0xFFE0A96D)),
                              SizedBox(width: 8),
                              Text('Planos de Assinatura Mensal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Color(0xFFE0A96D), size: 28),
                            tooltip: 'Criar Novo Plano',
                            onPressed: () => _abrirModalNovoOuEditarPlano(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('planos').snapshots(),
                        builder: (context, planosSnap) {
                          if (planosSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
                          }

                          final planos = planosSnap.data?.docs ?? [];

                          if (planos.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Nenhum plano cadastrado.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  TextButton.icon(
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Cadastrar Plano'),
                                    onPressed: () => _abrirModalNovoOuEditarPlano(),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: planos.length,
                            itemBuilder: (ctx, i) {
                              final pDoc = planos[i];
                              final p = pDoc.data() as Map<String, dynamic>;
                              final pId = pDoc.id;
                              final nome = p['nome']?.toString() ?? 'Plano';
                              final preco = (p['preco_mensal'] as num?)?.toDouble() ?? 0.0;
                              final cobertos = (p['servicos_cobertos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                              return Card(
                                color: const Color(0xFF1C1C1C),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFE0A96D),
                                    child: Icon(Icons.workspace_premium, color: Colors.black),
                                  ),
                                  title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  subtitle: Text(
                                    'R\$ ${preco.toStringAsFixed(2)}/mês\nCobre: ${cobertos.isEmpty ? "Todos os Serviços" : cobertos.join(", ")}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D)),
                                        tooltip: 'Editar',
                                        onPressed: () => _abrirModalNovoOuEditarPlano(planoId: pId, dadosAtuais: p),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        tooltip: 'Excluir Plano',
                                        onPressed: () => FirebaseFirestore.instance
                                            .collection('barbearias')
                                            .doc(widget.barbeariaId)
                                            .collection('planos')
                                            .doc(pId)
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF222222),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.schedule, color: Color(0xFFE0A96D)),
                          SizedBox(width: 8),
                          Text('Horário de Funcionamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _horasPossiveis.contains(horaAbertura) ? horaAbertura : '08:00',
                              decoration: const InputDecoration(labelText: 'Abertura', border: OutlineInputBorder()),
                              items: _horasPossiveis.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).set({
                                    'hora_abertura': val,
                                  }, SetOptions(merge: true));
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _horasPossiveis.contains(horaFechamento) ? horaFechamento : '22:00',
                              decoration: const InputDecoration(labelText: 'Fechamento', border: OutlineInputBorder()),
                              items: _horasPossiveis.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).set({
                                    'hora_fechamento': val,
                                  }, SetOptions(merge: true));
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: intervaloMinutos,
                        decoration: const InputDecoration(labelText: 'Intervalo de cada Horário', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 30, child: Text('De 30 em 30 minutos (Padrão)')),
                          DropdownMenuItem(value: 45, child: Text('De 45 em 45 minutos')),
                          DropdownMenuItem(value: 60, child: Text('De 1 em 1 hora')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).set({
                              'intervalo_minutos': val,
                            }, SetOptions(merge: true));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFF222222),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.calendar_month, color: Color(0xFFE0A96D)),
                          SizedBox(width: 8),
                          Text('Dias de Abertura da Barbearia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._diasNomes.entries.map((entry) {
                        final isAberto = diasFuncionamento.contains(entry.key);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(entry.value, style: TextStyle(fontWeight: isAberto ? FontWeight.bold : FontWeight.normal)),
                          value: isAberto,
                          activeColor: const Color(0xFFE0A96D),
                          onChanged: (val) {
                            final listaAtual = List<int>.from(diasFuncionamento);
                            if (val == true) {
                              listaAtual.add(entry.key);
                            } else {
                              listaAtual.remove(entry.key);
                            }
                            FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).set({
                              'dias_funcionamento': listaAtual,
                            }, SetOptions(merge: true));
                          },
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

