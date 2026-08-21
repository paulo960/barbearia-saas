import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Importações das telas de navegação financeira para evitar a tela branca
// (Certifique-se de que esses arquivos existem na pasta lib/screens/)
import 'repasses_equipe_screen.dart';
import 'historico_recibos_screen.dart';
import 'extrato_caixa_screen.dart';
import 'despesas_screen.dart';
import 'mensalidades_recebidas_screen.dart';

class FinanceiroScreen extends StatefulWidget {
  final String barbeariaId;
  const FinanceiroScreen({super.key, required this.barbeariaId});

  @override
  State<FinanceiroScreen> createState() => _FinanceiroScreenState();
}

class _FinanceiroScreenState extends State<FinanceiroScreen> {
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
                    'pago': false,
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
    required double totalFaturado,
    required double despesasPagas,
    required double despesasAberto,
    required double comissoesPagas,
    required double comissoesAberto,
    required double lucroLiquido,
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
              child: pw.Column(
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('FATURAMENTO BRUTO:'), pw.Text('R\$ ${totalFaturado.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Despesas (Pagas / Aberto):'), pw.Text('R\$ ${despesasPagas.toStringAsFixed(2)} / R\$ ${despesasAberto.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Comissões (Pagas / Aberto):'), pw.Text('R\$ ${comissoesPagas.toStringAsFixed(2)} / R\$ ${comissoesAberto.toStringAsFixed(2)}')]),
                  pw.Divider(height: 12),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('LUCRO REAL:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('R\$ ${lucroLiquido.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))]),
                ],
              ),
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
                            for (var b in barbeirosDocs) {
                              final data = b.data() as Map<String, dynamic>;
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
                                final agendamentosFiltrados = todosAgendamentos.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final despesasFiltradas = todasDespesas.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final mensalidadesFiltradas = todasMensalidades.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final valesFiltrados = todosVales.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();
                                final repassesFeitosFiltrados = todosRepassesFeitos.where((doc) => _verificarFiltroData(doc.data() as Map<String, dynamic>)).toList();

                                double despesasPagas = 0.0;
                                double despesasAberto = 0.0;
                                for (var dDoc in despesasFiltradas) {
                                  final d = dDoc.data() as Map<String, dynamic>;
                                  final val = (d['valor'] as num?)?.toDouble() ?? 0.0;
                                  if (d['pago'] == true) {
                                    despesasPagas += val;
                                  } else {
                                    despesasAberto += val;
                                  }
                                }

                                double comissoesPagas = 0.0;
                                for (var rDoc in repassesFeitosFiltrados) {
                                  final r = rDoc.data() as Map<String, dynamic>;
                                  comissoesPagas += (r['valor_comissoes'] as num?)?.toDouble() ?? 0.0;
                                }

                                double totalServicos = 0.0;
                                double totalProdutos = 0.0;
                                double totalComissoesGeral = 0.0;
                                double totalComissoesPendentes = 0.0;
                                double totalValesPendentes = 0.0;

                                for (var vDoc in valesFiltrados) {
                                  final d = vDoc.data() as Map<String, dynamic>;
                                  if (d['vale_liquidado'] != true) {
                                    totalValesPendentes += (d['valor'] as num?)?.toDouble() ?? 0.0;
                                  }
                                }

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

                                    totalComissoesGeral += comissaoDesteAtendimento;

                                    if (!repasseLiquidado) {
                                      totalComissoesPendentes += comissaoDesteAtendimento;
                                    }
                                  }
                                }

                                double totalMensalidades = 0.0;
                                for (var mDoc in mensalidadesFiltradas) {
                                  final d = mDoc.data() as Map<String, dynamic>;
                                  totalMensalidades += (d['valor'] as num?)?.toDouble() ?? 0.0;
                                }

                                final comissoesAberto = totalComissoesPendentes;
                                final faturamentoBrutoTotal = totalServicos + totalProdutos + totalMensalidades;
                                final totalDespesasGeral = despesasPagas + despesasAberto;
                                final lucroLiquido = faturamentoBrutoTotal - totalDespesasGeral - totalComissoesGeral;
                                final liquidoRepassePendenteGeral = (totalComissoesPendentes - totalValesPendentes).clamp(0.0, 999999.0);

                                return SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
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
                                                      const Text('🔴 Despesas (P/A)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${despesasPagas.toStringAsFixed(0)} / R\$ ${despesasAberto.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                                                    ],
                                                  ),
                                                  Column(
                                                    children: [
                                                      const Text('🟠 Comissões (P/A)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                                      const SizedBox(height: 4),
                                                      Text('R\$ ${comissoesPagas.toStringAsFixed(0)} / R\$ ${comissoesAberto.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
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
                                              totalFaturado: faturamentoBrutoTotal,
                                              despesasPagas: despesasPagas,
                                              despesasAberto: despesasAberto,
                                              comissoesPagas: comissoesPagas,
                                              comissoesAberto: comissoesAberto,
                                              lucroLiquido: lucroLiquido,
                                              registros: agendamentosFiltrados,
                                            ),
                                          ),
                                        ],
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
