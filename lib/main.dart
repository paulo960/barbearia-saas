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

// ---------------- PAINEL DO DONO ----------------
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

// ---------------- TELA DE CLIENTES ----------------
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
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
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

// ---------------- ABA DE AGENDA ----------------
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

// ---------------- ABA DE PRODUTOS E ESTOQUE ----------------
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

// ---------------- ABA DE EQUIPE ----------------
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

// ---------------- ABA DE AJUSTES ----------------
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
