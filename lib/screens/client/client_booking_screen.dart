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
  final List<String> _servicosSelecionados = [];
  double _precoTotal = 0.0;
  
  String? _barbeiroSelecionado; 
  String? _barbeiroRealId;      
  String? _barbeiroNome;
  
  final DateTime _dataSelecionada = DateTime.now();
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
        _horarioSelecionado = null;
      });
    }
  }

  Future<void> _confirmarAgendamento() async {
    final nome = _nomeClienteCtrl.text.trim();
    final telefone = _telefoneCtrl.text.trim();

    if (_servicosSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione pelo menos um serviço.')));
      return;
    }
    if (_barbeiroRealId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione o barbeiro.')));
      return;
    }
    if (_horarioSelecionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecione um horário disponível.')));
      return;
    }
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, informe o seu nome no Passo 5.')));
      return;
    }
    if (telefone.isEmpty || telefone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, informe o seu WhatsApp no Passo 5.')));
      return;
    }

    final dataFormatada = DateFormat('dd/MM/yyyy', 'pt_BR').format(_dataSelecionada);
    final dataHoraCompleta = '$dataFormatada às $_horarioSelecionado';
    final servicosTexto = _servicosSelecionados.join(' + ');

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
          'observacoes': 'Cadastrado via Agendamento Web',
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
        'servico': servicosTexto,
        'preco': _precoTotal,
        'preco_servico': _precoTotal,
        'preco_tabela_original': _precoTotal,
        'preco_produtos': 0.0,
        'barbeiro_id': _barbeiroRealId,
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
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Agendamento Confirmado!', style: TextStyle(color: Color(0xFF00C853))),
            content: Text('O seu horário para $dataHoraCompleta com $_barbeiroNome foi marcado com sucesso.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
                onPressed: () {
                  Navigator.pop(ctx); 
                  Navigator.pop(context); 
                },
                child: const Text('Concluir'),
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
                // --- BANNER VIP DE UPSELL ---
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE0A96D), Color(0xFFB87A3D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE0A96D).withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.black, size: 36),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seja um Cliente VIP!', 
                              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Pague um valor fixo e tenha cortes ilimitados o mês todo.', 
                              style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: const Color(0xFFE0A96D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: const Color(0xFF1E1E1E),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (context) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Planos VIP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                                        IconButton(
                                          icon: const Icon(Icons.close, color: Colors.grey),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFE0A96D).withValues(alpha: 0.5)),
                                        borderRadius: BorderRadius.circular(12),
                                        color: const Color(0xFF2C2C2C),
                                      ),
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Assinatura Mensal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              SizedBox(height: 4),
                                              Text('Cortes ilimitados o mês todo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                          Text('R\$ 90,00', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00C853), fontSize: 16)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text('Para aderir, fale com o seu barbeiro no momento do atendimento!', style: TextStyle(fontSize: 13, color: Colors.white70), textAlign: TextAlign.center),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: const Text('Ver Planos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                ),

                // PASSO 1: SERVIÇOS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('1. Escolha os Serviços', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                    if (_precoTotal > 0)
                      Text('Total: R\$ ${_precoTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                  ],
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('servicos').snapshots(),
                  builder: (ctx, snap) {
                    if (snap.hasError) return const Text('Erro de Permissão. Verifique as regras do Firebase.', style: TextStyle(color: Colors.red));
                    if (snap.connectionState == ConnectionState.waiting) return const LinearProgressIndicator(color: Color(0xFF00C853));
                    if (!snap.hasData || snap.data!.docs.isEmpty) return const Text('Nenhum serviço cadastrado.', style: TextStyle(color: Colors.grey));
                    
                    final servicos = snap.data!.docs;
                    return Column(
                      children: servicos.map((doc) {
                        final s = doc.data() as Map<String, dynamic>;
                        final nome = s['nome'] ?? '';
                        final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;
                        final isSelected = _servicosSelecionados.contains(nome);

                        return CheckboxListTile(
                          title: Text(nome),
                          subtitle: Text('R\$ ${preco.toStringAsFixed(2)}'),
                          value: isSelected,
                          activeColor: const Color(0xFFE0A96D),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _servicosSelecionados.add(nome);
                                _precoTotal += preco;
                              } else {
                                _servicosSelecionados.remove(nome);
                                _precoTotal -= preco;
                              }
                              _barbeiroSelecionado = null;
                              _barbeiroRealId = null;
                              _barbeiroNome = null;
                              _horarioSelecionado = null;
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 24),
                
                // PASSO 2: BARBEIRO
                const Text('2. Escolha o Profissional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                if (_servicosSelecionados.isEmpty)
                  const Text('Selecione pelo menos um serviço acima.', style: TextStyle(color: Colors.grey))
                else
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').snapshots(),
                    builder: (ctx, snap) {
                      if (!snap.hasData) return const LinearProgressIndicator();
                      final todosBarbeiros = snap.data!.docs;

                      final barbeiros = todosBarbeiros.where((doc) {
                        final b = doc.data() as Map<String, dynamic>;
                        final servicosBarbeiro = (b['servicos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
                        if (servicosBarbeiro.isEmpty) return true; 
                        return _servicosSelecionados.every((servicoSelecionado) => servicosBarbeiro.contains(servicoSelecionado));
                      }).toList();

                      if (barbeiros.isEmpty) return const Text('Nenhum barbeiro disponível para esses serviços.');

                      return Column(
                        children: [
                          Card(
                            color: const Color(0xFF2C2C2C),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: _barbeiroSelecionado == 'qualquer' ? const BorderSide(color: Color(0xFFE0A96D)) : BorderSide.none,
                            ),
                            child: RadioListTile<String>(
                              secondary: const CircleAvatar(backgroundColor: Color(0xFFE0A96D), child: Icon(Icons.flash_on, color: Colors.black, size: 20)),
                              title: const Text('Qualquer profissional', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: const Text('O primeiro horário disponível', style: TextStyle(fontSize: 12)),
                              value: 'qualquer',
                              groupValue: _barbeiroSelecionado,
                              activeColor: const Color(0xFFE0A96D),
                              onChanged: (val) {
                                setState(() {
                                  _barbeiroSelecionado = val;
                                  _barbeiroRealId = barbeiros.first.id;
                                  final bData = barbeiros.first.data() as Map<String, dynamic>;
                                  _barbeiroNome = bData['nome'] ?? 'Profissional';
                                  _horarioSelecionado = null;
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...barbeiros.map((doc) {
                            final b = doc.data() as Map<String, dynamic>;
                            final nome = b['nome'] ?? 'Barbeiro';

                            return RadioListTile<String>(
                              secondary: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey[800],
                                child: Text(nome.isNotEmpty ? nome[0].toUpperCase() : 'B', style: const TextStyle(color: Colors.white, fontSize: 14)),
                              ),
                              title: Text(nome),
                              value: doc.id,
                              groupValue: _barbeiroSelecionado,
                              activeColor: const Color(0xFFE0A96D),
                              onChanged: (val) {
                                setState(() {
                                  _barbeiroSelecionado = val;
                                  _barbeiroRealId = val;
                                  _barbeiroNome = nome;
                                  _horarioSelecionado = null;
                                });
                              },
                            );
                          }),
                        ],
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // PASSO 3: DATA
                const Text('3. Data do Atendimento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _abrirCalendario(diasFuncionamento),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0A96D)),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFF2C2C2C),
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

                // PASSO 4: HORÁRIOS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('4. Horários Disponíveis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                    Text('Das $horaAberturaGeral às $horaFechamentoGeral', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                if (_barbeiroRealId == null)
                  const Text('Selecione um profissional acima para ver os horários.', style: TextStyle(color: Colors.grey))
                else
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').doc(_barbeiroRealId).snapshots(),
                    builder: (ctx, barbDocSnap) {
                      final bData = barbDocSnap.data?.data() as Map<String, dynamic>? ?? {};
                      final diasBarbeiro = (bData['dias_trabalho'] as List<dynamic>?)?.map((e) => int.tryParse(e.toString()) ?? 1).toList() ?? [1, 2, 3, 4, 5, 6];
                      final hInicioBarbeiro = bData['hora_inicio']?.toString() ?? horaAberturaGeral;
                      final hFimBarbeiro = bData['hora_fim']?.toString() ?? horaFechamentoGeral;

                      final barbeiroTrabalhaHoje = diasBarbeiro.contains(_dataSelecionada.weekday);

                      if (!barbeiroTrabalhaHoje) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3))),
                          child: const Text('Não há atendimento neste dia da semana. Escolha outra data.', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                        );
                      }

                      final slotsHorarios = _gerarGradeHorarios(hInicioBarbeiro, hFimBarbeiro, intervaloMin);

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('agendamentos').where('barbeiro_id', isEqualTo: _barbeiroRealId).snapshots(),
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

                          return Wrap(
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
                                  color: isOcupado ? Colors.grey.shade700 : (isSelected ? Colors.black : Colors.white),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  decoration: isOcupado ? TextDecoration.lineThrough : null,
                                ),
                                onSelected: isOcupado ? null : (selected) {
                                  setState(() {
                                    _horarioSelecionado = selected ? hora : null;
                                  });
                                },
                              );
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                const SizedBox(height: 32),

                // PASSO 5: DADOS DO CLIENTE
                const Text('5. Confirme os seus Dados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
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