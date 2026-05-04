#!/usr/bin/env bash
# =============================================================================
# P0-1: migrateTargetBrokerIds 운영 호출 스크립트
# =============================================================================
#
# 본 스크립트는 functions/index.js의 onRequest 함수 `migrateTargetBrokerIds`를
# dryRun 모드로 호출한 뒤, 결과를 검토하고 실제 실행 여부를 운영자에게 묻는다.
#
# 사용법:
#   bash scripts/p0-migration/migrate-target-broker-ids.sh
#
# 환경 변수 (필수):
#   ADMIN_SECRET            — Firebase Functions secret value 'adminSecret'
#   FUNCTIONS_REGION_HOST   — 예: asia-northeast3-houseproject-18f44.cloudfunctions.net
#
# 산출물:
#   scripts/p0-migration/logs/migrate-target-broker-ids-dryrun.json
#   scripts/p0-migration/logs/migrate-target-broker-ids-real.json (실제 실행 시)
# =============================================================================

set -euo pipefail

if [[ -z "${ADMIN_SECRET:-}" ]]; then
  echo "[ERROR] ADMIN_SECRET 환경 변수가 설정되지 않았습니다." >&2
  exit 1
fi
if [[ -z "${FUNCTIONS_REGION_HOST:-}" ]]; then
  echo "[ERROR] FUNCTIONS_REGION_HOST 환경 변수가 설정되지 않았습니다." >&2
  echo "        예: asia-northeast3-houseproject-18f44.cloudfunctions.net" >&2
  exit 1
fi

LOG_DIR="$(dirname "$0")/logs"
mkdir -p "$LOG_DIR"

DRYRUN_LOG="$LOG_DIR/migrate-target-broker-ids-dryrun.json"
REAL_LOG="$LOG_DIR/migrate-target-broker-ids-real.json"

URL_BASE="https://${FUNCTIONS_REGION_HOST}/migrateTargetBrokerIds"

echo "[1/3] dryRun 호출 중..."
curl -sS -G "$URL_BASE" \
  --data-urlencode "secret=${ADMIN_SECRET}" \
  --data-urlencode "dryRun=true" \
  -o "$DRYRUN_LOG"

echo "[2/3] dryRun 결과:"
cat "$DRYRUN_LOG"
echo ""
echo ""
echo "==========================================================="
echo "위 결과를 확인하세요."
echo "  - migratedProperties / createdGrants 가 예상치인가?"
echo "  - skippedNoSellerUid > 0 이면 매도자 권한 누락 위험."
echo "  - sampleProperties 5건의 sellerUid 값이 모두 정상인가?"
echo "==========================================================="
echo ""
read -r -p "실제 실행하시겠습니까? (yes/no): " CONFIRM
if [[ "$CONFIRM" != "yes" ]]; then
  echo "[CANCELLED] 실행을 취소합니다. dryRun 로그만 보존됨: $DRYRUN_LOG"
  exit 0
fi

echo "[3/3] 실제 실행 중 (dryRun=false)..."
curl -sS -G "$URL_BASE" \
  --data-urlencode "secret=${ADMIN_SECRET}" \
  --data-urlencode "dryRun=false" \
  -o "$REAL_LOG"

echo "[DONE] 실행 결과:"
cat "$REAL_LOG"
echo ""
echo "로그: $REAL_LOG"
echo ""
echo "다음 단계: targetBrokerIds 인덱스 2건 삭제"
echo "  firestore.indexes.json 에서 다음 2건 제거:"
echo "    1. mlsProperties (targetBrokerIds CONTAINS, isDeleted ASC, broadcastedAt DESC)"
echo "    2. mlsProperties (targetBrokerIds CONTAINS, isActive ASC, isDeleted ASC, broadcastedAt DESC)"
echo "  → firebase deploy --only firestore:indexes"
