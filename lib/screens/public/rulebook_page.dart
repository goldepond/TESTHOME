import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../constants/app_constants.dart';
import '../../constants/spacing.dart';
import '../../constants/typography.dart';

/// 공개 룰북 페이지 (`/rulebook`)
///
/// Task 06(알고리즘 투명성) — 비로그인 접근 가능. 우선권 산정 가중치, 자격
/// 필터, 만료 사유 코드표 등을 마크다운으로 노출한다. 단일 진실원은
/// `docs/public/PRIORITY_RULEBOOK.md` 이며 그대로 asset 으로 등록되어 있다.
class RulebookPage extends StatefulWidget {
  const RulebookPage({super.key});

  @override
  State<RulebookPage> createState() => _RulebookPageState();
}

class _RulebookPageState extends State<RulebookPage> {
  static const String _assetPath = 'docs/public/PRIORITY_RULEBOOK.md';

  late final Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = rootBundle.loadString(_assetPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirbnbColors.surface,
      appBar: AppBar(
        title: Text(
          '차례 정하는 규칙',
          style: AppTypography.withColor(
            AppTypography.h4,
            AirbnbColors.textPrimary,
          ),
        ),
        backgroundColor: AirbnbColors.surface,
        foregroundColor: AirbnbColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: FutureBuilder<String>(
              future: _contentFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _buildError();
                }
                return Markdown(
                  data: snapshot.data!,
                  styleSheet: _buildStyleSheet(context),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: AirbnbColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '규칙 문서를 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
            textAlign: TextAlign.center,
            style: AppTypography.withColor(
              AppTypography.body,
              AirbnbColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
    return base.copyWith(
      h1: AppTypography.withColor(
        AppTypography.h1,
        AirbnbColors.textPrimary,
      ),
      h2: AppTypography.withColor(
        AppTypography.h2,
        AirbnbColors.textPrimary,
      ),
      h3: AppTypography.withColor(
        AppTypography.h3,
        AirbnbColors.textPrimary,
      ),
      h4: AppTypography.withColor(
        AppTypography.h4,
        AirbnbColors.textPrimary,
      ),
      p: AppTypography.withColor(
        AppTypography.body,
        AirbnbColors.textPrimary,
      ),
      listBullet: AppTypography.withColor(
        AppTypography.body,
        AirbnbColors.textPrimary,
      ),
      blockquote: AppTypography.withColor(
        AppTypography.bodySmall,
        AirbnbColors.textSecondary,
      ),
      blockquoteDecoration: const BoxDecoration(
        color: AirbnbColors.surface,
        border: Border(
          left: BorderSide(
            color: AirbnbColors.primary,
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      code: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: AirbnbColors.textPrimary,
        backgroundColor: AirbnbColors.surface,
      ),
      codeblockDecoration: BoxDecoration(
        color: AirbnbColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AirbnbColors.border),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpacing.md),
      tableHead: AppTypography.withColor(
        AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
        AirbnbColors.textPrimary,
      ),
      tableBody: AppTypography.withColor(
        AppTypography.bodySmall,
        AirbnbColors.textPrimary,
      ),
      tableBorder: TableBorder.all(
        color: AirbnbColors.border,
      ),
      tableHeadAlign: TextAlign.left,
      tableCellsPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      horizontalRuleDecoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AirbnbColors.border),
        ),
      ),
    );
  }
}
