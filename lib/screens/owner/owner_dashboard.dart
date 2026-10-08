import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'owner_clientes_tab.dart';
import 'owner_agenda_tab.dart';
import 'owner_servicos_tab.dart';
import 'owner_produtos_tab.dart';
import 'owner_financeiro_tab.dart';
import 'owner_barbeiros_tab.dart';
import 'owner_config_ajustes_tab.dart';
import '../client/client_booking_screen.dart';

class OwnerDashboard extends StatefulWidget {
  final String barbeariaId;
  // Atualizado para a sintaxe moderna (super_parameters) pedida pelo seu VS Code
  const OwnerDashboard({super.key, required this.barbeariaId});

  @override
  State createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Força o Dart a reconhecer o tipo correto, eliminando o erro da linha 27
    final String currentId = (widget as OwnerDashboard).barbeariaId;

    // As 5 abas principais do novo design
    final screens = [
      OwnerAgendamentosTab(barbeariaId: currentId),
      ClientesScreen(barbeariaId: currentId),
      OwnerFinanceiroTab(barbeariaId: currentId),
      _CatalogoTab(barbeariaId: currentId),
      _MaisTab(barbeariaId: currentId),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF121212),
          indicatorColor: const Color(0xFFE0A96D),
          // Voltamos ao WidgetStateProperty como sugerido pelo seu Flutter
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: Color(0xFFE0A96D), fontSize: 12, fontWeight: FontWeight.bold);
            }
            return const TextStyle(color: Colors.grey, fontSize: 12);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Colors.black);
            }
            return const IconThemeData(color: Colors.grey);
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.calendar_today, color: Colors.black),
              label: 'Agenda',
            ),
            NavigationDestination(
              icon: Icon(Icons.badge_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.badge, color: Colors.black),
              label: 'Clientes',
            ),
            NavigationDestination(
              icon: Icon(Icons.attach_money, color: Colors.grey),
              selectedIcon: Icon(Icons.attach_money, color: Colors.black),
              label: 'Financeiro',
            ),
            NavigationDestination(
              icon: Icon(Icons.content_cut_outlined, color: Colors.grey),
              selectedIcon: Icon(Icons.content_cut, color: Colors.black),
              label: 'Catálogo',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu, color: Colors.grey),
              selectedIcon: Icon(Icons.menu, color: Colors.black),
              label: 'Mais',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA CATÁLOGO
// ============================================================================
class _CatalogoTab extends StatelessWidget {
  final String barbeariaId;
  const _CatalogoTab({required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF121212),
          elevation: 0,
          title: const Text('Catálogo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
          bottom: const TabBar(
            indicatorColor: Color(0xFFE0A96D),
            labelColor: Color(0xFFE0A96D),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Serviços'),
              Tab(text: 'Produtos'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            OwnerServicosTab(barbeariaId: barbeariaId),
            OwnerProdutosTab(barbeariaId: barbeariaId),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ABA MAIS
// ============================================================================
class _MaisTab extends StatelessWidget {
  final String barbeariaId;
  const _MaisTab({required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        title: const Text('Mais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMenuItem(Icons.people_outline, 'Equipe', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerBarbeirosTab(barbeariaId: barbeariaId)));
          }),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.settings_outlined, 'Ajustes', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => OwnerConfigAjustesTab(barbeariaId: barbeariaId)));
          }),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.visibility_outlined, 'Ver página do cliente', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ClientBookingScreen(barbeariaId: barbeariaId)));
          }, trailingIcon: Icons.open_in_new),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.link, 'Copiar link de agendamento', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copiado!')));
          }, trailingIcon: Icons.copy),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _buildMenuItem(Icons.logout, 'Sair da conta', () {
            FirebaseAuth.instance.signOut();
          }, isDestructive: true),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap, {IconData trailingIcon = Icons.chevron_right, bool isDestructive = false}) {
    final color = isDestructive ? Colors.redAccent : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), 
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color, fontSize: 16)),
        trailing: Icon(trailingIcon, color: Colors.white54, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }
}