import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/support_service.dart';

class ManagerHelpSupportTab extends StatefulWidget {
  final String locationName;
  final String email;

  const ManagerHelpSupportTab({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  State<ManagerHelpSupportTab> createState() => _ManagerHelpSupportTabState();
}

class _ManagerHelpSupportTabState extends State<ManagerHelpSupportTab> {
  static const Color primary = Color(0xFFF97316);
  static const Color dark    = Color(0xFF1C1C1E);

  final _formKey = GlobalKey<FormState>();

  final _phoneCtrl    = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _daysCtrl     = TextEditingController();
  final _respCtrl     = TextEditingController();

  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  bool _isLoading = true;
  bool _isSaving  = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _daysCtrl.dispose();
    _respCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    final info = await SupportService.fetch(widget.locationName);
    if (!mounted) return;

    if (info == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load support info for ${widget.locationName}';
      });
      return;
    }

    setState(() {
      _phoneCtrl.text    = info.phone;
      _whatsappCtrl.text = info.whatsapp;
      _emailCtrl.text    = info.email;
      _addressCtrl.text  = info.address;
      _daysCtrl.text     = info.openingDays;
      _respCtrl.text     = info.averageResponse;
      _openTime  = _parseTime(info.openingTime);
      _closeTime = _parseTime(info.closingTime);
      _isLoading = false;
    });
  }

  TimeOfDay? _parseTime(String hms) {
    if (hms.isEmpty) return null;
    try {
      final p = hms.split(':');
      return TimeOfDay(
        hour: int.parse(p[0]),
        minute: p.length > 1 ? int.parse(p[1]) : 0,
      );
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}:00';
  }

  Future<void> _pickTime({required bool isOpen}) async {
    final initial = isOpen
        ? (_openTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (_closeTime ?? const TimeOfDay(hour: 22, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isOpen) {
        _openTime = picked;
      } else {
        _closeTime = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_openTime == null || _closeTime == null) {
      _snack('Please set opening and closing time', error: true);
      return;
    }

    setState(() => _isSaving = true);

    final err = await SupportService.update(
      locationName:    widget.locationName,
      email:           widget.email,
      supportPhone:    _phoneCtrl.text.trim(),
      supportWhatsapp: _whatsappCtrl.text.trim(),
      supportEmail:    _emailCtrl.text.trim(),
      supportAddress:  _addressCtrl.text.trim(),
      openingTime:     _formatTime(_openTime),
      closingTime:     _formatTime(_closeTime),
      openingDays:     _daysCtrl.text.trim(),
      averageResponse: _respCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (err == null) {
      _snack('Support info updated successfully');
    } else {
      _snack(err, error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.poppins(fontSize: 13))),
          ],
        ),
        backgroundColor: error ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primary),
      );
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: primary),
              const SizedBox(height: 12),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _load,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildBranchBanner(),
          const SizedBox(height: 16),
          _buildSection('Contact Details'),
          _buildField(
            controller: _phoneCtrl,
            label: 'Support Phone',
            hint: '+1 978-328-8409',
            icon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
          ),
          _buildField(
            controller: _whatsappCtrl,
            label: 'WhatsApp Number (digits only)',
            hint: '19783288409',
            icon: Icons.chat_bubble_rounded,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              if (v.trim().length < 8) return 'Enter a valid number';
              return null;
            },
          ),
          _buildField(
            controller: _emailCtrl,
            label: 'Support Email',
            hint: 'support@tiffinwales.com',
            icon: Icons.email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v.trim());
              return ok ? null : 'Enter a valid email';
            },
          ),
          _buildField(
            controller: _addressCtrl,
            label: 'Address',
            hint: '1001 Massachusetts Ave, Cambridge, MA',
            icon: Icons.location_on_rounded,
            maxLines: 2,
          ),

          const SizedBox(height: 20),
          _buildSection('Timings'),
          _buildField(
            controller: _daysCtrl,
            label: 'Opening Days',
            hint: 'Mon-Sun',
            icon: Icons.calendar_today_rounded,
          ),
          Row(
            children: [
              Expanded(child: _buildTimeField(
                label: 'Opens at',
                value: _openTime,
                onTap: () => _pickTime(isOpen: true),
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildTimeField(
                label: 'Closes at',
                value: _closeTime,
                onTap: () => _pickTime(isOpen: false),
              )),
            ],
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _respCtrl,
            label: 'Average Response Time',
            hint: 'under 5 minutes',
            icon: Icons.timer_rounded,
          ),

          const SizedBox(height: 24),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: _isSaving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _isSaving ? 'Saving...' : 'Save Changes',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing for your branch',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.locationName,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: dark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: dark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    final display = value == null
        ? 'Select'
        : value.format(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.access_time_rounded, color: primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
        child: Text(
          display,
          style: GoogleFonts.poppins(fontSize: 14, color: dark),
        ),
      ),
    );
  }
}