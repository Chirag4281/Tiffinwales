// lib/screens/help_support_page.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/support_service.dart';

class HelpSupportPage extends StatefulWidget {
  final String locationName;
  final String username;
  final String email;

  const HelpSupportPage({
    super.key,
    required this.locationName,
    required this.username,
    required this.email,
  });

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // Dynamic support info from DB
  SupportInfo? _info;
  bool _isLoadingInfo = true;

  // ============================================================
  // FAQ DATA — SAME FOR ALL LOCATIONS (static)
  // ============================================================
  final List<Map<String, String>> _faqs = const [
    {
      'q': 'How do I place an order?',
      'a': 'Browse the menu from the Home tab, add dishes to your cart, '
          'then proceed to checkout. You can pay online or choose Cash '
          'on Delivery if available in your area.',
    },
    {
      'q': 'How does a Meal Plan work?',
      'a': 'Meal plans let you pre-select your dishes for 1, 3, 5, 7, or more '
          'days. Tap "Customize" on any Meal Plan item, pick your dishes, and '
          'add to cart. You can edit them any time from your cart.',
    },
    {
      'q': 'Can I edit my meal plan after ordering?',
      'a': 'Yes. Open your cart, tap "Customize" on the meal plan item, and '
          're-select the dishes. Your old selection will be replaced automatically.',
    },
    {
      'q': 'What are the delivery hours?',
      'a': 'Standard delivery windows are 12:00 PM – 1:00 PM and 6:00 PM – 8:00 PM. '
          'You can pick your preferred slot at checkout.',
    },
    {
      'q': 'How much is the delivery fee?',
      'a': 'Delivery fee depends on your distance from the kitchen: '
          '\$8 (0–3 mi), \$10 (3–5 mi), \$12 (5–10 mi), \$14 (10–15 mi). '
          'Orders beyond 15 miles are not delivered.',
    },
    {
      'q': 'Can I cancel or refund my order?',
      'a': 'Orders can be cancelled up to 1 hour before the delivery window. '
          'Contact support via WhatsApp or email for refunds.',
    },
    {
      'q': 'How do I change my delivery address?',
      'a': 'Go to Profile → Delivery Address, or tap the address bar on the '
          'Home tab. You can also pick the location directly from the map.',
    },
    {
      'q': 'Is Cash on Delivery available?',
      'a': 'COD availability depends on your location and order value. '
          'If enabled, you will see the option at checkout.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _entranceController.forward();

    _loadSupportInfo();
  }

  Future<void> _loadSupportInfo() async {
    setState(() => _isLoadingInfo = true);
    final info = await SupportService.fetch(widget.locationName);
    if (!mounted) return;
    setState(() {
      _info = info;
      _isLoadingInfo = false;
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // ============================================================
  // LAUNCH HELPERS — iOS-friendly
  // ============================================================

  /// Tries multiple launch modes; iOS is picky about which works.
  Future<bool> _tryLaunch(
      Uri uri, {
        List<LaunchMode> modes = const [
          LaunchMode.externalApplication,
          LaunchMode.platformDefault,
          LaunchMode.inAppBrowserView,
        ],
      }) async {
    for (final mode in modes) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (_) {}
    }
    return false;
  }

  void _showSnack(String msg, {bool error = false}) {
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
        backgroundColor: error ? Colors.red : const Color(0xFFF97316),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final wa = _info?.whatsapp ?? '';
    if (wa.isEmpty) {
      _showSnack('WhatsApp not available right now', error: true);
      return;
    }

    final msg = Uri.encodeComponent(
      'Hi Tiffin Wales (${widget.locationName}) team! '
          'I need help with my order. — ${widget.username}',
    );

    // Primary: wa.me link (works on iOS + Android)
    final primary = Uri.parse('https://wa.me/$wa?text=$msg');
    if (await _tryLaunch(primary, modes: const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ])) return;

    // Fallback: whatsapp:// scheme
    final fallback = Uri.parse('whatsapp://send?phone=$wa&text=$msg');
    if (await _tryLaunch(fallback, modes: const [
      LaunchMode.externalApplication,
    ])) return;

    _showSnack('WhatsApp is not installed', error: true);
  }

  Future<void> _openEmail() async {
    final mail = _info?.email ?? '';
    if (mail.isEmpty) {
      _showSnack('Email not available right now', error: true);
      return;
    }

    final subject = Uri.encodeComponent(
      'Support Request — ${widget.locationName}',
    );
    final body = Uri.encodeComponent(
      'Hi Support,\n\n'
          'My name is ${widget.username}.\n'
          'I need help with:\n\n\n\n'
          'Thanks,\n${widget.username}\n${widget.email}',
    );

    final uri = Uri(
      scheme: 'mailto',
      path: mail,
      query: 'subject=$subject&body=$body',
    );

    final ok = await _tryLaunch(uri, modes: const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]);
    if (!ok) _showSnack('No email app configured', error: true);
  }

  Future<void> _openPhone() async {
    final rawPhone = _info?.phone ?? '';
    if (rawPhone.isEmpty) {
      _showSnack('Phone not available right now', error: true);
      return;
    }

    // Strip spaces, dashes, parens — keep + and digits
    final cleanPhone = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: cleanPhone);

    final ok = await _tryLaunch(uri, modes: const [
      LaunchMode.externalApplication,
      LaunchMode.platformDefault,
    ]);
    if (!ok) _showSnack('Could not start call', error: true);
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    const Color softBg = Color(0xFFFAFAFA);

    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // NEW: Support hours card (dynamic)
                      if (_isLoadingInfo)
                        _buildInfoLoading()
                      else if (_info != null)
                        _buildTimingsCard(),

                      const SizedBox(height: 14),
                      _buildQuickContactRow(),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Frequently Asked Questions'),
                      const SizedBox(height: 10),
                      ..._faqs.map(_buildFaqTile),
                      const SizedBox(height: 20),
                      _buildSectionTitle('Still need help?'),
                      const SizedBox(height: 10),
                      _buildContactCard(),
                      const SizedBox(height: 24),
                      _buildFooter(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TIMINGS CARD
  // ------------------------------------------------------------
  Widget _buildInfoLoading() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF97316),
          ),
        ),
      ),
    );
  }

  Widget _buildTimingsCard() {
    final info = _info!;
    final open = SupportInfo.prettyTime(info.openingTime);
    final close = SupportInfo.prettyTime(info.closingTime);

    return Container(
      padding: const EdgeInsets.all(16),
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
        border: Border.all(
          color: const Color(0xFFF97316).withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFFF97316),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Support Hours',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1C1E),
                ),
              ),

            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Days', info.openingDays),
          const SizedBox(height: 6),
          _buildInfoRow('Hours', '$open – $close'),
          const SizedBox(height: 6),
          _buildInfoRow('Response', info.averageResponse),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF1C1C1E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------
  Widget _buildHeader() {
    final online = _info?.isOpenNow ?? false;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: online
                            ? const Color(0xFF34D399)
                            : const Color(0xFFFBBF24),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      online ? 'We\'re online' : 'We\'ll be back soon',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help & Support',
                  style: GoogleFonts.poppins(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.locationName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // QUICK CONTACT ROW
  // ------------------------------------------------------------
  Widget _buildQuickContactRow() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickContact(
            icon: Icons.chat_bubble_rounded,
            label: 'WhatsApp',
            color: const Color(0xFF25D366),
            onTap: _openWhatsApp,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickContact(
            icon: Icons.phone_rounded,
            label: 'Call Us',
            color: const Color(0xFF0EA5E9),
            onTap: _openPhone,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildQuickContact(
            icon: Icons.email_rounded,
            label: 'Email',
            color: const Color(0xFFF97316),
            onTap: _openEmail,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickContact({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
          border: Border.all(color: color.withOpacity(0.15), width: 1),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1C1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------
  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFFF97316),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1C1C1E),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // FAQ TILE
  // ------------------------------------------------------------
  Widget _buildFaqTile(Map<String, String> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: const Color(0xFFF97316),
          collapsedIconColor: const Color(0xFF64748B),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.question_answer_rounded,
              size: 16,
              color: Color(0xFFF97316),
            ),
          ),
          title: Text(
            faq['q'] ?? '',
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1C1E),
              height: 1.3,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq['a'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF64748B),
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CONTACT CARD
  // ------------------------------------------------------------
  Widget _buildContactCard() {
    final phone = _info?.phone ?? '';
    final email = _info?.email ?? '';
    final address = _info?.address ?? '';
    final response = _info?.averageResponse ?? 'under 5 minutes';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Talk to a human',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Average response: $response',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (phone.isNotEmpty)
            _buildContactRow(Icons.phone_rounded, phone),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(Icons.email_rounded, email),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildContactRow(Icons.location_on_rounded, address),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openWhatsApp,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFF97316),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.chat_bubble_rounded, size: 18),
              label: Text(
                'Chat with us on WhatsApp',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.85), size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // FOOTER
  // ------------------------------------------------------------
  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFF97316),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'Made with care by Tiffin Wales',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFFF97316),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'App version 1.0.0',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}