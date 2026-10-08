import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerConfigAjustesTab extends StatefulWidget {
  final String barbeariaId;
  const OwnerConfigAjustesTab({super.key, required this.barbeariaId});

  @override
  State<OwnerConfigAjustesTab> createState() => OwnerConfigAjustesTabState();
}

class OwnerConfigAjustesTabState extends State<OwnerConfigAjustesTab> {
  final List<String> _horasPossiveis = [
    '06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
    '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
    '20:00', '21:00', '22:00', '23:00',
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

  // ---------- helpers Firestore ----------

  CollectionReference<Map<String, dynamic>> get _barbeariaRef =>
      FirebaseFirestore.instance.collection('barbearias');

  DocumentReference<Map<String, dynamic>> get _docRef =>
      _barbeariaRef.doc(widget.barbeariaId);

  CollectionReference<Map<String, dynamic>> get _planosRef =>
      _docRef.collection('planos');

  CollectionReference<Map<String, dynamic>> get _servicosRef =>
      _docRef.collection('servicos');

  Future<void> _salvarCampo(Map<String, dynamic> dados) async {
    try {
      await _docRef.set(dados, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    }
  }

  // ---------- modal de plano ----------

  Future<void> _abrirModalNovoOuEditarPlano({
    String? planoId,
    Map<String, dynamic>? dadosAtuais,
  }) async {
    final nomeCtrl = TextEditingController(
      text: dadosAtuais?['nome']?.toString() ?? '',
    );
    final precoCtrl = TextEditingController(
      text: dadosAtuais != null
          ? (dadosAtuais['preco_mensal'] as num?)?.toDouble().toStringAsFixed(2) ?? ''
          : '',
    );
    final List<String> servicosCobertos =
        (dadosAtuais?['servicos_cobertos'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(
                planoId == null ? 'Novo Plano de Assinatura' : 'Editar Plano',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome do Plano (Ex: Corte VIP Ilimitado) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: precoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Valor da Mensalidade (R\$) *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Serviços Cobertos pelo Plano:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE0A96D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _servicosRef.snapshots(),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return Text(
                            'Erro ao carregar serviços: ${snap.error}',
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                          );
                        }
                        if (!snap.hasData) {
                          return const LinearProgressIndicator();
                        }
                        final servicos = snap.data!.docs;

                        if (servicos.isEmpty) {
                          return const Text(
                            'Cadastre serviços primeiro para vinculá-los ao plano.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          );
                        }

                        return Column(
                          children: servicos.map((sDoc) {
                            final s = sDoc.data();
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
                                    if (!servicosCobertos.contains(sNome)) {
                                      servicosCobertos.add(sNome);
                                    }
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0A96D),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final nome = nomeCtrl.text.trim();
                    final precoStr = precoCtrl.text.trim().replaceAll(',', '.');
                    final preco = double.tryParse(precoStr);

                    if (nome.isEmpty || preco == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Preencha nome e valor corretamente.'),
                        ),
                      );
                      return;
                    }

                    final payload = <String, dynamic>{
                      'nome': nome,
                      'preco_mensal': preco,
                      'servicos_cobertos': servicosCobertos,
                    };

                    try {
                      if (planoId == null) {
                        payload['criado_em'] = FieldValue.serverTimestamp();
                        await _planosRef.add(payload);
                      } else {
                        await _planosRef.doc(planoId).update(payload);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Erro ao salvar plano: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );

    nomeCtrl.dispose();
    precoCtrl.dispose();
  }

  Future<void> _confirmarExclusaoPlano(String planoId, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir plano'),
        content: Text('Deseja realmente excluir o plano "$nome"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _planosRef.doc(planoId).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir plano: $e')),
        );
      }
    }
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        foregroundColor: Colors.white,
        title: const Text(
          'Ajustes da Barbearia',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final horaAbertura = data['hora_abertura']?.toString() ?? '08:00';
          final horaFechamento = data['hora_fechamento']?.toString() ?? '22:00';
          final intervaloMinutos =
              (data['intervalo_minutos'] as num?)?.toInt() ?? 30;
          final diasFuncionamento = (data['dias_funcionamento'] as List?)
                  ?.map((e) => int.tryParse(e.toString()) ?? 1)
                  .toList() ??
              <int>[1, 2, 3, 4, 5, 6];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // -------- Planos --------
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
                            const Row(
                              children: [
                                Icon(Icons.workspace_premium,
                                    color: Color(0xFFE0A96D)),
                                SizedBox(width: 8),
                                Text(
                                  'Planos de Assinatura Mensal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE0A96D),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: Color(0xFFE0A96D), size: 28),
                              tooltip: 'Criar Novo Plano',
                              onPressed: () => _abrirModalNovoOuEditarPlano(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _planosRef.snapshots(),
                          builder: (context, planosSnap) {
                            if (planosSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final planos = planosSnap.data?.docs ?? [];

                            if (planos.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Nenhum plano cadastrado.',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 13),
                                    ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Cadastrar Plano'),
                                      onPressed: () =>
                                          _abrirModalNovoOuEditarPlano(),
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
                                final p = pDoc.data();
                                final pId = pDoc.id;
                                final nome = p['nome']?.toString() ?? 'Plano';
                                final preco =
                                    (p['preco_mensal'] as num?)?.toDouble() ??
                                        0.0;
                                final cobertos = (p['servicos_cobertos']
                                            as List?)
                                        ?.map((e) => e.toString())
                                        .toList() ??
                                    <String>[];

                                return Card(
                                  color: const Color(0xFF1C1C1C),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: Color(0xFFE0A96D),
                                      child: Icon(Icons.workspace_premium,
                                          color: Colors.black),
                                    ),
                                    title: Text(
                                      nome,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'R\$ ${preco.toStringAsFixed(2)}/mês\n'
                                      'Cobre: ${cobertos.isEmpty ? "Todos os Serviços" : cobertos.join(", ")}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              color: Color(0xFFE0A96D)),
                                          tooltip: 'Editar',
                                          onPressed: () =>
                                              _abrirModalNovoOuEditarPlano(
                                            planoId: pId,
                                            dadosAtuais: p,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              color: Colors.redAccent),
                                          tooltip: 'Excluir Plano',
                                          onPressed: () =>
                                              _confirmarExclusaoPlano(
                                                  pId, nome),
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

                // -------- Horário --------
                Card(
                  color: const Color(0xFF222222),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.schedule, color: Color(0xFFE0A96D)),
                            SizedBox(width: 8),
                            Text(
                              'Horário de Funcionamento',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE0A96D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _horasPossiveis.contains(horaAbertura)
                                    ? horaAbertura
                                    : '08:00',
                                decoration: const InputDecoration(
                                  labelText: 'Abertura',
                                  border: OutlineInputBorder(),
                                ),
                                items: _horasPossiveis
                                    .map((h) => DropdownMenuItem(
                                          value: h,
                                          child: Text(h),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    _salvarCampo({'hora_abertura': val});
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _horasPossiveis.contains(horaFechamento)
                                    ? horaFechamento
                                    : '22:00',
                                decoration: const InputDecoration(
                                  labelText: 'Fechamento',
                                  border: OutlineInputBorder(),
                                ),
                                items: _horasPossiveis
                                    .map((h) => DropdownMenuItem(
                                          value: h,
                                          child: Text(h),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    _salvarCampo({'hora_fechamento': val});
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: intervaloMinutos,
                          decoration: const InputDecoration(
                            labelText: 'Intervalo de cada Horário',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 30,
                                child:
                                    Text('De 30 em 30 minutos (Padrão)')),
                            DropdownMenuItem(
                                value: 45,
                                child: Text('De 45 em 45 minutos')),
                            DropdownMenuItem(
                                value: 60,
                                child: Text('De 1 em 1 hora')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              _salvarCampo({'intervalo_minutos': val});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // -------- Dias --------
                Card(
                  color: const Color(0xFF222222),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_month,
                                color: Color(0xFFE0A96D)),
                            SizedBox(width: 8),
                            Text(
                              'Dias de Abertura da Barbearia',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE0A96D),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._diasNomes.entries.map((entry) {
                          final isAberto = diasFuncionamento.contains(entry.key);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(
                              entry.value,
                              style: TextStyle(
                                fontWeight: isAberto
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            value: isAberto,
                            activeColor: const Color(0xFFE0A96D),
                            onChanged: (val) {
                              final listaAtual = List<int>.from(diasFuncionamento);
                              if (val == true) {
                                if (!listaAtual.contains(entry.key)) {
                                  listaAtual.add(entry.key);
                                }
                              } else {
                                listaAtual.remove(entry.key);
                              }
                              _salvarCampo({'dias_funcionamento': listaAtual});
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}