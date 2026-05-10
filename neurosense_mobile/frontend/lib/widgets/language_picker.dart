import 'package:flutter/material.dart';
import '../services/language_service.dart';
import '../theme/app_theme.dart';

/// Opens a bottom sheet listing every supported language. The current language
/// is highlighted with a checkmark. Picking a language triggers
/// [LanguageService.setLanguage] which batch-translates via the backend on
/// first pick, then caches.
Future<void> showLanguagePicker(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetCtx) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet();
  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String? _pendingChoice;

  @override
  Widget build(BuildContext context) {
    final service = LanguageService.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.language_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Text(tr('Language'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: ListenableBuilder(
                listenable: service,
                builder: (_, __) {
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: LanguageService.supportedLanguages.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (_, i) {
                      final opt = LanguageService.supportedLanguages[i];
                      final isCurrent = opt.englishName == service.currentLanguage;
                      final isPending = service.isLoading && _pendingChoice == opt.englishName;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        title: Text(opt.nativeName,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            )),
                        subtitle: opt.englishName != opt.nativeName
                            ? Text(opt.englishName, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
                            : null,
                        trailing: isPending
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : isCurrent
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                                : const Icon(Icons.radio_button_unchecked, color: AppColors.divider, size: 22),
                        onTap: service.isLoading
                            ? null
                            : () async {
                                setState(() => _pendingChoice = opt.englishName);
                                final messenger = ScaffoldMessenger.of(context);
                                final sheetNav  = Navigator.of(context);
                                try {
                                  await service.setLanguage(opt.englishName);
                                  if (!mounted) return;
                                  sheetNav.pop();
                                } catch (e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(SnackBar(
                                    content: Text('Translation failed: $e'),
                                    backgroundColor: AppColors.riskHigh,
                                  ));
                                  setState(() => _pendingChoice = null);
                                }
                              },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            ListenableBuilder(
              listenable: service,
              builder: (_, __) => service.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text('Translating…',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small chip used on the register page so the user can pick a language before
/// signing up.
class LanguageChipButton extends StatelessWidget {
  const LanguageChipButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LanguageService.instance,
      builder: (context, _) {
        final opt = LanguageService.instance.currentOption;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showLanguagePicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(opt.nativeName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded, size: 16, color: AppColors.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}
