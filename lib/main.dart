import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
            final tenantId = data['barbearia_id']?.toString() ?? '';

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
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão Barbearia'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
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
        ],
      ),
    );
  }
}

class _OwnerAgendamentosTab extends StatelessWidget {
  final String barbeariaId;
  const _OwnerAgendamentosTab({required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    if (barbeariaId.isEmpty) {
      return const Center(child: Text('Barbearia não vinculada ao usuário.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('barbearias')
          .doc(barbeariaId)
          .collection('agendamentos')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final ags = snapshot.data?.docs ?? [];

        if (ags.isEmpty) {
          return const Center(child: Text('Nenhum agendamento registrado.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ags.length,
          itemBuilder: (ctx, i) {
            final ag = ags[i].data() as Map<String, dynamic>? ?? {};
            return Card(
              child: ListTile(
                leading: const Icon(Icons.schedule, color: Color(0xFFE0A96D)),
                title: Text(ag['cliente_nome']?.toString() ?? 'Cliente', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${ag['servico'] ?? 'Serviço'} • ${ag['barbeiro_nome'] ?? 'Barbeiro'}\nHorário: ${ag['data_hora'] ?? '-'}'),
                trailing: Text(
                  ag['status']?.toString() ?? 'pendente',
                  style: TextStyle(
                    color: ag['status'] == 'concluido' ? Colors.green : const Color(0xFFE0A96D),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
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
    final tempoCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Novo Serviço'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome (Ex: Corte Degradê)')),
            TextField(controller: precoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço (R\$)')),
            TextField(controller: tempoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duração (minutos)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE0A96D), foregroundColor: Colors.black),
            onPressed: () {
              if (nomeCtrl.text.isNotEmpty && precoCtrl.text.isNotEmpty) {
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
    if (barbeariaId.isEmpty) {
      return const Center(child: Text('Barbearia não vinculada.'));
    }

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

class _OwnerBarbeirosTab extends StatelessWidget {
  final String barbeariaId;
  const _OwnerBarbeirosTab({required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('barbearia_id', isEqualTo: barbeariaId)
          .where('role', isEqualTo: 'barbeiro')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final barbeiros = snapshot.data?.docs ?? [];

        if (barbeiros.isEmpty) {
          return const Center(child: Text('Nenhum barbeiro vinculado a esta unidade.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: barbeiros.length,
          itemBuilder: (ctx, i) {
            final b = barbeiros[i].data() as Map<String, dynamic>? ?? {};
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE0A96D),
                  child: Icon(Icons.person, color: Colors.black),
                ),
                title: Text(b['nome']?.toString() ?? 'Barbeiro', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Comissão: ${b['comissao_porcentagem'] ?? 50}%'),
              ),
            );
          },
        );
      },
    );
  }
}

class _OwnerFinanceiroTab extends StatelessWidget {
  final String barbeariaId;
  const _OwnerFinanceiroTab({required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: const Color(0xFF242424),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: const [
                  Text('Faturamento Total', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  SizedBox(height: 8),
                  Text('R\$ 0,00', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF00C853))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        Text('Atendimentos', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 6),
                        Text('0', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: const [
                        Text('Comissões', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 6),
                        Text('R\$ 0,00', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
      body: const Center(child: Text('Agenda e Extrato de Comissões')),
    );
  }
}

class ClientBookingScreen extends StatelessWidget {
  final String barbeariaId;
  const ClientBookingScreen({super.key, required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Horário')),
      body: const Center(child: Text('Seleção de Barbeiro, Serviço e Horário')),
    );
  }
}
