import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

class OwnerBarbeirosTab extends StatelessWidget {
  final String barbeariaId;
  const OwnerBarbeirosTab({super.key, required this.barbeariaId});

  // ============================================================
  // HELPERS VISUAIS
  // ============================================================

  Color _corAvatar(int index) {
    const cores = [
      Color(0xFF3D3522),
      Color(0xFF232A3D),
      Color(0xFF3D2323),
      Color(0xFF233D2A),
      Color(0xFF3D233D),
    ];
    return cores[index % cores.length];
  }

  String _resumirServicos(List<String> servicos) {
    if (servicos.isEmpty) return 'Todos os serviços';
    if (servicos.length <= 3) return servicos.join(', ');
    final primeiros = servicos.take(3).join(', ');
    return '$primeiros +${servicos.length - 3}';
  }

  String _diasResumidos(List<int> dias) {
    if (dias.isEmpty) return 'Sem dias';
    final sorted = List<int>.from(dias)..sort();
    final nomes = {1: 'Seg', 2: 'Ter', 3: 'Qua', 4: 'Qui', 5: 'Sex', 6: 'Sáb', 7: 'Dom'};

    if (sorted.length == 6 && sorted.first == 1 && sorted.last == 6) {
      return 'Seg a Sáb';
    }
    if (sorted.length == 7) return 'Todos os dias';
    if (sorted.length == 5 && sorted.first == 1 && sorted.last == 5) {
      return 'Seg a Sex';
    }
    return sorted.map((d) => nomes[d] ?? '').join(', ');
  }

  // ============================================================
  // BUILD — LISTA
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFE0A96D),
        foregroundColor: Colors.black,
        onPressed: () => _abrirWizardBarbeiro(context),
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
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE0A96D)));
          }

          final barbeiros = snapshot.data?.docs ?? [];

          if (barbeiros.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum profissional cadastrado.\nToque em + para adicionar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: barbeiros.length,
            itemBuilder: (ctx, i) {
              final doc = barbeiros[i];
              final b = doc.data() as Map<String, dynamic>;
              final id = doc.id;

              final nome = b['nome']?.toString() ?? 'Profissional';
              final fotoBase64 = b['foto_base64']?.toString() ?? '';
              final hInicio = b['hora_inicio']?.toString() ?? '08:00';
              final hFim = b['hora_fim']?.toString() ?? '22:00';
              final comServ = (b['comissao_porcentagem'] as num?)?.toInt() ?? 50;
              final comProd = (b['comissao_produtos_pct'] as num?)?.toInt() ?? 10;
              final comAssin = (b['comissao_assinante_pct'] as num?)?.toInt() ?? 30;
              final servicosList = (b['servicos'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  <String>[];
              final diasList = (b['dias_trabalho'] as List<dynamic>?)
                      ?.map((e) => int.tryParse(e.toString()) ?? 1)
                      .toList() ??
                  <int>[1, 2, 3, 4, 5, 6];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 60,
                        height: 60,
                        color: _corAvatar(i),
                        child: fotoBase64.isNotEmpty
                            ? Image.memory(
                                base64Decode(fotoBase64),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person_outline,
                                  color: Colors.white54,
                                  size: 32,
                                ),
                              )
                            : const Icon(
                                Icons.person_outline,
                                color: Colors.white54,
                                size: 32,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  nome,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InkWell(
                                onTap: () => _abrirMenuAcoesBarbeiro(
                                  context,
                                  barbeiroId: id,
                                  dados: b,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.more_vert,
                                    color: Colors.white54,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$hInicio às $hFim · ${_diasResumidos(diasList)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 10),

                          _buildChipComissao('Serviço', comServ),
                          const SizedBox(height: 6),
                          _buildChipComissao('Produtos', comProd),
                          const SizedBox(height: 6),
                          _buildChipComissao('Assinante', comAssin),

                          const SizedBox(height: 10),

                          Text(
                            _resumirServicos(servicosList),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildChipComissao(String label, int pct) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label $pct%',
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

// >>> CONTINUA NA PARTE 2/3 <<<

  // ============================================================
  // WIZARD — ABRE O MODAL DE 3 ETAPAS
  // ============================================================

  void _abrirWizardBarbeiro(BuildContext context, {String? barbeiroId, Map<String, dynamic>? dadosAtuais}) {
    final nomeCtrl = TextEditingController(text: dadosAtuais?['nome']?.toString() ?? '');
    final cpfCtrl = TextEditingController(text: dadosAtuais?['cpf']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: dadosAtuais?['email']?.toString() ?? '');

    final comServCtrl = TextEditingController(
      text: (dadosAtuais?['comissao_porcentagem'] ?? 50).toString(),
    );
    final comProdCtrl = TextEditingController(
      text: (dadosAtuais?['comissao_produtos_pct'] ?? 10).toString(),
    );
    final comAssinCtrl = TextEditingController(
      text: (dadosAtuais?['comissao_assinante_pct'] ?? 30).toString(),
    );

    int etapaAtual = 0;
    String fotoBase64 = dadosAtuais?['foto_base64']?.toString() ?? '';
    bool uploadingFoto = false;
    String horaInicio = dadosAtuais?['hora_inicio']?.toString() ?? '08:00';
    String horaFim = dadosAtuais?['hora_fim']?.toString() ?? '22:00';
    List<String> servicosSelecionados =
        (dadosAtuais?['servicos'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
    List<int> diasTrabalho =
        (dadosAtuais?['dias_trabalho'] as List<dynamic>?)
                ?.map((e) => int.tryParse(e.toString()) ?? 1)
                .toList() ??
            <int>[1, 2, 3, 4, 5, 6];

    String? erroNome;
    String? erroCpf;
    String? erroEmail;

    final nomesDias = {
      1: 'Seg', 2: 'Ter', 3: 'Qua', 4: 'Qui', 5: 'Sex', 6: 'Sáb', 7: 'Dom',
    };

    final List<String> horasDisponiveis = [
      '06:00', '07:00', '08:00', '09:00', '10:00', '11:00', '12:00',
      '13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00',
      '20:00', '21:00', '22:00', '23:00',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          // ============================================================
          // UPLOAD FOTO — BASE64 COM COMPRESSÃO
          // ============================================================
          Future<void> escolherEFazerUpload() async {
            debugPrint('📸 [FOTO] Iniciando...');

            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.image,
                withData: true,
              );

              if (result == null || result.files.isEmpty) {
                debugPrint('📸 [FOTO] Cancelado');
                return;
              }

              final file = result.files.first;
              debugPrint('📸 [FOTO] Arquivo: ${file.name} (${file.size} bytes)');

              if (file.bytes == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Não foi possível ler a imagem.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
                return;
              }

              setState(() => uploadingFoto = true);
                debugPrint('📸 [FOTO] Comprimindo...');

                // Decodifica
                final original = img.decodeImage(file.bytes!);
                if (original == null) {
                  throw Exception('Formato de imagem inválido');
                }

                // Pega o lado menor pra fazer um quadrado central
                final ladoMenor = original.width < original.height
                    ? original.width
                    : original.height;

                // Calcula offset pra centralizar
                final offsetX = (original.width - ladoMenor) ~/ 2;
                final offsetY = (original.height - ladoMenor) ~/ 2;

                // Corta quadrado do CENTRO da imagem
                final cortada = img.copyCrop(
                  original,
                  x: offsetX,
                  y: offsetY,
                  width: ladoMenor,
                  height: ladoMenor,
                );

                debugPrint('📸 [FOTO] Original: ${original.width}x${original.height}');
                debugPrint('📸 [FOTO] Cortado: ${cortada.width}x${cortada.height}');

                // Redimensiona o quadrado pra 300x300
                final resized = img.copyResize(
                  cortada,
                  width: 300,
                  height: 300,
                );

                // Comprime JPEG qualidade 70
                final compressed = img.encodeJpg(resized, quality: 70);

                debugPrint('📸 [FOTO] Após compressão: ${compressed.length} bytes');

                // Base64
                final base64String = base64Encode(compressed);
                debugPrint('📸 [FOTO] Base64: ${base64String.length} chars');

                setState(() {
                  fotoBase64 = base64String;
                  uploadingFoto = false;
                });

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Foto carregada!'),
                    backgroundColor: Color(0xFF00C853),
                  ),
                );
              }

              debugPrint('📸 [FOTO] ✅ Pronto!');
            } catch (e, stack) {
              debugPrint('📸 [FOTO] ❌ ERRO: $e');
              debugPrint('📸 [FOTO] $stack');
              setState(() => uploadingFoto = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro: $e'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            }
          }

          // ============================================================
          // ETAPA 1: PERFIL
          // ============================================================
          Widget buildEtapa1() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Perfil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),

                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              width: 140,
                              height: 140,
                              color: const Color(0xFF232323),
                              child: uploadingFoto
                                  ? const Center(
                                      child: CircularProgressIndicator(color: Color(0xFFE0A96D)),
                                    )
                                  : fotoBase64.isNotEmpty
                                      ? SizedBox(
                                          width: 140,
                                          height: 140,
                                          child: Image.memory(
                                            base64Decode(fotoBase64),
                                            fit: BoxFit.cover,
                                            width: 140,
                                            height: 140,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.person_outline,
                                              size: 64,
                                              color: Colors.white30,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person_outline,
                                          size: 64,
                                          color: Colors.white30,
                                        ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: InkWell(
                              onTap: uploadingFoto ? null : escolherEFazerUpload,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0A96D),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.black,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fotoBase64.isEmpty ? 'Adicionar foto' : 'Trocar foto',
                        style: const TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _buildCampoWizard(
                  label: 'Nome do profissional',
                  controller: nomeCtrl,
                  errorText: erroNome,
                  onChanged: (_) {
                    if (erroNome != null) setState(() => erroNome = null);
                  },
                ),
                const SizedBox(height: 12),
                _buildCampoWizard(
                  label: 'CPF (usado no login)',
                  controller: cpfCtrl,
                  keyboardType: TextInputType.number,
                  errorText: erroCpf,
                  onChanged: (_) {
                    if (erroCpf != null) setState(() => erroCpf = null);
                  },
                ),
                const SizedBox(height: 12),
                _buildCampoWizard(
                  label: 'E-mail para recuperar a senha',
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  errorText: erroEmail,
                  onChanged: (_) {
                    if (erroEmail != null) setState(() => erroEmail = null);
                  },
                ),
              ],
            );
          }

          // ============================================================
          // ETAPA 2: COMISSÕES
          // ============================================================
          Widget buildEtapa2() {
            final int comServ = int.tryParse(comServCtrl.text) ?? 0;
            final int comAssin = int.tryParse(comAssinCtrl.text) ?? 0;
            final double exServ = 30.0 * comServ / 100;
            final double exAssin = 30.0 * comAssin / 100;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Comissões',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),

                _buildLabelWizard('Serviços avulsos'),
                _buildCampoPct(
                  controller: comServCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ex.: 50% sobre cortes e barbas avulsos.',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),

                const SizedBox(height: 18),
                _buildLabelWizard('Produtos vendidos'),
                _buildCampoPct(
                  controller: comProdCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ex.: 10% sobre pomadas, cremes e similares.',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),

                const SizedBox(height: 18),
                _buildLabelWizard('Atendimento de assinantes'),
                _buildCampoPct(
                  controller: comAssinCtrl,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ex.: 30% do valor de tabela quando o cliente tem plano.',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Exemplo com essas taxas',
                        style: TextStyle(fontSize: 13, color: Colors.white54),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Corte de R\$ 30,00 avulso: R\$ ${exServ.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Corte de R\$ 30,00 de assinante: R\$ ${exAssin.toStringAsFixed(2).replaceAll('.', ',')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

// >>> CONTINUA NA PARTE 3/3 <<<

          // ============================================================
          // ETAPA 3: AGENDA
          // ============================================================
          Widget buildEtapa3() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Agenda',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),

                _buildLabelWizard('Horário de trabalho'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdownHora(
                        label: 'Entrada',
                        valor: horaInicio,
                        horas: horasDisponiveis,
                        onChanged: (v) => setState(() => horaInicio = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildDropdownHora(
                        label: 'Saída',
                        valor: horaFim,
                        horas: horasDisponiveis,
                        onChanged: (v) => setState(() => horaFim = v),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),
                _buildLabelWizard('Dias de atendimento'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: nomesDias.entries.map((entry) {
                    final isSel = diasTrabalho.contains(entry.key);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSel) {
                            diasTrabalho.remove(entry.key);
                          } else {
                            diasTrabalho.add(entry.key);
                          }
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white : const Color(0xFF232323),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: isSel ? Colors.black : Colors.white54,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 22),
                _buildLabelWizard('Serviços que realiza'),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('barbearias')
                      .doc(barbeariaId)
                      .collection('servicos')
                      .snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            color: Color(0xFFE0A96D),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    }
                    final servicos = snap.data!.docs;
                    if (servicos.isEmpty) {
                      return const Text(
                        'Nenhum serviço cadastrado ainda.',
                        style: TextStyle(fontSize: 12, color: Colors.white38),
                      );
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: servicos.map((sDoc) {
                        final s = sDoc.data() as Map<String, dynamic>;
                        final sNome = s['nome']?.toString() ?? '';
                        final isSel = servicosSelecionados.contains(sNome);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (isSel) {
                                servicosSelecionados.remove(sNome);
                              } else {
                                servicosSelecionados.add(sNome);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: isSel ? Colors.white : const Color(0xFF232323),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              sNome,
                              style: TextStyle(
                                color: isSel ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          }

          Widget buildConteudo() {
            switch (etapaAtual) {
              case 0:
                return buildEtapa1();
              case 1:
                return buildEtapa2();
              case 2:
                return buildEtapa3();
              default:
                return const SizedBox.shrink();
            }
          }

          // ============================================================
          // SALVAR
          // ============================================================
          Future<void> salvar() async {
            final nomeVazio = nomeCtrl.text.trim().isEmpty;
            final cpfVazio = cpfCtrl.text.trim().isEmpty;
            final emailVazio = emailCtrl.text.trim().isEmpty;
            final emailInvalido = !emailVazio && !emailCtrl.text.contains('@');

            if (nomeVazio || cpfVazio || emailVazio || emailInvalido) {
              setState(() {
                etapaAtual = 0;
                erroNome = nomeVazio ? 'Informe o nome' : null;
                erroCpf = cpfVazio ? 'Informe o CPF' : null;
                erroEmail = emailVazio
                    ? 'Informe o e-mail'
                    : (emailInvalido ? 'E-mail inválido' : null);
              });
              return;
            }

            final payload = <String, dynamic>{
              'nome': nomeCtrl.text.trim(),
              'cpf': cpfCtrl.text.trim().replaceAll(RegExp(r'\D'), ''),
              'email': emailCtrl.text.trim().toLowerCase(),
              'comissao_porcentagem': int.tryParse(comServCtrl.text.trim()) ?? 50,
              'comissao_produtos_pct': int.tryParse(comProdCtrl.text.trim()) ?? 10,
              'comissao_assinante_pct': int.tryParse(comAssinCtrl.text.trim()) ?? 30,
              'hora_inicio': horaInicio,
              'hora_fim': horaFim,
              'servicos': servicosSelecionados,
              'dias_trabalho': diasTrabalho,
              'foto_base64': fotoBase64.isNotEmpty ? fotoBase64 : null,
            };

            try {
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

              if (ctx.mounted) Navigator.pop(ctx);
            } catch (e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Erro ao salvar: $e')),
                );
              }
            }
          }

          // ============================================================
          // LAYOUT DO WIZARD
          // ============================================================
          const totalEtapas = 3;
          final isUltima = etapaAtual == totalEtapas - 1;
          final titulo = barbeiroId == null ? 'Novo barbeiro' : 'Editar barbeiro';

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (etapaAtual == 0) {
                                Navigator.pop(ctx);
                              } else {
                                setState(() => etapaAtual--);
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            titulo,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: List.generate(totalEtapas, (i) {
                          return Expanded(
                            child: Container(
                              margin: EdgeInsets.only(
                                right: i < totalEtapas - 1 ? 6 : 0,
                              ),
                              height: 4,
                              decoration: BoxDecoration(
                                color: i <= etapaAtual
                                    ? const Color(0xFFE0A96D)
                                    : const Color(0xFF2A2A2A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          );
                        }),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ['Perfil', 'Comissões', 'Agenda'][etapaAtual],
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Etapa ${etapaAtual + 1} de $totalEtapas',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      buildConteudo(),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (isUltima) {
                              salvar();
                            } else {
                              if (etapaAtual == 0) {
                                final nomeVazio = nomeCtrl.text.trim().isEmpty;
                                final cpfVazio = cpfCtrl.text.trim().isEmpty;
                                final emailVazio = emailCtrl.text.trim().isEmpty;
                                final emailInvalido =
                                    !emailVazio && !emailCtrl.text.contains('@');

                                setState(() {
                                  erroNome = nomeVazio ? 'Informe o nome' : null;
                                  erroCpf = cpfVazio ? 'Informe o CPF' : null;
                                  erroEmail = emailVazio
                                      ? 'Informe o e-mail'
                                      : (emailInvalido ? 'E-mail inválido' : null);
                                });

                                if (nomeVazio || cpfVazio || emailVazio || emailInvalido) {
                                  return;
                                }
                              }
                              setState(() => etapaAtual++);
                            }
                          },
                          child: Text(
                            isUltima ? 'Salvar barbeiro' : 'Continuar',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

// >>> CONTINUA NA PARTE 4/4 <<<

  // ============================================================
  // HELPERS DO WIZARD
  // ============================================================

  Widget _buildLabelWizard(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 14, color: Colors.white70),
    );
  }

  Widget _buildCampoWizard({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    String? errorText,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: errorText != null ? Colors.redAccent : Colors.white54,
        ),
        errorText: errorText,
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF232323),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: errorText != null
              ? const BorderSide(color: Colors.redAccent, width: 1.5)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? Colors.redAccent : const Color(0xFFE0A96D),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildCampoPct({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        suffixText: '%',
        suffixStyle: const TextStyle(color: Colors.white54, fontSize: 16),
        filled: true,
        fillColor: const Color(0xFF232323),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0A96D), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDropdownHora({
    required String label,
    required String valor,
    required List<String> horas,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF232323),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: horas.contains(valor) ? valor : horas.first,
          isExpanded: true,
          dropdownColor: const Color(0xFF232323),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          items: horas.map((h) {
            return DropdownMenuItem(value: h, child: Text(h));
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  // ============================================================
  // MENU DE AÇÕES
  // ============================================================

  void _abrirMenuAcoesBarbeiro(
    BuildContext context, {
    required String barbeiroId,
    required Map<String, dynamic> dados,
  }) {
    final nome = dados['nome']?.toString() ?? 'Profissional';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: Colors.white70, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      nome,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _buildMenuActionBarbeiro(
              icon: Icons.edit_outlined,
              label: 'Editar profissional',
              onTap: () {
                Navigator.pop(ctx);
                _abrirWizardBarbeiro(
                  context,
                  barbeiroId: barbeiroId,
                  dadosAtuais: dados,
                );
              },
            ),
            const Divider(color: Colors.white12, height: 1),
            _buildMenuActionBarbeiro(
              icon: Icons.delete_outline,
              label: 'Excluir profissional',
              corIcone: Colors.redAccent,
              corTexto: Colors.redAccent,
              onTap: () {
                Navigator.pop(ctx);
                _excluirBarbeiro(context, barbeiroId, nome);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuActionBarbeiro({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color corIcone = Colors.white70,
    Color corTexto = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: corIcone, size: 24),
            const SizedBox(width: 20),
            Text(
              label,
              style: TextStyle(
                color: corTexto,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EXCLUIR
  // ============================================================

  Future<void> _excluirBarbeiro(
    BuildContext context,
    String barbeiroId,
    String nome,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir profissional'),
        content: Text(
          'Tem certeza que deseja excluir "$nome"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('barbearias')
          .doc(barbeariaId)
          .collection('barbeiros')
          .doc(barbeiroId)
          .delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profissional excluído.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir: $e')),
        );
      }
    }
  }
}