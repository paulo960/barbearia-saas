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

class ClientesScreen extends StatefulWidget {
  final String barbeariaId;
  const ClientesScreen({super.key, required this.barbeariaId});

  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  final TextEditingController _buscaCtrl = TextEditingController();
  String _termoBusca = '';

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

  void _abrirWhatsApp(String telefone) {
    final cleanPhone = telefone.replaceAll(RegExp(r'\D'), '');
    final url = cleanPhone.startsWith('55') ? 'https://wa.me/$cleanPhone' : 'https://wa.me/55$cleanPhone';
    html.window.open(url, '_blank');
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

                final clientesFiltrados = todosClientes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nome = data['nome']?.toString().toLowerCase() ?? '';
                  final telefone = data['telefone']?.toString().toLowerCase() ?? '';
                  if (_termoBusca.isEmpty) return true;
                  return nome.contains(_termoBusca) || telefone.contains(_termoBusca);
                }).toList();

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
                    final planoId = c['plano_id']?.toString() ?? 'nenhum';
                    final planoNome = c['plano_nome']?.toString() ?? '';
                    final planoPreco = (c['plano_preco'] as num?)?.toDouble() ?? 0.0;
                    final vencimento = c['plano_vencimento']?.toString() ?? '';
                    final obs = c['observacoes']?.toString() ?? '';
                    final temPlano = planoId != 'nenhum' && planoNome.isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: temPlano ? const Color(0xFFE0A96D) : const Color(0xFF333333),
                          child: Icon(
                            temPlano ? Icons.workspace_premium : Icons.person,
                            color: temPlano ? Colors.black : Colors.white,
                          ),
                        ),
                        title: Row(
                          children: [
                            Flexible(child: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                            if (temPlano) ...[
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
                            if (temPlano)
                              IconButton(
                                icon: const Icon(Icons.monetization_on, color: Color(0xFF00C853), size: 22),
                                tooltip: 'Receber Mensalidade',
                                onPressed: () => _abrirModalReceberMensalidadeCliente(id, nome, planoNome, planoPreco),
                              ),
                            if (telefone.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.chat, color: Colors.greenAccent, size: 20),
                                tooltip: 'Chamar no WhatsApp',
                                onPressed: () => _abrirWhatsApp(telefone),
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D), size: 20),
                              tooltip: 'Editar',
                              onPressed: () => _abrirModalCliente(clienteId: id, dadosAtuais: c),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Excluir',
                              onPressed: () => FirebaseFirestore.instance
                                  .collection('barbearias')
                                  .doc(widget.barbeariaId)
                                  .collection('clientes')
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
          ),
        ],
      ),
    );
  }
}

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

  void _abrirModalConclusaoPagamento(String agendamentoId, String clienteNome, String clienteTelefone, String servicoNome, double valorServicoPadrao) async {
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

    final servicoLower = servicoNome.toLowerCase();
    bool servicoCoberto = false;

    if (servicosCobertos.isNotEmpty) {
      servicoCoberto = servicosCobertos.any((s) => servicoLower.contains(s) || s.contains(servicoLower));
    } else if (planoIdCliente != 'nenhum') {
      if (planoNomeCliente.toLowerCase().contains('corte') && servicoLower.contains('corte')) servicoCoberto = true;
      if (planoNomeCliente.toLowerCase().contains('barba') && servicoLower.contains('barba')) servicoCoberto = true;
    }

    final double valorServicoFinal = servicoCoberto ? 0.0 : valorServicoPadrao;

    String formaPagamento = 'pix';
    Map<String, int> produtosSelecionadosQtd = {};
    Map<String, Map<String, dynamic>> produtosDocsMap = {};
    String? produtoParaAdicionar;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('produtos').snapshots(),
            builder: (context, prodSnap) {
              final prodDocs = prodSnap.data?.docs ?? [];
              double valorProdutosTotal = 0.0;

              for (var pDoc in prodDocs) {
                final p = pDoc.data() as Map<String, dynamic>;
                produtosDocsMap[pDoc.id] = p;
                final qtd = produtosSelecionadosQtd[pDoc.id] ?? 0;
                final preco = (p['preco'] as num?)?.toDouble() ?? 0.0;
                valorProdutosTotal += (preco * qtd);
              }

              final valorFinalTotal = valorServicoFinal + valorProdutosTotal;

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
                        if (servicoCoberto) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE0A96D).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                            child: Text('★ SERVIÇO COBERTO PELO PLANO ($planoNomeCliente)', style: const TextStyle(color: Color(0xFFE0A96D), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text('Serviço: R\$ ${valorServicoFinal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
                        ],
                        if (valorProdutosTotal > 0)
                          Text('Produtos: R\$ ${valorProdutosTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold)),
                        const Divider(height: 16),
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
                        'preco': valorFinalTotal,
                        'preco_servico': valorServicoFinal,
                        'preco_tabela_original': valorServicoPadrao,
                        'preco_produtos': valorProdutosTotal,
                        'coberto_por_plano': servicoCoberto,
                        'forma_pagamento': servicoCoberto && valorProdutosTotal == 0 ? 'plano_mensal' : formaPagamento,
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

class _OwnerProdutosTab extends StatelessWidget {
  final String barbeariaId;
  const _OwnerProdutosTab({required this.barbeariaId});

  void _abrirModalProduto(BuildContext context, {String? produtoId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final precoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['preco'] as num?)?.toDouble().toStringAsFixed(2) ?? '' : '');
    final custoCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['custo'] as num?)?.toDouble().toStringAsFixed(2) ?? '' : '');
    final estoqueCtrl = TextEditingController(text: dadosAtuais != null ? (dadosAtuais['estoque'] as num?)?.toInt().toString() ?? '10' : '10');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(produtoId == null ? 'Novo Produto' : 'Editar Produto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nomeCtrl, decoration: const InputDecoration(labelText: 'Nome do Produto (Ex: Pomada Efeito Matte)')),
              const SizedBox(height: 8),
              TextField(controller: precoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço de Venda (R\$)')),
              const SizedBox(height: 8),
              TextField(controller: custoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço de Custo (Opcional)')),
              const SizedBox(height: 8),
              TextField(controller: estoqueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade em Estoque')),
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
                  'preco': double.tryParse(precoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                  'custo': double.tryParse(custoCtrl.text.trim().replaceAll(',', '.')) ?? 0.0,
                  'estoque': int.tryParse(estoqueCtrl.text.trim()) ?? 0,
                };

                if (produtoId == null) {
                  payload['criado_em'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(barbeariaId)
                      .collection('produtos')
                      .add(payload);
                } else {
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(barbeariaId)
                      .collection('produtos')
                      .doc(produtoId)
                      .update(payload);
                }
                if (context.mounted) Navigator.pop(ctx);
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
        onPressed: () => _abrirModalProduto(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('barbearias')
            .doc(barbeariaId)
            .collection('produtos')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final produtos = snapshot.data?.docs ?? [];

          if (produtos.isEmpty) {
            return const Center(child: Text('Nenhum produto cadastrado no estoque. Toque em + para adicionar.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: produtos.length,
            itemBuilder: (ctx, i) {
              final p = produtos[i].data() as Map<String, dynamic>? ?? {};
              final id = produtos[i].id;
              final preco = (p['preco'] as num?)?.toDouble() ?? 0.0;
              final estoque = (p['estoque'] as num?)?.toInt() ?? 0;
              final esgotado = estoque <= 0;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: esgotado ? Colors.red.withOpacity(0.2) : const Color(0xFFE0A96D).withOpacity(0.2),
                    child: Icon(Icons.inventory_2, color: esgotado ? Colors.redAccent : const Color(0xFFE0A96D)),
                  ),
                  title: Text(p['nome']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Estoque: $estoque unidades • Venda: R\$ ${preco.toStringAsFixed(2)}', style: TextStyle(color: esgotado ? Colors.redAccent : Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Color(0xFFE0A96D)),
                        onPressed: () => _abrirModalProduto(context, produtoId: id, dadosAtuais: p),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('barbearias')
                            .doc(barbeariaId)
                            .collection('produtos')
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

// ---------------- HUB PRINCIPAL DO FINANCEIRO (SEM ACCORDIONS) ----------------
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
    required double totalServicos,
    required double totalProdutos,
    required double totalMensalidades,
    required double totalFaturado,
    required double totalDespesas,
    required double totalComissoes,
    required double lucroLiquido,
    required int totalConcluidos,
    required int totalCancelados,
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
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  pw.Column(children: [
                    pw.Text('FATURAMENTO BRUTO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('R\$ ${totalFaturado.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('DESPESAS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('R\$ ${totalDespesas.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.red800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('COMISSÕES', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('R\$ ${totalComissoes.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, color: PdfColors.orange800)),
                  ]),
                  pw.Column(children: [
                    pw.Text('LUCRO REAL', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text('R\$ ${lucroLiquido.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  ]),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Detalhamento dos Atendimentos (${registros.length} registros)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Data/Hora', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Cliente', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Barbeiro', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Serviço / Itens', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Pagamento', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Status', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Total (R\$)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
                  ],
                ),
                ...registros.map((rDoc) {
                  final r = rDoc.data() as Map<String, dynamic>;
                  final preco = (r['preco'] as num?)?.toDouble() ?? 0.0;
                  final status = (r['status']?.toString() ?? 'pendente').toUpperCase();
                  final forma = (r['forma_pagamento']?.toString() ?? '-').toUpperCase();
                  final produtos = (r['produtos_extras'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                  String servicoItens = r['servico']?.toString() ?? 'Serviço';
                  if (produtos.isNotEmpty) {
                    servicoItens += ' + ${produtos.join(", ")}';
                  }

                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r['data_hora']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r['cliente_nome']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(r['barbeiro_nome']?.toString() ?? '-', style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(servicoItens, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(forma, style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(status, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(preco.toStringAsFixed(2), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }).toList(),
              ],
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
                            Map<String, String> nomesBarbeirosMap = {};

                            for (var b in barbeirosDocs) {
                              final data = b.data() as Map<String, dynamic>;
                              nomesBarbeirosMap[b.id] = data['nome']?.toString() ?? 'Barbeiro';
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

                                final agendamentosFiltrados = todosAgendamentos.where((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  return _verificarFiltroData(d);
                                }).toList();

                                final despesasFiltradas = todasDespesas.where((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  return _verificarFiltroData(d);
                                }).toList();

                                double totalDespesas = 0.0;
                                for (var dDoc in despesasFiltradas) {
                                  final d = dDoc.data() as Map<String, dynamic>;
                                  totalDespesas += (d['valor'] as num?)?.toDouble() ?? 0.0;
                                }

                                final mensalidadesFiltradas = todasMensalidades.where((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  return _verificarFiltroData(d);
                                }).toList();

                                double totalMensalidades = 0.0;
                                for (var mDoc in mensalidadesFiltradas) {
                                  final d = mDoc.data() as Map<String, dynamic>;
                                  totalMensalidades += (d['valor'] as num?)?.toDouble() ?? 0.0;
                                }

                                final valesFiltrados = todosVales.where((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  return _verificarFiltroData(d);
                                }).toList();

                                double totalValesPendentes = 0.0;
                                for (var vDoc in valesFiltrados) {
                                  final d = vDoc.data() as Map<String, dynamic>;
                                  if (d['vale_liquidado'] != true) {
                                    totalValesPendentes += (d['valor'] as num?)?.toDouble() ?? 0.0;
                                  }
                                }

                                final repassesFeitosFiltrados = todosRepassesFeitos.where((doc) {
                                  final d = doc.data() as Map<String, dynamic>;
                                  return _verificarFiltroData(d);
                                }).toList();

                                double totalServicos = 0.0;
                                double totalProdutos = 0.0;
                                double totalComissoes = 0.0;
                                double totalComissoesPendentes = 0.0;
                                int totalConcluidos = 0;
                                int totalCancelados = 0;

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
                                    totalConcluidos++;

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

                                    totalComissoes += comissaoDesteAtendimento;

                                    if (!repasseLiquidado) {
                                      totalComissoesPendentes += comissaoDesteAtendimento;
                                    }
                                  } else if (st == 'cancelado') {
                                    totalCancelados++;
                                  }
                                }

                                final faturamentoBrutoTotal = totalServicos + totalProdutos + totalMensalidades;
                                final lucroLiquido = faturamentoBrutoTotal - totalDespesas - totalComissoes;
                                final liquidoRepassePendenteGeral = (totalComissoesPendentes - totalValesPendentes).clamp(0.0, 999999.0);

                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // 1. FILTROS RÁPIDOS DE DATA
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

                                      // 2. CARD DRE PRINCIPAL
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
                                                      const Text('🔴 Despesas', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${totalDespesas.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      const Text('🟠 Comissões', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${totalComissoes.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
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

                                      // 3. BOTÕES DE AÇÕES RÁPIDAS
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
                                              totalServicos: totalServicos,
                                              totalProdutos: totalProdutos,
                                              totalMensalidades: totalMensalidades,
                                              totalFaturado: faturamentoBrutoTotal,
                                              totalDespesas: totalDespesas,
                                              totalComissoes: totalComissoes,
                                              lucroLiquido: lucroLiquido,
                                              totalConcluidos: totalConcluidos,
                                              totalCancelados: totalCancelados,
                                              registros: agendamentosFiltrados,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // 4. MENUS DE NAVEGAÇÃO (SUBTELAS)
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
                                          subtitle: Text('Pendente: R\$ ${liquidoRepassePendenteGeral.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onPressed: () {
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
                                          subtitle: Text('${repassesFeitosFiltrados.length} acertos liquidados', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onPressed: () {
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
                                          subtitle: const Text('Fluxo unificado de entradas e saídas', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onPressed: () {
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
                                          title: const Text('Despesas Operacionais (Saídas)', style: TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('${despesasFiltradas.length} despesas • R\$ ${totalDespesas.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onPressed: () {
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
                                          onPressed: () {
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

// ---------------- SUBTELA 1: REPASSES DA EQUIPE (A PAGAR) ----------------
class RepassesEquipeScreen extends StatefulWidget {
  final String barbeariaId;
  const RepassesEquipeScreen({super.key, required this.barbeariaId});

  @override
  State<RepassesEquipeScreen> createState() => _RepassesEquipeScreenState();
}

class _RepassesEquipeScreenState extends State<RepassesEquipeScreen> {
  String _filtroBarbeiro = 'todos';

  void _abrirModalLiquidarRepasse(String barbeiroId, String barbeiroNome, double comissoesAcumuladas, double totalVales, List<String> agsIds, List<String> valesIds) {
    final double liquidoAPagar = (comissoesAcumuladas - totalVales).clamp(0.0, 999999.0);
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
              Text('Comissões Acumuladas: R\$ ${comissoesAcumuladas.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
              if (totalVales > 0) ...[
                const SizedBox(height: 4),
                Text('(-) Vales / Adiantamentos: R\$ ${totalVales.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
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

                await FirebaseFirestore.instance
                    .collection('barbearias')
                    .doc(widget.barbeariaId)
                    .collection('repasses_barbeiros')
                    .add({
                  'barbeiro_id': barbeiroId,
                  'barbeiro_nome': barbeiroNome,
                  'valor_comissoes': comissoesAcumuladas,
                  'valor_vales_abatidos': totalVales,
                  'valor_total_repasse': liquidoAPagar,
                  'forma_pagamento': formaPagamento,
                  'data_iso': DateFormat('yyyy-MM-dd').format(hoje),
                  'data_formatada': DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(hoje),
                  'pago_em': FieldValue.serverTimestamp(),
                });

                for (var agId in agsIds) {
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('agendamentos')
                      .doc(agId)
                      .update({'repasse_liquidado': true});
                }

                for (var vId in valesIds) {
                  await FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(widget.barbeariaId)
                      .collection('vales_barbeiros')
                      .doc(vId)
                      .update({'vale_liquidado': true});
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Repasse de R\$ ${liquidoAPagar.toStringAsFixed(2)} para $barbeiroNome liquidado com sucesso!'), backgroundColor: Colors.green.shade800),
                  );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repasses da Equipe (A Pagar)'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('vales_barbeiros').snapshots(),
        builder: (context, valesSnap) {
          final todosVales = valesSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').snapshots(),
            builder: (context, barberSnap) {
              final barbeirosDocs = barberSnap.data?.docs ?? [];

              Map<String, Map<String, int>> comissoesBarbeirosMap = {};
              Map<String, String> nomesBarbeirosMap = {};

              for (var b in barbeirosDocs) {
                final data = b.data() as Map<String, dynamic>;
                nomesBarbeirosMap[b.id] = data['nome']?.toString() ?? 'Barbeiro';
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

                  Map<String, double> valesPendentesPorBarbeiro = {};
                  Map<String, List<String>> valesIdsPorBarbeiro = {};

                  for (var vDoc in todosVales) {
                    final d = vDoc.data() as Map<String, dynamic>;
                    final bId = d['barbeiro_id']?.toString() ?? '';
                    final vValor = (d['valor'] as num?)?.toDouble() ?? 0.0;
                    final isLiquidado = d['vale_liquidado'] == true;

                    if (!isLiquidado) {
                      valesPendentesPorBarbeiro[bId] = (valesPendentesPorBarbeiro[bId] ?? 0.0) + vValor;
                      valesIdsPorBarbeiro.putIfAbsent(bId, () => []).add(vDoc.id);
                    }
                  }

                  Map<String, double> comissoesPendentesPorBarbeiro = {};
                  Map<String, List<String>> agendamentosIdsPorBarbeiro = {};

                  for (var doc in todosAgendamentos) {
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

                    if (st == 'concluido' && !repasseLiquidado) {
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

                      comissoesPendentesPorBarbeiro[bId] = (comissoesPendentesPorBarbeiro[bId] ?? 0.0) + comissaoDesteAtendimento;
                      agendamentosIdsPorBarbeiro.putIfAbsent(bId, () => []).add(doc.id);
                    }
                  }

                  final barbeirosExibidos = barbeirosDocs.where((b) {
                    if (_filtroBarbeiro == 'todos') return true;
                    return b.id == _filtroBarbeiro;
                  }).toList();

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: const Color(0xFF1A1A1A),
                        child: DropdownButtonFormField<String>(
                          value: _filtroBarbeiro,
                          isDense: true,
                          decoration: const InputDecoration(labelText: 'Filtrar por Barbeiro', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: 'todos', child: Text('Todos os Barbeiros')),
                            ...barbeirosDocs.map((bDoc) {
                              final d = bDoc.data() as Map<String, dynamic>;
                              return DropdownMenuItem(value: bDoc.id, child: Text(d['nome']?.toString() ?? 'Barbeiro'));
                            }),
                          ],
                          onChanged: (val) => setState(() => _filtroBarbeiro = val ?? 'todos'),
                        ),
                      ),
                      Expanded(
                        child: barbeirosExibidos.isEmpty
                            ? const Center(child: Text('Nenhum barbeiro cadastrado.', style: TextStyle(color: Colors.grey)))
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: barbeirosExibidos.length,
                                itemBuilder: (ctx, i) {
                                  final bDoc = barbeirosExibidos[i];
                                  final bNome = nomesBarbeirosMap[bDoc.id] ?? 'Barbeiro';
                                  final comissoesPendentes = comissoesPendentesPorBarbeiro[bDoc.id] ?? 0.0;
                                  final valesPendentes = valesPendentesPorBarbeiro[bDoc.id] ?? 0.0;
                                  final liquidoAPagar = (comissoesPendentes - valesPendentes).clamp(0.0, 999999.0);
                                  final agsIds = agendamentosIdsPorBarbeiro[bDoc.id] ?? [];
                                  final valesIds = valesIdsPorBarbeiro[bDoc.id] ?? [];

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
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: const Color(0xFFE0A96D),
                                                    child: Text(bNome.isNotEmpty ? bNome[0].toUpperCase() : 'B', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(bNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                ],
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black),
                                                onPressed: (comissoesPendentes > 0 || valesPendentes > 0)
                                                    ? () => _abrirModalLiquidarRepasse(bDoc.id, bNome, comissoesPendentes, valesPendentes, agsIds, valesIds)
                                                    : null,
                                                child: const Text('Liquidar Repasse', style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          const Divider(height: 20),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Comissões Pendentes:', style: TextStyle(color: Colors.grey)),
                                              Text('R\$ ${comissoesPendentes.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          if (valesPendentes > 0) ...[
                                            const SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text('(-) Vales Adiantados:', style: TextStyle(color: Colors.redAccent)),
                                                Text('- R\$ ${valesPendentes.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Total Líquido a Pagar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                              Text('R\$ ${liquidoAPagar.toStringAsFixed(2)}', style: TextStyle(color: liquidoAPagar > 0 ? const Color(0xFF00C853) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 17)),
                                            ],
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
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- SUBTELA 2: HISTÓRICO DE RECIBOS PAGOS ----------------
class HistoricoRecibosScreen extends StatefulWidget {
  final String barbeariaId;
  const HistoricoRecibosScreen({super.key, required this.barbeariaId});

  @override
  State<HistoricoRecibosScreen> createState() => _HistoricoRecibosScreenState();
}

class _HistoricoRecibosScreenState extends State<HistoricoRecibosScreen> {
  String _filtroBarbeiro = 'todos';

  Future<void> _gerarReciboRepassePdf(Map<String, dynamic> rData) async {
    final docPdf = pw.Document();
    final bNome = rData['barbeiro_nome']?.toString() ?? 'Barbeiro';
    final comissao = (rData['valor_comissoes'] as num?)?.toDouble() ?? 0.0;
    final vales = (rData['valor_vales_abatidos'] as num?)?.toDouble() ?? 0.0;
    final total = (rData['valor_total_repasse'] as num?)?.toDouble() ?? 0.0;
    final dataFmt = rData['data_formatada']?.toString() ?? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final forma = (rData['forma_pagamento']?.toString() ?? 'PIX').toUpperCase();

    docPdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('RECIBO DE REPASSE DE COMISSÃO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Data do Pagamento: $dataFmt', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
              pw.Divider(height: 20),
              pw.Text('Profissional: $bNome', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Comissões Acumuladas:'), pw.Text('R\$ ${comissao.toStringAsFixed(2)}')]),
                    pw.SizedBox(height: 6),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('(-) Vales / Adiantamentos:'), pw.Text('R\$ ${vales.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red800))]),
                    pw.Divider(height: 12),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('VALOR LÍQUIDO PAGO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)), pw.Text('R\$ ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green800))]),
                    pw.SizedBox(height: 6),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Forma de Pagamento:'), pw.Text(forma, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(width: 200, height: 1, color: PdfColors.black),
                    pw.SizedBox(height: 4),
                    pw.Text('Assinatura do Profissional ($bNome)', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => docPdf.save(),
      name: 'recibo_repasse_${bNome}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Recibos Pagos')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('barbeiros').snapshots(),
        builder: (context, barberSnap) {
          final barbeirosDocs = barberSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('barbearias')
                .doc(widget.barbeariaId)
                .collection('repasses_barbeiros')
                .snapshots(),
            builder: (context, repassesSnap) {
              if (repassesSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final todosRepasses = repassesSnap.data?.docs ?? [];

              final repassesFiltrados = todosRepasses.where((doc) {
                final d = doc.data() as Map<String, dynamic>;
                if (_filtroBarbeiro == 'todos') return true;
                return d['barbeiro_id'] == _filtroBarbeiro;
              }).toList();

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1A1A1A),
                    child: DropdownButtonFormField<String>(
                      value: _filtroBarbeiro,
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Filtrar por Barbeiro', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem(value: 'todos', child: Text('Todos os Barbeiros')),
                        ...barbeirosDocs.map((bDoc) {
                          final d = bDoc.data() as Map<String, dynamic>;
                          return DropdownMenuItem(value: bDoc.id, child: Text(d['nome']?.toString() ?? 'Barbeiro'));
                        }),
                      ],
                      onChanged: (val) => setState(() => _filtroBarbeiro = val ?? 'todos'),
                    ),
                  ),
                  Expanded(
                    child: repassesFiltrados.isEmpty
                        ? const Center(child: Text('Nenhum repasse liquidado registrado.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: repassesFiltrados.length,
                            itemBuilder: (ctx, i) {
                              final rDoc = repassesFiltrados[i];
                              final r = rDoc.data() as Map<String, dynamic>;
                              final rId = rDoc.id;
                              final bNome = r['barbeiro_nome']?.toString() ?? 'Barbeiro';
                              final vLiq = (r['valor_total_repasse'] as num?)?.toDouble() ?? 0.0;
                              final vCom = (r['valor_comissoes'] as num?)?.toDouble() ?? 0.0;
                              final vVal = (r['valor_vales_abatidos'] as num?)?.toDouble() ?? 0.0;
                              final dataFmt = r['data_formatada']?.toString() ?? '-';
                              final forma = (r['forma_pagamento']?.toString() ?? 'PIX').toUpperCase();

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFF00C853),
                                    child: Icon(Icons.check, color: Colors.black),
                                  ),
                                  title: Text('$bNome • R\$ ${vLiq.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Bruto: R\$ ${vCom.toStringAsFixed(2)} | Vales: -R\$ ${vVal.toStringAsFixed(2)}\n$forma • $dataFmt', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.receipt, color: Color(0xFFE0A96D)),
                                        tooltip: 'Imprimir Recibo PDF',
                                        onPressed: () => _gerarReciboRepassePdf(r),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => FirebaseFirestore.instance
                                            .collection('barbearias')
                                            .doc(widget.barbeariaId)
                                            .collection('repasses_barbeiros')
                                            .doc(rId)
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
                            listaTransacoes.add({
                              'tipo': 'saida_despesa',
                              'titulo': '🔴 Despesa: ${d['descricao'] ?? "Despesa"}',
                              'subtitulo': 'Categoria: ${d['categoria'] ?? "-"} • ${d['data_formatada'] ?? "-"}',
                              'valor': (d['valor'] as num?)?.toDouble() ?? 0.0,
                              'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                            });
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
                                    DropdownMenuItem(value: 'saidas', child: Text('🔴 Apenas Saídas (Despesas, Vales & Repasses)')),
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

// ---------------- SUBTELA 4: DESPESAS OPERACIONAIS ----------------
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

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Icons.arrow_downward, color: Colors.redAccent),
                              title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$cat • $dataFmt', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('- R\$ ${v.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
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
