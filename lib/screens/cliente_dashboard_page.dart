import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Lembre-se de importar a sua tela de agendamento real aqui:
// import 'client_booking_screen.dart'; 

class ClienteDashboardPage extends StatefulWidget {
  final String barbeariaId;
  final String clienteId;
  final String nomeCliente;

  const ClienteDashboardPage({
    super.key,
    required this.barbeariaId,
    required this.clienteId,
    required this.nomeCliente,
  });

  @override
  State<ClienteDashboardPage> createState() => _ClienteDashboardPageState();
}

class _ClienteDashboardPageState extends State<ClienteDashboardPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Lista das 4 abas do menu
    final List<Widget> telas = [
      _construirAbaInicio(),
      _construirAbaConstrucao('Loja de Produtos', Icons.shopping_bag),
      _construirAbaConstrucao('Clube VIP', Icons.star),
      _construirAbaPerfil(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Barbearia'),
        centerTitle: true,
      ),
      body: telas[_selectedIndex], // Mostra a tela selecionada no menu
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFE0A96D), // Sua cor principal
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Loja'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'VIP'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }

  // --- O CONTEÚDO DE CADA ABA ---

  // ABA 1: Início / Agenda
  Widget _construirAbaInicio() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mensagem de Boas-vindas Dinâmica!
          Text(
            'Olá, ${widget.nomeCliente}! 👋',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Card de Agendamento Ativo
          const Text(
            'Próximo Agendamento',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Card(
            color: const Color(0xFF1E1E1E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              contentPadding: EdgeInsets.all(16),
              leading: Icon(Icons.calendar_month, color: Color(0xFFE0A96D), size: 32),
              title: Text('Nenhum horário marcado'),
              subtitle: Text('Que tal dar um trato no visual?'),
            ),
          ),
          const SizedBox(height: 32),

          // Botão gigante para Novo Agendamento
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE0A96D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Aqui você vai navegar para a tela de marcação que já tem pronta!
                // Exemplo: Navigator.push(context, MaterialPageRoute(builder: (_) => ClientBookingScreen(barbeariaId: widget.barbeariaId)));
              },
              child: const Text('AGENDAR AGORA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  // Abas 2 e 3 (Temporárias enquanto construímos o resto)
  Widget _construirAbaConstrucao(String titulo, IconData icone) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 80, color: Colors.grey[800]),
          const SizedBox(height: 16),
          Text('$titulo em breve...', style: const TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  // ABA 4: Perfil e Saída
  Widget _construirAbaPerfil() {
    return Center(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[900],
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        icon: const Icon(Icons.exit_to_app, color: Colors.white),
        label: const Text('Sair da Conta', style: TextStyle(color: Colors.white, fontSize: 16)),
        onPressed: () {
          FirebaseAuth.instance.signOut();
        },
      ),
    );
  }
}