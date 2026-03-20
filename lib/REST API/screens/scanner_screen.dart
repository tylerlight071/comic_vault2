// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../widgets/pressable.dart';
import '../../theme/services/database_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scanner = MobileScannerController();
  late final AnimationController _lineCtrl;
  late final Animation<double> _lineAnim;
  bool _scanned = false;
  bool _torchOn = false;
  List<Map<String, dynamic>> _recentScans = [];
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _lineCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut);
    _loadHistory();
  }

  @override
  void dispose() {
    _scanner.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await DatabaseService.instance.getBarcodeHistory(limit: 10);
    if (mounted) setState(() => _recentScans = history);
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    
    final validated = _validateAndNormalizeBarcode(raw);
    if (validated == null) return; // Invalid barcode
    
    setState(() => _scanned = true);
    Navigator.pop(context, validated);
  }

  String? _validateAndNormalizeBarcode(String raw) {
    var clean = raw.replaceAll(RegExp(r'[^\d]'), '');

    // Comic barcodes are UPC-A (12) or EAN-13 (13). Scanners sometimes
    // return the main barcode concatenated with a 2 or 5-digit supplement
    // (issue/edition info), producing 14, 15, 17, or 18 digits. Strip the
    // supplement so we're left with the standard 12 or 13-digit barcode.
    if (clean.length == 14 || clean.length == 17) {
      clean = clean.substring(0, 12); // UPC-A + supplement
    } else if (clean.length == 15 || clean.length == 18) {
      clean = clean.substring(0, 13); // EAN-13 + supplement
    }

    if (clean.length != 8 && clean.length != 12 && clean.length != 13) {
      return null;
    }
    return clean;
  }

  void _selectFromHistory(String barcode) {
    setState(() => _scanned = true);
    Navigator.pop(context, barcode);
  }

  void _toggleHistory() {
    setState(() => _showHistory = !_showHistory);
  }

  void _toggleTorch() {
    _scanner.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _scanner, onDetect: _onDetect),
          _buildOverlay(),
          _buildTopBar(),
          if (_showHistory) _buildHistoryPanel() else _buildBottomHint(),
        ],
      ),
    );
  }

  // ── Overlay ──────────────────────────────────────────────────────────────

  Widget _buildOverlay() {
    return LayoutBuilder(builder: (ctx, constraints) {
      const cutout = 260.0;
      final left = (constraints.maxWidth - cutout) / 2;
      final top = (constraints.maxHeight - cutout) / 2 - 24;

      return Stack(
        children: [
          // Semi-transparent vignette (4 rects around the cutout)
          _vignette(constraints, left, top, cutout),

          // Animated corner brackets
          Positioned(
            left: left,
            top: top,
            child: const _Corners(size: cutout),
          ),

          // Scan line
          Positioned(
            left: left + 8,
            top: top,
            width: cutout - 16,
            height: cutout,
            child: AnimatedBuilder(
              animation: _lineAnim,
              builder: (_, __) => Align(
                alignment: Alignment(0, (_lineAnim.value * 2) - 1),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.8),
                      Colors.transparent,
                    ]),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _vignette(BoxConstraints c, double l, double t, double s) {
    const color = Color(0xCC000000);
    return Stack(children: [
      Positioned(top: 0, left: 0, right: 0, height: t,
          child: const ColoredBox(color: color)),
      Positioned(top: t, left: 0, width: l, height: s,
          child: const ColoredBox(color: color)),
      Positioned(top: t, right: 0, width: l, height: s,
          child: const ColoredBox(color: color)),
      Positioned(top: t + s, left: 0, right: 0, bottom: 0,
          child: const ColoredBox(color: color)),
    ]);
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            _circleBtn(
              icon: Icons.close_rounded,
              onTap: () => Navigator.pop(context),
            ),
            const Spacer(),
            Text(
              'SCAN BARCODE',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                _circleBtn(
                  icon: Icons.history_rounded,
                  onTap: _toggleHistory,
                ),
                const SizedBox(width: 8),
                _circleBtn(
                  icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                  onTap: _toggleTorch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(
          {required IconData icon, required VoidCallback onTap}) =>
      Pressable(
        onTap: onTap,
        haptic: HapticStyle.light,
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      );

  // ── History panel ───────────────────────────────────────────────────────

  Widget _buildHistoryPanel() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.black54],
          ),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Recent Scans',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Pressable(
                    onTap: _toggleHistory,
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            // History list
            Expanded(
              child: _recentScans.isEmpty
                  ? Center(
                      child: Text(
                        'No recent scans',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _recentScans.length,
                      itemBuilder: (ctx, i) {
                        final scan = _recentScans[i];
                        final barcode = scan['barcode'] as String;
                        final timestamp = DateTime.parse(scan['timestamp'] as String);
                        final timeAgo = _formatTimeAgo(timestamp);
                        
                        return Pressable(
                          onTap: () => _selectFromHistory(barcode),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.qr_code_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        barcode,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        timeAgo,
                                        style: GoogleFonts.inter(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white54,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // ── Bottom hint ───────────────────────────────────────────────────────────

  Widget _buildBottomHint() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 48),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Text(
            'Point at the barcode on the back\nof your comic book',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
              height: 1.5,
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
        ),
      ),
    );
  }
}

// ── Corner brackets painter ──────────────────────────────────────────────────

class _Corners extends StatelessWidget {
  final double size;
  const _Corners({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _CornersPainter()),
    );
  }
}

class _CornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const arm = 24.0;
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(const Offset(0, arm), Offset.zero, p);
    canvas.drawLine(Offset.zero, const Offset(arm, 0), p);
    // Top-right
    canvas.drawLine(Offset(size.width - arm, 0), Offset(size.width, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, arm), p);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - arm), Offset(0, size.height), p);
    canvas.drawLine(Offset(0, size.height), Offset(arm, size.height), p);
    // Bottom-right
    canvas.drawLine(Offset(size.width - arm, size.height),
        Offset(size.width, size.height), p);
    canvas.drawLine(Offset(size.width, size.height - arm),
        Offset(size.width, size.height), p);
  }

  @override
  bool shouldRepaint(_) => false;
}
