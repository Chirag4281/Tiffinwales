import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart'; // <--- IMPORTANT: Make sure this is imported!

class LowellKathiyawadiScreen extends StatefulWidget {
  const LowellKathiyawadiScreen({super.key});

  @override
  State<LowellKathiyawadiScreen> createState() => _LowellKathiyawadiScreenState();
}

class _LowellKathiyawadiScreenState extends State<LowellKathiyawadiScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const KathiyawadiHomeTab(),
    const Center(child: Text("Kathiyawadi Menu")),
    const Center(child: Text("Kathiyawadi Orders")),
    const Center(child: Text("Kathiyawadi Profile")),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // Glass Background
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                    colors: [const Color(0xFFFFEBEE), Colors.white, const Color(0xFFFFCCBC)],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -50, left: -80,
              child: Container(
                width: 250, height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withOpacity(0.1),
                ),
              ),
            ),
            _pages[_selectedIndex],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF2E4A00),
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 12),
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "Menu"),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: "Orders"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

class KathiyawadiHomeTab extends StatelessWidget {
  const KathiyawadiHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFFB3D335);
    const Color darkGreen = Color(0xFF2E4A00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded( // Added Expanded to prevent overflow
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Lowell Kathiyawadi", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w800, color: darkGreen)),
                    Text("Bold Flavors & Spices", style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[600])),
                  ],
                ),
              ),
              // 🟢 CHANGE LOCATION BUTTON (Handled perfectly here)
              GestureDetector(
                onTap: () {
                  // This instantly takes the user back to the HomeScreen to pick a new location
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: darkGreen, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        "Change",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: darkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Delivery Info Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department, color: Colors.redAccent, size: 30),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Spicy & Authentic", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: darkGreen)),
                    Text("Traditional home style", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  ],
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Menu List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
            children: [
              Text("Must Try Dishes", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: darkGreen)),
              const SizedBox(height: 12),
              ...["Undhiyu", "Kathiyawadi Thali", "Bajri Rotla"].map((dish) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12))),
                    const SizedBox(width: 16),
                    Expanded(child: Text(dish, style: GoogleFonts.poppins(fontWeight: FontWeight.w500))),
                    Text("\$13.99", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.redAccent)),
                  ],
                ),
              )).toList(),
            ],
          ),
        )
      ],
    );
  }
}