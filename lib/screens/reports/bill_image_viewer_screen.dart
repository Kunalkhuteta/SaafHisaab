import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';

class BillImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String title;
  final bool isEn;

  const BillImageViewerScreen({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.isEn,
  });

  Future<void> _share() async {
    await Share.share(imageUrl, subject: title);
  }

  Future<void> _download(BuildContext context) async {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLang.tr(
            isEn,
            'Could not open bill image',
            'Bill image open nahi ho payi',
          )),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: AppLang.tr(isEn, 'Share', 'Share'),
            onPressed: _share,
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: AppLang.tr(isEn, 'Download', 'Download'),
            onPressed: () => _download(context),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const CircularProgressIndicator(color: Colors.white);
            },
            errorBuilder: (_, __, ___) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_rounded,
                    color: Colors.white70, size: 52),
                const SizedBox(height: 12),
                Text(
                  AppLang.tr(
                    isEn,
                    'Bill image not available',
                    'Bill image available nahi hai',
                  ),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
