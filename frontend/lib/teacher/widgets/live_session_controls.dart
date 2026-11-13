part of '../screens/broadcasting_screen.dart';

/// Tappable & swipe-up glass row showing verified attendee count and radio state.
class _AttendeesRow extends StatelessWidget {
  final int verifiedCount;
  final int inconclusiveCount;
  final String radioStatusLabel;
  final Color radioDotColor;
  final bool isPulsing;
  final Animation<double> pulseAnimation;
  final VoidCallback onOpenSheet;

  const _AttendeesRow({
    required this.verifiedCount,
    required this.inconclusiveCount,
    required this.radioStatusLabel,
    required this.radioDotColor,
    required this.isPulsing,
    required this.pulseAnimation,
    required this.onOpenSheet,
  });

  @override
  Widget build(BuildContext context) {
    return _TactilePress(
      onTap: onOpenSheet,
      onHaptic: AppHaptics.selectionClick,
      semanticsLabel:
          'Verified Attendees, $verifiedCount verified. $radioStatusLabel. Tap or swipe up to view list.',
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -120) {
          AppHaptics.selectionClick();
          onOpenSheet();
        }
      },
      child: _LiveGlassSurface(
        radius: _LiveTheme.attendeesRowRadius,
        height: _LiveTheme.attendeesRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: Row(
          children: [
            // Left 36px rounded indigo icon tile
            Container(
              width: 36.0,
              height: 36.0,
              decoration: ShapeDecoration(
                color: _LiveTheme.indigoRipple.withValues(alpha: 0.16),
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(11.0),
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.how_to_reg_outlined,
                size: 19.0,
                color: _LiveTheme.accent,
              ),
            ),
            const SizedBox(width: 12.0),
            // Middle title + pulsing radio subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Verified Attendees',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15.0,
                      fontWeight: FontWeight.w600,
                      color: _LiveTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Row(
                    children: [
                      _PulsingDot(
                        color: radioDotColor,
                        size: 6.5,
                        animation: pulseAnimation,
                        isPulsing: isPulsing,
                      ),
                      const SizedBox(width: 6.0),
                      Expanded(
                        child: Text(
                          inconclusiveCount > 0
                              ? '$radioStatusLabel · $inconclusiveCount unresolved'
                              : radioStatusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w500,
                            color: _LiveTheme.textMuted62,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8.0),
            // Count pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.10),
                  width: 1.0,
                ),
              ),
              child: Text(
                '$verifiedCount',
                style: GoogleFonts.inter(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w600,
                  color: _LiveTheme.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 6.0),
            const Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 20.0,
              color: _LiveTheme.textMuted66,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom 4-column iOS call-screen style controls.
class _SessionControls extends StatelessWidget {
  final bool isPaused;
  final VoidCallback onScanQr;
  final VoidCallback onShowQrCode;
  final VoidCallback onTogglePause;
  final VoidCallback onEndSession;

  const _SessionControls({
    required this.isPaused,
    required this.onScanQr,
    required this.onShowQrCode,
    required this.onTogglePause,
    required this.onEndSession,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ControlColumn(
            label: 'Scan QR',
            semanticsLabel: 'Scan student QR code',
            onTap: onScanQr,
            onHaptic: AppHaptics.lightImpact,
            button: const _LiveGlassSurface(
              isCircle: true,
              width: _LiveTheme.controlButtonSize,
              height: _LiveTheme.controlButtonSize,
              child: Center(
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 24.0,
                  color: _LiveTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _ControlColumn(
            label: 'QR code',
            semanticsLabel: 'Show optical QR code',
            onTap: onShowQrCode,
            onHaptic: AppHaptics.lightImpact,
            button: const _LiveGlassSurface(
              isCircle: true,
              width: _LiveTheme.controlButtonSize,
              height: _LiveTheme.controlButtonSize,
              child: Center(
                child: Icon(
                  Icons.qr_code_2_rounded,
                  size: 25.0,
                  color: _LiveTheme.textPrimary,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _ControlColumn(
            label: isPaused ? 'Resume' : 'Pause',
            semanticsLabel: isPaused ? 'Resume session' : 'Pause session',
            onTap: onTogglePause,
            onHaptic: AppHaptics.lightImpact,
            button: Container(
              width: _LiveTheme.controlButtonSize,
              height: _LiveTheme.controlButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFFFFFF),
                    Color(0xFFE9E9F3),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.08),
                    blurRadius: 0.0,
                    spreadRadius: 6.0,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 28.0,
                color: _LiveTheme.bgTop,
              ),
            ),
          ),
        ),
        Expanded(
          child: _ControlColumn(
            label: 'End session',
            semanticsLabel: 'End attendance session',
            onTap: onEndSession,
            onHaptic: AppHaptics.selectionClick,
            button: Container(
              width: _LiveTheme.controlButtonSize,
              height: _LiveTheme.controlButtonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _LiveTheme.endRedTop,
                    _LiveTheme.endRedBottom,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _LiveTheme.liveRed.withValues(alpha: 0.42),
                    blurRadius: 22.0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.stop_rounded,
                size: 26.0,
                color: _LiveTheme.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ControlColumn extends StatelessWidget {
  final Widget button;
  final String label;
  final String semanticsLabel;
  final VoidCallback onTap;
  final VoidCallback onHaptic;

  const _ControlColumn({
    required this.button,
    required this.label,
    required this.semanticsLabel,
    required this.onTap,
    required this.onHaptic,
  });

  @override
  Widget build(BuildContext context) {
    return _TactilePress(
      onTap: onTap,
      onHaptic: onHaptic,
      semanticsLabel: semanticsLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          const SizedBox(height: 8.0),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: _LiveTheme.textMuted82,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendeeDisplayData {
  final String name;
  final String id;
  final String mode;
  final String? rssi;
  final String? gpsBadge;
  final String timestamp;
  final Color badgeColor;
  final IconData badgeIcon;

  const _AttendeeDisplayData({
    required this.name,
    required this.id,
    required this.mode,
    this.rssi,
    this.gpsBadge,
    required this.timestamp,
    required this.badgeColor,
    required this.badgeIcon,
  });
}

/// Modal bottom sheet displaying verified attendees and any exception queue items.
class _LiveAttendeesSheet extends StatelessWidget {
  final List<_AttendeeDisplayData> attendees;
  final List<PassportAttendanceVerificationResult> inconclusiveStudents;
  final String radioStatusLabel;
  final Color radioDotColor;
  final VoidCallback onResolveExceptions;

  const _LiveAttendeesSheet({
    required this.attendees,
    required this.inconclusiveStudents,
    required this.radioStatusLabel,
    required this.radioDotColor,
    required this.onResolveExceptions,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.40,
      maxChildSize: 0.90,
      expand: false,
      builder: (context, scrollController) {
        return ClipPath(
          clipper: const ShapeBorderClipper(
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF14142E),
                  Color(0xFF0A0A1A),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.16),
                  width: 1.0,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 10.0),
                  Container(
                    width: 38.0,
                    height: 4.0,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verified Attendees (${attendees.length})',
                                style: GoogleFonts.inter(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.w700,
                                  color: _LiveTheme.textPrimary,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              Row(
                                children: [
                                  Container(
                                    width: 6.5,
                                    height: 6.5,
                                    decoration: BoxDecoration(
                                      color: radioDotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6.0),
                                  Text(
                                    radioStatusLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w500,
                                      color: _LiveTheme.textMuted62,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _TactilePress(
                          onTap: () => Navigator.pop(context),
                          semanticsLabel: 'Close attendees list',
                          child: const _LiveGlassSurface(
                            isCircle: true,
                            width: 36.0,
                            height: 36.0,
                            child: Center(
                              child: Icon(
                                Icons.close_rounded,
                                size: 18.0,
                                color: _LiveTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1.0,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20.0, 14.0, 20.0, 24.0),
                      children: [
                        if (inconclusiveStudents.isNotEmpty) ...[
                          _buildExceptionSection(),
                          const SizedBox(height: 14.0),
                        ],
                        if (attendees.isEmpty)
                          _LiveGlassSurface(
                            radius: 20.0,
                            padding: const EdgeInsets.symmetric(
                              vertical: 38.0,
                              horizontal: 20.0,
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.bluetooth_searching_rounded,
                                  size: 36.0,
                                  color: _LiveTheme.accent.withValues(alpha: 0.8),
                                ),
                                const SizedBox(height: 10.0),
                                Text(
                                  'No students verified yet',
                                  style: GoogleFonts.inter(
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    color: _LiveTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4.0),
                                Text(
                                  "Students tap 'Start Attendance' to respond",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.0,
                                    color: _LiveTheme.textMuted60,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...attendees.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _LiveGlassSurface(
                                radius: 18.0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14.0,
                                  vertical: 12.0,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34.0,
                                      height: 34.0,
                                      decoration: BoxDecoration(
                                        color: item.badgeColor.withValues(alpha: 0.16),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        item.badgeIcon,
                                        size: 17.0,
                                        color: item.badgeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.0,
                                              fontWeight: FontWeight.w600,
                                              color: _LiveTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4.0),
                                          Wrap(
                                            spacing: 8.0,
                                            runSpacing: 4.0,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7.0,
                                                  vertical: 2.0,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: item.badgeColor
                                                      .withValues(alpha: 0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          6.0),
                                                ),
                                                child: Text(
                                                  item.mode,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: item.badgeColor,
                                                  ),
                                                ),
                                              ),
                                              if (item.rssi != null)
                                                Text(
                                                  item.rssi!,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11.5,
                                                    color:
                                                        _LiveTheme.textMuted60,
                                                    fontFeatures: const [
                                                      FontFeature
                                                          .tabularFigures(),
                                                    ],
                                                  ),
                                                ),
                                              if (item.gpsBadge != null)
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 6.0,
                                                    vertical: 2.0,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _LiveTheme.onlineGreen
                                                        .withValues(alpha: 0.16),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6.0),
                                                  ),
                                                  child: Text(
                                                    item.gpsBadge!,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w600,
                                                      color:
                                                          _LiveTheme.onlineGreen,
                                                      fontFeatures: const [
                                                        FontFeature
                                                            .tabularFigures(),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      item.timestamp,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w500,
                                        color: _LiveTheme.textMuted60,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
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
        );
      },
    );
  }

  Widget _buildExceptionSection() {
    return _LiveGlassSurface(
      radius: 18.0,
      fillTop: _LiveTheme.amberFill,
      fillBottom: _LiveTheme.amberFill,
      borderColor: _LiveTheme.amberBorder,
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18.0,
                color: _LiveTheme.amber,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'EXCEPTION QUEUE (${inconclusiveStudents.length})',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: _LiveTheme.amberText,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              _TactilePress(
                onTap: onResolveExceptions,
                semanticsLabel: 'Resolve inconclusive students via QR challenge',
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 6.0,
                  ),
                  decoration: BoxDecoration(
                    color: _LiveTheme.amberTileFill,
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: _LiveTheme.amber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Resolve',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _LiveTheme.amberText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10.0),
          ...inconclusiveStudents.take(5).map((s) {
            final name = s.studentName ?? s.studentId ?? 'Unknown Student';
            final rssiText =
                s.medianRssi != null ? '${s.medianRssi} dBm' : 'Signal Unstable';
            final exceptionLabel = (s.gpsStatus == 'OUTSIDE_GEOFENCE' &&
                    s.gpsDistanceMeters != null)
                ? 'GPS: ${s.gpsDistanceMeters!.round()}m away'
                : 'RSSI: $rssiText (${s.proximityTier.code})';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                children: [
                  Container(
                    width: 5.0,
                    height: 5.0,
                    decoration: const BoxDecoration(
                      color: _LiveTheme.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: _LiveTheme.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    exceptionLabel,
                    style: GoogleFonts.inter(
                      fontSize: 11.0,
                      color: _LiveTheme.amberBody,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Dark glass modal bottom sheet for active Hotspot Burst gateway & phone settings.
class _HotspotGatewaySheet extends StatefulWidget {
  final PassportTeacherAttendanceService teacherService;
  final SessionModel session;
  final VoidCallback onEditCredentials;
  final VoidCallback onEnlargeQr;
  final VoidCallback onStopHotspot;

  const _HotspotGatewaySheet({
    required this.teacherService,
    required this.session,
    required this.onEditCredentials,
    required this.onEnlargeQr,
    required this.onStopHotspot,
  });

  @override
  State<_HotspotGatewaySheet> createState() => _HotspotGatewaySheetState();
}

class _HotspotGatewaySheetState extends State<_HotspotGatewaySheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!widget.teacherService.isHotspotActive) {
        Navigator.maybePop(context);
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.teacherService;
    final hotspotRem = service.hotspotRemainingSeconds;
    final isHardwareOn =
        service.isHardwareHotspotDetected || service.isNativeHotspot;
    final gatewayIp = service.detectedGatewayIp ?? '192.168.43.1';
    final ssid = service.hotspotSsid ?? '';
    final pass = service.hotspotPassword ?? '';
    final hotspotQrPayload = service.buildWifiHotspotQrPayload(
      sessionId: widget.session.id,
      fallbackTeacherId: widget.session.instructorName,
      gatewayIpOverride: gatewayIp,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 28.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF14142E), Color(0xFF0A0A1A)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.16),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Row(
              children: [
                Container(
                  width: 36.0,
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: _LiveTheme.indigoRipple.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(11.0),
                  ),
                  child: const Icon(
                    Icons.wifi_tethering_rounded,
                    size: 19.0,
                    color: _LiveTheme.accentLight,
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHardwareOn
                            ? 'WI-FI HOTSPOT GATEWAY'
                            : 'PHONE HOTSPOT IS OFF',
                        style: GoogleFonts.inter(
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: isHardwareOn
                              ? _LiveTheme.accentLight
                              : _LiveTheme.amberText,
                        ),
                      ),
                      Text(
                        isHardwareOn
                            ? '${hotspotRem}s active'
                            : '${hotspotRem}s listening',
                        style: GoogleFonts.inter(
                          fontSize: 12.0,
                          color: _LiveTheme.textMuted62,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                _TactilePress(
                  onTap: () => Navigator.pop(context),
                  semanticsLabel: 'Close hotspot sheet',
                  child: const _LiveGlassSurface(
                    isCircle: true,
                    width: 34.0,
                    height: 34.0,
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 18.0,
                        color: _LiveTheme.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            if (!isHardwareOn) ...[
              Text(
                "Turn on Personal Hotspot in your phone's Quick Settings to allow students to connect. Or tap below to open settings.",
                style: GoogleFonts.inter(
                  fontSize: 13.0,
                  color: _LiveTheme.textMuted66,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14.0),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      AppHaptics.selectionClick();
                      await service.openHotspotSettings();
                    },
                    icon: const Icon(Icons.settings_rounded,
                        size: 15.0, color: Colors.white),
                    label: Text(
                      'Open Hotspot Settings',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14.0, vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 0,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      AppHaptics.selectionClick();
                      final sm = ScaffoldMessenger.of(context);
                      final ok = await service.startNativeLocalOnlyHotspot();
                      if (ok) {
                        if (mounted) setState(() {});
                      } else if (mounted) {
                        final err = service.lastHotspotError ??
                            'Location is OFF or Carrier tethering restricted. Please turn ON Hotspot in phone settings.';
                        sm.showSnackBar(
                          SnackBar(
                            content: Text(err, style: GoogleFonts.inter(fontSize: 12)),
                            backgroundColor: _LiveTheme.amber,
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'Settings',
                              textColor: Colors.white,
                              onPressed: () => service.openHotspotSettings(),
                            ),
                          ),
                        );
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.bolt_rounded,
                        size: 15.0, color: _LiveTheme.accentLight),
                    label: Text(
                      'Auto Hotspot',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _LiveTheme.accentLight,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: _LiveTheme.accent.withValues(alpha: 0.45)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onEditCredentials,
                    icon: const Icon(Icons.edit_rounded,
                        size: 15.0, color: _LiveTheme.textPrimary),
                    label: Text(
                      'Edit Name & Pass',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _LiveTheme.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.22)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12.0, vertical: 10.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Text(
                'Card activates automatically once you toggle Hotspot ON.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: _LiveTheme.amberText,
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: widget.onEnlargeQr,
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: QrImageView(
                        data: hotspotQrPayload,
                        version: QrVersions.auto,
                        size: 112.0,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14.0),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6.5,
                              height: 6.5,
                              decoration: const BoxDecoration(
                                color: _LiveTheme.onlineGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6.0),
                            Expanded(
                              child: Text(
                                'Gateway: $gatewayIp:53318',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: _LiveTheme.onlineGreen,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Scan to Join & Verify',
                          style: GoogleFonts.inter(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w700,
                            color: _LiveTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3.0),
                        Text(
                          'Students scan with CampusOS to connect & submit offline.',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: _LiveTheme.textMuted62,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        _LiveGlassSurface(
                          radius: 12.0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10.0,
                            vertical: 6.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SSID: $ssid',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: _LiveTheme.textPrimary,
                                ),
                              ),
                              Text(
                                'Pass: $pass',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600,
                                  color: _LiveTheme.accentLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onEditCredentials,
                  icon: const Icon(Icons.edit_rounded,
                      size: 14.0, color: _LiveTheme.accentLight),
                  label: Text(
                    'Edit Name & Pass',
                    style: GoogleFonts.inter(
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      color: _LiveTheme.accentLight,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14.0),
            ElevatedButton(
              onPressed: () {
                AppHaptics.mediumImpact();
                widget.onStopHotspot();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _LiveTheme.liveRed.withValues(alpha: 0.22),
                foregroundColor: _LiveTheme.liveRedText,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
                  side: BorderSide(
                    color: _LiveTheme.liveRed.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Text(
                'Stop Hotspot Burst',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
