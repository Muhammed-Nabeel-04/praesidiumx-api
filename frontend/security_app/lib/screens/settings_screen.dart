import 'package:flutter/material.dart';
import '../services/api_config.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _controller;
  bool _saved = false;
  String _currentUrl = '';

  // Quick presets
  static const _presets = {
    'Emulator': 'http://10.0.2.2:8000',
    'Localhost': 'http://localhost:8000',
  };

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final url = await ApiConfig.getBaseUrl();
    if (mounted) {
      setState(() {
        _currentUrl = url;
        _controller.text = url;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _controller.text.trim();

    if (url.isEmpty ||
        (!url.startsWith('http://') && !url.startsWith('https://'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("URL must start with http:// or https://"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ApiConfig.setBaseUrl(url);
      await ApiConfig.init();

      final fresh = await ApiConfig.getBaseUrl();

      if (!mounted) return;
      setState(() {
        _currentUrl = fresh;
        _saved = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Saved! Returning to login..."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reset() async {
    await ApiConfig.resetUrl();
    await ApiConfig.init();

    final fresh = await ApiConfig.getBaseUrl();
    if (mounted) {
      setState(() {
        _currentUrl = fresh;
        _controller.text = fresh;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.appBar,
        elevation: 0,
        title: const Text(
          "BACKEND SETTINGS",
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecond,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current URL display ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CURRENT BACKEND",
                          style: TextStyle(
                            color: AppColors.textSecond,
                            fontSize: 10,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),

                        Text(
                          _currentUrl.isEmpty ? "Loading..." : _currentUrl,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Quick presets ────────────────────────────────────
            const Text(
              "QUICK PRESETS",
              style: TextStyle(
                color: AppColors.textSecond,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presets.entries
                  .map(
                    (e) => GestureDetector(
                      onTap: () => setState(() => _controller.text = e.value),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          e.key,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),

            // ── Custom URL input ──────────────────────────────────
            const Text(
              "CUSTOM URL",
              style: TextStyle(
                color: AppColors.textSecond,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: "http://192.168.1.X:8000",
                hintStyle: TextStyle(
                  color: AppColors.textSecond.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                prefixIcon: const Icon(
                  Icons.link_rounded,
                  color: AppColors.textSecond,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Hint ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningDim,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "On real device: run  ipconfig  on PC → use IPv4 WiFi address.\nPC and phone must be on same WiFi.",
                      style: TextStyle(
                        color: AppColors.warning,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Save button ───────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(_saved ? Icons.check_rounded : Icons.save_rounded),
                label: Text(_saved ? "SAVED!" : "SAVE & APPLY"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saved
                      ? AppColors.success
                      : AppColors.primary,
                  foregroundColor: AppColors.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Reset button ──────────────────────────────────────
            GestureDetector(
              onTap: _reset,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textSecond,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "RESET TO DEFAULT",
                      style: TextStyle(
                        color: AppColors.textSecond,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
