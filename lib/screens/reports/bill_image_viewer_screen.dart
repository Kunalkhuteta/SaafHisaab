import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../globalVar.dart';

class BillImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final List<String> imageUrls;
  final String title;
  final bool isEn;

  const BillImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.imageUrls = const [],
    required this.title,
    required this.isEn,
  });

  @override
  State<BillImageViewerScreen> createState() => _BillImageViewerScreenState();
}

class _BillImageViewerScreenState extends State<BillImageViewerScreen> {
  late final PageController _pageCtrl;
  late final List<String> _images;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _images = widget.imageUrls.isNotEmpty ? widget.imageUrls : [widget.imageUrl];
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    await Share.share(_images[_index], subject: widget.title);
  }

  Future<void> _download(BuildContext context) async {
    final uri = Uri.tryParse(_images[_index]);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLang.tr(
            widget.isEn,
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
        title: Text(
          _images.length > 1
              ? '${widget.title} ${_index + 1}/${_images.length}'
              : widget.title,
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: AppLang.tr(widget.isEn, 'Share', 'Share'),
            onPressed: _share,
            icon: const Icon(Icons.share_rounded),
          ),
          IconButton(
            tooltip: AppLang.tr(widget.isEn, 'Download', 'Download'),
            onPressed: () => _download(context),
            icon: const Icon(Icons.download_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) => Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  _images[index],
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
                          widget.isEn,
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
          ),
          if (_images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_images.length, (index) {
                  final selected = index == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: selected ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
