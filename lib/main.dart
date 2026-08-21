import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'screens/clientes_screen.dart';
import 'screens/agenda_screen.dart';
import 'screens/produtos_screen.dart';
import 'screens/servicos_screen.dart';
import 'screens/equipe_screen.dart';

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
      supportedLocales: const [Locale('pt', 'BR')],
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

            if (role == 'superadmin') return const SuperAdminDashboard();
            if (role == 'dono') return OwnerDashboard(barbeariaId: tenantId);
            if (role == 'barbeiro') return BarberDashboard(barbeariaId: tenantId, barberId: user.uid);

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
      _OwnerProdutosTab(barbeariaId: widget.barbeariaId),
      _OwnerBarbeirosTab(barbeariaId: widget.barbeariaId),
      _OwnerFinanceiroTab(barbeariaId: widget.barbeariaId),
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


  final String barbeariaId;
  const _OwnerAgendamentosTab({required this.barbeariaId});

  @override
  State<_OwnerAgendamentosTab> createState() => _OwnerAgendamentosTabState();
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

// ---------------- HUB PRINCIPAL DO FINANCEIRO (DRE COM PAGO VS. ABERTO) ----------------
class _OwnerFinanceiroTab extends StatefulWidget {
  final String barbeariaId;
  const _OwnerFinanceiroTab({required this.barbeariaId});

  @override
  State<_OwnerFinanceiroTab> createState() => _OwnerFinanceiroTabState();
}

class _OwnerFinanceiroTabState extends State<_OwnerFinanceiroTab> {
  String _filtroPeriodo = 'todos';
  DateTimeRange? _intervaloCustom;

  void _abrirModalNovaDespesa() {
    final descCtrl = TextEditingController();
    final valorCtrl = TextEditingController();
    String categoria = 'Fixa (Aluguel/Luz/Água/Net)';
    String formaPagamento = 'pix';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Lançar Nova Despesa'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Descrição da Despesa (Ex: Conta de Energia) *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor da Despesa (R\$) *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                const Text('Categoria:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: categoria,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'Fixa (Aluguel/Luz/Água/Net)', child: Text('🏠 Fixa (Aluguel/Luz/Água/Net)')),
                    DropdownMenuItem(value: 'Insumos / Lâminas / Descartáveis', child: Text('✂ Insumos / Lâminas / Descartáveis')),
                    DropdownMenuItem(value: 'Reposição de Estoque', child: Text('📦 Reposição de Estoque')),
                    DropdownMenuItem(value: 'Limpeza / Manutenção', child: Text('🧹 Limpeza / Manutenção')),
                    DropdownMenuItem(value: 'Marketing / Anúncios', child: Text('📢 Marketing / Anúncios')),
                    DropdownMenuItem(value: 'Outros', child: Text('📌 Outros')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => categoria = val);
                  },
                ),
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
                    DropdownMenuItem(value: 'boleto', child: Text('📄 Boleto / Transferência')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => formaPagamento = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                if (descCtrl.text.trim().isNotEmpty && valorCtrl.text.trim().isNotEmpty) {
                  final hoje = DateTime.now();
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('despesas')
                      .add({
                    'descricao': descCtrl.text.trim(),
                    'valor': double.tryParse(valorCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                    'categoria': categoria,
                    'forma_pagamento': formaPagamento,
                    'pago': false, // Começa em aberto por padrão
                    'data_iso': DateFormat('yyyy-MM-dd').format(hoje),
                    'data_formatada': DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(hoje),
                    'criado_em': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Lançar Despesa', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalNovoVale(List<QueryDocumentSnapshot> barbeirosDocs) {
    if (barbeirosDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre barbeiros primeiro para lançar vales.')));
      return;
    }

    String barbeiroSelecionadoId = barbeirosDocs.first.id;
    String barbeiroSelecionadoNome = (barbeirosDocs.first.data() as Map<String, dynamic>)['nome']?.toString() ?? 'Barbeiro';
    final valorCtrl = TextEditingController();
    final motivoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Lançar Vale / Adiantamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selecione o Barbeiro:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: barbeiroSelecionadoId,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: barbeirosDocs.map((bDoc) {
                    final bData = bDoc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: bDoc.id,
                      child: Text(bData['nome']?.toString() ?? 'Barbeiro'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        barbeiroSelecionadoId = val;
                        final match = barbeirosDocs.firstWhere((d) => d.id == val);
                        barbeiroSelecionadoNome = (match.data() as Map<String, dynamic>)['nome']?.toString() ?? 'Barbeiro';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valorCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Valor do Vale (R\$) *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motivoCtrl,
                  decoration: const InputDecoration(labelText: 'Motivo / Observação (Opcional)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black),
              onPressed: () async {
                if (valorCtrl.text.trim().isNotEmpty) {
                  final hoje = DateTime.now();
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('vales_barbeiros')
                      .add({
                    'barbeiro_id': barbeiroSelecionadoId,
                    'barbeiro_nome': barbeiroSelecionadoNome,
                    'valor': double.tryParse(valorCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                    'motivo': motivoCtrl.text.trim(),
                    'vale_liquidado': false,
                    'data_iso': DateFormat('yyyy-MM-dd').format(hoje),
                    'data_formatada': DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(hoje),
                    'criado_em': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Vale de R\$ ${valorCtrl.text} lançado para $barbeiroSelecionadoNome!')),
                    );
                  }
                }
              },
              child: const Text('Confirmar Vale', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirModalReceberMensalidadeAvulsa(List<QueryDocumentSnapshot> clientesDocs) {
    final assinantes = clientesDocs.where((c) {
      final data = c.data() as Map<String, dynamic>;
      return (data['plano_id']?.toString() ?? 'nenhum') != 'nenhum';
    }).toList();

    if (assinantes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum cliente assinante cadastrado.')));
      return;
    }

    String clienteSelecionadoId = assinantes.first.id;
    String clienteSelecionadoNome = (assinantes.first.data() as Map<String, dynamic>)['nome']?.toString() ?? 'Cliente';
    String planoNome = (assinantes.first.data() as Map<String, dynamic>)['plano_nome']?.toString() ?? 'Plano';
    double valorPlano = ((assinantes.first.data() as Map<String, dynamic>)['plano_preco'] as num?)?.toDouble() ?? 0.0;
    String formaPagamento = 'pix';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Receber Mensalidade de Plano'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selecione o Cliente Assinante:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: clienteSelecionadoId,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: assinantes.map((cDoc) {
                    final cData = cDoc.data() as Map<String, dynamic>;
                    final nome = cData['nome']?.toString() ?? 'Cliente';
                    final pNome = cData['plano_nome']?.toString() ?? 'Plano';
                    return DropdownMenuItem<String>(
                      value: cDoc.id,
                      child: Text('$nome ($pNome)', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() {
                        clienteSelecionadoId = val;
                        final match = assinantes.firstWhere((d) => d.id == val);
                        final cData = match.data() as Map<String, dynamic>;
                        clienteSelecionadoNome = cData['nome']?.toString() ?? 'Cliente';
                        planoNome = cData['plano_nome']?.toString() ?? 'Plano';
                        valorPlano = (cData['plano_preco'] as num?)?.toDouble() ?? 0.0;
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                Text('Valor a Receber: R\$ ${valorPlano.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
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
                  'cliente_id': clienteSelecionadoId,
                  'cliente_nome': clienteSelecionadoNome,
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
                    .doc(clienteSelecionadoId)
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

  Future<void> _gerarRelatorioPdf({
    required double totalFaturado,
    required double despesasPagas,
    required double despesasAberto,
    required double comissoesPagas,
    required double comissoesAberto,
    required double lucroLiquido,
    required List<QueryDocumentSnapshot> registros,
  }) async {
    final docPdf = pw.Document();

    String periodoDescricao = 'Todos os Registros';
    if (_filtroPeriodo == 'hoje') periodoDescricao = 'Hoje (${DateFormat('dd/MM/yyyy', 'pt_BR').format(DateTime.now())})';
    if (_filtroPeriodo == '7dias') periodoDescricao = 'Últimos 7 dias';
    if (_filtroPeriodo == 'mes') periodoDescricao = 'Este Mês (${DateFormat('MM/yyyy', 'pt_BR').format(DateTime.now())})';
    if (_filtroPeriodo == 'custom' && _intervaloCustom != null) {
      periodoDescricao = '${DateFormat('dd/MM/yyyy', 'pt_BR').format(_intervaloCustom!.start)} até ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_intervaloCustom!.end)}';
    }

    docPdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RELATÓRIO FINANCEIRO (DRE)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Período: $periodoDescricao', style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                  pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(6),
                color: PdfColors.grey100,
              ),
              child: pw.Column(
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('FATURAMENTO BRUTO:'), pw.Text('R\$ ${totalFaturado.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Despesas (Pagas / Aberto):'), pw.Text('R\$ ${despesasPagas.toStringAsFixed(2)} / R\$ ${despesasAberto.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Comissões (Pagas / Aberto):'), pw.Text('R\$ ${comissoesPagas.toStringAsFixed(2)} / R\$ ${comissoesAberto.toStringAsFixed(2)}')]),
                  pw.Divider(height: 12),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('LUCRO REAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('R\$ ${lucroLiquido.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))]),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => docPdf.save(),
      name: 'relatorio_financeiro_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('clientes').snapshots(),
      builder: (context, clientesSnap) {
        final clientesDocs = clientesSnap.data?.docs ?? [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('mensalidades').snapshots(),
          builder: (context, mensalidadesSnap) {
            final todasMensalidades = mensalidadesSnap.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('vales_barbeiros').snapshots(),
              builder: (context, valesSnap) {
                final todosVales = valesSnap.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('repasses_barbeiros').snapshots(),
                  builder: (context, repassesSnap) {
                    final todosRepassesFeitos = repassesSnap.data?.docs ?? [];

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('despesas').snapshots(),
                      builder: (context, despesasSnap) {
                        final todasDespesas = despesasSnap.data?.docs ?? [];

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').snapshots(),
                          builder: (context, barberSnap) {
                            final barbeirosDocs = barberSnap.data?.docs ?? [];

                            Map<String, Map<String, int>> comissoesBarbeirosMap = {};
                            for (var b in barbeirosDocs) {
                              final data = b.data() as Map<String, dynamic>;
                              comissoesBarbeirosMap[b.id] = {
                                'servico': int.tryParse(data['comissao_porcentagem']?.toString() ?? '50') ?? 50,
                                'produto': int.tryParse(data['comissao_produtos_pct']?.toString() ?? '10') ?? 10,
                                'assinante': int.tryParse(data['comissao_assinante_pct']?.toString() ?? '30') ?? 30,
                              };
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
                                final agendamentosFiltrados = todosAgendamentos.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final despesasFiltradas = todasDespesas.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final mensalidadesFiltradas = todasMensalidades.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final valesFiltrados = todosVales.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final repassesFeitosFiltrados = todosRepassesFeitos.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();

                                // Despesas pagas vs. em aberto
                                double despesasPagas = 0.0;
                                double despesasAberto = 0.0;
                                for (var dDoc in despesasFiltradas) {
                                  final d = dDoc.data() as Map<String, dynamic>;
                                  final val = (d['valor'] as num?)?.toDouble() ?? 0.0;
                                  if (d['pago'] == true) {
                                  despesasPagas += val;
                                  } else {
                                    despesasAberto += val;
                                  }
                                }

                                // Comissões já pagas (via histórico de repasses) vs. em aberto (pendentes)
                                double comissoesPagas = 0.0;
                                for (var rDoc in repassesFeitosFiltrados) {
                                  final r = rDoc.data() as Map<String, dynamic>;
                                  comissoesPagas += (r['valor_comissoes'] as num?)?.toDouble() ?? 0.0;
                                }

                                double totalServicos = 0.0;
                                double totalProdutos = 0.0;
                                double totalComissoesGeral = 0.0;
                                double totalComissoesPendentes = 0.0;
                                double totalValesPendentes = 0.0;

                                for (var vDoc in valesFiltrados) {
                                  final d = vDoc.data() as Map<String, dynamic>;
                                  if (d['vale_liquidado'] != true) {
                                    totalValesPendentes += (d['valor'] as num?)?.toDouble() ?? 0.0;
                                  }
                                }

                                for (var doc in agendamentosFiltrados) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  final bId = d['barbeiro_id']?.toString() ?? '';
                                  final st = d['status']?.toString() ?? 'pendente';
                                  final precoTotal = (d['preco'] as num?)?.toDouble() ?? 0.0;
                                  final precoProd = (d['preco_produtos'] as num?)?.toDouble() ?? 0.0;
                                  final precoServCobrado = (d['preco_servico'] as num?)?.toDouble() ?? (precoTotal - precoProd);
                                  final precoTabelaOriginal = (d['preco_tabela_original'] as num?)?.toDouble() ?? precoServCobrado;
                                  final cobertoPorPlano = d['coberto_por_plano'] == true;
                                  final repasseLiquidado = d['repasse_liquidado'] == true;

                                  final comissoesDoBarbeiro = comissoesBarbeirosMap[bId] ?? {'servico': 50, 'produto': 10, 'assinante': 30};

                                  if (st == 'concluido') {
                                    totalServicos += precoServCobrado;
                                    totalProdutos += precoProd;

                                    double comissaoDesteAtendimento = 0.0;
                                    if (cobertoPorPlano) {
                                      final pctAssinante = comissoesDoBarbeiro['assinante'] ?? 30;
                                      comissaoDesteAtendimento += (precoTabelaOriginal * pctAssinante) / 100;
                                    } else {
                                      final pctServico = comissoesDoBarbeiro['servico'] ?? 50;
                                      comissaoDesteAtendimento += (precoServCobrado * pctServico) / 100;
                                    }

                                    if (precoProd > 0) {
                                      final pctProd = comissoesDoBarbeiro['produto'] ?? 10;
                                      comissaoDesteAtendimento += (precoProd * pctProd) / 100;
                                    }

                                    totalComissoesGeral += comissaoDesteAtendimento;

                                    if (!repasseLiquidado) {
                                      totalComissoesPendentes += comissaoDesteAtendimento;
                                    }
                                  }
                                }

                                double totalMensalidades = 0.0;
                                for (var mDoc in mensalidadesFiltradas) {
                                  final d = mDoc.data() as Map<String, dynamic>;
                                  totalMensalidades += (d['valor'] as num?)?.toDouble() ?? 0.0;
                                }

                                final comissoesAberto = totalComissoesPendentes;
                                final faturamentoBrutoTotal = totalServicos + totalProdutos + totalMensalidades;
                                final totalDespesasGeral = despesasPagas + despesasAberto;
                                final lucroLiquido = faturamentoBrutoTotal - totalDespesasGeral - totalComissoesGeral;
                                final liquidoRepassePendenteGeral = (totalComissoesPendentes - totalValesPendentes).clamp(0.0, 999999.0);

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
                                              const Text('Faturamento Bruto Total', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                              const SizedBox(height: 4),
                                              Text('R\$ ${faturamentoBrutoTotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                                              const Divider(height: 24, color: Colors.grey),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                                children: [
                                                  Column(
                                                    children: [
                                                      const Text('👑 Planos', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${totalMensalidades.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      const Text('🔴 Despesas (P/A)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${despesasPagas.toStringAsFixed(0)} / R\$ ${despesasAberto.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      const Text('🟠 Comissões (P/A)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${comissoesPagas.toStringAsFixed(0)} / R\$ ${comissoesAberto.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      const Text('🟢 Lucro Real', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${lucroLiquido.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                            icon: const Icon(Icons.add, size: 16),
                                            label: const Text('Nova Despesa', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            onPressed: () => _abrirModalNovaDespesa(),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                            icon: const Icon(Icons.money, size: 16),
                                            label: const Text('Lançar Vale', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            onPressed: () => _abrirModalNovoVale(barbeirosDocs),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                            icon: const Icon(Icons.workspace_premium, size: 16),
                                            label: const Text('Receber Plano', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            onPressed: () => _abrirModalReceberMensalidadeAvulsa(clientesDocs),
                                          ),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                                            icon: const Icon(Icons.picture_as_pdf, size: 16),
                                            label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            onPressed: () => _gerarRelatorioPdf(
                                              totalFaturado: faturamentoBrutoTotal,
                                              despesasPagas: despesasPagas,
                                              despesasAberto: despesasAberto,
                                              comissoesPagas: comissoesPagas,
                                              comissoesAberto: comissoesAberto,
                                              lucroLiquido: lucroLiquido,
                                              registros: agendamentosFiltrados,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      const Text('Módulos e Históricos Financeiros', style: TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 8),

                                      Card(
                                        color: const Color(0xFF1E1E1E),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Colors.orangeAccent,
                                            child: Icon(Icons.people, color: Colors.black),
                                          ),
                                          title: const Text('Repasses da Equipe (A Pagar)', style: TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Pendente geral: R\$ ${liquidoRepassePendenteGeral.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => RepassesEquipeScreen(barbeariaId: widget.barbeariaId)),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      Card(
                                        color: const Color(0xFF1E1E1E),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFF00C853),
                                            child: Icon(Icons.history_edu, color: Colors.black),
                                          ),
                                          title: const Text('Histórico de Repasses Pagos (Recibos)', style: TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('${repassesFeitosFiltrados.length} acertos liquidados (Com opção de estorno)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => HistoricoRecibosScreen(barbeariaId: widget.barbeariaId)),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      Card(
                                        color: const Color(0xFF1E1E1E),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFFE0A96D),
                                            child: Icon(Icons.account_balance_wallet, color: Colors.black),
                                          ),
                                          title: const Text('Extrato Geral de Caixa (Linha do Tempo)', style: TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: const Text('Fluxo unificado de atendimentos, produtos e planos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => ExtratoCaixaScreen(barbeariaId: widget.barbeariaId)),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      Card(
                                        color: const Color(0xFF1E1E1E),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Colors.redAccent,
                                            child: Icon(Icons.money_off, color: Colors.black),
                                          ),
                                          title: const Text('Despesas Operacionais (Saídas & Quitação)', style: TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Pagas: R\$ ${despesasPagas.toStringAsFixed(2)} | Aberto: R\$ ${despesasAberto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => DespesasScreen(barbeariaId: widget.barbeariaId)),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      Card(
                                        color: const Color(0xFF1E1E1E),
                                        child: ListTile(
                                          leading: const CircleAvatar(
                                            backgroundColor: Color(0xFF00E5FF),
                                            child: Icon(Icons.workspace_premium, color: Colors.black),
                                          ),
                                          title: const Text('Mensalidades de Planos Recebidas', style: TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('${mensalidadesFiltradas.length} mensalidades • R\$ ${totalMensalidades.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => MensalidadesRecebidasScreen(barbeariaId: widget.barbeariaId)),
                                            );
                                          },
                                        ),
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
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------------- SUBTELA 1: REPASSES DA EQUIPE (EXIBINDO O VALOR DIRETO NO CARD) ----------------
class RepassesEquipeScreen extends StatelessWidget {
  final String barbeariaId;
  const RepassesEquipeScreen({super.key, required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repasses da Equipe (A Pagar)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('vales_barbeiros').snapshots(),
        builder: (context, valesSnap) {
          final todosVales = valesSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('barbeiros').snapshots(),
            builder: (context, barberSnap) {
              if (!barberSnap.hasData) return const Center(child: CircularProgressIndicator());
              final barbeirosDocs = barberSnap.data!.docs;

              if (barbeirosDocs.isEmpty) {
                return const Center(child: Text('Nenhum barbeiro cadastrado.', style: TextStyle(color: Colors.grey)));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('agendamentos').snapshots(),
                builder: (context, agSnap) {
                  if (!agSnap.hasData) return const Center(child: CircularProgressIndicator());
                  final todosAgendamentos = agSnap.data!.docs;

                  Map<String, Map<String, int>> comissoesBarbeirosMap = {};
                  for (var b in barbeirosDocs) {
                    final data = b.data() as Map<String, dynamic>;
                    comissoesBarbeirosMap[b.id] = {
                      'servico': int.tryParse(data['comissao_porcentagem']?.toString() ?? '50') ?? 50,
                      'produto': int.tryParse(data['comissao_produtos_pct']?.toString() ?? '10') ?? 10,
                      'assinante': int.tryParse(data['comissao_assinante_pct']?.toString() ?? '30') ?? 30,
                    };
                  }

                  Map<String, double> valesPendentesPorBarbeiro = {};
                  for (var vDoc in todosVales) {
                    final d = vDoc.data() as Map<String, dynamic>;
                    final bId = d['barbeiro_id']?.toString() ?? '';
                    final vValor = (d['valor'] as num?)?.toDouble() ?? 0.0;
                    if (d['vale_liquidado'] != true) {
                      valesPendentesPorBarbeiro[bId] = (valesPendentesPorBarbeiro[bId] ?? 0.0) + vValor;
                    }
                  }

                  Map<String, double> comissoesPendentesPorBarbeiro = {};
                  for (var doc in todosAgendamentos) {
                    final d = doc.data() as Map<String, dynamic>;
                    final bId = d['barbeiro_id']?.toString() ?? '';
                    final st = d['status']?.toString() ?? 'pendente';
                    final precoTotal = (d['preco'] as num?)?.toDouble() ?? 0.0;
                    final precoProd = (d['preco_produtos'] as num?)?.toDouble() ?? 0.0;
                    final precoServ = (d['preco_servico'] as num?)?.toDouble() ?? (precoTotal - precoProd);
                    final tabelaOriginal = (d['preco_tabela_original'] as num?)?.toDouble() ?? precoServ;
                    final coberto = d['coberto_por_plano'] == true;
                    final liquidado = d['repasse_liquidado'] == true;

                    final config = comissoesBarbeirosMap[bId] ?? {'servico': 50, 'produto': 10, 'assinante': 30};

                    if (st == 'concluido' && !liquidado) {
                      double com = 0.0;
                      if (coberto) {
                        com += (tabelaOriginal * (config['assinante'] ?? 30)) / 100;
                      } else {
                        com += (precoServ * (config['servico'] ?? 50)) / 100;
                      }
                      if (precoProd > 0) {
                        com += (precoProd * (config['produto'] ?? 10)) / 100;
                      }
                      comissoesPendentesPorBarbeiro[bId] = (comissoesPendentesPorBarbeiro[bId] ?? 0.0) + com;
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: barbeirosDocs.length,
                    itemBuilder: (ctx, i) {
                      final bDoc = barbeirosDocs[i];
                      final bData = bDoc.data() as Map<String, dynamic>;
                      final bNome = bData['nome']?.toString() ?? 'Barbeiro';

                      final coms = comissoesPendentesPorBarbeiro[bDoc.id] ?? 0.0;
                      final vals = valesPendentesPorBarbeiro[bDoc.id] ?? 0.0;
                      final liquido = (coms - vals).clamp(0.0, 999999.0);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE0A96D),
                            child: Text(bNome.isNotEmpty ? bNome[0].toUpperCase() : 'B', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(bNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('A Pagar: R\$ ${liquido.toStringAsFixed(2)} (Comissões: R\$ ${coms.toStringAsFixed(2)} | Vales: R\$ ${vals.toStringAsFixed(2)})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuditoriaBarbeiroScreen(
                                  barbeariaId: barbeariaId,
                                  barbeiroId: bDoc.id,
                                  barbeiroNome: bNome,
                                  comissoesConfig: bData,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- TELA DE AUDITORIA ANALÍTICA POR BARBEIRO ----------------
class AuditoriaBarbeiroScreen extends StatelessWidget {
  final String barbeariaId;
  final String barbeiroId;
  final String barbeiroNome;
  final Map<String, dynamic> comissoesConfig;

  const AuditoriaBarbeiroScreen({
    super.key,
    required this.barbeariaId,
    required this.barbeiroId,
    required this.barbeiroNome,
    required this.comissoesConfig,
  });

  Future<void> _gerarReciboDetalhadoPdf(
    BuildContext context, {
    required double comissaoServicos,
    required double comissaoAssinaturas,
    required double comissaoProdutos,
    required double totalVales,
    required double liquidoFinal,
    required List<Map<String, dynamic>> itensDetalhados,
  }) async {
    final docPdf = pw.Document();
    final dataFmt = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now());

    docPdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('RECIBO DE REPASSE DETALHADO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Profissional: $barbeiroNome', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Text('Data: $dataFmt', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cortes e Serviços Avulsos:'), pw.Text('Comissão: R\$ ${comissaoServicos.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Atendimentos de Assinantes (Planos):'), pw.Text('Comissão: R\$ ${comissaoAssinaturas.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Comissão sobre Produtos Vendidos:'), pw.Text('R\$ ${comissaoProdutos.toStringAsFixed(2)}')]),
                  if (totalVales > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('(-) Vales / Adiantamentos Abatidos:'), pw.Text('- R\$ ${totalVales.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red800))]),
                  ],
                  pw.Divider(height: 12),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('VALOR LÍQUIDO PAGO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)), pw.Text('R\$ ${liquidoFinal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green800))]),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Extrato Analítico dos Atendimentos:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Data/Hora', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Cliente / Serviço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Categoria', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Valor Base', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Comissão', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  ],
                ),
                ...itensDetalhados.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['data_hora'] ?? '-', style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item['cliente']} - ${item['servico']}', style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['categoria'], style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('R\$ ${item['valor_base'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('R\$ ${item['comissao'].toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Assinatura do Profissional ($barbeiroNome)', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => docPdf.save(),
      name: 'recibo_detalhado_${barbeiroNome}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  void _abrirModalLiquidar(
    BuildContext context, {
    required double comissoesBrutas,
    required double totalVales,
    required List<String> agsIds,
    required List<String> valesIds,
    required double servicosComissao,
    required double assinaturasComissao,
    required double produtosComissao,
    required double totalServicosBase,
    required double totalAssinaturasBase,
    required double totalProdutosBase,
    required List<Map<String, dynamic>> itensDetalhados,
  }) {
    final double liquidoAPagar = (comissoesBrutas - totalVales).clamp(0.0, 999999.0);
    String formaPagamento = 'pix';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Liquidar Repasse • $barbeiroNome'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comissões Totais: R\$ ${comissoesBrutas.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
              if (totalVales > 0)
                Text('(-) Vales Abatidos: R\$ ${totalVales.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Líquido a Pagar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('R\$ ${liquidoAPagar.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Forma de Pagamento:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE0A96D))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: formaPagamento,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'pix', child: Text('⚡ Pix')),
                  DropdownMenuItem(value: 'dinheiro', child: Text('💵 Dinheiro')),
                  DropdownMenuItem(value: 'transferencia', child: Text('🏦 Transferência')),
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

                await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('repasses_barbeiros').add({
                  'barbeiro_id': barbeiroId,
                  'barbeiro_nome': barbeiroNome,
                  'valor_comissoes': comissoesBrutas,
                  'valor_vales_abatidos': totalVales,
                  'valor_total_repasse': liquidoAPagar,
                  'detalhe_servicos_comissao': servicosComissao,
                  'detalhe_assinaturas_comissao': assinaturasComissao,
                  'detalhe_produtos_comissao': produtosComissao,
                  'itens_analiticos': itensDetalhados,
                  'ags_ids': agsIds,
                  'vales_ids': valesIds,
                  'forma_pagamento': formaPagamento,
                  'data_iso': DateFormat('yyyy-MM-dd').format(hoje),
                  'data_formatada': DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(hoje),
                  'pago_em': FieldValue.serverTimestamp(),
                });

                for (var id in agsIds) {
                  await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('agendamentos').doc(id).update({'repasse_liquidado': true});
                }
                for (var id in valesIds) {
                  await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('vales_barbeiros').doc(id).update({'vale_liquidado': true});
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                  _gerarReciboDetalhadoPdf(
                    context,
                    comissaoServicos: servicosComissao,
                    comissaoAssinaturas: assinaturasComissao,
                    comissaoProdutos: produtosComissao,
                    totalVales: totalVales,
                    liquidoFinal: liquidoAPagar,
                    itensDetalhados: itensDetalhados,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Repasse de $barbeiroNome liquidado!'), backgroundColor: Colors.green.shade800));
                }
              },
              child: const Text('Confirmar Pagamento', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pctServico = int.tryParse(comissoesConfig['comissao_porcentagem']?.toString() ?? '50') ?? 50;
    final pctProduto = int.tryParse(comissoesConfig['comissao_produtos_pct']?.toString() ?? '10') ?? 10;
    final pctAssinante = int.tryParse(comissoesConfig['comissao_assinante_pct']?.toString() ?? '30') ?? 30;

    return Scaffold(
      appBar: AppBar(title: Text('Auditoria: $barbeiroNome')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('vales_barbeiros')
            .where('barbeiro_id', isEqualTo: barbeiroId).snapshots(),
        builder: (context, valesSnap) {
          final valesDocs = valesSnap.data?.docs ?? [];
          double totalVales = 0.0;
          List<String> valesIds = [];
          for (var v in valesDocs) {
            final data = v.data() as Map<String, dynamic>;
            if (data['vale_liquidado'] != true) {
              totalVales += (data['valor'] as num?)?.toDouble() ?? 0.0;
              valesIds.add(v.id);
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('agendamentos')
                .where('barbeiro_id', isEqualTo: barbeiroId).where('status', isEqualTo: 'concluido').snapshots(),
            builder: (context, agSnap) {
              if (!agSnap.hasData) return const Center(child: CircularProgressIndicator());
              final agDocs = agSnap.data!.docs;

              double servicosBase = 0.0, servicosComissao = 0.0;
              double assinaturasBase = 0.0, assinaturasComissao = 0.0;
              double produtosBase = 0.0, produtosComissao = 0.0;

              List<String> agsIds = [];
              List<Map<String, dynamic>> itensDetalhados = [];

              for (var doc in agDocs) {
                final d = doc.data() as Map<String, dynamic>;
                if (d['repasse_liquidado'] == true) continue;

                agsIds.add(doc.id);
                final precoTotal = (d['preco'] as num?)?.toDouble() ?? 0.0;
                final precoProd = (d['preco_produtos'] as num?)?.toDouble() ?? 0.0;
                final precoServ = (d['preco_servico'] as num?)?.toDouble() ?? (precoTotal - precoProd);
                final tabelaOriginal = (d['preco_tabela_original'] as num?)?.toDouble() ?? precoServ;
                final coberto = d['coberto_por_plano'] == true;
                final dataHora = d['data_hora'] ?? '-';
                final cliente = d['cliente_nome'] ?? 'Cliente';
                final servico = d['servico'] ?? 'Serviço';
                final produtosExtrasList = (d['produtos_extras'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                if (coberto) {
                  final com = (tabelaOriginal * pctAssinante) / 100;
                  assinaturasBase += tabelaOriginal;
                  assinaturasComissao += com;
                  itensDetalhados.add({
                    'data_hora': dataHora,
                    'cliente': cliente,
                    'servico': '$servico (Assinatura)',
                    'categoria': 'Assinatura',
                    'valor_base': tabelaOriginal,
                    'comissao': com,
                  });
                } else {
                  final com = (precoServ * pctServico) / 100;
                  servicosBase += precoServ;
                  servicosComissao += com;
                  itensDetalhados.add({
                    'data_hora': dataHora,
                    'cliente': cliente,
                    'servico': servico,
                    'categoria': 'Corte Avulso',
                    'valor_base': precoServ,
                    'comissao': com,
                  });
                }

                if (precoProd > 0) {
                  final comProd = (precoProd * pctProduto) / 100;
                  produtosBase += precoProd;
                  produtosComissao += comProd;
                  itensDetalhados.add({
                    'data_hora': dataHora,
                    'cliente': cliente,
                    'servico': 'Produtos: ${produtosExtrasList.join(", ")}',
                    'categoria': 'Produtos',
                    'valor_base': precoProd,
                    'comissao': comProd,
                  });
                }
              }

              final comissaoTotal = servicosComissao + assinaturasComissao + produtosComissao;
              final liquidoFinal = (comissaoTotal - totalVales).clamp(0.0, 999999.0);

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1E1E1E),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Discriminação Analítica do Repasse', style: TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('✂ Cortes Avulsos: R\$ ${servicosComissao.toStringAsFixed(2)} ($pctServico%)', style: const TextStyle(fontSize: 13)),
                        Text('👑 Assinaturas / Planos: R\$ ${assinaturasComissao.toStringAsFixed(2)} ($pctAssinante%)', style: const TextStyle(fontSize: 13)),
                        Text('📦 Produtos Vendidos: R\$ ${produtosComissao.toStringAsFixed(2)} ($pctProduto%)', style: const TextStyle(fontSize: 13)),
                        if (totalVales > 0)
                          Text('(-) Vales Adiantados: R\$ ${totalVales.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Líquido a Pagar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('R\$ ${liquidoFinal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black),
                          icon: const Icon(Icons.check),
                          label: const Text('Liquidar Repasse & Gerar Recibo PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: (comissaoTotal > 0 || totalVales > 0)
                              ? () => _abrirModalLiquidar(
                                    context,
                                    comissoesBrutas: comissaoTotal,
                                    totalVales: totalVales,
                                    agsIds: agsIds,
                                    valesIds: valesIds,
                                    servicosComissao: servicosComissao,
                                    assinaturasComissao: assinaturasComissao,
                                    produtosComissao: produtosComissao,
                                    totalServicosBase: servicosBase,
                                    totalAssinaturasBase: assinaturasBase,
                                    totalProdutosBase: produtosBase,
                                    itensDetalhados: itensDetalhados,
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: itensDetalhados.isEmpty
                        ? const Center(child: Text('Nenhum atendimento pendente para este barbeiro.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: itensDetalhados.length,
                            itemBuilder: (ctx, i) {
                              final item = itensDetalhados[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text('${item['cliente']} • ${item['servico']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${item['data_hora']} • Categoria: ${item['categoria']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Text('Comissão: R\$ ${item['comissao'].toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- SUBTELA 2: HISTÓRICO DE RECIBOS PAGOS COM OPÇÃO DE ESTORNO ----------------
class HistoricoRecibosScreen extends StatelessWidget {
  final String barbeariaId;
  const HistoricoRecibosScreen({super.key, required this.barbeariaId});

  Future<void> _estornarRepasse(BuildContext context, String repasseId, Map<String, dynamic> rData) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estornar Repasse?'),
        content: const Text('Isso vai reabrir os atendimentos e vales deste acerto, retornando-os para a aba "A Pagar", e apagar este registro de pagamento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Estornar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final agsIds = (rData['ags_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final valesIds = (rData['vales_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      // Reabre agendamentos
      for (var id in agsIds) {
        await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('agendamentos').doc(id).update({'repasse_liquidado': false});
      }
      // Reabre vales
      for (var id in valesIds) {
        await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('vales_barbeiros').doc(id).update({'vale_liquidado': false});
      }
      // Apaga o documento de repasse pago
      await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('repasses_barbeiros').doc(repasseId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repasse estornado com sucesso! Os valores voltaram para pendentes.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Recibos Pagos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('repasses_barbeiros').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final list = snapshot.data!.docs;
          if (list.isEmpty) return const Center(child: Text('Nenhum recibo emitido.', style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final rDoc = list[i];
              final d = rDoc.data() as Map<String, dynamic>;
              final nome = d['barbeiro_nome'] ?? 'Barbeiro';
              final total = (d['valor_total_repasse'] as num?)?.toDouble() ?? 0.0;
              final dataFmt = d['data_formatada'] ?? '-';
              final analiticos = (d['itens_analiticos'] as List<dynamic>?) ?? [];

              return Card(
                child: ExpansionTile(
                  title: Text('$nome • R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Pago em $dataFmt', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.undo, color: Colors.redAccent),
                        tooltip: 'Estornar Repasse (Voltar para A Pagar)',
                        onPressed: () => _estornarRepasse(context, rDoc.id, d),
                      ),
                    ],
                  ),
                  children: [
                    ...analiticos.map((item) {
                      return ListTile(
                        dense: true,
                        title: Text('${item['cliente']} (${item['servico']})'),
                        subtitle: Text('${item['data_hora']} • ${item['categoria']}'),
                        trailing: Text('R\$ ${item['comissao'].toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853))),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- SUBTELA 3: EXTRATO GERAL DE CAIXA ----------------
class ExtratoCaixaScreen extends StatefulWidget {
  final String barbeariaId;
  const ExtratoCaixaScreen({super.key, required this.barbeariaId});

  @override
  State<ExtratoCaixaScreen> createState() => _ExtratoCaixaScreenState();
}

class _ExtratoCaixaScreenState extends State<ExtratoCaixaScreen> {
  String _filtroTipo = 'todos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Extrato Geral de Caixa')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('mensalidades').snapshots(),
        builder: (context, mensalidadesSnap) {
          final mensalidades = mensalidadesSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('despesas').snapshots(),
            builder: (context, despesasSnap) {
              final despesas = despesasSnap.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('vales_barbeiros').snapshots(),
                builder: (context, valesSnap) {
                  final vales = valesSnap.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('repasses_barbeiros').snapshots(),
                    builder: (context, repassesSnap) {
                      final repasses = repassesSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('agendamentos').snapshots(),
                        builder: (context, agSnap) {
                          if (agSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final agendamentos = agSnap.data?.docs ?? [];
                          List<Map<String, dynamic>> listaTransacoes = [];

                          for (var doc in agendamentos) {
                            final d = doc.data() as Map<String, dynamic>;
                            if (d['status'] == 'concluido') {
                              listaTransacoes.add({
                                'tipo': 'entrada_atendimento',
                                'titulo': '${d['cliente_nome'] ?? "Cliente"} (${d['servico'] ?? "Serviço"})',
                                'subtitulo': 'Barbeiro: ${d['barbeiro_nome'] ?? "-"} • ${d['data_hora'] ?? "-"}',
                                'valor': (d['preco'] as num?)?.toDouble() ?? 0.0,
                                'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                              });
                            }
                          }

                          for (var doc in mensalidades) {
                            final d = doc.data() as Map<String, dynamic>;
                            listaTransacoes.add({
                              'tipo': 'entrada_mensalidade',
                              'titulo': '👑 Mensalidade: ${d['cliente_nome'] ?? "Cliente"}',
                              'subtitulo': 'Plano: ${d['plano_nome'] ?? "-"} • ${d['data_formatada'] ?? "-"}',
                              'valor': (d['valor'] as num?)?.toDouble() ?? 0.0,
                              'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                            });
                          }

                          for (var doc in despesas) {
                            final d = doc.data() as Map<String, dynamic>;
                            if (d['pago'] == true) {
                              listaTransacoes.add({
                                'tipo': 'saida_despesa',
                                'titulo': '🔴 Despesa (Paga): ${d['descricao'] ?? "Despesa"}',
                                'subtitulo': 'Categoria: ${d['categoria'] ?? "-"} • ${d['data_formatada'] ?? "-"}',
                                'valor': (d['valor'] as num?)?.toDouble() ?? 0.0,
                                'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                              });
                            }
                          }

                          for (var doc in vales) {
                            final d = doc.data() as Map<String, dynamic>;
                            listaTransacoes.add({
                              'tipo': 'saida_vale',
                              'titulo': '🟠 Vale/Adiantamento: ${d['barbeiro_nome'] ?? "Barbeiro"}',
                              'subtitulo': 'Motivo: ${d['motivo'] ?? "Adiantamento"} • ${d['data_formatada'] ?? "-"}',
                              'valor': (d['valor'] as num?)?.toDouble() ?? 0.0,
                              'forma': 'DINHEIRO',
                            });
                          }

                          for (var doc in repasses) {
                            final d = doc.data() as Map<String, dynamic>;
                            listaTransacoes.add({
                              'tipo': 'saida_repasse',
                              'titulo': '💰 Repasse Liquidado: ${d['barbeiro_nome'] ?? "Barbeiro"}',
                              'subtitulo': 'Acerto efetuado em ${d['data_formatada'] ?? "-"}',
                              'valor': (d['valor_total_repasse'] as num?)?.toDouble() ?? 0.0,
                              'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                            });
                          }

                          final transacoesFiltradas = listaTransacoes.where((t) {
                            if (_filtroTipo == 'todos') return true;
                            if (_filtroTipo == 'entradas') return t['tipo'].toString().startsWith('entrada');
                            if (_filtroTipo == 'saidas') return t['tipo'].toString().startsWith('saida');
                            return true;
                          }).toList();

                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                color: const Color(0xFF1A1A1A),
                                child: DropdownButtonFormField<String>(
                                  value: _filtroTipo,
                                  isDense: true,
                                  decoration: const InputDecoration(labelText: 'Tipo de Movimentação', border: OutlineInputBorder()),
                                  items: const [
                                    DropdownMenuItem(value: 'todos', child: Text('Todas as Movimentações')),
                                    DropdownMenuItem(value: 'entradas', child: Text('🟢 Apenas Entradas (Atendimentos & Planos)')),
                                    DropdownMenuItem(value: 'saidas', child: Text('🔴 Apenas Saídas Efectivas (Despesas Pagas, Vales & Repasses)')),
                                  ],
                                  onChanged: (val) => setState(() => _filtroTipo = val ?? 'todos'),
                                ),
                              ),
                              Expanded(
                                child: transacoesFiltradas.isEmpty
                                    ? const Center(child: Text('Nenhuma movimentação registrada.', style: TextStyle(color: Colors.grey)))
                                    : ListView.builder(
                                        padding: const EdgeInsets.all(16),
                                        itemCount: transacoesFiltradas.length,
                                        itemBuilder: (ctx, i) {
                                          final item = transacoesFiltradas[i];
                                          final isEntrada = item['tipo'].toString().startsWith('entrada');
                                          final cor = isEntrada ? const Color(0xFF00C853) : Colors.redAccent;
                                          final prefixo = isEntrada ? '+ R\$ ' : '- R\$ ';

                                          return Card(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            child: ListTile(
                                              leading: Icon(isEntrada ? Icons.arrow_upward : Icons.arrow_downward, color: cor),
                                              title: Text(item['titulo'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              subtitle: Text('${item['subtitulo']} • ${item['forma']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                              trailing: Text(
                                                '$prefixo${(item['valor'] as double).toStringAsFixed(2)}',
                                                style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- SUBTELA 4: DESPESAS OPERACIONAIS COM BOTÃO DE QUITAÇÃO ----------------
class DespesasScreen extends StatefulWidget {
  final String barbeariaId;
  const DespesasScreen({super.key, required this.barbeariaId});

  @override
  State<DespesasScreen> createState() => _DespesasScreenState();
}

class _DespesasScreenState extends State<DespesasScreen> {
  String _filtroCategoria = 'todas';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Despesas Operacionais (Saídas)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('despesas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final todasDespesas = snapshot.data?.docs ?? [];

          final despesasFiltradas = todasDespesas.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            if (_filtroCategoria == 'todas') return true;
            return (d['categoria'] ?? '') == _filtroCategoria;
          }).toList();

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1A1A1A),
                child: DropdownButtonFormField<String>(
                  value: _filtroCategoria,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Filtrar por Categoria', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'todas', child: Text('Todas as Categorias')),
                    DropdownMenuItem(value: 'Fixa (Aluguel/Luz/Água/Net)', child: Text('Fixa (Aluguel/Luz/Água/Net)')),
                    DropdownMenuItem(value: 'Insumos / Lâminas / Descartáveis', child: Text('Insumos / Lâminas / Descartáveis')),
                    DropdownMenuItem(value: 'Reposição de Estoque', child: Text('Reposição de Estoque')),
                    DropdownMenuItem(value: 'Limpeza / Manutenção', child: Text('Limpeza / Manutenção')),
                    DropdownMenuItem(value: 'Marketing / Anúncios', child: Text('Marketing / Anúncios')),
                    DropdownMenuItem(value: 'Outros', child: Text('Outros')),
                  ],
                  onChanged: (val) => setState(() => _filtroCategoria = val ?? 'todas'),
                ),
              ),
              Expanded(
                child: despesasFiltradas.isEmpty
                    ? const Center(child: Text('Nenhuma despesa lançada nesta categoria.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: despesasFiltradas.length,
                        itemBuilder: (ctx, i) {
                          final dDoc = despesasFiltradas[i];
                          final d = dDoc.data() as Map<String, dynamic>;
                          final dId = dDoc.id;
                          final desc = d['descricao']?.toString() ?? 'Despesa';
                          final v = (d['valor'] as num?)?.toDouble() ?? 0.0;
                          final cat = d['categoria']?.toString() ?? 'Fixa';
                          final dataFmt = d['data_formatada']?.toString() ?? '-';
                          final pago = d['pago'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.arrow_downward, color: pago ? Colors.grey : Colors.redAccent),
                              title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$cat • $dataFmt\nStatus: ${pago ? "Paga / Liquidada" : "Em Aberto"}', style: TextStyle(fontSize: 12, color: pago ? Colors.greenAccent : Colors.orangeAccent)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('R\$ ${v.toStringAsFixed(2)}', style: TextStyle(color: pago ? Colors.grey : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: pago ? Colors.grey.shade800 : const Color(0xFF00C853),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    onPressed: () {
                                      FirebaseFirestore.instance
                                          .collection('barbearias')
                                          .doc(widget.barbeariaId)
                                          .collection('despesas')
                                          .doc(dId)
                                          .update({'pago': !pago});
                                    },
                                    child: Text(pago ? 'Reabrir' : 'Quitar', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => FirebaseFirestore.instance
                                        .collection('barbearias')
                                        .doc(widget.barbeariaId)
                                        .collection('despesas')
                                        .doc(dId)
                                        .delete(),
                                  ),
                                ],
                              ),
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
  }
}

// ---------------- SUBTELA 5: MENSALIDADES DE PLANOS RECEBIDAS ----------------
class MensalidadesRecebidasScreen extends StatelessWidget {
  final String barbeariaId;
  const MensalidadesRecebidasScreen({super.key, required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensalidades Recebidas')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('mensalidades').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final mensalidades = snapshot.data?.docs ?? [];

          if (mensalidades.isEmpty) {
            return const Center(child: Text('Nenhuma mensalidade de plano recebida.', style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mensalidades.length,
            itemBuilder: (ctx, i) {
              final mDoc = mensalidades[i];
              final m = mDoc.data() as Map<String, dynamic>;
              final mId = mDoc.id;
              final cNome = m['cliente_nome']?.toString() ?? 'Cliente';
              final pNome = m['plano_nome']?.toString() ?? 'Plano';
              final v = (m['valor'] as num?)?.toDouble() ?? 0.0;
              final dataFmt = m['data_formatada']?.toString() ?? '-';
              final fPag = (m['forma_pagamento']?.toString() ?? 'pix').toUpperCase();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Color(0xFF00C853)),
                  title: Text('$cNome • $pNome', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Recebido via $fPag • $dataFmt', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('+ R\$ ${v.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 14)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(barbeariaId)
                            .collection('mensalidades')
                            .doc(mId)
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

// ---------------- SUBTELA: AGENDAMENTO DO CLIENTE ----------------
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
