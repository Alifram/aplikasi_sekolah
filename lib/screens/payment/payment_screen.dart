import 'package:flutter/material.dart';
import 'package:aplikasi_sekolah/core/constants/app_colors.dart';
import 'package:aplikasi_sekolah/core/services/payment_service.dart';

class PaymentScreen extends StatefulWidget {
  final String role;

  const PaymentScreen({super.key, required this.role});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _categories = [];
  Map<String, dynamic>? _report;
  String? _loadError;
  int? _selectedStudentId;
  String? _selectedCategoryCode;
  DateTime _paidAt = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isLoading = true;
  bool _isSaving = false;
  int _reportRequestId = 0;

  bool get _isParent => widget.role == 'orang_tua';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _readRows(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final results = await Future.wait([
      _isParent
          ? PaymentService.getMyLinkedStudents()
          : PaymentService.getPaymentStudents(),
      if (!_isParent) PaymentService.getMyCategories(),
    ]);

    if (!mounted) return;
    final studentResponse = results.first;
    if (studentResponse['status'] != 'success') {
      setState(() {
        _isLoading = false;
        _loadError =
            studentResponse['message']?.toString() ??
            'Data siswa belum dapat dimuat.';
      });
      return;
    }

    final students = _readRows(studentResponse['data']);
    var categories = <Map<String, dynamic>>[];
    if (!_isParent) {
      final categoryResponse = results[1];
      if (categoryResponse['status'] != 'success') {
        setState(() {
          _isLoading = false;
          _loadError =
              categoryResponse['message']?.toString() ??
              'Kategori pembayaran belum dapat dimuat.';
        });
        return;
      }
      categories = _readRows(categoryResponse['data']);
    }

    setState(() {
      _students = students;
      _categories = categories;
      _selectedStudentId ??= students.isEmpty
          ? null
          : int.tryParse(students.first['id'].toString());
      if (_selectedStudentId != null &&
          !students.any(
            (student) =>
                int.tryParse(student['id'].toString()) == _selectedStudentId,
          )) {
        _selectedStudentId = students.isEmpty
            ? null
            : int.tryParse(students.first['id'].toString());
      }
      _selectedCategoryCode ??= categories.isEmpty
          ? null
          : categories.first['code']?.toString();
      if (_selectedCategoryCode != null &&
          !categories.any(
            (category) => category['code']?.toString() == _selectedCategoryCode,
          )) {
        _selectedCategoryCode = categories.isEmpty
            ? null
            : categories.first['code']?.toString();
      }
      _isLoading = false;
    });

    if (_selectedStudentId != null) await _loadReport();
  }

  Future<void> _loadReport() async {
    final requestId = ++_reportRequestId;
    final studentId = _selectedStudentId;
    if (studentId == null) {
      setState(() => _report = null);
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final response = await PaymentService.getMonthlyReport(
      year: _selectedYear,
      month: _selectedMonth,
      studentUserId: studentId,
    );
    if (!mounted || requestId != _reportRequestId) return;

    if (response['status'] != 'success') {
      setState(() {
        _isLoading = false;
        _report = null;
        _loadError =
            response['message']?.toString() ?? 'Laporan belum dapat dimuat.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _report = response;
    });
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    final studentId = _selectedStudentId;
    final categoryCode = _selectedCategoryCode;
    final amount = num.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (studentId == null || categoryCode == null || amount == null) return;

    setState(() => _isSaving = true);
    final response = await PaymentService.recordTransaction(
      studentUserId: studentId,
      categoryCode: categoryCode,
      amount: amount,
      paidAt: _paidAt,
      note: _noteController.text.trim(),
    );
    if (!mounted) return;

    setState(() => _isSaving = false);
    if (response['status'] != 'success') {
      _showMessage(
        response['message']?.toString() ?? 'Transaksi belum berhasil disimpan.',
        isError: true,
      );
      return;
    }

    _amountController.clear();
    _noteController.clear();
    setState(() {
      _selectedMonth = _paidAt.month;
      _selectedYear = _paidAt.year;
    });
    await _loadReport();
    if (mounted) {
      _showMessage(response['message']?.toString() ?? 'Transaksi tersimpan.');
    }
  }

  Future<void> _choosePaymentDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) setState(() => _paidAt = date);
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primary,
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-${date.year}';

  String _formatAmount(dynamic value) {
    final amount = value is num ? value : num.tryParse(value.toString()) ?? 0;
    final whole = amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2);
    final parts = whole.split('.');
    final digits = parts.first;
    final grouped = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) {
        grouped.write('.');
      }
      grouped.write(digits[index]);
    }
    return 'Rp ${grouped.toString()}'
        '${parts.length > 1 ? ',${parts[1]}' : ''}';
  }

  Widget _buildMonthSelector(Color textColor) {
    final thisYear = DateTime.now().year;
    final years = List.generate(7, (index) => thisYear - index);
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _selectedMonth,
            decoration: const InputDecoration(
              labelText: 'Bulan laporan',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: List.generate(
              _months.length,
              (index) => DropdownMenuItem(
                value: index + 1,
                child: Text(_months[index]),
              ),
            ),
            onChanged: (month) {
              if (month == null) return;
              setState(() => _selectedMonth = month);
              _loadReport();
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: DropdownButtonFormField<int>(
            initialValue: years.contains(_selectedYear)
                ? _selectedYear
                : thisYear,
            decoration: const InputDecoration(
              labelText: 'Tahun',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: years
                .map(
                  (year) => DropdownMenuItem(value: year, child: Text('$year')),
                )
                .toList(),
            onChanged: (year) {
              if (year == null) return;
              setState(() => _selectedYear = year);
              _loadReport();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTotals(Color surfaceColor, Color textColor) {
    final totals = _readRows(_report?['totals']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: surfaceColor,
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.summarize_rounded, color: Colors.white),
            ),
            title: Text('Total bulan ini', style: TextStyle(color: textColor)),
            trailing: Text(
              _formatAmount(_report?['total_amount'] ?? 0),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        if (totals.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Rincian per jenis',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...totals.map(
            (total) => ListTile(
              dense: true,
              title: Text(
                total['category_name']?.toString() ?? '-',
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                '${total['transaction_count'] ?? 0} transaksi',
                style: TextStyle(color: textColor.withValues(alpha: 0.65)),
              ),
              trailing: Text(
                _formatAmount(total['amount']),
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTransactions(Color surfaceColor, Color textColor) {
    final transactions = _readRows(_report?['transactions']);
    if (transactions.isEmpty) {
      return Card(
        color: surfaceColor,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Belum ada transaksi pada bulan ini.',
            style: TextStyle(color: textColor),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Riwayat transaksi',
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        ...transactions.map(
          (transaction) => Card(
            color: surfaceColor,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE7F4EE),
                child: Icon(Icons.receipt_long, color: AppColors.primary),
              ),
              title: Text(
                transaction['category_name']?.toString() ?? 'Pembayaran',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                [
                  _dateLabel(
                    DateTime.tryParse(
                          transaction['paid_at']?.toString() ?? '',
                        ) ??
                        DateTime.now(),
                  ),
                  if (!_isParent) transaction['student_name']?.toString() ?? '',
                  if ((transaction['note']?.toString() ?? '').isNotEmpty)
                    transaction['note'].toString(),
                ].where((part) => part.isNotEmpty).join(' • '),
                style: TextStyle(color: textColor.withValues(alpha: 0.7)),
              ),
              trailing: Text(
                _formatAmount(transaction['amount']),
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1C2D35) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (_isLoading && _students.isEmpty && _loadError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null && _students.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadInitialData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _isParent ? 'Riwayat Infaq & Wakaf' : 'Pencatatan Pembayaran',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isParent
                ? 'Lihat transaksi infaq dan wakaf anak per bulan.'
                : 'Catat transaksi yang sudah diterima dan lihat laporan bulanan.',
            style: TextStyle(color: textColor.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 16),
          if (_students.isEmpty)
            Card(
              color: surfaceColor,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  _isParent
                      ? 'Belum ada siswa yang ditautkan ke akun ini. Hubungi admin sekolah.'
                      : 'Belum ada siswa aktif untuk dicatat.',
                  style: TextStyle(color: textColor),
                ),
              ),
            ),
          if (_students.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              initialValue: _selectedStudentId,
              decoration: InputDecoration(
                labelText: _isParent ? 'Pilih anak' : 'Pilih siswa',
                border: const OutlineInputBorder(),
              ),
              items: _students
                  .map(
                    (student) => DropdownMenuItem(
                      value: int.tryParse(student['id'].toString()),
                      child: Text(
                        [
                          student['nama_lengkap']?.toString() ?? 'Siswa',
                          if ((student['kelas_nama']?.toString() ?? '')
                              .isNotEmpty)
                            student['kelas_nama'].toString(),
                        ].join(' — '),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (studentId) {
                setState(() => _selectedStudentId = studentId);
                _loadReport();
              },
            ),
            const SizedBox(height: 12),
            _buildMonthSelector(textColor),
            if (!_isParent) ...[
              const SizedBox(height: 18),
              Card(
                color: surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catat transaksi diterima',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryCode,
                          decoration: const InputDecoration(
                            labelText: 'Jenis pembayaran',
                            border: OutlineInputBorder(),
                          ),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category['code']?.toString(),
                                  child: Text(
                                    category['name']?.toString() ?? '-',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (code) =>
                              setState(() => _selectedCategoryCode = code),
                          validator: (code) =>
                              code == null ? 'Pilih jenis pembayaran' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Nominal diterima',
                            prefixText: 'Rp ',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final amount = num.tryParse(
                              (value ?? '').trim().replaceAll(',', '.'),
                            );
                            return amount == null ||
                                    !amount.isFinite ||
                                    amount <= 0 ||
                                    amount > 999999999999.99
                                ? 'Nominal harus lebih dari 0 dan maksimal Rp 999.999.999.999,99'
                                : null;
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _choosePaymentDate,
                          icon: const Icon(Icons.calendar_month),
                          label: Text(
                            'Tanggal diterima: ${_dateLabel(_paidAt)}',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          maxLength: 500,
                          decoration: const InputDecoration(
                            labelText: 'Catatan (opsional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                _isSaving ||
                                    _selectedCategoryCode == null ||
                                    _selectedStudentId == null
                                ? null
                                : _saveTransaction,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSaving ? 'Menyimpan...' : 'Simpan transaksi',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (_loadError != null)
              Card(
                color: surfaceColor,
                child: ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: Text(_loadError!, style: TextStyle(color: textColor)),
                  trailing: IconButton(
                    onPressed: _loadReport,
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              )
            else if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_report != null) ...[
              _buildTotals(surfaceColor, textColor),
              const SizedBox(height: 12),
              _buildTransactions(surfaceColor, textColor),
            ],
          ],
        ],
      ),
    );
  }
}
