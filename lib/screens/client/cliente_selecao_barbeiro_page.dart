import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClienteSelecaoBarbeiroPage extends StatelessWidget {
  final String barbeariaId;
  final String nomeServico;
  final double precoServico;
  final bool isPlano;

  const ClienteSelecaoBarbeiroPage({
    super.key,
    required this.barbeariaId,
    required this.nomeServico,
    required this.precoServico,
    required this.isPlano,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Escolha o Profissional',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Resumo do serviço selecionado
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE0A96D).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(nomeServico, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  Text(
                    'R\$ ${precoServico.toStringAsFixed(2)}',
                    style: const TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de Barbeiros (Roleta)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('barbearias')
                  .doc(barbeariaId)
                  .collection('barbeiros')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE0A96D)));
                }

                final barbeiros = snapshot.data?.docs ?? [];

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Opção 1: Qualquer Profissional (Otimiza a agenda do dono)
                    _buildBarberCard(
                      context,
                      nome: 'Qualquer profissional',
                      fotoUrl: null,
                      isQualquer: true,
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'Profissionais disponíveis:',
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ),
                    
                    // Opção 2: Lista dinâmica de barbeiros reais
                    if (barbeiros.isEmpty)
                      const Center(
                        child: Text(
                          'Nenhum profissional cadastrado.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      ...barbeiros.map((doc) {
                        final b = doc.data() as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildBarberCard(
                            context,
                            nome: b['nome']?.toString() ?? 'Barbeiro',
                            fotoUrl: b['fotoUrl']?.toString(),
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarberCard(BuildContext context, {required String nome, String? fotoUrl, bool isQualquer = false}) {
    return Card(
      color: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isQualquer 
            ? const BorderSide(color: Color(0xFFE0A96D), width: 1.5) 
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: isQualquer ? const Color(0xFFE0A96D).withOpacity(0.2) : Colors.grey[800],
          radius: 28,
          backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
          child: fotoUrl == null
              ? Icon(isQualquer ? Icons.flash_on : Icons.person, color: const Color(0xFFE0A96D), size: 28)
              : null,
        ),
        title: Text(
          nome,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          isQualquer ? 'O primeiro horário disponível' : 'Ver agenda completa',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        onTap: () {
          // No próximo passo, isto abrirá o calendário de horários
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('A avançar para a agenda de: $nome'),
              backgroundColor: const Color(0xFFE0A96D),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }
}