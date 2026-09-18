import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cliente_selecao_barbeiro_page.dart';

class ClienteServicosPage extends StatefulWidget {
  final String barbeariaId;

  const ClienteServicosPage({super.key, required this.barbeariaId});

  @override
  State<ClienteServicosPage> createState() => _ClienteServicosPageState();
}

class _ClienteServicosPageState extends State<ClienteServicosPage> {
  
  // Função que será chamada quando o cliente tocar num serviço ou plano
 void _avancarParaProfissionais(BuildContext context, String nomeItem, double preco, bool isPlano) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClienteSelecaoBarbeiroPage(
          barbeariaId: widget.barbeariaId,
          nomeServico: nomeItem,
          precoServico: preco,
          isPlano: isPlano,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF1E1E1E),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'O que deseja fazer?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: const TabBar(
            indicatorColor: Color(0xFFE0A96D),
            labelColor: Color(0xFFE0A96D),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(text: 'SERVIÇOS AVULSOS'),
              Tab(text: 'ASSINATURAS VIP'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ABA 1: SERVIÇOS AVULSOS
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('barbearias')
                  .doc(widget.barbeariaId)
                  .collection('servicos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE0A96D)));
                }

                final servicos = snapshot.data?.docs ?? [];

                if (servicos.isEmpty) {
                  // SERVIÇO DE TESTE PARA PODERMOS CLICAR
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        color: const Color(0xFF2C2C2C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: const Text('Corte Degradê (TESTE)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: const Text('⏱️ 45 min', style: TextStyle(color: Colors.white54, fontSize: 13)),
                          trailing: const Text(
                            'R\$ 35.00',
                            style: TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          onTap: () => _avancarParaProfissionais(context, 'Corte Degradê (TESTE)', 35.0, false),
                        ),
                      ),
                    ],
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: servicos.length,
                  itemBuilder: (context, index) {
                    final s = servicos[index].data() as Map<String, dynamic>;
                    final nome = s['nome']?.toString() ?? 'Serviço';
                    final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;
                    final duracao = s['duracao']?.toString() ?? '30 min';

                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        title: Text(nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text('⏱️ $duracao', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        trailing: Text(
                          'R\$ ${preco.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onTap: () => _avancarParaProfissionais(context, nome, preco, false),
                      ),
                    );
                  },
                );
              },
            ),

            // ABA 2: ASSINATURAS / PLANOS
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('barbearias')
                  .doc(widget.barbeariaId)
                  .collection('planos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFE0A96D)));
                }

                final planos = snapshot.data?.docs ?? [];

                if (planos.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma assinatura disponível.', style: TextStyle(color: Colors.white54)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: planos.length,
                  itemBuilder: (context, index) {
                    final p = planos[index].data() as Map<String, dynamic>;
                    final nome = p['nome']?.toString() ?? 'Plano VIP';
                    final preco = (p['valor'] as num?)?.toDouble() ?? 0.0;
                    final frequencia = p['frequencia']?.toString() ?? 'Mensal';

                    return Card(
                      color: const Color(0xFF2C2C2C),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE0A96D), width: 1), // Borda dourada para destacar
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        leading: const Icon(Icons.workspace_premium, color: Color(0xFFE0A96D), size: 30),
                        title: Text(nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(frequencia, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        trailing: Text(
                          'R\$ ${preco.toStringAsFixed(2)}',
                          style: const TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onTap: () => _avancarParaProfissionais(context, nome, preco, true),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}