import 'package:flutter/material.dart';
import 'package:property/models/quote_request.dart';
import 'package:property/models/property.dart';

/// 견적(QuoteRequest) 라이프사이클 상태 정의 및 헬퍼
class QuoteLifecycleStatus {
  /// 판매자가 견적을 보낸 직후 (아직 답변 없음)
  static const String requested = 'requested';

  /// 여러 중개사 답변이 수집되는 중 (문서 단위보다는 그룹 단위 개념)
  static const String collecting = 'collecting';

  /// 답변을 받은 상태에서 판매자가 비교 중
  static const String comparing = 'comparing';

  /// 판매자가 특정 견적을 선택한 상태
  static const String selected = 'selected';

  /// 실제 상담/거래까지 끝난 상태
  static const String completed = 'completed';

  /// 취소됨
  static const String cancelled = 'cancelled';

  /// 개별 QuoteRequest 문서 기준으로 라이프사이클 단계 계산
  ///
  /// 기존 status(pending/answered/completed/cancelled) + isSelectedByUser + hasAnswer 조합을
  /// 새로운 라이프사이클 개념(requested/comparing/selected/completed/cancelled)으로 매핑한다.
  static String fromQuote(QuoteRequest quote) {
    final rawStatus = quote.status;

    if (rawStatus == 'cancelled') {
      return cancelled;
    }

    // 2) 판매자가 이 견적을 선택했으면 무조건 '선택됨'으로 본다
    if (quote.isSelectedByUser == true) {
      return selected;
    }

    if (rawStatus == 'completed') {
      return completed;
    }

    // 답변이 있으면 판매자 입장에서는 "비교 가능한 상태"
    if (quote.hasAnswer) {
      return comparing;
    }

    // 아직 답변이 없는 경우: 요청만 된 상태
    return requested;
  }

  /// 라이프사이클 라벨 (한국어)
  static String label(String lifecycleStatus) {
    switch (lifecycleStatus) {
      case requested:
        return '요청됨';
      case collecting:
        return '수집중';
      case comparing:
        return '비교중';
      case selected:
        return '선택됨';
      case completed:
        return '완료';
      case cancelled:
        return '취소됨';
      default:
        return lifecycleStatus;
    }
  }

  /// 라이프사이클별 대표 색상
  static Color color(String lifecycleStatus) {
    switch (lifecycleStatus) {
      case requested:
        return const Color(0xFFFFA726); // 주황
      case collecting:
        return const Color(0xFF42A5F5); // 파랑
      case comparing:
        return const Color(0xFF7E57C2); // 보라
      case selected:
        return const Color(0xFF26A69A); // 청록
      case completed:
        return const Color(0xFF66BB6A); // 초록
      case cancelled:
        return const Color(0xFFEF5350); // 빨강
      default:
        return const Color(0xFF9E9E9E); // 회색
    }
  }
}

/// 매물(Property) 라이프사이클 상태 정의 및 헬퍼
///
/// 현재는 `contractStatus`와 `status` 조합을 기반으로 개념상 단계를 계산한다.
class PropertyLifecycleStatus {
  /// 중개사에게 의뢰는 되었지만, 아직 본격 광고 전 단계
  static const String assigned = 'assigned';

  /// 내집구매 등 채널에 노출 중인 상태
  static const String marketing = 'marketing';

  /// 방문/협상/계약 등 실제 거래 진행 중
  static const String negotiating = 'negotiating';

  /// 거래 완료 또는 의뢰 종료
  static const String finished = 'finished';

  /// 일시 보류/예약 상태
  static const String paused = 'paused';

  /// 기존 `contractStatus` / `status` 값을 기반으로 개념상 라이프사이클 단계 추론
  static String fromProperty(Property property) {
    final contract = property.contractStatus;
    final rawStatus = property.status;

    // 명시적으로 finished인 경우 우선
    if (rawStatus == finished) {
      return finished;
    }

    if (contract == '진행중') {
      return negotiating;
    }

    if (contract == '예약' || contract == '보류') {
      return paused;
    }

    // status 필드가 marketing 으로 세팅되어 있으면 광고 중으로 간주
    if (rawStatus == marketing) {
      return marketing;
    }

    // brokerInfo가 있으면 이미 중개사에게 의뢰된 것으로 보고 assigned 로 간주
    if (property.brokerInfo != null || property.brokerId != null) {
      return assigned;
    }

    // 그 외는 일단 assigned 직전 단계로 처리
    return assigned;
  }

  static String label(String lifecycleStatus) {
    switch (lifecycleStatus) {
      case assigned:
        return '의뢰 확정';
      case marketing:
        return '광고 중';
      case negotiating:
        return '계약 진행 중';
      case finished:
        return '거래 완료';
      case paused:
        return '보류/예약';
      default:
        return lifecycleStatus;
    }
  }

  static Color color(String lifecycleStatus) {
    switch (lifecycleStatus) {
      case assigned:
        return const Color(0xFF42A5F5); // 파랑
      case marketing:
        return const Color(0xFF26A69A); // 청록
      case negotiating:
        return const Color(0xFFFFA726); // 주황
      case finished:
        return const Color(0xFF66BB6A); // 초록
      case paused:
        return const Color(0xFFAB47BC); // 보라
      default:
        return const Color(0xFF9E9E9E); // 회색
    }
  }
}


