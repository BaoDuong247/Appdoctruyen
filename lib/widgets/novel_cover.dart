import 'package:flutter/material.dart';

class NovelCover extends StatelessWidget {
  const NovelCover({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  ImageProvider? get provider {
    if (url.startsWith('asset:')) return AssetImage(url.substring(6));
    if (url.startsWith('http://') || url.startsWith('https://'))
      return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = provider;
    if (imageProvider == null) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.auto_stories_rounded,
          size: 38,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return Image(
      image: imageProvider,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          size: 34,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
