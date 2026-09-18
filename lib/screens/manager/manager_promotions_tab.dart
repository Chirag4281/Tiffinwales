import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManagerPromotionsTab extends StatefulWidget {
  final String locationName;
  final String email;

  const ManagerPromotionsTab({
    super.key,
    required this.locationName,
    required this.email,
  });

  @override
  State<ManagerPromotionsTab> createState() => _ManagerPromotionsTabState();
}

class _ManagerPromotionsTabState extends State<ManagerPromotionsTab> {
  // Promotion list state
  List<Map<String, dynamic>> _promotions = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  // Promotion form state
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _ctaTextController = TextEditingController(text: 'Order Now');

  File? _selectedImage;
  String? _imageBase64;
  String _targetAudience = 'all_users'; // Default: All Users
  final ImagePicker _picker = ImagePicker();

  // API URL - Only using send_notification.php
  final String _notificationApiUrl = 'https://quantorra.co/tiffinwales/send_notification.php';

  @override
  void initState() {
    super.initState();
    _loadPromotions();
  }

  // ==============================================
  // LOAD PROMOTIONS (Using send_notification.php)
  // ==============================================
  Future<void> _loadPromotions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_notificationApiUrl));
      request.fields['action'] = 'get_promotions';
      request.fields['location_name'] = widget.locationName;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      if (data['status'] == 'success') {
        setState(() {
          _promotions = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to load promotions';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // ==============================================
  // PICK IMAGE
  // ==============================================
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 400,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        setState(() {
          _selectedImage = File(image.path);
          _imageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==============================================
  // CREATE PROMOTION
  // ==============================================
  Future<void> _createPromotion() async {
    // Reset form
    _titleController.clear();
    _bodyController.clear();
    _ctaTextController.text = 'Order Now';
    _selectedImage = null;
    _imageBase64 = null;
    _targetAudience = 'all_users'; // Default: All Users

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: Color(0xFFF97316),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Create Promotion',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Target Audience Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _targetAudience,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            labelText: 'Target Audience',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all_users',
                              child: Row(
                                children: [
                                  Icon(Icons.public_rounded, size: 16, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('All Users'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'specific_location',
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_rounded, size: 16, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('This Location Only'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'managers_only',
                              child: Row(
                                children: [
                                  Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFFF97316)),
                                  SizedBox(width: 8),
                                  Text('Managers Only'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setStateDialog(() {
                                _targetAudience = value;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Promotion Image Preview
                      GestureDetector(
                        onTap: () async {
                          await _pickImage();
                          setStateDialog(() {});
                        },
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                              : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_rounded,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add promo image',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'JPG/PNG • Max 800x400px',
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title Field
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Promotion Title *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.title_rounded),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Body Field
                      TextFormField(
                        controller: _bodyController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: 'Message Body *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.message_rounded),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Message is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // CTA Text Field
                      TextFormField(
                        controller: _ctaTextController,
                        decoration: InputDecoration(
                          labelText: 'Button Text',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.touch_app_rounded),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Info Box
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Promotion will be sent as a notification to selected audience',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    if (_imageBase64 == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a promotional image'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    await _sendPromotion();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Send Promotion'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==============================================
  // SEND PROMOTION - ONLY USING send_notification.php
  // ==============================================
  Future<void> _sendPromotion() async {
    setState(() {
      _isSending = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(_notificationApiUrl));
      request.fields['action'] = 'send_promo_notification';
      request.fields['title'] = _titleController.text.trim();
      request.fields['body'] = _bodyController.text.trim();
      request.fields['cta_text'] = _ctaTextController.text.trim();
      request.fields['target_audience'] = _targetAudience;
      request.fields['sender_email'] = widget.email;
      request.fields['location_name'] = widget.locationName;
      request.fields['image_base64'] = _imageBase64!;

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();
      var data = json.decode(responseBody);

      setState(() {
        _isSending = false;
      });

      if (data['status'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data['message'] ?? 'Promotion sent successfully!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          _resetForm();
          _loadPromotions();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to send promotion'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // ==============================================
  // RESET FORM
  // ==============================================
  void _resetForm() {
    _titleController.clear();
    _bodyController.clear();
    _ctaTextController.text = 'Order Now';
    setState(() {
      _selectedImage = null;
      _imageBase64 = null;
      _targetAudience = 'all_users';
    });
  }

  // ==============================================
  // DELETE PROMOTION
  // ==============================================
  Future<void> _deletePromotion(int promoId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Delete Promotion',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
        content: const Text('Are you sure you want to delete this promotion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                var request = http.MultipartRequest('POST', Uri.parse(_notificationApiUrl));
                request.fields['action'] = 'delete_promotion';
                request.fields['promotion_id'] = promoId.toString();

                var response = await request.send();
                var responseBody = await response.stream.bytesToString();
                var data = json.decode(responseBody);

                if (data['status'] == 'success') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Promotion deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadPromotions();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(data['message'] ?? 'Failed to delete'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // GET STATUS COLOR
  // ==============================================
  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
      case 'active':
        return Colors.green;
      case 'draft':
        return Colors.orange;
      case 'inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ==============================================
  // GET TARGET AUDIENCE LABEL
  // ==============================================
  String _getTargetAudienceLabel(String target) {
    switch (target) {
      case 'all_users':
        return 'All Users';
      case 'specific_location':
        return '📍 This Location';
      case 'managers_only':
        return '👔 Managers Only';
      default:
        return target;
    }
  }

  // ==============================================
  // FORMAT DATE
  // ==============================================
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // ==============================================
  // BUILD
  // ==============================================
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFFF97316);
    const Color darkColor = Color(0xFF1C1C1E);
    const Color lightBg = Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: lightBg,
      floatingActionButton: FloatingActionButton(
        onPressed: _createPromotion,
        backgroundColor: const Color(0xFFF97316),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFF97316)),
      )
          : _errorMessage != null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPromotions,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : _promotions.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_offer_rounded,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No promotions yet',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create your first promotion',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadPromotions,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _promotions.length,
          itemBuilder: (context, index) {
            final promo = _promotions[index];
            final status = promo['status'] ?? 'draft';
            final targetAudience = promo['target_audience'] ?? 'all_users';
            final title = promo['title'] ?? 'No Title';
            final description = promo['description'] ?? '';
            final createdAt = promo['created_at'] ?? '';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: status == 'sent'
                    ? Border.all(
                  color: Colors.green.withOpacity(0.3),
                  width: 1.5,
                )
                    : null,
              ),
              child: Column(
                children: [
                  // Promotion Image
                  if (promo['image_base64'] != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: Image.memory(
                        base64Decode(promo['image_base64']),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            color: Colors.grey[100],
                            child: const Icon(
                              Icons.broken_image_rounded,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: darkColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(status),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF97316).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getTargetAudienceLabel(targetAudience),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFF97316),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _deletePromotion(promo['id'] ?? 0),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _ctaTextController.dispose();
    super.dispose();
  }
}