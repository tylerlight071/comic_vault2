// lib/widgets/comic_card.dart

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/models/comic.dart';
import '../theme/services/cover_palette_service.dart';
import 'pressable.dart';
import 'skeleton_box.dart';

TextStyle _ui(double size,
        {Color? color,
        FontWeight weight = FontWeight.w500,
        double? height,
        double letterSpacing = 0}) =>
    GoogleFonts.dmSans(
      color: color ?? AppColors.textPrimary,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

class ComicCard extends StatefulWidget {
  final Comic comic;
  final VoidCallback onTap;

  const ComicCard({super.key, required this.comic, required this.onTap});

  @override
  State<ComicCard> createState() => _ComicCardState();
}

class _ComicCardState extends State<ComicCard> {
  // Start at pure black — fades to the palette colour once extracted.
  Color _paletteColor = Colors.black;

  @override
  void initState() {
    super.initState();
    // Defer palette extraction to after the first frame so it doesn't compete
    // with the image decode on the raster thread during grid population.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadPalette();
    });
  }

  @override
  void didUpdateWidget(ComicCard old) {
    super.didUpdateWidget(old);
    // Re-extract if the cover URL changed (e.g. after a vault refresh)
    if (old.comic.coverImageUrl != widget.comic.coverImageUrl) {
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    final color = await CoverPaletteService.instance
        .getColor(widget.comic.coverImageUrl);
    if (mounted) setState(() => _paletteColor = color);
  }

  @override
  Widget build(BuildContext context) {
    final comic = widget.comic;
    return Pressable(
      onTap: widget.onTap,
      haptic: HapticStyle.light,
      scaleDown: 0.95,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Cover image ───────────────────────────────────────────────
            Hero(
              tag: 'cover-${comic.id}',
              child: comic.coverImageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: comic.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonBox.cover(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            // ── Palette-tinted gradient ───────────────────────────────────
            // The bottom stop animates from pure black to the cover's dominant
            // dark colour once the palette has been extracted, giving each card
            // its own colour fingerprint without ever blowing out the text.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      _paletteColor.withOpacity(0.97),
                      Colors.black.withOpacity(0.42),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.52, 1.0],
                  ),
                ),
              ),
            ),

            // ── Bottom text — issue number + series name ──────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(9, 0, 9, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (comic.issueNumber != null)
                      Text(
                        '#${comic.issueNumber}',
                        style: _ui(9,
                            color: Colors.white.withOpacity(0.45),
                            weight: FontWeight.w700,
                            letterSpacing: 0.4),
                      ),
                    const SizedBox(height: 1),
                    Text(
                      comic.seriesName,
                      style: _ui(11,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),

            // ── Top-right badges ──────────────────────────────────────────
            Positioned(
              top: 7,
              right: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (comic.isRead)
                    _badge(
                      child: const Icon(Icons.check_rounded,
                          color: AppColors.greenOwned, size: 12),
                    ),
                  if (comic.starRating > 0) ...[
                    const SizedBox(height: 4),
                    _badge(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: AppColors.gold, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            '${comic.starRating}',
                            style: _ui(10,
                                color: Colors.white,
                                weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: child,
      );

  Widget _placeholder() => Container(
        color: AppColors.surface2,
        child: Center(
          child: Icon(Icons.menu_book_rounded,
              color: AppColors.textDisabled.withOpacity(0.4), size: 36),
        ),
      );
}