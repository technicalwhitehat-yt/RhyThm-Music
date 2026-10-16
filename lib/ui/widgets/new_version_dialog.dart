import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';
import '../screens/Home/home_screen_controller.dart';
import 'snackbar.dart';

class NewVersionDialog extends StatefulWidget {
  final AppReleaseInfo releaseInfo;

  const NewVersionDialog({
    super.key,
    required this.releaseInfo,
  });

  @override
  State<NewVersionDialog> createState() => _NewVersionDialogState();
}

class _NewVersionDialogState extends State<NewVersionDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String _statusMessage = "Downloading update...";
  bool _downloadFailed = false;
  String _errorMessage = "";
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
    _totalBytes = widget.releaseInfo.fileSize;
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _cancelDownload() {
    _cancelToken?.cancel("Cancelled by user");
    setState(() {
      _isDownloading = false;
      _progress = 0.0;
      _receivedBytes = 0;
      _downloadFailed = false;
      _statusMessage = "Downloading update...";
    });
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadFailed = false;
      _errorMessage = "";
      _progress = 0.0;
      _receivedBytes = 0;
      _statusMessage = "Connecting to server...";
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final updateDir = Directory("${tempDir.path}/update");
      if (!await updateDir.exists()) {
        await updateDir.create(recursive: true);
      }

      final fileName = widget.releaseInfo.fileName.isNotEmpty
          ? widget.releaseInfo.fileName
          : "rhythm_music_update.apk";
      final filePath = "${updateDir.path}/$fileName";
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      _cancelToken = CancelToken();

      final dio = Dio();
      await dio.download(
        widget.releaseInfo.downloadUrl,
        filePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _statusMessage = "Downloading update...";
            _receivedBytes = received;
            if (total > 0) {
              _totalBytes = total;
              _progress = received / total;
            } else if (widget.releaseInfo.fileSize > 0) {
              _totalBytes = widget.releaseInfo.fileSize;
              _progress = (received / widget.releaseInfo.fileSize).clamp(0.0, 1.0);
            }
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _progress = 1.0;
        _statusMessage = "Launching installer...";
      });

      await Future.delayed(const Duration(milliseconds: 300));

      if (GetPlatform.isAndroid) {
        final success = await UpdateService.installApk(filePath);
        if (!success && mounted) {
          launchUrl(
            Uri.parse(widget.releaseInfo.downloadUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      } else if (GetPlatform.isWindows) {
        try {
          await Process.start(filePath, []);
        } catch (_) {
          if (mounted) {
            launchUrl(
              Uri.parse(widget.releaseInfo.downloadUrl),
              mode: LaunchMode.externalApplication,
            );
          }
        }
      } else {
        launchUrl(
          Uri.parse(widget.releaseInfo.downloadUrl),
          mode: LaunchMode.externalApplication,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (CancelToken.isCancel(e as dynamic)) return;
      if (!mounted) return;
      setState(() {
        _downloadFailed = true;
        _errorMessage = "Download error: $e";
        _statusMessage = "Download failed";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.secondary != Colors.transparent
        ? theme.colorScheme.secondary
        : theme.primaryColor;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 440),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surface.withOpacity(0.92),
                      theme.colorScheme.surface.withOpacity(0.80),
                    ],
                  ),
                  border: Border.all(
                    color: accentColor.withOpacity(0.30),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.18),
                      blurRadius: 32,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Glowing circular rocket icon
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor,
                              accentColor.withOpacity(0.70),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rocket_launch_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title
                      Text(
                        "Update Available 🚀",
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      // Version Pill Badge (Ultra-Modern iOS / Spotify Style)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentColor.withOpacity(0.16),
                              accentColor.withOpacity(0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: accentColor.withOpacity(0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.12),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accentColor,
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.8),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDisplayVersion(widget.releaseInfo.displayVersion),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 1,
                              height: 12,
                              color: accentColor.withOpacity(0.35),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Official Release",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.75),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // What's New Changelog Card
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 200),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "✨ What's New",
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Flexible(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: _buildChangelogList(widget.releaseInfo.body, theme, accentColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Interactive Download Progress / Action Buttons
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.95, end: 1.0).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _isDownloading
                            ? _buildProgressState(theme, accentColor)
                            : _buildActionButtons(theme, accentColor),
                      ),

                      // Don't show again toggle
                      if (!_isDownloading) ...[
                        const SizedBox(height: 10),
                        _buildDontShowAgainRow(theme),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDisplayVersion(String raw) {
    String clean = raw.trim();
    while (clean.startsWith('v') || clean.startsWith('V') || clean.startsWith('.')) {
      clean = clean.substring(1).trim();
    }
    return "v$clean";
  }

  /// Extracts bullet points strictly from the "What's New" / "What’s New" section of the GitHub release notes.
  List<String> _extractWhatsNewBullets(String rawBody) {
    if (rawBody.trim().isEmpty) return [];

    final lines = rawBody.split('\n');
    bool inWhatsNewSection = false;
    final List<String> whatsNewRawLines = [];

    // Case-insensitive regex matching "# What's New", "## 🚀 What’s New", "### Whats New", "## What is New", etc.
    final whatsNewHeaderRegExp = RegExp(
      r'^#+\s*.*what[\x27\u2019]?s?\s*new.*$',
      caseSensitive: false,
    );
    // Matches start of any subsequent markdown heading (#, ##, ###)
    final anyHeaderRegExp = RegExp(r'^#+\s+.*$');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (whatsNewHeaderRegExp.hasMatch(line)) {
        inWhatsNewSection = true;
        continue;
      }

      if (inWhatsNewSection) {
        // Stop if a new markdown section or horizontal divider starts
        if (anyHeaderRegExp.hasMatch(line) ||
            line.startsWith('---') ||
            line.startsWith('===') ||
            line.startsWith('***')) {
          break;
        }
        whatsNewRawLines.add(line);
      }
    }

    final List<String> bulletList = [];

    // If "What's New" section was found, parse only its bullet points
    if (inWhatsNewSection && whatsNewRawLines.isNotEmpty) {
      for (final line in whatsNewRawLines) {
        final clean = line.trim();
        if (clean.isEmpty) continue;
        if (clean.startsWith('- ') || clean.startsWith('* ') || clean.startsWith('• ')) {
          bulletList.add(clean.substring(2).trim());
        } else if (clean.startsWith('– ') || clean.startsWith('— ')) {
          bulletList.add(clean.substring(2).trim());
        } else if (RegExp(r'^\d+[\.\)]\s+').hasMatch(clean)) {
          bulletList.add(clean.replaceFirst(RegExp(r'^\d+[\.\)]\s+'), '').trim());
        } else if (!clean.startsWith('#') && !clean.startsWith('---')) {
          bulletList.add(clean);
        }
      }
    } else {
      // Fallback: If no dedicated What's New heading exists, extract any bullet points from body
      for (final rawLine in lines) {
        final clean = rawLine.trim();
        if (clean.isEmpty || clean.startsWith('#') || clean.startsWith('---') || clean.startsWith('|')) {
          continue;
        }
        if (clean.startsWith('- ') || clean.startsWith('* ') || clean.startsWith('• ')) {
          bulletList.add(clean.substring(2).trim());
        }
      }
    }

    return bulletList;
  }

  /// Parses markdown **bold** text inside bullet points and formats with TextSpan
  Widget _buildFormattedMarkdownText(String text, ThemeData theme) {
    final defaultColor = theme.textTheme.bodyMedium?.color ?? Colors.white;
    final onSurfaceColor = theme.colorScheme.onSurface;

    final List<InlineSpan> spans = [];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) continue;

      final isBold = (i % 2 == 1);
      spans.add(
        TextSpan(
          text: part,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? onSurfaceColor : defaultColor.withOpacity(0.90),
            fontSize: 13,
            height: 1.35,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildChangelogList(String rawBody, ThemeData theme, Color accentColor) {
    final bullets = _extractWhatsNewBullets(rawBody);

    if (bullets.isEmpty) {
      return Text(
        "Performance optimizations and general bug fixes.",
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bullets.map((line) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5.5, right: 9.0),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.45),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _buildFormattedMarkdownText(line, theme),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons(ThemeData theme, Color accentColor) {
    return Row(
      key: const ValueKey("actionButtons"),
      children: [
        // Later button
        Expanded(
          flex: 2,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.2) ?? Colors.grey,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              "Later",
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Update Now prominent button
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [accentColor, accentColor.withOpacity(0.85)],
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _startDownload,
              icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
              label: const Text(
                "Update Now",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressState(ThemeData theme, Color accentColor) {
    final downloadedMB = _receivedBytes / (1024 * 1024);
    final totalMB = _totalBytes > 0
        ? _totalBytes / (1024 * 1024)
        : (widget.releaseInfo.fileSize > 0
            ? widget.releaseInfo.fileSize / (1024 * 1024)
            : 0.0);

    return Container(
      key: const ValueKey("progressState"),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Status (left) & Percentage (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _statusMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "${(_progress * 100).toInt()}%",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Linear Progress Indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress <= 0 ? null : _progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 10),

          // Bottom Row: MB downloaded vs total & Cancel button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalMB > 0
                    ? "${downloadedMB.toStringAsFixed(1)} MB / ${totalMB.toStringAsFixed(1)} MB"
                    : "${downloadedMB.toStringAsFixed(1)} MB",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!_downloadFailed)
                InkWell(
                  onTap: _cancelDownload,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      "Cancel",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Error / Fallback Retry buttons
          if (_downloadFailed) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _startDownload,
                    child: const Text("Retry Download", style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.open_in_browser_rounded),
                  tooltip: "Open in browser",
                  onPressed: () {
                    launchUrl(
                      Uri.parse(widget.releaseInfo.downloadUrl),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDontShowAgainRow(ThemeData theme) {
    if (!Get.isRegistered<HomeScreenController>()) return const SizedBox.shrink();
    return GetX<HomeScreenController>(builder: (controller) {
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          controller.onChangeVersionVisibility(controller.showVersionDialog.value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: controller.showVersionDialog.isFalse,
                  onChanged: (val) {
                    controller.onChangeVersionVisibility(val ?? false);
                  },
                  shape: const CircleBorder(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                "dontShowInfoAgain".tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.65),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
