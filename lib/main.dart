import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';

// Importação das telas modularizadas
import 'screens/agenda_screen.dart';
import 'screens/clientes_screen.dart';
import 'screens/equipe_screen.dart';
import 'screens/financeiro_screen.dart';
import 'screens/produtos_screen.dart';
import 'screens/servicos_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('pt_BR', null);
  runApp(const BarbeariaApp());
}

class BarbeariaApp extends StatelessWidget {
  const BarbeariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barbearia SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFFE0A96D),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE0A96D),
          secondary: Color(0xFFE0A96D),
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const HomeScreenSelector(),
    );
  }
}

class HomeScreenSelector extends StatelessWidget {
  const HomeScreenSelector({super.key});

  @override
  Widget build(BuildContext context) {
    // Insira aqui o ID padrão da sua barbearia para testes
    const String barbeariaIdPadrao = 'sua_barbearia_id_aqui';

    return const OwnerMainDashboard(barbeariaId: barbeariaIdPadrao);
  }
}

class OwnerMainDashboard extends StatefulWidget {
  final String barbeariaId;
  const OwnerMainDashboard({super.key, required this.barbeariaId});

  @override
  State<OwnerMainDashboard> createState() => _OwnerMainDashboardState();
}

class _OwnerMainDashboardState extends State<OwnerMainDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> telas = [
      AgendaScreen(barbeariaId: widget.barbeariaId),
      FinanceiroScreen(barbeariaId: widget.barbeariaId),
      ClientesScreen(barbeariaId: widget.barbeariaId),
      EquipeScreen(barbeariaId: widget.barbeariaId),
      ProdutosScreen(barbeariaId: widget.barbeariaId),
      ServicosScreen(barbeariaId: widget.barbeariaId),
    ];

    return Scaffold(
      body: telas[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1A1A1A),
        selectedItemColor: const Color(0xFFE0A96D),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Agenda'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money), label: 'Financeiro'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.badge), label: 'Equipe'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Produtos'),
          BottomNavigationBarItem(icon: Icon(Icons.content_cut), label: 'Serviços'),
        ],
      ),
    );
  }
}
