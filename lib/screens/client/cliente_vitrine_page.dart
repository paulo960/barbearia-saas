import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'client_booking_screen.dart';

class ClienteVitrinePage extends StatefulWidget {
  final String barbeariaId;

  // Recebe o ID da barbearia pela URL (no futuro SaaS)
  const ClienteVitrinePage({super.key, required this.barbeariaId});

  @override
  State<ClienteVitrinePage> createState() => _ClienteVitrinePageState();
}

class _ClienteVitrinePageState extends State<ClienteVitrinePage> {
  String nomeBarbearia = 'Carregando...';
  String whatsappBarbearia = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDadosBarbearia();
  }

  Future<void> _carregarDadosBarbearia() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('barbearias')
          .doc(widget.barbeariaId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          nomeBarbearia = data['nome']?.toString() ?? 'Barbearia';
          whatsappBarbearia = data['telefone']?.toString() ?? '';
          isLoading = false;
        });
      } else {
        setState(() {
          nomeBarbearia = 'Barbearia não encontrada';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        nomeBarbearia = 'Erro ao carregar';
        isLoading = false;
      });
    }
  }

  Future<void> _abrirWhatsApp() async {
    if (whatsappBarbearia.isEmpty) return;
    
    // Limpa o número deixando apenas os dígitos
    final numeroLimpo = whatsappBarbearia.replaceAll(RegExp(r'\D'), '');
    final url = Uri.parse('https://wa.me/55$numeroLimpo?text=Olá,%20gostaria%20de%20ajuda%20para%20agendar%20um%20horário.');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE0A96D)))
          : Stack(
              children: [
                // 1. Fundo Fotográfico Premium Escurecido
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      // Foto genérica de fundo
                      image: NetworkImage('https://images.unsplash.com/photo-1585747860715-2ba37e788b70?auto=format&fit=crop&w=800&q=80'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Película escura por cima da foto para dar contraste
                Container(
                  color: Colors.black.withOpacity(0.75),
                ),
                
                // 2. Conteúdo do Ecrã
                SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Topo: Nome da Barbearia
                      Padding(
                        padding: const EdgeInsets.only(top: 60.0, left: 20, right: 20),
                        child: Column(
                          children: [
                            const Icon(Icons.content_cut, color: Color(0xFFE0A96D), size: 40),
                            const SizedBox(height: 16),
                            Text(
                              nomeBarbearia.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Meio: Botão de Agendamento
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE0A96D),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              elevation: 8,
                            ),
                            onPressed: () {
                              // Navega diretamente para o ecrã completo de agendamento
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ClientBookingScreen(barbeariaId: widget.barbeariaId),
                                  ),
                                );
                              },
                            child: const Text(
                              'AGENDAR HORÁRIO',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Rodapé: Botão salva-vidas do WhatsApp
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30.0),
                        child: TextButton.icon(
                          onPressed: _abrirWhatsApp,
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white54, size: 20),
                          label: const Text(
                            'Dificuldade para agendar? Chame no WhatsApp',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}