import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Task 06 — 알고리즘 투명성: 룰북·코드 일관성 검증.
///
/// `docs/public/PRIORITY_RULEBOOK.md` 의 §2.1 가중치 표 6개 변수와 §2.1 임계값,
/// §2.4 한도, §2.3 활동 점수 컷오프가 모두 명시되어 있는지 검사한다.
///
/// 가중치 자체의 *값* 일치는 향후 Agent A 가 `algorithm_config/{version}` 으로
/// 옮긴 뒤 functions/index.js 와 직접 대조하지만, 본 테스트는 *문서가 빠짐없이
/// 명시되어 있는지* (=재현 가능성의 최소조건) 만 검증한다.
void main() {
  group('PRIORITY_RULEBOOK 일관성', () {
    late String content;

    setUpAll(() {
      final file = File('docs/public/PRIORITY_RULEBOOK.md');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'docs/public/PRIORITY_RULEBOOK.md 가 존재해야 합니다.',
      );
      content = file.readAsStringSync();
    });

    test('버전이 v1.5.0 이상으로 표기돼야 한다', () {
      expect(
        content.contains('**버전**: v1.5.0') ||
            content.contains('버전: v1.5.0') ||
            RegExp(r'v1\.5\.\d+').hasMatch(content),
        isTrue,
        reason: '룰북 버전 표기가 v1.5.x 여야 합니다.',
      );
    });

    test('산정 변수 6개가 모두 명시돼야 한다', () {
      const expectedVariables = [
        'timeRank',
        'jurisdictionMatch',
        'licenseStatus',
        'activityScore',
        'distance',
        'capHeadroom',
      ];
      for (final v in expectedVariables) {
        expect(
          content.contains(v),
          isTrue,
          reason: '변수 "$v" 가 룰북에 명시돼 있어야 합니다.',
        );
      }
    });

    test('가중치 6개 (0.45/0.20/0.10×3/0.05) 가 모두 명시돼야 한다', () {
      // 합 = 0.45 + 0.20 + 0.10 + 0.10 + 0.10 + 0.05 = 1.00
      const expectedWeights = ['0.45', '0.20', '0.10', '0.05'];
      for (final w in expectedWeights) {
        expect(
          content.contains(w),
          isTrue,
          reason: '가중치 "$w" 가 룰북에 명시돼 있어야 합니다.',
        );
      }
      // 가중치 합 100% 표기
      expect(
        content.contains('가중치 합 = 1.00') ||
            content.contains('합 = 1.00') ||
            content.contains('합계 1.00'),
        isTrue,
        reason: '가중치 합 = 1.00 이 룰북에 명시돼야 합니다.',
      );
    });

    test('점수 임계값 0.55 가 명시돼야 한다', () {
      expect(
        content.contains('0.55'),
        isTrue,
        reason: '점수 임계값 0.55 가 룰북에 명시돼야 합니다.',
      );
    });

    test('80% 활동 룰 (0.80) 이 명시돼야 한다', () {
      expect(
        content.contains('0.80'),
        isTrue,
        reason: '활동 점수 컷오프 0.80 이 룰북에 명시돼야 합니다.',
      );
    });

    test('5개 한도가 명시돼야 한다', () {
      expect(
        content.contains('5개'),
        isTrue,
        reason: '동시 보유 5개 한도가 룰북에 명시돼야 합니다.',
      );
    });

    test('만료 사유 코드표의 핵심 코드가 모두 명시돼야 한다', () {
      const expectedCodes = [
        'timeout',
        'activity_under_80',
        'revoked_by_self',
        'revoked_by_buyer_switch',
        'cap_exceeded',
        'eligibility_not_found',
        'license_not_verified',
        'jurisdiction_mismatch',
        'score_below_threshold',
        'revoke_cooldown',
        'buyer_switch_cooldown',
        'migrated_legacy',
      ];
      for (final code in expectedCodes) {
        expect(
          content.contains(code),
          isTrue,
          reason: '만료 사유 코드 "$code" 가 룰북에 명시돼야 합니다.',
        );
      }
    });

    test('이의 제기 절차(replayDecision)가 명시돼야 한다', () {
      expect(
        content.contains('replayDecision'),
        isTrue,
        reason: '재현 함수 replayDecision 이 룰북에 명시돼야 합니다.',
      );
    });

    test('1부(80세 어르신용)·2부(정책 상세) 구조가 유지돼야 한다', () {
      expect(
        content.contains('1부') && content.contains('2부'),
        isTrue,
        reason: '1부/2부 구조가 룰북에 유지돼야 합니다.',
      );
    });
  });
}
