import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClientBookingScreen extends StatefulWidget {
  final String barbeariaId;
  const ClientBookingScreen({super.key, required this.barbeariaId});

  @override
  State<ClientBookingScreen> createState() => _ClientBookingScreenState();
}

class _ClientBookingScreenState extends State<ClientBookingScreen> {
  String? _servicoSelecionado;
  double _precoSelecionado = 0.0;
  String? _barbeiroSelecionado;
  String? _barbeiroNome;
  DateTime _dataSelecionada = DateTime.now();
  String? _horarioSelecionado;
  
  final _nomeClienteCtrl = TextEditingController();
  final _telefoneCtrl = TextEditingController();
  bool _enviando = false;

  List<String> _gerarGradeHorarios(String horaInicio, String horaFim, int intervaloMin) {
    List<String> slots = [];
    try {
      final hInicio = int.parse(horaInicio.split(':')[0]);
      final hLimite = int.parse(horaFim.split(':')[0]);

      DateTime atual = DateTime(2026, 1, 1, hInicio, 0);
      final limite = DateTime(2026, 1, 1, hLimite, 0);

      while (atual.isBefore(limite)) {
        slots.add(DateFormat('HH:mm').format(atual));
        atual = atual.add(Duration(minutes: intervaloMin));
      }
    } catch (_) {
      slots = [
        '08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
        '13:00', '13:30', '14:00', '14:30', '15:00', '15:30', '16:00', '16:30',
        '17:00', '17:30', '18:00', '18:30', '19:00', '19:30'
      ];
    }
    return slots;
  }

  Future<void> _abrirCalendario(List<int> diasFuncionamentoBarbearia) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      locale: const Locale('pt', 'BR'),
      selectableDayPredicate: (day) {
        if (diasFuncionamentoBarbearia.isEmpty) return true;
        return diasFuncionamentoBarbearia.contains(day.weekday);
      },
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

    if (picked != null && picked != _dataSelecionada) {
      setState(() {
        _dataSelecionada = picked;
        _horarioSelecionado = null;
      });
    }
  }

  Future<void> _confirmarAgendamento() async {
    final nome = _nomeClienteCtrl.text.trim();
    final telefone = _telefoneCtrl.text.trim();

    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, informe seu nome.')));
      return;
    }

    if (telefone.isEmpty || telefone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, informe seu WhatsApp.')));
      return;
    }

    if (_servicoSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um serviço.')));
      return;
    }

    if (_barbeiroSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione o barbeiro.')));
      return;
    }

    if (_horarioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um horário disponível.')));
      return;
    }

    final dataFormatada = DateFormat('dd/MM/yyyy', 'pt_BR').format(_dataSelecionada);
    final dataHoraCompleta = '$dataFormatada às $_horarioSelecionado';

    setState(() => _enviando = true);

    try {
      final clientesRef = FirebaseFirestore.instance
          .collection('barbearias')
          .doc(widget.barbeariaId)
          .collection('clientes');

      final queryExistente = await clientesRef.where('telefone', isEqualTo: telefone).limit(1).get();

      if (queryExistente.docs.isEmpty) {
        await clientesRef.add({
          'nome': nome,
          'telefone': telefone,
          'plano_id': 'nenhum',
          'plano_nome': '',
          'observacoes': 'Cadastrado via Agendamento',
          'criado_em': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseFirestore.instance
          .collection('barbearias')
          .doc(widget.barbeariaId)
          .collection('agendamentos')
          .add({
        'cliente_nome': nome,
        'cliente_telefone': telefone,
        'servico': _servicoSelecionado,
        'preco': _precoSelecionado,
        'preco_servico': _precoSelecionado,
        'preco_tabela_original': _precoSelecionado,
        'preco_produtos': 0.0,
        'barbeiro_id': _barbeiroSelecionado,
        'barbeiro_nome': _barbeiroNome,
        'data_iso': DateFormat('yyyy-MM-dd').format(_dataSelecionada),
        'horario': _horarioSelecionado,
        'data_hora': dataHoraCompleta,
        'status': 'pendente',
        'repasse_liquidado': false,
        'criado_em': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Agendamento Confirmado!'),
            content: Text('Agendado para $dataHoraCompleta com $_barbeiroNome.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(_dataSelecionada);
    final dataIso = DateFormat('yyyy-MM-dd').format(_dataSelecionada);
    final agora = DateTime.now();
    final isHoje = _dataSelecionada.year == agora.year &&
        _dataSelecionada.month == agora.month &&
        _dataSelecionada.day == agora.day;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).snapshots(),
      builder: (context, configSnap) {
        final configData = configSnap.data?.data() as Map<String, dynamic>? ?? {};
        final horaAberturaGeral = configData['hora_abertura']?.toString() ?? '08:00';
        final horaFechamentoGeral = configData['hora_fechamento']?.toString() ?? '22:00';
        final intervaloMin = (configData['intervalo_minutos'] as num?)?.toInt() ?? 30;
        final diasFuncionamento = (configData['dias_funcionamento'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 1).toList() ?? [1, 2, 3, 4, 5, 6];

        return Scaffold(
          appBar: AppBar(title: const Text('Agendar Atendimento')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('1. Seus Dados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 12),
                TextField(
                  controller: _nomeClienteCtrl,
                  decoration: const InputDecoration(labelText: 'Seu Nome *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _telefoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp com DDD *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                ),
                const SizedBox(height: 24),
                const Text('2. Escolha o Serviço', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('servicos').snapshots(),
                  builder: (ctx, snap) {
                    if (!snap.hasData) return const LinearProgressIndicator();
                    final servicos = snap.data!.docs;
                    if (servicos.isEmpty) return const Text('Nenhum serviço cadastrado.');

                    return Column(
                      children: servicos.map((doc) {
                        final s = doc.data() as Map<String, dynamic>;
                        final nome = s['nome'] ?? '';
                        final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;
                        return RadioListTile<String>(
                          title: Text(nome),
                          subtitle: Text('R\$ ${preco.toStringAsFixed(2)}'),
                          value: nome,
                          groupValue: _servicoSelecionado,
                          onChanged: (val) {
                            setState(() {
                              _servicoSelecionado = val;
                              _precoSelecionado = preco;
                              _barbeiroSelecionado = null;
                              _barbeiroNome = null;
                              _horarioSelecionado = null;
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                const Text('3. Escolha o Barbeiro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                if (_servicoSelecionado == null)
                  const Text('Selecione primeiro um serviço acima.', style: TextStyle(color: Colors.grey))
                else
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('barbearias')
                        .doc(widget.barbeariaId)
                        .collection('barbeiros')
                        .snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      final todosBarbeiros = snap.data!.docs;

                      final barbeiros = todosBarbeiros.where((doc) {
                        final b = doc.data() as Map<String, dynamic>;
                        final servicos = (b['servicos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                        return servicos.isEmpty || servicos.contains(_servicoSelecionado);
                      }).toList();

                      if (barbeiros.isEmpty) return const Text('Nenhum barbeiro disponível para este serviço.');

                      return Column(
                        children: barbeiros.map((doc) {
                          final b = doc.data() as Map<String, dynamic>;
                          final nome = b['nome'] ?? 'Barbeiro';

                          return RadioListTile<String>(
                            secondary: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFE0A96D),
                              child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : 'B', style: const TextStyle(color: Colors.black, fontSize: 12)),
                            ),
                            title: Text(nome),
                            value: doc.id,
                            groupValue: _barbeiroSelecionado,
                            onChanged: (val) {
                              setState(() {
                                _barbeiroSelecionado = val;
                                _barbeiroNome = nome;
                                _horarioSelecionado = null;
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                const Text('4. Data do Atendimento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _abrirCalendario(diasFuncionamento),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0A96D)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month, color: Color(0xFFE0A96D)),
                            const SizedBox(width: 12),
                            Text(dataStr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Text('Mudar Data', style: TextStyle(color: Color(0xFFE0A96D), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('5. Horários Disponíveis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                    Text('Das $horaAberturaGeral às $horaFechamentoGeral', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_barbeiroSelecionado == null)
                  const Text('Selecione o barbeiro para ver a grade de horários.', style: TextStyle(color: Colors.grey))
                else
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('barbearias')
                        .doc(widget.barbeariaId)
                        .collection('barbeiros')
                        .doc(_barbeiroSelecionado)
                        .snapshots(),
                    builder: (ctx, barbDocSnap) {
                      final bData = barbDocSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final diasBarbeiro = (bData['dias_trabalho'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 1).toList() ?? [1, 2, 3, 4, 5, 6];
                      final hInicioBarbeiro = bData['hora_inicio']?.toString() ?? horaAberturaGeral;
                      final hFimBarbeiro = bData['hora_fim']?.toString() ?? horaFechamentoGeral;

                      final barbeiroTrabalhaHoje = diasBarbeiro.contains(_dataSelecionada.weekday);

                      if (!barbeiroTrabalhaHoje) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withOpacity(0.3))),
                          child: Text('$_barbeiroNome não atende neste dia da semana. Escolha outra data ou outro profissional.', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                        );
                      }

                      final slotsHorarios = _gerarGradeHorarios(hInicioBarbeiro, hFimBarbeiro, intervaloMin);

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(widget.barbeariaId)
                            .collection('agendamentos')
                            .where('barbeiro_id', isEqualTo: _barbeiroSelecionado)
                            .snapshots(),
                        builder: (ctx, agSnap) {
                          if (!agSnap.hasData) return const Center(child: CircularProgressIndicator());

                          final ocupados = <String>{};
                          for (var doc in agSnap.data!.docs) {
                            final data = doc.data() as Map<String, dynamic>;
                            final st = data['status']?.toString() ?? 'pendente';
                            final dHora = data['data_hora']?.toString() ?? '';
                            final dIso = data['data_iso']?.toString() ?? '';
                            final h = data['horario']?.toString() ?? '';

                            if (st != 'cancelado') {
                              if (dIso == dataIso && h.isNotEmpty) {
                                ocupados.add(h);
                              } else if (dHora.contains(dataStr)) {
                                for (var slot in slotsHorarios) {
                                  if (dHora.contains(slot)) ocupados.add(slot);
                                }
                              }
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Turno de $_barbeiroNome: $hInicioBarbeiro às $hFimBarbeiro', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: slotsHorarios.map((hora) {
                                  bool isPassadoOuMuitoProximo = false;

                                  if (isHoje) {
                                    final partes = hora.split(':');
                                    final h = int.tryParse(partes[0]) ?? 0;
                                    final m = int.tryParse(partes[1]) ?? 0;
                                    final dataHoraSlot = DateTime(agora.year, agora.month, agora.day, h, m);

                                    if (dataHoraSlot.isBefore(agora.add(const Duration(hours: 1)))) {
                                      isPassadoOuMuitoProximo = true;
                                    }
                                  }

                                  final isOcupado = ocupados.contains(hora) || isPassadoOuMuitoProximo;
                                  final isSelected = _horarioSelecionado == hora;

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
                                            setState(() {
                                              _horarioSelecionado = selected ? hora : null;
                                            });
                                          },
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 32),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0A96D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _enviando ? null : _confirmarAgendamento,
                  child: _enviando
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('Confirmar Agendamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
