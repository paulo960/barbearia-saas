import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide TextSpan;
import 'package:universal_html/html.dart' as html;

// -------------------------------------------------------------------
// ---------------- HUB PRINCIPAL DO FINANCEIRO (DRE COM PAGO VS. ABERTO) ----------------
class OwnerFinanceiroTab extends StatefulWidget {
  final String barbeariaId;
  const OwnerFinanceiroTab({required this.barbeariaId});

  @override
  State<OwnerFinanceiroTab> createState() => _OwnerFinanceiroTabState();
}

class _OwnerFinanceiroTabState extends State<OwnerFinanceiroTab> {
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
                    'pago': false, // Começa em aberto por padrão
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

void _gerarExcelParaContador(
    double faturamento, double despesasPagas, double despesasAberto, 
    double comissoesPagas, double comissoesAberto, double lucro,
    List agendamentos, List despesasLista,
    String nomeArquivo, String periodoPlanilha,
    DateTime? dataInicio, DateTime? dataFim
  ) {
    var excel = Excel.createExcel();
    
    // ABA 1: Resumo
    Sheet sheetResumo = excel['Resumo Mensal'];
    sheetResumo.setColumnWidth(0, 30.0); 
    sheetResumo.setColumnWidth(1, 25.0); 

    // Imprimindo o período e as datas exatas para a contabilidade
    sheetResumo.appendRow([TextCellValue('Período do Relatório:'), TextCellValue(periodoPlanilha)]);
    
    if (dataInicio != null && dataFim != null) {
      final iniStr = DateFormat('dd/MM/yyyy').format(dataInicio);
      final fimStr = DateFormat('dd/MM/yyyy').format(dataFim);
      sheetResumo.appendRow([TextCellValue('Data Inicial:'), TextCellValue(iniStr)]);
      sheetResumo.appendRow([TextCellValue('Data Final:'), TextCellValue(fimStr)]);
    }
    
    sheetResumo.appendRow([TextCellValue(''), TextCellValue('')]); // Linha em branco

    sheetResumo.appendRow([TextCellValue('Categoria'), TextCellValue('Valor (R\$)')]);
    sheetResumo.appendRow([TextCellValue('Faturamento Bruto'), DoubleCellValue(faturamento)]);
    sheetResumo.appendRow([TextCellValue('Despesas Pagas'), DoubleCellValue(despesasPagas)]);
    sheetResumo.appendRow([TextCellValue('Despesas em Aberto'), DoubleCellValue(despesasAberto)]);
    sheetResumo.appendRow([TextCellValue('Comissões Pagas'), DoubleCellValue(comissoesPagas)]);
    sheetResumo.appendRow([TextCellValue('Comissões em Aberto'), DoubleCellValue(comissoesAberto)]);
    sheetResumo.appendRow([TextCellValue('Lucro Estimado (Caixa)'), DoubleCellValue(lucro)]);

    // ABA 2: Entradas
    Sheet sheetEntradas = excel['Entradas'];
    sheetEntradas.setColumnWidth(0, 15.0);
    sheetEntradas.setColumnWidth(1, 30.0);
    sheetEntradas.appendRow([TextCellValue('Status'), TextCellValue('Serviço'), TextCellValue('Valor (R\$)')]);
    for (var doc in agendamentos) {
      final d = doc.data() as Map<String, dynamic>;
      sheetEntradas.appendRow([
        TextCellValue(d['status']?.toString() ?? ''),
        TextCellValue(d['servico_nome']?.toString() ?? 'Serviço'),
        DoubleCellValue((d['preco'] as num?)?.toDouble() ?? 0.0),
      ]);
    }

    // ABA 3: Saídas
    Sheet sheetSaidas = excel['Saidas'];
    sheetSaidas.setColumnWidth(0, 25.0);
    sheetSaidas.setColumnWidth(1, 30.0);
    sheetSaidas.appendRow([TextCellValue('Categoria'), TextCellValue('Descrição'), TextCellValue('Valor (R\$)')]);
    for (var doc in despesasLista) {
      final d = doc.data() as Map<String, dynamic>;
      sheetSaidas.appendRow([
        TextCellValue(d['categoria']?.toString() ?? ''),
        TextCellValue(d['descricao']?.toString() ?? ''),
        DoubleCellValue((d['valor'] as num?)?.toDouble() ?? 0.0),
      ]);
    }

    excel.delete('Sheet1'); 

    final bytes = excel.save();
    if (bytes != null) {
      final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "Relatorio_$nomeArquivo.xlsx")
        ..click();
      html.Url.revokeObjectUrl(url);
    }
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

                                // Despesas pagas vs. em aberto
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

                                // Comissões já pagas (via histórico de repasses) vs. em aberto (pendentes)
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
                                      const SizedBox(height: 20),
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
                                          subtitle: Text('Pendente geral: R\$ ${liquidoRepassePendenteGeral.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => RepassesEquipeScreen(barbeariaId: widget.barbeariaId)),
                                            );
                                          },
                                        ),
                                      ),

                                      const SizedBox(height: 6),
                                      // --- NOVO CARD DE EXPORTAÇÃO EXCEL ---
                                      Card(
                                      color: const Color(0xFF1E1E1E),
                                      child: ExpansionTile(
                                        leading: const CircleAvatar(
                                          backgroundColor: Colors.green,
                                          child: Icon(Icons.table_view, color: Colors.black),
                                        ),
                                        title: const Text('Exportação para Contabilidade', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                        subtitle: const Text('Baixar relatório detalhado em Excel (.xlsx)', style: TextStyle(color: Colors.white70)),
                                        iconColor: const Color(0xFFE0A96D),
                                        collapsedIconColor: const Color(0xFFE0A96D),
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                const Text(
                                                  'Selecione o período desejado para o relatório:',
                                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
                                                ),
                                                const SizedBox(height: 10),
                                                
                                                // Chips de escolha de período dentro da sanfona
                                                Wrap(
                                                  spacing: 8.0,
                                                  runSpacing: 8.0,
                                                  children: [
                                                    ChoiceChip(
                                                      label: const Text('Hoje'),
                                                      selected: _filtroPeriodo == 'hoje',
                                                      onSelected: (selected) {
                                                        setState(() => _filtroPeriodo = 'hoje');
                                                      },
                                                    ),
                                                    ChoiceChip(
                                                      label: const Text('7 Dias'),
                                                      selected: _filtroPeriodo == '7dias',
                                                      onSelected: (selected) {
                                                        setState(() => _filtroPeriodo = '7dias');
                                                      },
                                                    ),
                                                    ChoiceChip(
                                                      label: const Text('Este Mês'),
                                                      selected: _filtroPeriodo == 'mes',
                                                      onSelected: (selected) {
                                                        setState(() => _filtroPeriodo = 'mes');
                                                      },
                                                    ),
                                                    ChoiceChip(
                                                      label: const Text('Todos'),
                                                      selected: _filtroPeriodo == 'todos',
                                                      onSelected: (selected) {
                                                        setState(() => _filtroPeriodo = 'todos');
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                
                                                const SizedBox(height: 16),
                                                const Text(
                                                  'O arquivo gerado conterá 3 abas (Resumo Mensal, Entradas e Saídas) formatadas.',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                                const SizedBox(height: 16),
                                                
                                                // Botão de Download
                                                ElevatedButton.icon(
                                                  onPressed: () {
                                                    String txtArquivo = 'Completo';
                                                    String txtPlanilha = 'Todos os Registros';
                                                    
                                                    if (_filtroPeriodo == 'hoje') { 
                                                      txtArquivo = 'Hoje'; 
                                                      txtPlanilha = 'Hoje'; 
                                                    } else if (_filtroPeriodo == '7dias') { 
                                                      txtArquivo = '7_Dias'; 
                                                      txtPlanilha = 'Últimos 7 Dias'; 
                                                    } else if (_filtroPeriodo == 'mes') { 
                                                      txtArquivo = 'Este_Mes'; 
                                                      txtPlanilha = 'Mês Atual'; 
                                                    } else if (_filtroPeriodo == 'custom' && _intervaloCustom != null) {
                                                      final ini = DateFormat('dd-MM-yy').format(_intervaloCustom!.start);
                                                      final fim = DateFormat('dd-MM-yy').format(_intervaloCustom!.end);
                                                      txtArquivo = '${ini}_a_${fim}';
                                                      txtPlanilha = '${ini.replaceAll('-', '/')} até ${fim.replaceAll('-', '/')}';
                                                    }

                                                    _gerarExcelParaContador(
                                                      faturamentoBrutoTotal,
                                                      despesasPagas,
                                                      despesasAberto,
                                                      comissoesPagas,
                                                      comissoesAberto,
                                                      lucroLiquido,
                                                      agendamentosFiltrados,
                                                      despesasFiltradas,
                                                      txtArquivo,
                                                      txtPlanilha,
                                                    );
                                                  },
                                                  icon: const Icon(Icons.download, size: 18),
                                                  label: const Text('Baixar Relatório Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green.shade700,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
                                          subtitle: Text('${repassesFeitosFiltrados.length} acertos liquidados (Com opção de estorno)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
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
                                          subtitle: const Text('Fluxo unificado de atendimentos, produtos e planos', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
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
                                          title: const Text('Despesas Operacionais (Saídas & Quitação)', style: TextStyle(fontWeight: FontWeight.bold)),
                                          subtitle: Text('Pagas: R\$ ${despesasPagas.toStringAsFixed(2)} | Aberto: R\$ ${despesasAberto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                                          onTap: () {
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
                                          onTap: () {
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

// ---------------- SUBTELA 1: REPASSES DA EQUIPE (EXIBINDO O VALOR DIRETO NO CARD) ----------------
class RepassesEquipeScreen extends StatelessWidget {
  final String barbeariaId;
  const RepassesEquipeScreen({super.key, required this.barbeariaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repasses da Equipe (A Pagar)')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('vales_barbeiros').snapshots(),
        builder: (context, valesSnap) {
          final todosVales = valesSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('barbeiros').snapshots(),
            builder: (context, barberSnap) {
              if (!barberSnap.hasData) return const Center(child: CircularProgressIndicator());
              final barbeirosDocs = barberSnap.data!.docs;

              if (barbeirosDocs.isEmpty) {
                return const Center(child: Text('Nenhum barbeiro cadastrado.', style: TextStyle(color: Colors.grey)));
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('agendamentos').snapshots(),
                builder: (context, agSnap) {
                  if (!agSnap.hasData) return const Center(child: CircularProgressIndicator());
                  final todosAgendamentos = agSnap.data!.docs;

                  Map<String, Map<String, int>> comissoesBarbeirosMap = {};
                  for (var b in barbeirosDocs) {
                    final data = b.data() as Map<String, dynamic>;
                    comissoesBarbeirosMap[b.id] = {
                      'servico': int.tryParse(data['comissao_porcentagem']?.toString() ?? '50') ?? 50,
                      'produto': int.tryParse(data['comissao_produtos_pct']?.toString() ?? '10') ?? 10,
                      'assinante': int.tryParse(data['comissao_assinante_pct']?.toString() ?? '30') ?? 30,
                    };
                  }

                  Map<String, double> valesPendentesPorBarbeiro = {};
                  for (var vDoc in todosVales) {
                    final d = vDoc.data() as Map<String, dynamic>;
                    final bId = d['barbeiro_id']?.toString() ?? '';
                    final vValor = (d['valor'] as num?)?.toDouble() ?? 0.0;
                    if (d['vale_liquidado'] != true) {
                      valesPendentesPorBarbeiro[bId] = (valesPendentesPorBarbeiro[bId] ?? 0.0) + vValor;
                    }
                  }

                  Map<String, double> comissoesPendentesPorBarbeiro = {};
                  for (var doc in todosAgendamentos) {
                    final d = doc.data() as Map<String, dynamic>;
                    final bId = d['barbeiro_id']?.toString() ?? '';
                    final st = d['status']?.toString() ?? 'pendente';
                    final precoTotal = (d['preco'] as num?)?.toDouble() ?? 0.0;
                    final precoProd = (d['preco_produtos'] as num?)?.toDouble() ?? 0.0;
                    final precoServ = (d['preco_servico'] as num?)?.toDouble() ?? (precoTotal - precoProd);
                    final tabelaOriginal = (d['preco_tabela_original'] as num?)?.toDouble() ?? precoServ;
                    final coberto = d['coberto_por_plano'] == true;
                    final liquidado = d['repasse_liquidado'] == true;

                    final config = comissoesBarbeirosMap[bId] ?? {'servico': 50, 'produto': 10, 'assinante': 30};

                    if (st == 'concluido' && !liquidado) {
                      double com = 0.0;
                      if (coberto) {
                        com += (tabelaOriginal * (config['assinante'] ?? 30)) / 100;
                      } else {
                        com += (precoServ * (config['servico'] ?? 50)) / 100;
                      }
                      if (precoProd > 0) {
                        com += (precoProd * (config['produto'] ?? 10)) / 100;
                      }
                      comissoesPendentesPorBarbeiro[bId] = (comissoesPendentesPorBarbeiro[bId] ?? 0.0) + com;
                    }
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: barbeirosDocs.length,
                    itemBuilder: (ctx, i) {
                      final bDoc = barbeirosDocs[i];
                      final bData = bDoc.data() as Map<String, dynamic>;
                      final bNome = bData['nome']?.toString() ?? 'Barbeiro';

                      final coms = comissoesPendentesPorBarbeiro[bDoc.id] ?? 0.0;
                      final vals = valesPendentesPorBarbeiro[bDoc.id] ?? 0.0;
                      final liquido = (coms - vals).clamp(0.0, 999999.0);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE0A96D),
                            child: Text(bNome.isNotEmpty ? bNome[0].toUpperCase() : 'B', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(bNome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              children: [
                                const TextSpan(text: 'A Pagar: '),
                                TextSpan(
                                  text: 'R\$ ${liquido.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    // Se o líquido for maior que zero, fica verde e em negrito!
                                    color: liquido > 0 ? const Color(0xFF00C853) : Colors.grey,
                                    fontWeight: liquido > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                TextSpan(text: '\n(Comissões: R\$ ${coms.toStringAsFixed(2)} | Vales: R\$ ${vals.toStringAsFixed(2)})'),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, color: Color(0xFFE0A96D)),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AuditoriaBarbeiroScreen(
                                  barbeariaId: barbeariaId,
                                  barbeiroId: bDoc.id,
                                  barbeiroNome: bNome,
                                  comissoesConfig: bData,
                                ),
                              ),
                            );
                          },
                        ),
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

// ---------------- TELA DE AUDITORIA ANALÍTICA POR BARBEIRO ----------------
class AuditoriaBarbeiroScreen extends StatelessWidget {
  final String barbeariaId;
  final String barbeiroId;
  final String barbeiroNome;
  final Map<String, dynamic> comissoesConfig;

  const AuditoriaBarbeiroScreen({
    super.key,
    required this.barbeariaId,
    required this.barbeiroId,
    required this.barbeiroNome,
    required this.comissoesConfig,
  });

  Future<void> _gerarReciboDetalhadoPdf(
    BuildContext context, {
    required double comissaoServicos,
    required double comissaoAssinaturas,
    required double comissaoProdutos,
    required double totalVales,
    required double liquidoFinal,
    required List<Map<String, dynamic>> itensDetalhados,
  }) async {
    final docPdf = pw.Document();
    final dataFmt = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(DateTime.now());

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
                      pw.Text('RECIBO DE REPASSE DETALHADO', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Profissional: $barbeiroNome', style: const pw.TextStyle(fontSize: 12)),
                    ],
                  ),
                  pw.Text('Data: $dataFmt', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                children: [
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Cortes e Serviços Avulsos:'), pw.Text('Comissão: R\$ ${comissaoServicos.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Atendimentos de Assinantes (Planos):'), pw.Text('Comissão: R\$ ${comissaoAssinaturas.toStringAsFixed(2)}')]),
                  pw.SizedBox(height: 4),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Comissão sobre Produtos Vendidos:'), pw.Text('R\$ ${comissaoProdutos.toStringAsFixed(2)}')]),
                  if (totalVales > 0) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('(-) Vales / Adiantamentos Abatidos:'), pw.Text('- R\$ ${totalVales.toStringAsFixed(2)}', style: const pw.TextStyle(color: PdfColors.red800))]),
                  ],
                  pw.Divider(height: 12),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('VALOR LÍQUIDO PAGO:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)), pw.Text('R\$ ${liquidoFinal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14, color: PdfColors.green800))]),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Extrato Analítico dos Atendimentos:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Data/Hora', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Cliente / Serviço', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Categoria', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Valor Base', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Comissão', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
                  ],
                ),
                ...itensDetalhados.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['data_hora'] ?? '-', style: pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item['cliente']} - ${item['servico']}', style: pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['categoria'], style: pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('R\$ ${item['valor_base'].toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 7))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('R\$ ${item['comissao'].toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    ],
                  );
                }).toList(),
              ],
            ),
            pw.SizedBox(height: 40),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Container(width: 200, height: 1, color: PdfColors.black),
                  pw.SizedBox(height: 4),
                  pw.Text('Assinatura do Profissional ($barbeiroNome)', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => docPdf.save(),
      name: 'recibo_detalhado_${barbeiroNome}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  void _abrirModalLiquidar(
    BuildContext context, {
    required double comissoesBrutas,
    required double totalVales,
    required List<String> agsIds,
    required List<String> valesIds,
    required double servicosComissao,
    required double assinaturasComissao,
    required double produtosComissao,
    required double totalServicosBase,
    required double totalAssinaturasBase,
    required double totalProdutosBase,
    required List<Map<String, dynamic>> itensDetalhados,
  }) {
    final double liquidoAPagar = (comissoesBrutas - totalVales).clamp(0.0, 999999.0);
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
              Text('Comissões Totais: R\$ ${comissoesBrutas.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
              if (totalVales > 0)
                Text('(-) Vales Abatidos: R\$ ${totalVales.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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

                await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('repasses_barbeiros').add({
                  'barbeiro_id': barbeiroId,
                  'barbeiro_nome': barbeiroNome,
                  'valor_comissoes': comissoesBrutas,
                  'valor_vales_abatidos': totalVales,
                  'valor_total_repasse': liquidoAPagar,
                  'detalhe_servicos_comissao': servicosComissao,
                  'detalhe_assinaturas_comissao': assinaturasComissao,
                  'detalhe_produtos_comissao': produtosComissao,
                  'itens_analiticos': itensDetalhados,
                  'ags_ids': agsIds,
                  'vales_ids': valesIds,
                  'forma_pagamento': formaPagamento,
                  'data_iso': DateFormat('yyyy-MM-dd').format(hoje),
                  'data_formatada': DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(hoje),
                  'pago_em': FieldValue.serverTimestamp(),
                });

                for (var id in agsIds) {
                  await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('agendamentos').doc(id).update({'repasse_liquidado': true});
                }
                for (var id in valesIds) {
                  await FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('vales_barbeiros').doc(id).update({'vale_liquidado': true});
                }

                if (context.mounted) {
                  Navigator.pop(ctx);
                  _gerarReciboDetalhadoPdf(
                    context,
                    comissaoServicos: servicosComissao,
                    comissaoAssinaturas: assinaturasComissao,
                    comissaoProdutos: produtosComissao,
                    totalVales: totalVales,
                    liquidoFinal: liquidoAPagar,
                    itensDetalhados: itensDetalhados,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Repasse de $barbeiroNome liquidado!'), backgroundColor: Colors.green.shade800));
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
    final pctServico = int.tryParse(comissoesConfig['comissao_porcentagem']?.toString() ?? '50') ?? 50;
    final pctProduto = int.tryParse(comissoesConfig['comissao_produtos_pct']?.toString() ?? '10') ?? 10;
    final pctAssinante = int.tryParse(comissoesConfig['comissao_assinante_pct']?.toString() ?? '30') ?? 30;

    return Scaffold(
      appBar: AppBar(title: Text('Auditoria: $barbeiroNome')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('vales_barbeiros')
            .where('barbeiro_id', isEqualTo: barbeiroId).snapshots(),
        builder: (context, valesSnap) {
          final valesDocs = valesSnap.data?.docs ?? [];
          double totalVales = 0.0;
          List<String> valesIds = [];
          for (var v in valesDocs) {
            final data = v.data() as Map<String, dynamic>;
            if (data['vale_liquidado'] != true) {
              totalVales += (data['valor'] as num?)?.toDouble() ?? 0.0;
              valesIds.add(v.id);
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('barbearias').doc(barbeariaId).collection('agendamentos')
                .where('barbeiro_id', isEqualTo: barbeiroId).where('status', isEqualTo: 'concluido').snapshots(),
            builder: (context, agSnap) {
              if (!agSnap.hasData) return const Center(child: CircularProgressIndicator());
              final agDocs = agSnap.data!.docs;

              double servicosBase = 0.0, servicosComissao = 0.0;
              double assinaturasBase = 0.0, assinaturasComissao = 0.0;
              double produtosBase = 0.0, produtosComissao = 0.0;

              List<String> agsIds = [];
              List<Map<String, dynamic>> itensDetalhados = [];

              for (var doc in agDocs) {
                final d = doc.data() as Map<String, dynamic>;
                if (d['repasse_liquidado'] == true) continue;

                agsIds.add(doc.id);
                final precoTotal = (d['preco'] as num?)?.toDouble() ?? 0.0;
                final precoProd = (d['preco_produtos'] as num?)?.toDouble() ?? 0.0;
                final precoServ = (d['preco_servico'] as num?)?.toDouble() ?? (precoTotal - precoProd);
                final tabelaOriginal = (d['preco_tabela_original'] as num?)?.toDouble() ?? precoServ;
                final coberto = d['coberto_por_plano'] == true;
                final dataHora = d['data_hora'] ?? '-';
                final cliente = d['cliente_nome'] ?? 'Cliente';
                final servico = d['servico'] ?? 'Serviço';
                final produtosExtrasList = (d['produtos_extras'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

                if (coberto) {
                  final com = (tabelaOriginal * pctAssinante) / 100;
                  assinaturasBase += tabelaOriginal;
                  assinaturasComissao += com;
                  itensDetalhados.add({
                    'data_hora': dataHora,
                    'cliente': cliente,
                    'servico': '$servico (Assinatura)',
                    'categoria': 'Assinatura',
                    'valor_base': tabelaOriginal,
                    'comissao': com,
                  });
                } else {
                  final com = (precoServ * pctServico) / 100;
                  servicosBase += precoServ;
                  servicosComissao += com;
                  itensDetalhados.add({
                    'data_hora': dataHora,
                    'cliente': cliente,
                    'servico': servico,
                    'categoria': 'Corte Avulso',
                    'valor_base': precoServ,
                    'comissao': com,
                  });
                }

                if (precoProd > 0) {
                  final comProd = (precoProd * pctProduto) / 100;
                  produtosBase += precoProd;
                  produtosComissao += comProd;
                  itensDetalhados.add({
                    'data_hora': dataHora,
                    'cliente': cliente,
                    'servico': 'Produtos: ${produtosExtrasList.join(", ")}',
                    'categoria': 'Produtos',
                    'valor_base': precoProd,
                    'comissao': comProd,
                  });
                }
              }

              final comissaoTotal = servicosComissao + assinaturasComissao + produtosComissao;
              final liquidoFinal = (comissaoTotal - totalVales).clamp(0.0, 999999.0);

              return Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF1E1E1E),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Discriminação Analítica do Repasse', style: TextStyle(color: Color(0xFFE0A96D), fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('✂ Cortes Avulsos: R\$ ${servicosComissao.toStringAsFixed(2)} ($pctServico%)', style: const TextStyle(fontSize: 13)),
                        Text('👑 Assinaturas / Planos: R\$ ${assinaturasComissao.toStringAsFixed(2)} ($pctAssinante%)', style: const TextStyle(fontSize: 13)),
                        Text('📦 Produtos Vendidos: R\$ ${produtosComissao.toStringAsFixed(2)} ($pctProduto%)', style: const TextStyle(fontSize: 13)),
                        if (totalVales > 0)
                          Text('(-) Vales Adiantados: R\$ ${totalVales.toStringAsFixed(2)}', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Líquido a Pagar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('R\$ ${liquidoFinal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C853), foregroundColor: Colors.black),
                          icon: const Icon(Icons.check),
                          label: const Text('Liquidar Repasse & Gerar Recibo PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: (comissaoTotal > 0 || totalVales > 0)
                              ? () => _abrirModalLiquidar(
                                    context,
                                    comissoesBrutas: comissaoTotal,
                                    totalVales: totalVales,
                                    agsIds: agsIds,
                                    valesIds: valesIds,
                                    servicosComissao: servicosComissao,
                                    assinaturasComissao: assinaturasComissao,
                                    produtosComissao: produtosComissao,
                                    totalServicosBase: servicosBase,
                                    totalAssinaturasBase: assinaturasBase,
                                    totalProdutosBase: produtosBase,
                                    itensDetalhados: itensDetalhados,
                                  )
                              : null,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: itensDetalhados.isEmpty
                        ? const Center(child: Text('Nenhum atendimento pendente para este barbeiro.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: itensDetalhados.length,
                            itemBuilder: (ctx, i) {
                              final item = itensDetalhados[i];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text('${item['cliente']} • ${item['servico']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${item['data_hora']} • Categoria: ${item['categoria']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  trailing: Text('Comissão: R\$ ${item['comissao'].toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.bold)),
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

// ---------------- SUBTELA 2: HISTÓRICO DE RECIBOS PAGOS COM OPÇÃO DE ESTORNO ----------------
// ---------------- SUBTELA 2: HISTÓRICO DE RECIBOS PAGOS COM OPÇÃO DE ESTORNO ----------------
class HistoricoRecibosScreen extends StatefulWidget {
  final String barbeariaId;
  const HistoricoRecibosScreen({super.key, required this.barbeariaId});

  @override
  State<HistoricoRecibosScreen> createState() => _HistoricoRecibosScreenState();
}

class _HistoricoRecibosScreenState extends State<HistoricoRecibosScreen> {
  String _filtroData = 'mes';
  DateTimeRange? _intervaloCustom;

  Future<void> _selecionarPeriodoCustom() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'), // Garante o calendário em Português
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
        _filtroData = 'custom';
      });
    }
  }

  Future<void> _estornarRepasse(BuildContext context, String repasseId, Map<String, dynamic> rData) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estornar Repasse?'),
        content: const Text('Isso vai reabrir os atendimentos e vales deste acerto, retornando-os para a aba "A Pagar", e apagar este registro de pagamento.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sim, Estornar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      final agsIds = (rData['ags_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      final valesIds = (rData['vales_ids'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      for (var id in agsIds) {
        await FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('agendamentos').doc(id).update({'repasse_liquidado': false});
      }
      for (var id in valesIds) {
        await FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('vales_barbeiros').doc(id).update({'vale_liquidado': false});
      }
      await FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('repasses_barbeiros').doc(repasseId).delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repasse estornado com sucesso! Os valores voltaram para pendentes.')));
      }
    }
  }

  bool _verificarData(Map<String, dynamic> data) {
    if (_filtroData == 'todos') return true;
    final hoje = DateTime.now();
    final dataIso = data['data_iso']?.toString() ?? '';
    final dStr = data['data_formatada']?.toString() ?? '';

    if (_filtroData == 'hoje') {
      final hojeStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(hoje);
      return dStr.contains(hojeStr);
    }

    DateTime? dReal;
    if (dataIso.isNotEmpty) {
      try { dReal = DateTime.parse(dataIso); } catch (_) {}
    }

    if (dReal != null) {
      if (_filtroData == '7dias') {
        return dReal.isAfter(hoje.subtract(const Duration(days: 7))) && dReal.isBefore(hoje.add(const Duration(days: 1)));
      }
      if (_filtroData == 'mes') {
        return dReal.month == hoje.month && dReal.year == hoje.year;
      }
      if (_filtroData == 'custom' && _intervaloCustom != null) {
        return dReal.isAfter(_intervaloCustom!.start.subtract(const Duration(days: 1))) &&
               dReal.isBefore(_intervaloCustom!.end.add(const Duration(days: 1)));
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de Recibos Pagos')),
      body: Column(
        children: [
          _buildFiltroDataUI(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('repasses_barbeiros').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final listFiltrada = snapshot.data!.docs.where((doc) {
                  return _verificarData(doc.data() as Map<String, dynamic>);
                }).toList();

                if (listFiltrada.isEmpty) return const Center(child: Text('Nenhum recibo neste período.', style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: listFiltrada.length,
                  itemBuilder: (ctx, i) {
                    final rDoc = listFiltrada[i];
                    final d = rDoc.data() as Map<String, dynamic>;
                    final nome = d['barbeiro_nome'] ?? 'Barbeiro';
                    final total = (d['valor_total_repasse'] as num?)?.toDouble() ?? 0.0;
                    final dataFmt = d['data_formatada'] ?? '-';
                    final analiticos = (d['itens_analiticos'] as List<dynamic>?) ?? [];

                    return Card(
                      child: ExpansionTile(
                        title: Text('$nome • R\$ ${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Pago em $dataFmt', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.undo, color: Colors.redAccent),
                              tooltip: 'Estornar Repasse (Voltar para A Pagar)',
                              onPressed: () => _estornarRepasse(context, rDoc.id, d),
                            ),
                          ],
                        ),
                        children: [
                          ...analiticos.map((item) {
                            return ListTile(
                              dense: true,
                              title: Text('${item['cliente']} (${item['servico']})'),
                              subtitle: Text('${item['data_hora']} • ${item['categoria']}'),
                              trailing: Text('R\$ ${item['comissao'].toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00C853))),
                            );
                          }),
                        ],
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

  Widget _buildFiltroDataUI() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(label: const Text('Hoje'), selected: _filtroData == 'hoje', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'hoje')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('7 Dias'), selected: _filtroData == '7dias', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = '7dias')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Este Mês'), selected: _filtroData == 'mes', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'mes')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Tudo'), selected: _filtroData == 'todos', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'todos')),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16, color: Color(0xFFE0A96D)),
            label: Text(_filtroData == 'custom' && _intervaloCustom != null
                ? '${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.start)} - ${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.end)}'
                : 'Calendário'),
            backgroundColor: _filtroData == 'custom' ? const Color(0xFFE0A96D).withOpacity(0.2) : const Color(0xFF2C2C2C),
            side: BorderSide(color: _filtroData == 'custom' ? const Color(0xFFE0A96D) : Colors.transparent),
            onPressed: _selecionarPeriodoCustom,
          ),
        ],
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
  String _filtroData = 'hoje';
  DateTimeRange? _intervaloCustom;

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
        _filtroData = 'custom';
      });
    }
  }

  bool _verificarData(String? dIso, String? dStr) {
    if (_filtroData == 'todos') return true;
    final hoje = DateTime.now();

    if (_filtroData == 'hoje') {
      final hojeStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(hoje);
      return (dStr ?? '').contains(hojeStr) || (dStr ?? '').toLowerCase().contains('hoje');
    }

    DateTime? dReal;
    if (dIso != null && dIso.isNotEmpty) {
      try { dReal = DateTime.parse(dIso); } catch (_) {}
    }

    if (dReal != null) {
      if (_filtroData == '7dias') {
        return dReal.isAfter(hoje.subtract(const Duration(days: 7))) && dReal.isBefore(hoje.add(const Duration(days: 1)));
      }
      if (_filtroData == 'mes') {
        return dReal.month == hoje.month && dReal.year == hoje.year;
      }
      if (_filtroData == 'custom' && _intervaloCustom != null) {
        return dReal.isAfter(_intervaloCustom!.start.subtract(const Duration(days: 1))) &&
               dReal.isBefore(_intervaloCustom!.end.add(const Duration(days: 1)));
      }
    }
    return true;
  }

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
                            if (d['status'] == 'concluido' && _verificarData(d['data_iso']?.toString(), d['data_hora']?.toString())) {
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
                            if (_verificarData(d['data_iso']?.toString(), d['data_formatada']?.toString())) {
                              listaTransacoes.add({
                                'tipo': 'entrada_mensalidade',
                                'titulo': '👑 Mensalidade: ${d['cliente_nome'] ?? "Cliente"}',
                                'subtitulo': 'Plano: ${d['plano_nome'] ?? "-"} • ${d['data_formatada'] ?? "-"}',
                                'valor': (d['valor'] as num?)?.toDouble() ?? 0.0,
                                'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                              });
                            }
                          }

                          for (var doc in despesas) {
                            final d = doc.data() as Map<String, dynamic>;
                            if (d['pago'] == true && _verificarData(d['data_iso']?.toString(), d['data_formatada']?.toString())) {
                              listaTransacoes.add({
                                'tipo': 'saida_despesa',
                                'titulo': '🔴 Despesa (Paga): ${d['descricao'] ?? "Despesa"}',
                                'subtitulo': 'Categoria: ${d['categoria'] ?? "-"} • ${d['data_formatada'] ?? "-"}',
                                'valor': (d['valor'] as num?)?.toDouble() ?? 0.0,
                                'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                              });
                            }
                          }

                          for (var doc in vales) {
                            final d = doc.data() as Map<String, dynamic>;
                            if (_verificarData(d['data_iso']?.toString(), d['data_formatada']?.toString())) {
                              listaTransacoes.add({
                                'tipo': 'saida_vale',
                                'titulo': '🟠 Vale/Adiantamento: ${d['barbeiro_nome'] ?? "Barbeiro"}',
                                'subtitulo': 'Motivo: ${d['motivo'] ?? "Adiantamento"} • ${d['data_formatada'] ?? "-"}',
                                'valor': (d['valor'] as num?)?.toDouble() ?? 0.0,
                                'forma': 'DINHEIRO',
                              });
                            }
                          }

                          for (var doc in repasses) {
                            final d = doc.data() as Map<String, dynamic>;
                            if (_verificarData(d['data_iso']?.toString(), d['data_formatada']?.toString())) {
                              listaTransacoes.add({
                                'tipo': 'saida_repasse',
                                'titulo': '💰 Repasse Liquidado: ${d['barbeiro_nome'] ?? "Barbeiro"}',
                                'subtitulo': 'Acerto efetuado em ${d['data_formatada'] ?? "-"}',
                                'valor': (d['valor_total_repasse'] as num?)?.toDouble() ?? 0.0,
                                'forma': (d['forma_pagamento'] ?? 'pix').toString().toUpperCase(),
                              });
                            }
                          }

                          final transacoesFiltradas = listaTransacoes.where((t) {
                            if (_filtroTipo == 'todos') return true;
                            if (_filtroTipo == 'entradas') return t['tipo'].toString().startsWith('entrada');
                            if (_filtroTipo == 'saidas') return t['tipo'].toString().startsWith('saida');
                            return true;
                          }).toList();

                          return Column(
                            children: [
                              _buildFiltroDataUI(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                color: const Color(0xFF1A1A1A),
                                child: DropdownButtonFormField<String>(
                                  value: _filtroTipo,
                                  isDense: true,
                                  decoration: const InputDecoration(labelText: 'Tipo de Movimentação', border: OutlineInputBorder()),
                                  items: const [
                                    DropdownMenuItem(value: 'todos', child: Text('Todas as Movimentações')),
                                    DropdownMenuItem(value: 'entradas', child: Text('🟢 Apenas Entradas (Atendimentos & Planos)')),
                                    DropdownMenuItem(value: 'saidas', child: Text('🔴 Apenas Saídas Efectivas (Despesas, Vales & Repasses)')),
                                  ],
                                  onChanged: (val) => setState(() => _filtroTipo = val ?? 'todos'),
                                ),
                              ),
                              Expanded(
                                child: transacoesFiltradas.isEmpty
                                    ? const Center(child: Text('Nenhuma movimentação registrada no período.', style: TextStyle(color: Colors.grey)))
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

  Widget _buildFiltroDataUI() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(label: const Text('Hoje'), selected: _filtroData == 'hoje', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'hoje')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('7 Dias'), selected: _filtroData == '7dias', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = '7dias')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Este Mês'), selected: _filtroData == 'mes', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'mes')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Tudo'), selected: _filtroData == 'todos', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'todos')),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16, color: Color(0xFFE0A96D)),
            label: Text(_filtroData == 'custom' && _intervaloCustom != null
                ? '${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.start)} - ${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.end)}'
                : 'Calendário'),
            backgroundColor: _filtroData == 'custom' ? const Color(0xFFE0A96D).withOpacity(0.2) : const Color(0xFF2C2C2C),
            side: BorderSide(color: _filtroData == 'custom' ? const Color(0xFFE0A96D) : Colors.transparent),
            onPressed: _selecionarPeriodoCustom,
          ),
        ],
      ),
    );
  }
}

// ---------------- SUBTELA 4: DESPESAS OPERACIONAIS COM BOTÃO DE QUITAÇÃO ----------------
class DespesasScreen extends StatefulWidget {
  final String barbeariaId;
  const DespesasScreen({super.key, required this.barbeariaId});

  @override
  State<DespesasScreen> createState() => _DespesasScreenState();
}

class _DespesasScreenState extends State<DespesasScreen> {
  String _filtroCategoria = 'todas';
  String _filtroData = 'mes';
  DateTimeRange? _intervaloCustom;

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
        _filtroData = 'custom';
      });
    }
  }

  bool _verificarData(Map<String, dynamic> data) {
    if (_filtroData == 'todos') return true;
    final hoje = DateTime.now();
    final dataIso = data['data_iso']?.toString() ?? '';
    final dStr = data['data_formatada']?.toString() ?? '';

    if (_filtroData == 'hoje') {
      final hojeStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(hoje);
      return dStr.contains(hojeStr);
    }

    DateTime? dReal;
    if (dataIso.isNotEmpty) {
      try { dReal = DateTime.parse(dataIso); } catch (_) {}
    }

    if (dReal != null) {
      if (_filtroData == '7dias') {
        return dReal.isAfter(hoje.subtract(const Duration(days: 7))) && dReal.isBefore(hoje.add(const Duration(days: 1)));
      }
      if (_filtroData == 'mes') {
        return dReal.month == hoje.month && dReal.year == hoje.year;
      }
      if (_filtroData == 'custom' && _intervaloCustom != null) {
        return dReal.isAfter(_intervaloCustom!.start.subtract(const Duration(days: 1))) &&
               dReal.isBefore(_intervaloCustom!.end.add(const Duration(days: 1)));
      }
    }
    return true;
  }

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
            if (_filtroCategoria != 'todas' && (d['categoria'] ?? '') != _filtroCategoria) return false;
            return _verificarData(d);
          }).toList();

          return Column(
            children: [
              _buildFiltroDataUI(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    ? const Center(child: Text('Nenhuma despesa lançada neste período.', style: TextStyle(color: Colors.grey)))
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
                          final pago = d['pago'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.arrow_downward, color: pago ? Colors.grey : Colors.redAccent),
                              title: Text(desc, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$cat • $dataFmt\nStatus: ${pago ? "Paga / Liquidada" : "Em Aberto"}', style: TextStyle(fontSize: 12, color: pago ? Colors.greenAccent : Colors.orangeAccent)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('R\$ ${v.toStringAsFixed(2)}', style: TextStyle(color: pago ? Colors.grey : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: pago ? Colors.grey.shade800 : const Color(0xFF00C853),
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                    onPressed: () {
                                      FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('despesas').doc(dId).update({'pago': !pago});
                                    },
                                    child: Text(pago ? 'Reabrir' : 'Quitar', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () => FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('despesas').doc(dId).delete(),
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

  Widget _buildFiltroDataUI() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(label: const Text('Hoje'), selected: _filtroData == 'hoje', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'hoje')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('7 Dias'), selected: _filtroData == '7dias', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = '7dias')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Este Mês'), selected: _filtroData == 'mes', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'mes')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Tudo'), selected: _filtroData == 'todos', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'todos')),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16, color: Color(0xFFE0A96D)),
            label: Text(_filtroData == 'custom' && _intervaloCustom != null
                ? '${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.start)} - ${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.end)}'
                : 'Calendário'),
            backgroundColor: _filtroData == 'custom' ? const Color(0xFFE0A96D).withOpacity(0.2) : const Color(0xFF2C2C2C),
            side: BorderSide(color: _filtroData == 'custom' ? const Color(0xFFE0A96D) : Colors.transparent),
            onPressed: _selecionarPeriodoCustom,
          ),
        ],
      ),
    );
  }
}

// ---------------- SUBTELA 5: MENSALIDADES DE PLANOS RECEBIDAS ----------------
class MensalidadesRecebidasScreen extends StatefulWidget {
  final String barbeariaId;
  const MensalidadesRecebidasScreen({super.key, required this.barbeariaId});

  @override
  State<MensalidadesRecebidasScreen> createState() => _MensalidadesRecebidasScreenState();
}

class _MensalidadesRecebidasScreenState extends State<MensalidadesRecebidasScreen> {
  String _filtroData = 'mes';
  DateTimeRange? _intervaloCustom;

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
        _filtroData = 'custom';
      });
    }
  }

  bool _verificarData(Map<String, dynamic> data) {
    if (_filtroData == 'todos') return true;
    final hoje = DateTime.now();
    final dataIso = data['data_iso']?.toString() ?? '';
    final dStr = data['data_formatada']?.toString() ?? '';

    if (_filtroData == 'hoje') {
      final hojeStr = DateFormat('dd/MM/yyyy', 'pt_BR').format(hoje);
      return dStr.contains(hojeStr);
    }

    DateTime? dReal;
    if (dataIso.isNotEmpty) {
      try { dReal = DateTime.parse(dataIso); } catch (_) {}
    }

    if (dReal != null) {
      if (_filtroData == '7dias') {
        return dReal.isAfter(hoje.subtract(const Duration(days: 7))) && dReal.isBefore(hoje.add(const Duration(days: 1)));
      }
      if (_filtroData == 'mes') {
        return dReal.month == hoje.month && dReal.year == hoje.year;
      }
      if (_filtroData == 'custom' && _intervaloCustom != null) {
        return dReal.isAfter(_intervaloCustom!.start.subtract(const Duration(days: 1))) &&
               dReal.isBefore(_intervaloCustom!.end.add(const Duration(days: 1)));
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensalidades Recebidas')),
      body: Column(
        children: [
          _buildFiltroDataUI(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('mensalidades').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final mensalidades = snapshot.data?.docs ?? [];
                
                final listFiltrada = mensalidades.where((doc) {
                  return _verificarData(doc.data() as Map<String, dynamic>);
                }).toList();

                if (listFiltrada.isEmpty) {
                  return const Center(child: Text('Nenhuma mensalidade neste período.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: listFiltrada.length,
                  itemBuilder: (ctx, i) {
                    final mDoc = listFiltrada[i];
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
                              onPressed: () => FirebaseFirestore.instance.collection('barbearias').doc(widget.barbeariaId).collection('mensalidades').doc(mId).delete(),
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

  Widget _buildFiltroDataUI() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(label: const Text('Hoje'), selected: _filtroData == 'hoje', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'hoje')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('7 Dias'), selected: _filtroData == '7dias', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = '7dias')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Este Mês'), selected: _filtroData == 'mes', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'mes')),
          const SizedBox(width: 6),
          ChoiceChip(label: const Text('Tudo'), selected: _filtroData == 'todos', selectedColor: const Color(0xFFE0A96D), onSelected: (s) => setState(() => _filtroData = 'todos')),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16, color: Color(0xFFE0A96D)),
            label: Text(_filtroData == 'custom' && _intervaloCustom != null
                ? '${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.start)} - ${DateFormat('dd/MM', 'pt_BR').format(_intervaloCustom!.end)}'
                : 'Calendário'),
            backgroundColor: _filtroData == 'custom' ? const Color(0xFFE0A96D).withOpacity(0.2) : const Color(0xFF2C2C2C),
            side: BorderSide(color: _filtroData == 'custom' ? const Color(0xFFE0A96D) : Colors.transparent),
            onPressed: _selecionarPeriodoCustom,
          ),
        ],
      ),
    );
  }
}
