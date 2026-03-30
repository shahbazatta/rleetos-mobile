import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/fleet_provider.dart';
import '../../config/app_config.dart';

enum QrScanMode { pairBus, dispatch }

class QrScanScreen extends StatefulWidget {
  final QrScanMode mode;
  const QrScanScreen({super.key, required this.mode});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  late AnimationController _animController;
  late Animation<double> _scanLineAnim;

  bool _processing = false;
  bool _scanned = false;
  String? _error;
  String? _successMsg;

  String get _title =>
      widget.mode == QrScanMode.pairBus ? 'Scan Bus QR Code' : 'Scan Dispatch Approval';

  String get _hint =>
      widget.mode == QrScanMode.pairBus
          ? 'Point camera at the QR code on the bus'
          : 'Point camera at the supervisor\'s approval QR code';

  String get _icon => widget.mode == QrScanMode.pairBus ? '🚌' : '✅';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  Future<void> _handleScan(String rawValue) async {
    if (_processing || _scanned) return;
    setState(() {
      _processing = true;
      _scanned = true;
      _error = null;
    });
    await _controller.stop();

    try {
      final fleet = context.read<FleetProvider>();

      if (widget.mode == QrScanMode.pairBus) {
        final result = await fleet.pairWithBus(rawValue);
        final reg = (result['vehicle'] as Map<String, dynamic>)['registration'] as String;
        setState(() => _successMsg = 'Paired with bus $reg!');
      } else {
        final result = await fleet.approveDispatch(rawValue);
        final tripId = (result['trip_id'] as String).substring(0, 8);
        setState(() => _successMsg = 'Trip started! Trip #$tripId...');
      }

      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _processing = false;
        _scanned = false;
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_title, style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(children: [
        // Camera feed
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            final barcode = capture.barcodes.firstOrNull;
            if (barcode?.rawValue != null) {
              _handleScan(barcode!.rawValue!);
            }
          },
        ),

        // Dark overlay with cutout
        _ScanOverlay(scanLineAnim: _scanLineAnim),

        // Mode badge (top)
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.mode == QrScanMode.pairBus
                      ? AppConfig.primaryColor.withOpacity(0.5)
                      : AppConfig.greenColor.withOpacity(0.5),
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(_icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ]),
            ),
          ),
        ),

        // Bottom status panel
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _StatusPanel(
            successMsg: _successMsg,
            error: _error,
            processing: _processing,
            hint: _hint,
            mode: widget.mode,
            onRetry: () {
              setState(() {
                _error = null;
                _processing = false;
                _scanned = false;
              });
              _controller.start();
            },
          ),
        ),
      ]),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }
}

// ── Scan Overlay (frame + animated line) ──────────────────────────────────────

class _ScanOverlay extends StatelessWidget {
  final Animation<double> scanLineAnim;
  const _ScanOverlay({required this.scanLineAnim});

  @override
  Widget build(BuildContext context) {
    const frameSize = 260.0;
    const cornerSize = 28.0;
    const cornerThickness = 3.5;
    const cornerRadius = 8.0;
    const borderColor = AppConfig.primaryColor;

    return LayoutBuilder(builder: (context, constraints) {
      final cx = constraints.maxWidth / 2 - frameSize / 2;
      final cy = constraints.maxHeight / 2 - frameSize / 2 - 40;

      return Stack(children: [
        // Semi-transparent overlay
        Positioned.fill(
          child: CustomPaint(
            painter: _OverlayPainter(
              frameLeft: cx,
              frameTop: cy,
              frameSize: frameSize,
            ),
          ),
        ),

        // Corner decorators
        Positioned(
          left: cx,
          top: cy,
          child: const _CornerBrackets(
            size: frameSize,
            cornerSize: cornerSize,
            thickness: cornerThickness,
            radius: cornerRadius,
            color: borderColor,
          ),
        ),

        // Animated scan line
        Positioned(
          left: cx + 12,
          top: cy,
          width: frameSize - 24,
          height: frameSize,
          child: AnimatedBuilder(
            animation: scanLineAnim,
            builder: (_, __) => Stack(children: [
              Positioned(
                top: scanLineAnim.value * (frameSize - 4),
                left: 0,
                right: 0,
                height: 2,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        borderColor.withOpacity(0.8),
                        borderColor,
                        borderColor.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]);
    });
  }
}

class _OverlayPainter extends CustomPainter {
  final double frameLeft, frameTop, frameSize;
  _OverlayPainter({required this.frameLeft, required this.frameTop, required this.frameSize});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.62);
    final frame = Rect.fromLTWH(frameLeft, frameTop, frameSize, frameSize);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(full)
      ..addRRect(RRect.fromRectAndRadius(frame, const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.frameLeft != frameLeft || old.frameTop != frameTop;
}

class _CornerBrackets extends StatelessWidget {
  final double size, cornerSize, thickness, radius;
  final Color color;
  const _CornerBrackets({
    required this.size,
    required this.cornerSize,
    required this.thickness,
    required this.radius,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CornerPainter(
          cornerSize: cornerSize,
          thickness: thickness,
          radius: radius,
          color: color,
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final double cornerSize, thickness, radius;
  final Color color;
  _CornerPainter({
    required this.cornerSize,
    required this.thickness,
    required this.radius,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      // Top-left
      [
        Offset(0, cornerSize),
        Offset(0, radius),
        Offset(radius, 0),
        Offset(cornerSize, 0)
      ],
      // Top-right
      [
        Offset(size.width - cornerSize, 0),
        Offset(size.width - radius, 0),
        Offset(size.width, radius),
        Offset(size.width, cornerSize)
      ],
      // Bottom-left
      [
        Offset(0, size.height - cornerSize),
        Offset(0, size.height - radius),
        Offset(radius, size.height),
        Offset(cornerSize, size.height)
      ],
      // Bottom-right
      [
        Offset(size.width - cornerSize, size.height),
        Offset(size.width - radius, size.height),
        Offset(size.width, size.height - radius),
        Offset(size.width, size.height - cornerSize)
      ],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[3].dx, pts[3].dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// ── Status Panel ──────────────────────────────────────────────────────────────

class _StatusPanel extends StatelessWidget {
  final String? successMsg;
  final String? error;
  final bool processing;
  final String hint;
  final QrScanMode mode;
  final VoidCallback onRetry;

  const _StatusPanel({
    this.successMsg,
    this.error,
    required this.processing,
    required this.hint,
    required this.mode,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    IconData icon;
    String message;
    Color iconColor;

    if (successMsg != null) {
      bgColor = AppConfig.greenColor.withOpacity(0.92);
      icon = Icons.check_circle;
      iconColor = Colors.white;
      message = successMsg!;
    } else if (error != null) {
      bgColor = AppConfig.redColor.withOpacity(0.92);
      icon = Icons.error_outline;
      iconColor = Colors.white;
      message = error!;
    } else if (processing) {
      bgColor = AppConfig.surfaceColor.withOpacity(0.95);
      icon = Icons.hourglass_empty;
      iconColor = AppConfig.primaryColor;
      message = 'Processing...';
    } else {
      bgColor = Colors.black.withOpacity(0.75);
      icon = Icons.qr_code_scanner;
      iconColor = AppConfig.primaryColor;
      message = hint;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle bar
        Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(children: [
          if (processing && successMsg == null && error == null)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppConfig.primaryColor,
              ),
            )
          else
            Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight:
                    successMsg != null ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ]),
        if (error != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppConfig.redColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
