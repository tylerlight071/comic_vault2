// lib/REST API/screens/comic_detail_widgets.dart
part of 'comic_detail_screen.dart';

// ── Cover zoom screen ─────────────────────────────────────────────────────────

class _CoverZoomScreen extends StatelessWidget {
  final String imageUrl;
  final Object heroTag;
  const _CoverZoomScreen({required this.imageUrl, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(
                    color: Colors.white38,
                    strokeWidth: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Price bottom sheet ────────────────────────────────────────────────────────

class _PriceBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  const _PriceBottomSheet({required this.controller});

  @override
  State<_PriceBottomSheet> createState() => _PriceBottomSheetState();
}

class _PriceBottomSheetState extends State<_PriceBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Purchase Price', style: tUi(17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('What did you pay for this comic?',
              style: tUi(13, color: AppColors.textTertiary, weight: FontWeight.w400)),
          const SizedBox(height: 14),
          TextField(
            controller: widget.controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: tUi(16, color: AppColors.textPrimary, weight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: '0.00',
              hintStyle: tUi(16, color: AppColors.textTertiary),
              helperText: 'Enter amount in your local currency',
              helperStyle: tUi(11, color: AppColors.textTertiary),
              filled: true,
              fillColor: AppColors.surface3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.45)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context),
                haptic: HapticStyle.select,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(child: Text('Cancel',
                      style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w600))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context, widget.controller.text),
                haptic: HapticStyle.medium,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text('Save',
                      style: tUi(14, color: AppColors.bg, weight: FontWeight.w700))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Loan bottom sheet ─────────────────────────────────────────────────────────

class _LoanBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  const _LoanBottomSheet({required this.controller});

  @override
  State<_LoanBottomSheet> createState() => _LoanBottomSheetState();
}

class _LoanBottomSheetState extends State<_LoanBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Loan Out', style: tUi(17, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Who are you loaning this to?',
              style: tUi(13, color: AppColors.textTertiary, weight: FontWeight.w400)),
          const SizedBox(height: 14),
          TextField(
            controller: widget.controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: tUi(14, color: AppColors.textPrimary, weight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: 'Person\'s name…',
              hintStyle: tUi(14, color: AppColors.textTertiary),
              prefixIcon: const Icon(Icons.person_outlined,
                  color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: AppColors.surface3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.22)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.45)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context),
                haptic: HapticStyle.select,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(child: Text('Cancel',
                      style: tUi(14, color: AppColors.textSecondary, weight: FontWeight.w600))),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context, widget.controller.text),
                haptic: HapticStyle.medium,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text('Loan Out',
                      style: tUi(14, color: AppColors.bg, weight: FontWeight.w700))),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Notes bottom sheet ────────────────────────────────────────────────────────

class _NotesBottomSheet extends StatefulWidget {
  final TextEditingController controller;
  const _NotesBottomSheet({required this.controller});

  @override
  State<_NotesBottomSheet> createState() => _NotesBottomSheetState();
}

class _NotesBottomSheetState extends State<_NotesBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Notes', style: tUi(17, weight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: widget.controller,
            autofocus: true,
            maxLines: 6,
            style: tUi(14,
                color: AppColors.textPrimary,
                weight: FontWeight.w400,
                height: 1.6),
            decoration: InputDecoration(
              hintText: 'Your thoughts on this issue…',
              hintStyle: tUi(14,
                  color: AppColors.textDisabled, weight: FontWeight.w400),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderFocus),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Pressable(
                onTap: () => Navigator.pop(context),
                haptic: HapticStyle.select,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text('Cancel',
                        style: tUi(14,
                            color: AppColors.textSecondary,
                            weight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                onTap: () =>
                    Navigator.pop(context, widget.controller.text),
                haptic: HapticStyle.medium,
                scaleDown: 0.97,
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Save',
                        style: tUi(14,
                            color: AppColors.bg,
                            weight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
