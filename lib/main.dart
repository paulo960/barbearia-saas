import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyCFuOLPZ5ZcYOe_yKD9nKDIGi0KM67pQDA",
      authDomain: "barbearia-saas-master.firebaseapp.com",
      projectId: "barbearia-saas-master",
      storageBucket: "barbearia-saas-master.firebasestorage.app",
      messagingSenderId: "124942270610",
      appId: "1:124942270610:web:9eee46ef5b572eac7fe64b",
    ),
  );
  runApp(const BarbeariaSaaSApp());
}

class BarbeariaSaaSApp extends StatelessWidget {
  const BarbeariaSaaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestão Barbearia',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        primaryColor: const Color(0xFFE0A96D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE0A96D),
          secondary: Color(0xFF00C853),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('usuarios').doc(user.uid).snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            if (!userSnap.hasData || !userSnap.data!.exists) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Perfil não configurado no Firestore.', textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('UID: ${user.uid}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Sair'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
            final role = data['role']?.toString() ?? 'cliente';
            final tenantId = data['barbearia_id']?.toString() ?? 'barbearia_central';

            if (role == 'superadmin') {
              return const SuperAdminDashboard();
            }

            if (role == 'dono') {
              return OwnerDashboard(barbeariaId: tenantId);
            }

            if (role == 'barbeiro') {
              return BarberDashboard(barbeariaId: tenantId, barberId: user.uid);
            }

            return ClientBookingScreen(barbeariaId: tenantId);
          },
        );
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = 'Erro Auth (${e.code}): ${e.message}');
    } catch (e) {
      setState(() => _error = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.content_cut, size: 64, color: Color(0xFFE0A96D)),
                const SizedBox(height: 16),
                const Text(
                  'BarberSaaS Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D)),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'E-mail', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Senha', border: OutlineInputBorder()),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                    ),
                    child: Text(_error, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0A96D),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Entrar', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SuperAdminDashboard extends StatelessWidget {
  const SuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Admin • SaaS'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data?.docs ?? [];

          if (list.isEmpty) {
            return const Center(child: Text('Nenhuma barbearia cadastrada no banco.'));
          }

          return ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (ctx, i) {
              final b = list[i].data() as Map<String, dynamic>? ?? {};
              final id = list[i].id;
              final status = b['status_assinatura']?.toString() ?? 'ativo';
              final isBloqueado = status == 'bloqueado';

              return Card(
                child: ListTile(
                  title: Text(b['nome']?.toString() ?? 'Sem Nome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Plano: ${b['plano'] ?? 'Básico'} | Vencimento: ${b['vencimento'] ?? '-'}'),
                  trailing: IconButton(
                    icon: Icon(isBloqueado ? Icons.lock : Icons.lock_open, color: isBloqueado ? Colors.red : Colors.green),
                    onPressed: () {
                      FirebaseFirestore.instance.collection('barbearias').doc(id).update({
                        'status_assinatura': isBloqueado ? 'ativo' : 'bloqueado',
                      });
                    },
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

// ---------------- PAINEL DO DONO COM 5 ABAS ----------------
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
      _OwnerAgendamentosTab(barbeariaId: widget.barbeariaId),
      _OwnerServicosTab(barbeariaId: widget.barbeariaId),
      _OwnerBarbeirosTab(barbeariaId: widget.barbeariaId),
      _OwnerFinanceiroTab(barbeariaId: widget.barbeariaId),
      _OwnerConfigHorariosTab(barbeariaId: widget.barbeariaId),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão Barbearia'),
        actions: [
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
          NavigationDestination(icon: Icon(Icons.people), label: 'Equipe'),
          NavigationDestination(icon: Icon(Icons.attach_money), label: 'Financeiro'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Horários'),
        ],
      ),
    );
  }
}

// ---------------- ABA DE AGENDA (APENAS PENDENTES) ----------------
class _OwnerAgendamentosTab extends StatefulWidget {
  final String barbeariaId;
  const _OwnerAgendamentosTab({required this.barbeariaId});

  @override
  State<_OwnerAgendamentosTab> createState() => _OwnerAgendamentosTabState();
}

class _OwnerAgendamentosTabState extends State<_OwnerAgendamentosTab> {
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

  void _abrirModalConclusaoPagamento(String agendamentoId, String clienteNome, double valor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Concluir Atendimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cliente: $clienteNome', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Valor: R\$ ${valor.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Qual foi a forma de pagamento?', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade800)),
              leading: const Icon(Icons.flash_on, color: Colors.tealAccent),
              title: const Text('Pix', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => _concluirAgendamento(ctx, agendamentoId, 'pix'),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade800)),
              leading: const Icon(Icons.payments, color: Colors.greenAccent),
              title: const Text('Dinheiro', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => _concluirAgendamento(ctx, agendamentoId, 'dinheiro'),
            ),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade800)),
              leading: const Icon(Icons.credit_card, color: Colors.orangeAccent),
              title: const Text('Cartão (Crédito/Débito)', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => _concluirAgendamento(ctx, agendamentoId, 'cartao'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        ],
      ),
    );
  }

  Future<void> _concluirAgendamento(BuildContext dialogCtx, String agendamentoId, String formaPagamento) async {
    Navigator.pop(dialogCtx);
    await FirebaseFirestore.instance
        .collection('barbearias')
        .doc(widget.barbeariaId)
        .collection('agendamentos')
        .doc(agendamentoId)
        .update({
      'status': 'concluido',
      'forma_pagamento': formaPagamento,
      'concluido_em': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Atendimento concluído via ${formaPagamento.toUpperCase()}! Enviado ao Financeiro.'),
          backgroundColor: Colors.green.shade800,
        ),
      );
    }
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

                    if (_filtroServico != 'todos' && servicoNome != _filtroServico) {
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
                      final telefone = ag['cliente_telefone']?.toString() ?? '';
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
                              Text('${ag['servico'] ?? 'Serviço'} • ${ag['barbeiro_nome'] ?? 'Barbeiro'}', style: const TextStyle(color: Colors.grey)),
                              Text('Horário: ${ag['data_hora'] ?? '-'}', style: const TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold)),
                              if (telefone.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.phone, size: 14, color: Colors.greenAccent),
                                    const SizedBox(width: 4),
                                    Text(telefone, style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
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
                                      onPressed: () => _abrirModalConclusaoPagamento(id, clienteNome, preco),
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

class _OwnerServicosTab extends StatelessWidget {
  final String barbeariaId;
  const _OwnerServicosTab({required this.barbeariaId});

  void _abrirModalNovoServico(BuildContext context) {
    final nomeCtrl = TextEditingController();
    final precoCtrl = TextEditingController();
    final tempoCtrl = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Serviço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome (Ex: Barba Terapia)')),
            TextField(controller: precoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço (R\$)')),
            TextField(controller: tempoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duração (minutos)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
            onPressed: () {
              if (nomeCtrl.text.trim().isNotEmpty && precoCtrl.text.trim().isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('barbearias')
                    .doc(barbeariaId)
                    .collection('servicos')
                    .add({
                  'nome': nomeCtrl.text.trim(),
                  'preco': double.tryParse(precoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                  'duracao_minutos': int.tryParse(tempoCtrl.text.trim()) ?? 30,
                  'criado_em': FieldValue.serverTimestamp(),
                });
                Navigator.pop(ctx);
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
        onPressed: () => _abrirModalNovoServico(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('servicos')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final servicos = snapshot.data?.docs ?? [];

          if (servicos.isEmpty) {
            return const Center(child: Text('Nenhum serviço cadastrado. Toque em + para adicionar.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: servicos.length,
            itemBuilder: (ctx, i) {
              final s = servicos[i].data() as Map<String, dynamic>? ?? {};
              final id = servicos[i].id;
              final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;

              return Card(
                child: ListTile(
                  title: Text(s['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${s['duracao_minutos'] ?? 30} min'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('R\$ ${preco.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, color: Color(0xFFE0A96D), fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(barbeariaId)
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

// ---------------- ABA DE EQUIPE COM HORÁRIOS DE ENTRADA/SAÍDA E DIAS ----------------
class _OwnerBarbeirosTab extends StatelessWidget {
  final String barbeariaId;
  const _OwnerBarbeirosTab({required this.barbeariaId});

  void _abrirModalBarbeiro(BuildContext context, {String? barbeiroId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final comissaoCtrl = TextEditingController(text: (dadosAtuais?['comissao_porcentagem'] ?? 50).toString());
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
                TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do Profissional')),
                const SizedBox(height: 8),
                TextField(controller: comissaoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Comissão (%)')),
                const SizedBox(height: 16),
                const Text('Horário de Trabalho do Barbeiro:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
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
                  'comissao_porcentagem': int.tryParse(comissaoCtrl.text.trim()) ?? 50,
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
                        Text('Horário: $hInicio às $hFim • Comissão: ${b['comissao_porcentagem'] ?? 50}%', style: const TextStyle(color: Color(0xFFE0A96D), fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          servicosList.isEmpty ? 'Todos os serviços' : 'Faz: ${servicosList.join(", ")}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
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

// ---------------- ABA DE CONFIGURAÇÕES DE HORÁRIOS DA BARBEARIA ----------------
class _OwnerConfigHorariosTab extends StatefulWidget {
  final String barbeariaId;
  const _OwnerConfigHorariosTab({required this.barbeariaId});

  @override
  State<_OwnerConfigHorariosTab> createState() => _OwnerConfigHorariosTabState();
}

class _OwnerConfigHorariosTabState extends State<_OwnerConfigHorariosTab> {
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
                        children: const [
                          Icon(Icons.schedule, color: Color(0xFFE0A96D)),
                          SizedBox(width: 8),
                          Text('Horário Geral de Funcionamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
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
                          Text('Dias de Funcionamento da Barbearia', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
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

// ---------------- ABA FINANCEIRO ----------------
class _OwnerFinanceiroTab extends StatefulWidget {
  final String barbeariaId;
  const _OwnerFinanceiroTab({required this.barbeariaId});

  @override
  State<_OwnerFinanceiroTab> createState() => _OwnerFinanceiroTabState();
}

class _OwnerFinanceiroTabState extends State<_OwnerFinanceiroTab> {
  String _filtroBarbeiro = 'todos';
  String _filtroStatus = 'todos';
  String _filtroServico = 'todos';
  String _filtroFormaPagamento = 'todos';
  String _filtroPeriodo = 'todos';
  DateTimeRange? _intervaloCustom;

  Future<void> _selecionarPeriodoCustom() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
      initialDateRange: _intervaloCustom ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
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
        _intervaloCustom = picked;
        _filtroPeriodo = 'custom';
      });
    }
  }

  bool _verificarFiltroData(Map<String, dynamic> data) {
    if (_filtroPeriodo == 'todos') return true;

    final hoje = DateTime.now();
    final hojeStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(hoje);
    final dataIso = data['data_iso']?.toString() ?? '';
    final dataHora = data['data_hora']?.toString() ?? '';

    DateTime? dataAgendamento;
    if (dataIso.isNotEmpty) {
      try {
        dataAgendamento = DateTime.parse(dataIso);
      } catch (_) {}
    }

    if (_filtroPeriodo == 'hoje') {
      return dataHora.contains(hojeStr) || dataHora.toLowerCase().contains('hoje');
    }

    if (dataAgendamento != null) {
      if (_filtroPeriodo == '7dias') {
        final limite7 = hoje.subtract(const Duration(days: 7));
        return dataAgendamento.isAfter(limite7.subtract(const Duration(days: 1))) && dataAgendamento.isBefore(hoje.add(const Duration(days: 1)));
      }
      if (_filtroPeriodo == 'mes') {
        return dataAgendamento.month == hoje.month && dataAgendamento.year == hoje.year;
      }
      if (_filtroPeriodo == 'custom' && _intervaloCustom != null) {
        return dataAgendamento.isAfter(_intervaloCustom!.start.subtract(const Duration(days: 1))) &&
            dataAgendamento.isBefore(_intervaloCustom!.end.add(const Duration(days: 1)));
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('servicos').snapshots(),
      builder: (context, servicosSnap) {
        final servicosDocs = servicosSnap.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').snapshots(),
          builder: (context, barberSnap) {
            final barbeirosDocs = barberSnap.data?.docs ?? [];
            Map<String, int> comissoesMap = {};
            for (var b in barbeirosDocs) {
              final data = b.data() as Map<String, dynamic>;
              comissoesMap[b.id] = int.tryParse(data['comissao_porcentagem']?.toString() ?? '50') ?? 50;
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('barbearias')
                  .doc(widget.barbeariaId)
                  .collection('agendamentos')
                  .snapshots(),
              builder: (context, agSnap) {
                if (agSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final todosAgendamentos = agSnap.data?.docs ?? [];

                final agendamentosFiltrados = todosAgendamentos.where((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final bId = d['barbeiro_id']?.toString() ?? '';
                  final st = d['status']?.toString() ?? 'pendente';
                  final sNome = d['servico']?.toString() ?? '';
                  final fPag = d['forma_pagamento']?.toString() ?? '';

                  final bateBarbeiro = _filtroBarbeiro == 'todos' || bId == _filtroBarbeiro;
                  final bateStatus = _filtroStatus == 'todos' || st == _filtroStatus;
                  final bateServico = _filtroServico == 'todos' || sNome == _filtroServico;
                  final batePagamento = _filtroFormaPagamento == 'todos' || fPag == _filtroFormaPagamento;
                  final bateData = _verificarFiltroData(d);

                  return bateBarbeiro && bateStatus && bateServico && batePagamento && bateData;
                }).toList();

                double totalFaturado = 0.0;
                double totalComissoes = 0.0;
                int totalConcluidos = 0;
                int totalCancelados = 0;

                for (var doc in agendamentosFiltrados) {
                  final d = doc.data() as Map<String, dynamic>;
                  final bId = d['barbeiro_id']?.toString() ?? '';
                  final st = d['status']?.toString() ?? 'pendente';
                  final preco = (d['preco'] as num?)?.toDouble() ?? 0.0;

                  if (st == 'concluido') {
                    totalFaturado += preco;
                    totalConcluidos++;
                    final comissaoPct = comissoesMap[bId] ?? 50;
                    totalComissoes += (preco * comissaoPct) / 100;
                  } else if (st == 'cancelado') {
                    totalCancelados++;
                  }
                }

                final lucroLiquido = totalFaturado - totalComissoes;

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Hoje'),
                              selected: _filtroPeriodo == 'hoje',
                              selectedColor: const Color(0xFFE0A96D),
                              labelStyle: TextStyle(color: _filtroPeriodo == 'hoje' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                              onSelected: (s) => setState(() => _filtroPeriodo = 'hoje'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Últimos 7 dias'),
                              selected: _filtroPeriodo == '7dias',
                              selectedColor: const Color(0xFFE0A96D),
                              labelStyle: TextStyle(color: _filtroPeriodo == '7dias' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                              onSelected: (s) => setState(() => _filtroPeriodo = '7dias'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Este Mês'),
                              selected: _filtroPeriodo == 'mes',
                              selectedColor: const Color(0xFFE0A96D),
                              labelStyle: TextStyle(color: _filtroPeriodo == 'mes' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                              onSelected: (s) => setState(() => _filtroPeriodo = 'mes'),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('Tudo'),
                              selected: _filtroPeriodo == 'todos',
                              selectedColor: const Color(0xFFE0A96D),
                              labelStyle: TextStyle(color: _filtroPeriodo == 'todos' ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                              onSelected: (s) => setState(() => _filtroPeriodo = 'todos'),
                            ),
                            const SizedBox(width: 6),
                            ActionChip(
                              avatar: const Icon(Icons.date_range, size: 16, color: Color(0xFFE0A96D)),
                              label: Text(_filtroPeriodo == 'custom' && _intervaloCustom != null
                                  ? '${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.start)} - ${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.end)}'
                                  : 'Período'),
                              backgroundColor: _filtroPeriodo == 'custom' ? const Color(0xFFE0A96D).withOpacity(0.2) : const Color(0xFF2C2C2C),
                              side: BorderSide(color: _filtroPeriodo == 'custom' ? const Color(0xFFE0A96D) : Colors.transparent),
                              onPressed: _selecionarPeriodoCustom,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: const Color(0xFF222222),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text('Faturamento Bruto (Filtrado)', style: TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 4),
                              Text('R\$ ${totalFaturado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                              const Divider(height: 24, color: Colors.grey),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text('Comissões', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('R\$ ${totalComissoes.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text('Lucro Barbearia', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                      const SizedBox(height: 4),
                                      Text('R\$ ${lucroLiquido.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    const Text('Concluídos', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('$totalConcluidos', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    const Text('Cancelados', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                    const SizedBox(height: 4),
                                    Text('$totalCancelados', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Filtros Avançados', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filtroFormaPagamento,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Pagamento', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: const [
                                DropdownMenuItem(value: 'todos', child: Text('Todos Pagamentos', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'pix', child: Text('⚡ Pix')),
                                DropdownMenuItem(value: 'dinheiro', child: Text('💵 Dinheiro')),
                                DropdownMenuItem(value: 'cartao', child: Text('💳 Cartão')),
                              ],
                              onChanged: (val) => setState(() => _filtroFormaPagamento = val ?? 'todos'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filtroServico,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Serviço', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: [
                                const DropdownMenuItem(value: 'todos', child: Text('Todos Serviços', overflow: TextOverflow.ellipsis)),
                                ...servicosDocs.map((sDoc) {
                                  final d = sDoc.data() as Map<String, dynamic>;
                                  final sNome = d['nome']?.toString() ?? 'Serviço';
                                  return DropdownMenuItem(value: sNome, child: Text(sNome, overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              onChanged: (val) => setState(() => _filtroServico = val ?? 'todos'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filtroBarbeiro,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Barbeiro', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: [
                                const DropdownMenuItem(value: 'todos', child: Text('Todos Barbeiros', overflow: TextOverflow.ellipsis)),
                                ...barbeirosDocs.map((bDoc) {
                                  final d = bDoc.data() as Map<String, dynamic>;
                                  return DropdownMenuItem(value: bDoc.id, child: Text(d['nome']?.toString() ?? 'Barbeiro', overflow: TextOverflow.ellipsis));
                                }),
                              ],
                              onChanged: (val) => setState(() => _filtroBarbeiro = val ?? 'todos'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _filtroStatus,
                              isDense: true,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              items: const [
                                DropdownMenuItem(value: 'todos', child: Text('Todos Status', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'concluido', child: Text('Concluídos')),
                                DropdownMenuItem(value: 'cancelado', child: Text('Cancelados')),
                              ],
                              onChanged: (val) => setState(() => _filtroStatus = val ?? 'todos'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Histórico Financeiro', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                      const SizedBox(height: 8),
                      if (agendamentosFiltrados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Center(child: Text('Nenhum atendimento para os filtros selecionados.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: agendamentosFiltrados.length,
                          itemBuilder: (ctx, i) {
                            final ag = agendamentosFiltrados[i].data() as Map<String, dynamic>;
                            final status = ag['status']?.toString() ?? 'pendente';
                            final preco = (ag['preco'] as num?)?.toDouble() ?? 0.0;
                            final bNome = ag['barbeiro_nome']?.toString() ?? 'Barbeiro';
                            final fPag = ag['forma_pagamento']?.toString() ?? '';

                            Color corBadge = Colors.orangeAccent;
                            if (status == 'concluido') corBadge = Colors.green;
                            if (status == 'cancelado') corBadge = Colors.redAccent;

                            String textoPag = '';
                            if (fPag == 'pix') textoPag = '⚡ PIX';
                            if (fPag == 'dinheiro') textoPag = '💵 DINHEIRO';
                            if (fPag == 'cartao') textoPag = '💳 CARTÃO';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: corBadge.withOpacity(0.2),
                                  child: Icon(
                                    status == 'concluido' ? Icons.check : (status == 'cancelado' ? Icons.close : Icons.schedule),
                                    color: corBadge,
                                  ),
                                ),
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(ag['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Text('R\$ ${preco.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${ag['servico']} com $bNome • ${ag['data_hora'] ?? '-'}'),
                                    if (textoPag.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('Recebido via: $textoPag', style: const TextStyle(color: Colors.tealAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ],
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: corBadge.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: corBadge.withOpacity(0.5)),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: TextStyle(color: corBadge, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------------- FLUXO DE AGENDAMENTO (CALCULA SLOTS COM BASE NO TURNO DO BARBEIRO) ----------------
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
      await FirebaseFirestore.instance
          .collection('barbearias')
          .doc(widget.barbeariaId)
          .collection('agendamentos')
          .add({
        'cliente_nome': nome,
        'cliente_telefone': telefone,
        'servico': _servicoSelecionado,
        'preco': _precoSelecionado,
        'barbeiro_id': _barbeiroSelecionado,
        'barbeiro_nome': _barbeiroNome,
        'data_iso': DateFormat('yyyy-MM-dd').format(_dataSelecionada),
        'horario': _horarioSelecionado,
        'data_hora': dataHoraCompleta,
        'status': 'pendente',
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
                  decoration: const InputDecoration(labelText: 'WhatsApp com DDD (Ex: 62999998888) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
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
                const Text('5. Horários Disponíveis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
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

// ---------------- PAINEL DO BARBEIRO ----------------
class BarberDashboard extends StatelessWidget {
  final String barbeariaId;
  final String barberId;
  const BarberDashboard({super.key, required this.barbeariaId, required this.barberId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Barbeiro'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('agendamentos')
            .where('barbeiro_id', isEqualTo: barberId)
            .where('status', isEqualTo: 'pendente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ags = snapshot.data?.docs ?? [];

          if (ags.isEmpty) {
            return const Center(child: Text('Nenhum atendimento na sua fila.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ags.length,
            itemBuilder: (ctx, i) {
              final ag = ags[i].data() as Map<String, dynamic>? ?? {};
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person, color: Color(0xFFE0A96D)),
                  title: Text(ag['cliente_nome'] ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${ag['servico']} - ${ag['data_hora']}'),
                  trailing: const Text('Pendente', style: TextStyle(color: Colors.orangeAccent)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
