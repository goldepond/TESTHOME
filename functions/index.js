/**
 * MyHome Cloud Functions
 *
 * Firestore notifications 컬렉션에 문서가 추가되면
 * 해당 사용자에게 FCM 푸시 알림을 전송합니다.
 */

const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const axios = require("axios");
const cors = require("cors")({ origin: true });
const ngeohash = require("ngeohash");

// Firebase Admin 초기화
initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const auth = getAuth();

// 관리자 설정 시크릿 (firebase functions:secrets:set ADMIN_SECRET 로 설정)
const adminSecret = defineSecret("ADMIN_SECRET");

/**
 * 관리자 Custom Claims 설정 (Callable Function)
 *
 * 사용법:
 * 1. 먼저 시크릿 설정: firebase functions:secrets:set ADMIN_SECRET
 * 2. 함수 배포: firebase deploy --only functions
 * 3. 클라이언트에서 호출 시 secret 파라미터에 시크릿 값 전달
 *
 * 요청 파라미터:
 *   - targetUid: 관리자로 지정할 사용자 UID
 *   - secret: ADMIN_SECRET 값
 *   - revoke: true면 관리자 권한 해제 (선택사항)
 */
exports.setAdminClaim = onCall(
  { region: "asia-northeast3", secrets: [adminSecret] },
  async (request) => {
    const { targetUid, secret, revoke } = request.data;

    // 시크릿 검증
    if (!secret || secret !== adminSecret.value()) {
      throw new HttpsError("permission-denied", "Invalid admin secret");
    }

    if (!targetUid) {
      throw new HttpsError("invalid-argument", "targetUid is required");
    }

    try {
      if (revoke) {
        // 관리자 권한 해제
        await auth.setCustomUserClaims(targetUid, { admin: false });
        console.log(`Admin claim revoked for user: ${targetUid}`);
        return { success: true, message: `Admin revoked for ${targetUid}` };
      }

      // 관리자 권한 부여
      await auth.setCustomUserClaims(targetUid, { admin: true });
      console.log(`Admin claim set for user: ${targetUid}`);
      return { success: true, message: `Admin granted for ${targetUid}` };
    } catch (error) {
      console.error("Error setting admin claim:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

/**
 * notifications 컬렉션에 새 문서가 생성되면 푸시 알림 전송
 *
 * 리전 정렬: Task 002 Phase 3 — 다른 34개 함수와 동일한 asia-northeast3로 통일.
 * 운영팀 후속 명령(배포 직후 1회): firebase functions:delete sendPushNotification --region us-central1 --force
 */
exports.sendPushNotification = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "notifications/{notificationId}",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return;
    }

    const notification = snapshot.data();
    const userId = notification.userId;
    const title = notification.title || "알림";
    const body = notification.message || "";
    const type = notification.type || "general";
    const relatedId = notification.relatedId;

    if (!userId) {
      console.log("No userId in notification");
      return;
    }

    try {
      // 사용자의 FCM 토큰 가져오기 (users → brokers 순서로 확인)
      let fcmToken = null;
      let tokenSource = "users";

      const userDoc = await db.collection("users").doc(userId).get();
      if (userDoc.exists) {
        fcmToken = userDoc.data().fcmToken;
      }

      // users에서 못 찾으면 brokers 컬렉션도 확인
      if (!fcmToken) {
        const brokerDoc = await db.collection("brokers").doc(userId).get();
        if (brokerDoc.exists) {
          fcmToken = brokerDoc.data().fcmToken;
          tokenSource = "brokers";
        }
      }

      if (!fcmToken) {
        console.log(`No FCM token for user ${userId} in users or brokers`);
        return;
      }

      // FCM 메시지 구성
      const message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          type: type,
          relatedId: relatedId || "",
          notificationId: event.params.notificationId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "myhome_notifications",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              badge: 1,
              sound: "default",
            },
          },
        },
      };

      // 푸시 알림 전송
      const response = await messaging.send(message);
      console.log(`Successfully sent push to ${userId}:`, response);

      // 전송 성공 기록 (선택)
      await snapshot.ref.update({
        pushSentAt: new Date(),
        pushSuccess: true,
      });

    } catch (error) {
      console.error(`Error sending push to ${userId}:`, error);

      // 토큰이 만료된 경우 삭제
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        console.log(`Removing invalid token for user ${userId} from ${tokenSource}`);
        await db.collection(tokenSource).doc(userId).update({
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        });
      }

      // 전송 실패 기록
      await snapshot.ref.update({
        pushSentAt: new Date(),
        pushSuccess: false,
        pushError: error.message,
      });
    }
  }
);

// sendBrokerPushNotification 제거됨:
// brokerNotifications 컬렉션은 앱에서 사용하지 않음.
// 모든 알림(중개사 포함)은 notifications 컬렉션을 통해 sendPushNotification에서 처리.
// sendPushNotification은 users → brokers 순서로 FCM 토큰을 조회하므로 중개사 알림도 정상 동작.

/**
 * FCM 전송 헬퍼 함수
 */
async function sendFCM(fcmToken, title, body, notification, notificationId, docRef) {
  const message = {
    token: fcmToken,
    notification: { title, body },
    data: {
      type: notification.type || "general",
      relatedId: notification.relatedId || "",
      notificationId: notificationId,
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "myhome_notifications",
        priority: "high",
      },
    },
    apns: {
      payload: {
        aps: {
          alert: { title, body },
          badge: 1,
          sound: "default",
        },
      },
    },
  };

  const response = await messaging.send(message);
  console.log("Push sent successfully:", response);

  await docRef.update({
    pushSentAt: new Date(),
    pushSuccess: true,
  });
}

// 캐시 설정
const CACHE_TTL_HOURS = 6; // 실거래가 API 캐시 TTL (시간)
const CACHE_COLLECTION = "apiCache";

/**
 * 캐시 키 생성 (URL에서 ServiceKey 제외)
 */
function generateCacheKey(url) {
  try {
    const urlObj = new URL(url);
    const params = new URLSearchParams(urlObj.search);
    // ServiceKey는 캐시 키에서 제외 (보안 + 동일 요청 매칭)
    params.delete("ServiceKey");
    return `${urlObj.pathname}_${params.toString()}`.replace(/[\/\?&=]/g, "_");
  } catch {
    return null;
  }
}

/**
 * Firestore에서 캐시 조회
 */
async function getCache(cacheKey) {
  try {
    const doc = await db.collection(CACHE_COLLECTION).doc(cacheKey).get();
    if (!doc.exists) return null;

    const data = doc.data();
    const cachedAt = data.cachedAt?.toDate();
    if (!cachedAt) return null;

    // TTL 확인
    const ageHours = (Date.now() - cachedAt.getTime()) / (1000 * 60 * 60);
    if (ageHours > CACHE_TTL_HOURS) {
      console.log(`[Cache] Expired: ${cacheKey} (${ageHours.toFixed(1)}h old)`);
      return null;
    }

    console.log(`[Cache] Hit: ${cacheKey} (${ageHours.toFixed(1)}h old)`);
    return data.response;
  } catch (error) {
    console.error("[Cache] Get error:", error.message);
    return null;
  }
}

/**
 * Firestore에 캐시 저장
 */
async function setCache(cacheKey, response) {
  try {
    await db.collection(CACHE_COLLECTION).doc(cacheKey).set({
      response: response,
      cachedAt: new Date(),
    });
    console.log(`[Cache] Saved: ${cacheKey}`);
  } catch (error) {
    console.error("[Cache] Set error:", error.message);
  }
}

/**
 * 캐시 가능한 API인지 확인
 */
function isCacheableApi(url) {
  // 국토부 실거래가 API만 캐싱
  return url.includes("apis.data.go.kr") &&
         (url.includes("RTMSDataSvc") || url.includes("실거래"));
}

/**
 * CORS 프록시 함수 (서버 사이드 캐싱 포함)
 * Flutter 웹에서 외부 API(JUSO 등) 호출 시 CORS 우회용
 *
 * 사용법: /proxy?q=<encoded_url>
 */
exports.proxy = onRequest(
  {
    region: "asia-northeast3",
    cors: true,
  },
  async (req, res) => {
    // CORS 처리
    cors(req, res, async () => {
      try {
        const targetUrl = req.query.q;

        if (!targetUrl) {
          res.status(400).json({ error: "Missing 'q' parameter" });
          return;
        }

        // URL 디코딩
        const decodedUrl = decodeURIComponent(targetUrl);
        console.log(`[Proxy] Fetching: ${decodedUrl}`);

        // data.go.kr API는 + 문자가 %2B로 인코딩되어야 함
        // URL의 query string에서 + 문자를 %2B로 치환
        const urlParts = decodedUrl.split("?");
        let finalUrl = decodedUrl;
        if (urlParts.length > 1) {
          const baseUrl = urlParts[0];
          const queryString = urlParts.slice(1).join("?");
          // + 문자를 %2B로 치환 (ServiceKey 등에 포함된 + 처리)
          const encodedQuery = queryString.replace(/\+/g, "%2B");
          finalUrl = `${baseUrl}?${encodedQuery}`;
        }
        console.log(`[Proxy] Final URL: ${finalUrl}`);

        // 허용된 도메인 체크 (보안)
        const allowedDomains = [
          "business.juso.go.kr",
          "api.vworld.kr",
          "apis.data.go.kr",
          "openapi.seoul.go.kr",
          "map.vworld.kr",
        ];

        const url = new URL(decodedUrl);
        if (!allowedDomains.some(domain => url.hostname.includes(domain))) {
          console.log(`[Proxy] Blocked domain: ${url.hostname}`);
          res.status(403).json({ error: "Domain not allowed" });
          return;
        }

        // 서버 사이드 캐싱 (국토부 실거래가 API만)
        if (isCacheableApi(decodedUrl)) {
          const cacheKey = generateCacheKey(decodedUrl);
          if (cacheKey) {
            // 캐시 확인
            const cachedResponse = await getCache(cacheKey);
            if (cachedResponse) {
              res.set("X-Cache", "HIT");
              res.status(200).json(cachedResponse);
              return;
            }

            // 외부 API 호출
            const response = await axios.get(finalUrl, {
              timeout: 15000,
              headers: {
                "Accept": "application/json",
                "Accept-Encoding": "gzip, deflate",
              },
            });

            console.log(`[Proxy] Success: ${response.status}`);

            // 성공 응답만 캐시
            if (response.status === 200 && response.data) {
              // 비동기로 캐시 저장 (응답 지연 방지)
              setCache(cacheKey, response.data);
            }

            res.set("X-Cache", "MISS");
            res.status(response.status).json(response.data);
            return;
          }
        }

        // 캐싱하지 않는 API는 바로 호출
        const response = await axios.get(finalUrl, {
          timeout: 10000,
          headers: {
            "Accept": "application/json",
            "Accept-Encoding": "gzip, deflate",
          },
        });

        console.log(`[Proxy] Success: ${response.status}`);

        // 응답 반환
        res.status(response.status).json(response.data);

      } catch (error) {
        console.error("[Proxy] Error:", error.message);

        if (error.response) {
          // 서버에서 에러 응답을 받은 경우
          res.status(error.response.status).json({
            error: error.message,
            data: error.response.data,
          });
        } else if (error.code === "ECONNABORTED") {
          res.status(504).json({ error: "Gateway timeout" });
        } else {
          res.status(500).json({ error: error.message });
        }
      }
    });
  }
);

// ============================================================================
// Task 01 — Priority Grant 데이터 모델 Cloud Functions
// ============================================================================
//
// 명세: docs/task/01-data-model.md §8
// 컬렉션: priority_grants, broker_eligibility, priority_audit_logs
//
// 핵심 원칙:
//  - 모든 grant 생성/만료/취소는 audit log와 동일 트랜잭션에 기록 (안티패턴 §10)
//  - 클라이언트는 grant를 직접 생성/수정/삭제 불가 (Functions only)
//  - 보수/수수료 관련 필드 일절 도입 금지
//  - targetBrokerIds는 read-only (마이그레이션 함수에서 읽기만)
// ============================================================================

// Task 06: 알고리즘 설정 저장 위치를 코드 상수에서 Firestore(algorithm_config/active)로
// 이전. MATCHING_WEIGHTS / MATCHING_THRESHOLD / MATCHING_VERSION 자체 값은 변경 없음
// (matching_v1.3.0 동일). 룰북 의미가 바뀌었으므로 RULEBOOK_VERSION 만 v1.5.0 으로 bump.
const RULEBOOK_VERSION = "v1.5.0";
const DEFAULT_GRANT_TTL_DAYS = 14;

// Task 04 — 지역 단계 노출 (Tiered Release)
// 매물 등록 후 1km → 동(region) → 인접(시군구 내 다른 동) → 시군구(district) 순으로
// 단계적으로 알림 노출 범위를 확장한다. exclusive 매물은 전 단계 skip.
const TIER_DURATIONS_MS = {
  tier1_1km: 24 * 60 * 60 * 1000, // 24h
  tier2_dong: 24 * 60 * 60 * 1000, // 24h
  tier3_adjacent: 48 * 60 * 60 * 1000, // 48h
};
const TIER_RADIUS_KM = 1.0;
const GEOHASH_PRECISION = 7;
const TIER_ORDER = ["tier1_1km", "tier2_dong", "tier3_adjacent", "tier4_district"];
// Task 03 — M1.2 매수자-중개사 매칭은 *체결 단계* 우선권이라 더 긴 TTL을 갖는다.
// 명세 03-m1-buyer-broker.md §4 — "expiresAt = now + 30일".
const BUYER_MATCH_TTL_DAYS = 30;
const DEFAULT_ACTIVE_GRANTS_CAP = 5;
const ACTIVITY_RULE_DAYS = 7;
const ACTIVITY_RULE_THRESHOLD = 0.8;

// P1-3: activityScore 자동 갱신 가산치 (Task 02 §3.2 정의)
//
// 정책 (명세 02-m1-seller-broker.md §3.2):
//   - participation 단계: 7일 내 임장 요청 1건 이상 → 0.8 / 매수자 컨택 추가 → 1.0
//   - visit 단계: 14일 내 매수자 매칭 1건 → 0.8 / 의향서 단계 진척 → 1.0
//
// 본 가산치는 *증분식* 누적이며 0~1 clamp.
//   - visit_request approved/scheduled  → +0.4 (임장 단계 진척)
//   - broker_participations advanced to visit_scheduled → +0.4 (위와 동일 경로의 미러)
//   - brokerOffer 생성                   → +0.6 (의향서 단계 — 더 큰 진척)
//   - broker_participations advanced to offer_made → +0.6
//
// enforceActivityRule(0.8 미만 + 7일 경과 → expired) 와 충돌 없도록 *오직 가산만* 한다.
// 직접 감산 / 0 으로 리셋 하는 경로는 본 P1-3 에서 도입하지 않는다.
const ACTIVITY_SCORE_DELTA_VISIT = 0.4;
const ACTIVITY_SCORE_DELTA_OFFER = 0.6;

// 우선권 자진 만료 후 동일 매물 재참여 쿨다운 (시간 단위)
const REVOKE_COOLDOWN_HOURS = 24;
// Task 03 — 매수자가 동일 inquiry에서 중개사를 *교체* 시도할 때 적용되는 쿨다운.
// 한 매수자가 24h 내 반복적으로 중개사를 갈아치우는 악용 패턴 방지 (명세 §4 #4).
const BUYER_SWITCH_COOLDOWN_HOURS = 24;

// 사유 코드 (Reason codes) — 클라이언트 카피 매핑 진실원
const REASON = {
  // 발급/거절
  ELIGIBILITY_NOT_FOUND: "eligibility_not_found",
  LICENSE_NOT_VERIFIED: "license_not_verified",
  JURISDICTION_MISMATCH: "jurisdiction_mismatch",
  CAP_EXCEEDED: "cap_exceeded",
  ALREADY_GRANTED: "already_granted",
  REVOKE_COOLDOWN: "revoke_cooldown",
  SCORE_BELOW_THRESHOLD: "score_below_threshold",
  // 자진 만료
  REVOKED_BY_SELF: "revoked_by_self",
  NOT_GRANT_OWNER: "not_grant_owner",
  GRANT_NOT_ACTIVE: "grant_not_active",
  // 시스템 만료
  TIMEOUT: "timeout",
  ACTIVITY_UNDER_80: "activity_under_80",
  MIGRATED_LEGACY: "migrated_legacy",
  // Task 03 — 매수자-중개사 매칭
  BUYER_NOT_OWNER: "buyer_not_owner",
  INQUIRY_NOT_FOUND: "inquiry_not_found",
  BUYER_SWITCH_COOLDOWN: "buyer_switch_cooldown",
  BUYER_SWITCH_REQUIRED: "buyer_switch_required",
  REVOKED_BY_BUYER_SWITCH: "revoked_by_buyer_switch",
  // Task 07 — 매도자 자율 단독 지정 (Open / Exclusive Listing)
  // 법무 라인: MyHome이 지정 = §33①9호 위반. 매도자 자율 = 합법.
  // 따라서 *모든* 거절 사유는 매도자 자율의 결과임을 분명히 표현한다.
  NOT_IN_EXCLUSIVE_LIST: "not_in_exclusive_list",
  EXCLUSIVE_HAS_ACTIVE_GRANT: "exclusive_has_active_grant",
  EXCLUSIVE_BROKER_LIMIT_EXCEEDED: "exclusive_broker_limit_exceeded",
  EXCLUSIVE_COOLDOWN: "exclusive_cooldown",
  EXCLUSIVE_BROKER_NOT_VERIFIED: "exclusive_broker_not_verified",
  NOT_PROPERTY_OWNER: "not_property_owner",
  INVALID_LISTING_MODE: "invalid_listing_mode",
  EXCLUSIVE_CONSENT_REQUIRED: "exclusive_consent_required",
};

// Task 07 — 매도자가 listingMode/exclusiveBrokerIds 를 변경한 뒤 24h 쿨다운.
// 한 매도자가 24h 내에 반복적으로 지정/해제하며 우선권 흐름을 흔드는 악용 방지.
const LISTING_MODE_CHANGE_COOLDOWN_HOURS = 24;
const EXCLUSIVE_BROKER_MAX = 3;

// Dynamic Matching 가중치 — Task 06 부터 algorithm_config/active 컬렉션이 *진실원*.
// 아래 상수는 (1) bootstrap 초기값, (2) Firestore read 실패 시 폴백 안전망 으로만 사용.
// 가중치/임계값을 변경하려면 algorithm_config/active 문서를 update + audit log 기록하고
// 새 버전을 algorithm_config/{newVersion} 에 아카이브해야 한다 (RULEBOOK_VERSION 도 함께 bump).
const MATCHING_WEIGHTS = {
  time: 0.45,
  jurisdiction: 0.20,
  license: 0.10,
  activity: 0.10,
  distance: 0.10,
  capHeadroom: 0.05,
};
const MATCHING_THRESHOLD = 0.55;
const MATCHING_VERSION = "matching_v1.3.0";

// Task 06 — algorithm_config 메모리 캐시 (Functions 인스턴스 단위, 5분 TTL).
// 본 캐시는 단일 인스턴스에 한정되므로 다중 인스턴스 환경에서도 5분 안에 전파된다.
let _matchingConfigCache = null;
let _matchingConfigCachedAt = 0;
const MATCHING_CONFIG_TTL_MS = 5 * 60 * 1000;

/**
 * Task 06 — algorithm_config/active 로부터 현재 활성 가중치/임계값/버전 로드.
 *
 * 캐시 hit (TTL 5분) → 캐시 반환.
 * 문서 없음 → bootstrap: 코드 상수로 active + {version} 두 문서 set + audit log
 *   (eventType: 'algorithm_config_bootstrapped') 1건.
 * 문서 있음 → 그대로 반환 + 캐시.
 *
 * 반환: { version, weights, threshold, updatedAt? }
 *
 * 폴백: read 자체가 실패하면 코드 상수로 응답 (가용성 우선). 이 경우 캐시 갱신은 skip.
 */
async function loadMatchingConfig() {
  const nowMs = Date.now();
  if (_matchingConfigCache && nowMs - _matchingConfigCachedAt < MATCHING_CONFIG_TTL_MS) {
    return _matchingConfigCache;
  }

  const activeRef = db.collection("algorithm_config").doc("active");
  try {
    const activeSnap = await activeRef.get();
    if (activeSnap.exists) {
      const data = activeSnap.data() || {};
      const config = {
        version: data.version || MATCHING_VERSION,
        weights: data.weights || MATCHING_WEIGHTS,
        threshold: typeof data.threshold === "number" ? data.threshold : MATCHING_THRESHOLD,
        updatedAt: data.updatedAt || null,
      };
      _matchingConfigCache = config;
      _matchingConfigCachedAt = nowMs;
      return config;
    }

    // Bootstrap — 최초 1회: 코드 상수로 Firestore 두 문서 + audit log 채움.
    const now = Timestamp.now();
    const bootstrapData = {
      version: MATCHING_VERSION,
      weights: MATCHING_WEIGHTS,
      threshold: MATCHING_THRESHOLD,
      updatedAt: now,
      updatedBy: "system_bootstrap",
      changelog: "Initial bootstrap from code constants (Task 06).",
    };
    const versionRef = db.collection("algorithm_config").doc(MATCHING_VERSION);
    const auditRef = newAuditLogRef();
    const batch = db.batch();
    batch.set(activeRef, bootstrapData);
    batch.set(versionRef, bootstrapData);
    batch.set(auditRef, {
      eventId: auditRef.id,
      eventType: "algorithm_config_bootstrapped",
      actorUid: null,
      propertyId: null,
      brokerId: null,
      sellerUid: null,
      grantId: null,
      inputs: { trigger: "loadMatchingConfig", reason: "active_doc_missing" },
      outputs: {
        version: MATCHING_VERSION,
        weights: MATCHING_WEIGHTS,
        threshold: MATCHING_THRESHOLD,
      },
      rulebookVersion: RULEBOOK_VERSION,
      createdAt: now,
    });
    try {
      await batch.commit();
    } catch (e) {
      console.error("[loadMatchingConfig] bootstrap batch failed:", e.message);
    }

    const config = {
      version: MATCHING_VERSION,
      weights: MATCHING_WEIGHTS,
      threshold: MATCHING_THRESHOLD,
      updatedAt: now,
    };
    _matchingConfigCache = config;
    _matchingConfigCachedAt = nowMs;
    return config;
  } catch (e) {
    console.error("[loadMatchingConfig] read failed, fallback to constants:", e.message);
    return {
      version: MATCHING_VERSION,
      weights: MATCHING_WEIGHTS,
      threshold: MATCHING_THRESHOLD,
      updatedAt: null,
    };
  }
}

/**
 * 헬퍼: 일(day) 단위를 millis로 변환한 후 Timestamp에 더한다.
 */
function addDaysToTimestamp(baseTs, days) {
  const baseMillis = baseTs.toMillis();
  const futureMillis = baseMillis + days * 24 * 60 * 60 * 1000;
  return Timestamp.fromMillis(futureMillis);
}

/**
 * 헬퍼: 시간(hour) 단위를 millis로 변환한 후 Timestamp에 더한다.
 */
function addHoursToTimestamp(baseTs, hours) {
  const baseMillis = baseTs.toMillis();
  const futureMillis = baseMillis + hours * 60 * 60 * 1000;
  return Timestamp.fromMillis(futureMillis);
}

/**
 * 헬퍼: 입력값을 [0, 1] 범위로 클램프. NaN/비숫자는 0.
 */
function clamp01(x) {
  if (typeof x !== "number" || Number.isNaN(x)) return 0;
  return Math.max(0, Math.min(1, x));
}

/**
 * 헬퍼: Dynamic Matching 점수 계산.
 *
 * 입력:
 *   - timeRank: 0~1 (1.0이 가장 빠른 참여)
 *   - jurisdictionMatch: bool (관할 일치 여부)
 *   - licenseStatus: 'verified' | 'pending' | 'invalid' | ...
 *   - activityScore: 0~1 (기본 0.5)
 *   - distanceKm: number (10km 이상은 0)
 *   - capHeadroom: 0~1 (남은 cap 비율, 기본 1)
 *
 * 반환: { score, breakdown, weights, threshold, version, rawInputs }
 */
function computeMatchingScore(inputs, configOverride) {
  const time = clamp01(inputs.timeRank ?? 0);
  const jurisdiction = inputs.jurisdictionMatch ? 1.0 : 0.0;
  const license = inputs.licenseStatus === "verified" ? 1.0 : 0.0;
  const activity = clamp01(inputs.activityScore ?? 0.5);
  // distanceKm 작을수록 점수 ↑, 10km 이상은 0
  const distanceKm = inputs.distanceKm ?? 0;
  const distance = clamp01(1 - Math.min(distanceKm, 10) / 10);
  const capHeadroom = clamp01(inputs.capHeadroom ?? 1);

  // Task 06 — configOverride 가 주어지면 그것을 사용, 없으면 코드 상수 폴백.
  const w = (configOverride && configOverride.weights) || MATCHING_WEIGHTS;
  const threshold = configOverride && typeof configOverride.threshold === "number"
    ? configOverride.threshold
    : MATCHING_THRESHOLD;
  const version = (configOverride && configOverride.version) || MATCHING_VERSION;

  const breakdown = {
    time: time * (w.time ?? 0),
    jurisdiction: jurisdiction * (w.jurisdiction ?? 0),
    license: license * (w.license ?? 0),
    activity: activity * (w.activity ?? 0),
    distance: distance * (w.distance ?? 0),
    capHeadroom: capHeadroom * (w.capHeadroom ?? 0),
  };
  const score = Object.values(breakdown).reduce((a, b) => a + b, 0);
  return {
    score,
    breakdown,
    weights: w,
    threshold,
    version,
    rawInputs: { time, jurisdiction, license, activity, distance, capHeadroom },
  };
}

/**
 * Task 06 — replay 전용 보조 헬퍼.
 *
 * priority_grants/{id}.scoringInputs.rawInputs 는 이미 0~1 정규화된 값이므로,
 * 가중치만 다시 적용해 score/breakdown 을 재계산한다 (정규화 재적용 X).
 *
 * 입력:
 *   - rawInputs: { time, jurisdiction, license, activity, distance, capHeadroom } (0~1)
 *   - config: { weights, threshold, version }
 *
 * 반환: { score, breakdown, weights, threshold, version, rawInputs }
 */
function computeMatchingScoreFromRawInputs(rawInputs, config) {
  const w = (config && config.weights) || MATCHING_WEIGHTS;
  const threshold = config && typeof config.threshold === "number"
    ? config.threshold
    : MATCHING_THRESHOLD;
  const version = (config && config.version) || MATCHING_VERSION;
  const r = rawInputs || {};
  const time = clamp01(r.time ?? 0);
  const jurisdiction = clamp01(r.jurisdiction ?? 0);
  const license = clamp01(r.license ?? 0);
  const activity = clamp01(r.activity ?? 0);
  const distance = clamp01(r.distance ?? 0);
  const capHeadroom = clamp01(r.capHeadroom ?? 0);
  const breakdown = {
    time: time * (w.time ?? 0),
    jurisdiction: jurisdiction * (w.jurisdiction ?? 0),
    license: license * (w.license ?? 0),
    activity: activity * (w.activity ?? 0),
    distance: distance * (w.distance ?? 0),
    capHeadroom: capHeadroom * (w.capHeadroom ?? 0),
  };
  const score = Object.values(breakdown).reduce((a, b) => a + b, 0);
  return {
    score,
    breakdown,
    weights: w,
    threshold,
    version,
    rawInputs: { time, jurisdiction, license, activity, distance, capHeadroom },
  };
}

/**
 * 헬퍼: priority_audit_logs 신규 문서 ref 생성.
 */
function newAuditLogRef() {
  return db.collection("priority_audit_logs").doc();
}

/**
 * P2-4 헬퍼: scoringInputs.rawInputs 를 client-readable 한 줄 직렬 형식으로 변환.
 *
 * 출력 예: 'jurisdiction=0;license=verified;activity=0.20;capHeadroom=0.50;timeRank=0.40;distance=0.80'
 *
 * 클라이언트(GrantMessages.extractScoringInputs)가 이 문자열을
 * Map<String, dynamic> 으로 파싱해 describeScoringFailure 로 80세 화법 변환.
 *
 * 점수/threshold/총점 *값* 은 포함하지 않는다 — 그것은 *내부 감사용* 이며
 * 사용자에게 직접 노출되어선 안 됨 (copy-deck §0 80세 노인 테스트).
 * rawInputs 의 0~1 정규화 값은 *클라가 재해석* 하는 통로일 뿐 — 이 자체가
 * 점수가 아니라 *어느 변수가 가장 부족한지 분기를 위한 입력* 이다.
 */
function serializeRawInputs(rawInputs, licenseStatus) {
  if (!rawInputs || typeof rawInputs !== "object") return "";
  const parts = [];
  // jurisdiction (bool 또는 0/1)
  if ("jurisdiction" in rawInputs) {
    parts.push(`jurisdiction=${rawInputs.jurisdiction === 1 || rawInputs.jurisdiction === true ? 1 : 0}`);
  }
  // license — string 형식이 더 명확하므로 licenseStatus 우선.
  if (typeof licenseStatus === "string") {
    parts.push(`license=${licenseStatus}`);
  } else if ("license" in rawInputs) {
    parts.push(`license=${rawInputs.license.toFixed(2)}`);
  }
  // activity / distance / capHeadroom / time — 0~1 정규화.
  for (const key of ["activity", "distance", "capHeadroom", "time"]) {
    if (key in rawInputs && typeof rawInputs[key] === "number") {
      parts.push(`${key === "time" ? "timeRank" : key}=${rawInputs[key].toFixed(2)}`);
    }
  }
  return parts.join(";");
}

/**
 * 헬퍼: 동일 (propertyId, type, stage[, buyerInquiryId])로 active grant 존재 여부 확인.
 *
 * 트랜잭션 외부에서 1차 인덱스 쿼리로 후보를 좁힌 뒤, 트랜잭션 내부에서 다시 검증한다.
 * (트랜잭션 내 쿼리는 firestore-admin SDK에서 가능하지만, 인덱스 쿼리 결과 일관성을
 *  보장하기 위해 후보 ref를 트랜잭션에 전달.)
 */
async function findConflictingActiveGrants({ propertyId, type, stage, buyerInquiryId }) {
  let query = db
    .collection("priority_grants")
    .where("propertyId", "==", propertyId)
    .where("type", "==", type)
    .where("stage", "==", stage)
    .where("status", "==", "active");

  const snapshot = await query.get();
  if (snapshot.empty) return [];

  // M1.2 (buyer_match)는 buyerInquiryId까지 동일할 때만 충돌
  if (type === "buyer_match" && buyerInquiryId) {
    return snapshot.docs.filter(
      (doc) => doc.data().buyerInquiryId === buyerInquiryId
    );
  }
  return snapshot.docs;
}

/**
 * 1.1 issuePriorityGrant (callable)
 *
 * 자격·5개 한도·중복·쿨다운·매칭 점수 검증 후 priority_grants 문서 생성 + audit log 동시 기록.
 *
 * 입력:
 *   - propertyId: string (필수)
 *   - brokerId: string (필수, 본인 brokerId 또는 brokerUid가 caller uid와 일치해야 함)
 *   - type: 'seller_match' | 'buyer_match' (필수)
 *   - stage: 'participation' | 'visit' | 'offer' (필수)
 *   - buyerInquiryId: string (type='buyer_match'일 때 필수)
 *   - scoringInputs: map (선택, 기본 {}) — distanceKm 등 클라이언트가 알 수 있는 보조 입력
 *
 * 인증: request.auth 필수. 본인 brokerId만 발급 가능 (admin-only 체크는 Task 02에서 제거).
 *
 * 거절 사유는 REASON 코드로 메시지 prefix를 붙여 클라이언트가 카피 매핑할 수 있게 한다.
 */
exports.issuePriorityGrant = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {
      propertyId,
      brokerId,
      type,
      stage,
      buyerInquiryId,
      scoringInputs,
    } = request.data || {};

    // 입력 검증
    if (!propertyId || typeof propertyId !== "string") {
      throw new HttpsError("invalid-argument", "propertyId is required");
    }
    if (!brokerId || typeof brokerId !== "string") {
      throw new HttpsError("invalid-argument", "brokerId is required");
    }
    if (!["seller_match", "buyer_match"].includes(type)) {
      throw new HttpsError(
        "invalid-argument",
        "type must be 'seller_match' or 'buyer_match'"
      );
    }
    if (!["participation", "visit", "offer"].includes(stage)) {
      throw new HttpsError(
        "invalid-argument",
        "stage must be 'participation' | 'visit' | 'offer'"
      );
    }
    if (type === "buyer_match" && !buyerInquiryId) {
      throw new HttpsError(
        "invalid-argument",
        "buyerInquiryId is required for type='buyer_match'"
      );
    }

    // 사전 충돌 후보 조회 (트랜잭션 내에서 다시 검증)
    const conflictDocs = await findConflictingActiveGrants({
      propertyId,
      type,
      stage,
      buyerInquiryId,
    });
    const conflictRefs = conflictDocs.map((d) => d.ref);

    // 사전 쿨다운 검증: 동일 (propertyId, brokerUid)로 최근 자진 만료된 grant가 있는지 확인.
    // 트랜잭션 외부에서 1차 조회 후 트랜잭션 내부에서 다시 검사한다.
    const cooldownSnap = await db
      .collection("priority_grants")
      .where("propertyId", "==", propertyId)
      .where("brokerUid", "==", request.auth.uid)
      .where("status", "==", "revoked")
      .orderBy("revokedAt", "desc")
      .limit(1)
      .get();
    const cooldownRef = cooldownSnap.empty ? null : cooldownSnap.docs[0].ref;

    const propertyRef = db.collection("mlsProperties").doc(propertyId);
    const eligibilityRef = db.collection("broker_eligibility").doc(brokerId);

    const grantId = `pg_${Date.now()}_${brokerId}`;
    const grantRef = db.collection("priority_grants").doc(grantId);
    const auditRef = newAuditLogRef();

    try {
      const result = await db.runTransaction(async (tx) => {
        // 1) mlsProperties 존재 확인 + sellerUid(매도자 uid) 캡처
        const propertySnap = await tx.get(propertyRef);
        if (!propertySnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            `Property ${propertyId} does not exist`
          );
        }
        const propertyData = propertySnap.data();
        const sellerUid = propertyData.userId || null;

        // 1-1) Task 07 — 매도자 자율 단독 지정 매물 검증.
        // listingMode === 'exclusive' 이고 brokerId 가 exclusiveBrokerIds 에 포함되지 않으면
        // 매도자가 자율적으로 *지정 외* 인 분이므로 우선권을 받을 수 없다.
        // 이 거절은 *매도자의 자발 선택* 결과이며 MyHome 의 추천이 아님 (§33①9호 회피).
        if (propertyData.listingMode === "exclusive") {
          const exclusiveList = Array.isArray(propertyData.exclusiveBrokerIds)
            ? propertyData.exclusiveBrokerIds
            : [];
          if (!exclusiveList.includes(brokerId)) {
            // 거절도 audit log 에 기록 (매도자 자율 의사 추적용).
            try {
              const rejectAuditRef = newAuditLogRef();
              tx.set(rejectAuditRef, {
                eventId: rejectAuditRef.id,
                eventType: "grant_rejected_not_in_exclusive_list",
                actorUid: request.auth.uid,
                propertyId,
                brokerId,
                sellerUid,
                grantId: null,
                inputs: { type, stage, exclusiveListSize: exclusiveList.length },
                outputs: { rejected: true, reason: REASON.NOT_IN_EXCLUSIVE_LIST },
                rulebookVersion: RULEBOOK_VERSION,
                createdAt: Timestamp.now(),
              });
            } catch (_) {
              // audit 실패는 거절 자체를 막지 않는다 (가용성 우선).
            }
            throw new HttpsError(
              "failed-precondition",
              `${REASON.NOT_IN_EXCLUSIVE_LIST}: brokerId(${brokerId}) is not in exclusiveBrokerIds for property(${propertyId})`
            );
          }
        }

        // 2) broker_eligibility 존재 + verified 확인
        const eligibilitySnap = await tx.get(eligibilityRef);
        if (!eligibilitySnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.ELIGIBILITY_NOT_FOUND}: broker_eligibility/${brokerId} not found`
          );
        }
        const eligibility = eligibilitySnap.data();

        // 2-1) 본인 brokerId 검증 — caller uid가 brokerId 또는 eligibility.brokerUid와 일치해야 함
        const eligBrokerUid = eligibility.brokerUid || brokerId;
        if (
          brokerId !== request.auth.uid &&
          eligBrokerUid !== request.auth.uid
        ) {
          throw new HttpsError(
            "permission-denied",
            `${REASON.NOT_GRANT_OWNER}: brokerId(${brokerId}) does not belong to caller uid(${request.auth.uid})`
          );
        }

        if (eligibility.licenseStatus !== "verified") {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.LICENSE_NOT_VERIFIED}: broker license not verified (status=${eligibility.licenseStatus})`
          );
        }

        // 3) 동시 grant 한도 검증
        const cap = eligibility.activeGrantsCap || DEFAULT_ACTIVE_GRANTS_CAP;
        const currentCount = eligibility.activeGrantsCount || 0;
        if (currentCount >= cap) {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.CAP_EXCEEDED}: activeGrantsCount(${currentCount}) >= cap(${cap})`
          );
        }

        // 4) 중복 차단 (트랜잭션 내 재검증)
        for (const ref of conflictRefs) {
          const snap = await tx.get(ref);
          if (snap.exists && snap.data().status === "active") {
            // M1.2는 buyerInquiryId까지 같을 때만 충돌
            if (type === "buyer_match") {
              if (snap.data().buyerInquiryId === buyerInquiryId) {
                throw new HttpsError(
                  "failed-precondition",
                  `${REASON.ALREADY_GRANTED}: duplicate_active_grant (${propertyId}, ${type}, ${stage}, ${buyerInquiryId})`
                );
              }
            } else {
              throw new HttpsError(
                "failed-precondition",
                `${REASON.ALREADY_GRANTED}: duplicate_active_grant (${propertyId}, ${type}, ${stage})`
              );
            }
          }
        }

        // 4-1) 24시간 쿨다운 검증 (자진 만료 후 재참여 차단)
        if (cooldownRef) {
          const prevSnap = await tx.get(cooldownRef);
          if (prevSnap.exists) {
            const prev = prevSnap.data();
            const nowMs = Date.now();
            let cooldownEndMs = null;
            if (prev.revokeCooldownUntil && typeof prev.revokeCooldownUntil.toMillis === "function") {
              cooldownEndMs = prev.revokeCooldownUntil.toMillis();
            } else if (prev.revokedAt && typeof prev.revokedAt.toMillis === "function") {
              cooldownEndMs = prev.revokedAt.toMillis() + REVOKE_COOLDOWN_HOURS * 60 * 60 * 1000;
            }
            if (cooldownEndMs !== null && cooldownEndMs > nowMs) {
              throw new HttpsError(
                "failed-precondition",
                `${REASON.REVOKE_COOLDOWN}: cooldown active until ${new Date(cooldownEndMs).toISOString()}`
              );
            }
          }
        }

        // 4-2) Dynamic Matching 점수 계산 + threshold 검증
        const grantedAt = Timestamp.now();
        const createdAtMs =
          propertyData.createdAt && typeof propertyData.createdAt.toMillis === "function"
            ? propertyData.createdAt.toMillis()
            : grantedAt.toMillis();
        const ageDays = Math.max(0, (grantedAt.toMillis() - createdAtMs) / (24 * 60 * 60 * 1000));
        const timeRank = 1 / (1 + ageDays / 3);

        // jurisdictionMatch: 매물 region/lawdCd가 eligibility.jurisdictions에 포함되는지
        const propertyJurisdiction = propertyData.region || propertyData.lawdCd || null;
        const jurisdictions = Array.isArray(eligibility.jurisdictions)
          ? eligibility.jurisdictions
          : [];
        const jurisdictionMatch =
          propertyJurisdiction !== null &&
          jurisdictions.length > 0 &&
          jurisdictions.includes(propertyJurisdiction);

        const capHeadroom = cap > 0 ? Math.max(0, (cap - currentCount) / cap) : 0;
        const clientInputs = scoringInputs || {};
        const distanceKm =
          typeof clientInputs.distanceKm === "number" ? clientInputs.distanceKm : 0;

        // Task 06 — algorithm_config 동적 로드 (가중치/임계값 외부화).
        const cfg = await loadMatchingConfig();
        const compiled = computeMatchingScore(
          {
            timeRank,
            jurisdictionMatch,
            licenseStatus: eligibility.licenseStatus,
            activityScore: typeof clientInputs.activityScore === "number"
              ? clientInputs.activityScore
              : 0.5,
            distanceKm,
            capHeadroom,
          },
          cfg
        );

        if (compiled.score < compiled.threshold) {
          // P2-4: error message 에 rawInputs 직렬화 첨부 — 클라이언트
          // GrantMessages.extractScoringInputs / describeScoringFailure 가
          // 파싱해 80세 노인 화법 1줄로 변환해 SnackBar 노출.
          // 점수/threshold *값* 노출은 *내부 디버깅용* (사용자 화면에 직접
          // 노출 금지 — extractReasonCode 가 score_below_threshold 만 추출).
          throw new HttpsError(
            "failed-precondition",
            `${REASON.SCORE_BELOW_THRESHOLD}: matching score ${compiled.score.toFixed(3)} < threshold ${compiled.threshold} | inputs:${serializeRawInputs(compiled.rawInputs, eligibility.licenseStatus)}`
          );
        }

        // 5) grant 생성
        const expiresAt = addDaysToTimestamp(grantedAt, DEFAULT_GRANT_TTL_DAYS);
        const brokerUid = eligibility.brokerUid || brokerId;

        // 5-1) broker_participations 시간기록 (Task 05 M2) — 모든 tx.set/update 이전에
        //      tx.get 을 통해 participationRef + collection size 를 읽어 displayName 발급.
        await upsertBrokerParticipationInTx({
          tx,
          propertyRef,
          propertyId,
          brokerId,
          brokerUid,
          stage, // normalizeStage 가 participation/visit/offer → declared/visit_scheduled/offer_made 매핑
          relatedGrantId: grantId,
          now: grantedAt,
          actorUid: request.auth.uid,
          trigger: `issuePriorityGrant:${type}`,
        });

        const grantData = {
          id: grantId,
          propertyId,
          brokerId,
          brokerUid,
          sellerUid, // Rules에서 매도자 권한 검사용 (firestore.rules priority_grants read)
          type,
          buyerInquiryId: buyerInquiryId || null,
          stage,
          grantedAt,
          expiresAt,
          status: "active",
          statusReason: null,
          activityScore: 0,
          lastActivityAt: null,
          scoringInputs: compiled,
          revokedAt: null,
          revokeCooldownUntil: null,
          fulfilledAt: null,
        };
        tx.set(grantRef, grantData);

        // 6) eligibility 카운터 증가
        tx.update(eligibilityRef, {
          activeGrantsCount: FieldValue.increment(1),
          updatedAt: Timestamp.now(),
        });

        // 7) audit log 동시 기록
        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType: "grant_issued",
          actorUid: request.auth.uid,
          propertyId,
          brokerId,
          grantId,
          inputs: { propertyId, brokerId, type, stage, buyerInquiryId: buyerInquiryId || null },
          outputs: {
            grantId,
            expiresAt: expiresAt.toMillis(),
            score: compiled.score,
            matchingVersion: compiled.version,
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: Timestamp.now(),
        });

        return { grantId, expiresAt: expiresAt.toMillis(), score: compiled.score };
      });

      console.log(`[issuePriorityGrant] success: ${result.grantId}`);
      return result;
    } catch (error) {
      // 실패 audit log (별도 트랜잭션)
      try {
        const failureAuditRef = newAuditLogRef();
        const msg = error.message || "";
        let failureEventType = "eligibility_check";
        if (msg.startsWith(REASON.CAP_EXCEEDED) || msg.includes("cap_blocked")) {
          failureEventType = "cap_blocked";
        }
        // revoke_cooldown / score_below_threshold / 기타 → eligibility_check (기본)
        await failureAuditRef.set({
          eventId: failureAuditRef.id,
          eventType: failureEventType,
          actorUid: request.auth.uid,
          propertyId,
          brokerId,
          grantId: null,
          inputs: { propertyId, brokerId, type, stage, buyerInquiryId: buyerInquiryId || null },
          outputs: { error: msg || String(error) },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: Timestamp.now(),
        });
      } catch (auditError) {
        console.error(
          "[issuePriorityGrant] failed to write failure audit log:",
          auditError
        );
      }

      if (error instanceof HttpsError) throw error;
      console.error("[issuePriorityGrant] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

/**
 * 1.1b revokeOwnGrant (callable)
 *
 * 중개사 본인이 자신의 active grant를 자진 만료(취소)한다.
 * 24시간 쿨다운이 설정되며, 동일 매물에 재참여하려면 쿨다운 해제 후 가능.
 *
 * 입력:
 *   - grantId: string (필수)
 *
 * 인증: request.auth 필수. grant.brokerUid === caller uid 만 허용.
 *
 * 반환: { grantId, revokedAt: millis, revokeCooldownUntil: millis }
 */
exports.revokeOwnGrant = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { grantId } = request.data || {};
    if (!grantId || typeof grantId !== "string") {
      throw new HttpsError("invalid-argument", "grantId is required");
    }

    const grantRef = db.collection("priority_grants").doc(grantId);

    try {
      const result = await db.runTransaction(async (tx) => {
        const grantSnap = await tx.get(grantRef);
        if (!grantSnap.exists) {
          throw new HttpsError("not-found", `priority_grants/${grantId} not found`);
        }
        const grant = grantSnap.data();

        if (grant.brokerUid !== request.auth.uid) {
          throw new HttpsError(
            "permission-denied",
            `${REASON.NOT_GRANT_OWNER}: caller uid(${request.auth.uid}) is not grant owner(${grant.brokerUid})`
          );
        }
        if (grant.status !== "active") {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.GRANT_NOT_ACTIVE}: grant status is ${grant.status}`
          );
        }

        const now = Timestamp.now();
        const cooldownUntil = addHoursToTimestamp(now, REVOKE_COOLDOWN_HOURS);

        tx.update(grantRef, {
          status: "revoked",
          statusReason: REASON.REVOKED_BY_SELF,
          revokedAt: now,
          revokeCooldownUntil: cooldownUntil,
        });

        const eligibilityRef = db.collection("broker_eligibility").doc(grant.brokerId);
        const eligibilitySnap = await tx.get(eligibilityRef);
        if (eligibilitySnap.exists) {
          tx.update(eligibilityRef, {
            activeGrantsCount: FieldValue.increment(-1),
            updatedAt: now,
          });
        }

        const auditRef = newAuditLogRef();
        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType: "grant_revoked",
          actorUid: request.auth.uid,
          propertyId: grant.propertyId,
          brokerId: grant.brokerId,
          grantId,
          inputs: { grantId, statusReason: REASON.REVOKED_BY_SELF },
          outputs: {
            previousStatus: "active",
            newStatus: "revoked",
            revokedAt: now.toMillis(),
            revokeCooldownUntil: cooldownUntil.toMillis(),
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: now,
        });

        return {
          grantId,
          revokedAt: now.toMillis(),
          revokeCooldownUntil: cooldownUntil.toMillis(),
        };
      });

      console.log(`[revokeOwnGrant] success: ${result.grantId}`);
      return result;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("[revokeOwnGrant] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

/**
 * 1.1c createBuyerMatchGrant (callable) — Task 03 M1.2
 *
 * **매수자**가 특정 매물에 대해 자기 *임장(방문) 담당 중개사*를 선택할 때 호출된다.
 * M1.1(매도자측 seller_match)와는 *공존 가능* — 같은 매물에 두 grant가 따로 있을 수 있음.
 *
 * 입력:
 *   - propertyId: string (필수)
 *   - brokerId: string (필수, 매수자가 선택한 중개사)
 *   - buyerInquiryId: string (필수, buyerInquiries/{id})
 *   - confirmSwitch: boolean (선택, 같은 inquiry에 다른 중개사 grant가 있을 때 명시적 교체 의도)
 *   - scoringInputs: map (선택, distanceKm 등 보조 입력)
 *
 * 인증: request.auth 필수. caller uid가 buyerInquiry.buyerUserId와 일치해야 함.
 *      (M1.1과 달리 호출자는 *매수자*이므로 broker_eligibility.brokerUid 검사 안 함.)
 *
 * 흐름 (명세 03-m1-buyer-broker.md §2·§4):
 *   1) 매수자 인증
 *   2) buyerInquiries/{id} 로드, buyerUserId === caller uid 검증
 *   3) broker_eligibility/{brokerId} 자격 검증 (verified, jurisdiction, cap)
 *   4) 같은 (buyerInquiryId, brokerId) 활성 grant 있음 → ALREADY_GRANTED
 *   5) 같은 buyerInquiryId에 다른 brokerId 활성 grant 있음 →
 *        - confirmSwitch=false → BUYER_SWITCH_REQUIRED 거절 (UI에서 매수자 동의 후 재호출)
 *        - confirmSwitch=true 이고 24h 쿨다운 안 지남 → BUYER_SWITCH_COOLDOWN
 *        - confirmSwitch=true 이고 쿨다운 통과 → 기존 grant revoke + 새 grant 생성
 *   6) priority_grants 신규 문서 (TTL 30일)
 *   7) buyerInquiries 문서 갱신 (selectedBrokerId / activeBuyerMatchGrantId / brokerSelectedAt)
 *   8) mlsProperties/{id}/broker_participations 시간기록
 *   9) audit log
 *
 * 거절은 REASON 코드를 메시지 prefix로 부착해 클라이언트가 카피 매핑할 수 있게 한다.
 *
 * 반환: { grantId, expiresAt: millis, score, switched: boolean, previousGrantId?: string }
 */
exports.createBuyerMatchGrant = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const {
      propertyId,
      brokerId,
      buyerInquiryId,
      confirmSwitch,
      scoringInputs,
    } = request.data || {};

    // 입력 검증
    if (!propertyId || typeof propertyId !== "string") {
      throw new HttpsError("invalid-argument", "propertyId is required");
    }
    if (!brokerId || typeof brokerId !== "string") {
      throw new HttpsError("invalid-argument", "brokerId is required");
    }
    if (!buyerInquiryId || typeof buyerInquiryId !== "string") {
      throw new HttpsError("invalid-argument", "buyerInquiryId is required");
    }

    // 사전: 같은 buyerInquiryId의 모든 활성 grant 조회 (해당 inquiry에 대한 단일 활성 보장).
    const inquiryActiveGrantsSnap = await db
      .collection("priority_grants")
      .where("buyerInquiryId", "==", buyerInquiryId)
      .where("type", "==", "buyer_match")
      .where("status", "==", "active")
      .get();
    const inquiryActiveGrantRefs = inquiryActiveGrantsSnap.docs.map((d) => ({
      ref: d.ref,
      data: d.data(),
    }));

    const propertyRef = db.collection("mlsProperties").doc(propertyId);
    const inquiryRef = db.collection("buyerInquiries").doc(buyerInquiryId);
    const eligibilityRef = db.collection("broker_eligibility").doc(brokerId);

    const grantId = `pg_${Date.now()}_${brokerId}`;
    const grantRef = db.collection("priority_grants").doc(grantId);
    const auditRef = newAuditLogRef();
    const switchAuditRef = newAuditLogRef();
    const participationRef = propertyRef
      .collection("broker_participations")
      .doc(brokerId);

    try {
      const result = await db.runTransaction(async (tx) => {
        // 1) inquiry 존재 + 본인 검증
        const inquirySnap = await tx.get(inquiryRef);
        if (!inquirySnap.exists) {
          throw new HttpsError(
            "not-found",
            `${REASON.INQUIRY_NOT_FOUND}: buyerInquiries/${buyerInquiryId} not found`
          );
        }
        const inquiry = inquirySnap.data();
        if (inquiry.buyerUserId !== request.auth.uid) {
          throw new HttpsError(
            "permission-denied",
            `${REASON.BUYER_NOT_OWNER}: caller uid(${request.auth.uid}) is not buyer of inquiry`
          );
        }
        if (inquiry.propertyId !== propertyId) {
          throw new HttpsError(
            "failed-precondition",
            `inquiry.propertyId(${inquiry.propertyId}) does not match request.propertyId(${propertyId})`
          );
        }

        // 2) 매물 존재 + sellerUid 캡처
        const propertySnap = await tx.get(propertyRef);
        if (!propertySnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            `Property ${propertyId} does not exist`
          );
        }
        const propertyData = propertySnap.data();
        const sellerUid = propertyData.userId || null;

        // 3) broker_eligibility 검증 (verified + cap)
        const eligibilitySnap = await tx.get(eligibilityRef);
        if (!eligibilitySnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.ELIGIBILITY_NOT_FOUND}: broker_eligibility/${brokerId} not found`
          );
        }
        const eligibility = eligibilitySnap.data();
        if (eligibility.licenseStatus !== "verified") {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.LICENSE_NOT_VERIFIED}: broker license not verified (status=${eligibility.licenseStatus})`
          );
        }
        const cap = eligibility.activeGrantsCap || DEFAULT_ACTIVE_GRANTS_CAP;
        const currentCount = eligibility.activeGrantsCount || 0;
        if (currentCount >= cap) {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.CAP_EXCEEDED}: activeGrantsCount(${currentCount}) >= cap(${cap})`
          );
        }

        // 3-1) Task 05 broker_participations 사전 read.
        //      Firestore 트랜잭션은 *모든 read 가 모든 write 보다 앞서야* 하므로,
        //      이후 단계에서 set 만 수행할 수 있도록 미리 capture.
        const participationSnap = await tx.get(participationRef);
        const partExisting = participationSnap.exists ? participationSnap.data() : null;
        let partOrderIndex = null;
        let partDisplayName = partExisting && partExisting.displayName
          ? partExisting.displayName
          : null;
        if (!partDisplayName) {
          const colSnap = await tx.get(propertyRef.collection("broker_participations"));
          partOrderIndex = colSnap.size;
          partDisplayName = buildAnonymousDisplayName(partOrderIndex);
        }

        // 4) 동일 inquiry 활성 grant 검사 + 교체 흐름
        let revokedPreviousGrantId = null;
        const stage = "participation"; // 매수자 매칭 시작 단계
        for (const item of inquiryActiveGrantRefs) {
          const liveSnap = await tx.get(item.ref);
          if (!liveSnap.exists) continue;
          const live = liveSnap.data();
          if (live.status !== "active") continue;

          if (live.brokerId === brokerId && live.stage === stage) {
            throw new HttpsError(
              "failed-precondition",
              `${REASON.ALREADY_GRANTED}: duplicate_active_grant (buyer_match, ${buyerInquiryId}, ${brokerId})`
            );
          }
          if (live.brokerId !== brokerId) {
            // 다른 중개사가 이미 활성 — 교체 시도
            if (confirmSwitch !== true) {
              throw new HttpsError(
                "failed-precondition",
                `${REASON.BUYER_SWITCH_REQUIRED}: existing active grant ${live.id || liveSnap.id} for inquiry ${buyerInquiryId}`
              );
            }
            // 24h 쿨다운: brokerSelectedAt 기준
            const lastSelectedAtMs =
              inquiry.brokerSelectedAt && typeof inquiry.brokerSelectedAt.toMillis === "function"
                ? inquiry.brokerSelectedAt.toMillis()
                : (inquiry.brokerSelectedAt
                  ? new Date(inquiry.brokerSelectedAt).getTime()
                  : null);
            if (lastSelectedAtMs !== null) {
              const cooldownEndMs = lastSelectedAtMs + BUYER_SWITCH_COOLDOWN_HOURS * 60 * 60 * 1000;
              if (cooldownEndMs > Date.now()) {
                throw new HttpsError(
                  "failed-precondition",
                  `${REASON.BUYER_SWITCH_COOLDOWN}: cooldown active until ${new Date(cooldownEndMs).toISOString()}`
                );
              }
            }
            // 기존 grant revoke (트랜잭션 내) + 카운터 감소
            const now = Timestamp.now();
            tx.update(liveSnap.ref, {
              status: "revoked",
              statusReason: REASON.REVOKED_BY_BUYER_SWITCH,
              revokedAt: now,
            });
            const prevElig = db.collection("broker_eligibility").doc(live.brokerId);
            const prevEligSnap = await tx.get(prevElig);
            if (prevEligSnap.exists) {
              tx.update(prevElig, {
                activeGrantsCount: FieldValue.increment(-1),
                updatedAt: now,
              });
            }
            tx.set(switchAuditRef, {
              eventId: switchAuditRef.id,
              eventType: "grant_revoked",
              actorUid: request.auth.uid,
              propertyId,
              brokerId: live.brokerId,
              grantId: live.id || liveSnap.id,
              inputs: {
                statusReason: REASON.REVOKED_BY_BUYER_SWITCH,
                buyerInquiryId,
                replacedByBrokerId: brokerId,
              },
              outputs: { previousStatus: "active", newStatus: "revoked" },
              rulebookVersion: RULEBOOK_VERSION,
              createdAt: now,
            });
            revokedPreviousGrantId = live.id || liveSnap.id;
          }
        }

        // 5) Dynamic Matching 점수 계산 (M1.1과 동일 변수 + threshold 0.55)
        const grantedAt = Timestamp.now();
        const createdAtMs =
          propertyData.createdAt && typeof propertyData.createdAt.toMillis === "function"
            ? propertyData.createdAt.toMillis()
            : grantedAt.toMillis();
        const ageDays = Math.max(0, (grantedAt.toMillis() - createdAtMs) / (24 * 60 * 60 * 1000));
        const timeRank = 1 / (1 + ageDays / 3);

        const propertyJurisdiction = propertyData.region || propertyData.lawdCd || null;
        const jurisdictions = Array.isArray(eligibility.jurisdictions)
          ? eligibility.jurisdictions
          : [];
        const jurisdictionMatch =
          propertyJurisdiction !== null &&
          jurisdictions.length > 0 &&
          jurisdictions.includes(propertyJurisdiction);

        const capHeadroom = cap > 0 ? Math.max(0, (cap - currentCount) / cap) : 0;
        const clientInputs = scoringInputs || {};
        const distanceKm =
          typeof clientInputs.distanceKm === "number" ? clientInputs.distanceKm : 0;

        // Task 06 — algorithm_config 동적 로드.
        const cfg = await loadMatchingConfig();
        const compiled = computeMatchingScore(
          {
            timeRank,
            jurisdictionMatch,
            licenseStatus: eligibility.licenseStatus,
            activityScore: typeof clientInputs.activityScore === "number"
              ? clientInputs.activityScore
              : 0.5,
            distanceKm,
            capHeadroom,
          },
          cfg
        );

        if (compiled.score < compiled.threshold) {
          // P2-4: createBuyerMatchGrant 분기에도 동일하게 rawInputs 직렬 첨부.
          throw new HttpsError(
            "failed-precondition",
            `${REASON.SCORE_BELOW_THRESHOLD}: matching score ${compiled.score.toFixed(3)} < threshold ${compiled.threshold} | inputs:${serializeRawInputs(compiled.rawInputs, eligibility.licenseStatus)}`
          );
        }

        // 6) priority_grants 신규 문서 (TTL 30일)
        const expiresAt = addDaysToTimestamp(grantedAt, BUYER_MATCH_TTL_DAYS);
        const brokerUid = eligibility.brokerUid || brokerId;

        tx.set(grantRef, {
          id: grantId,
          propertyId,
          brokerId,
          brokerUid,
          sellerUid,
          type: "buyer_match",
          buyerInquiryId,
          stage,
          grantedAt,
          expiresAt,
          status: "active",
          statusReason: null,
          activityScore: 0,
          lastActivityAt: null,
          scoringInputs: compiled,
          revokedAt: null,
          revokeCooldownUntil: null,
          fulfilledAt: null,
        });

        // 7) eligibility 카운터 증가
        tx.update(eligibilityRef, {
          activeGrantsCount: FieldValue.increment(1),
          updatedAt: grantedAt,
        });

        // 8) buyerInquiries 갱신 — 클라이언트 직접 변경 차단 필드들이라 admin SDK로만 기록.
        tx.update(inquiryRef, {
          selectedBrokerId: brokerId,
          activeBuyerMatchGrantId: grantId,
          brokerSelectedAt: grantedAt,
        });

        // 9) broker_participations 시간기록 (Task 05 M2)
        //    - displayName: 사전에 partDisplayName 으로 결정 (기존 보존 또는 신규 발급).
        //    - participationStage: 명세 어휘로 정규화 (participation→declared).
        //    - declaredAt + publiclyVisibleAt: 첫 발급 1회만 (즉시 공개).
        //    - stage 단조 증가: createBuyerMatchGrant 의 stage 는 항상 'declared' 이므로
        //      기존이 visit_scheduled/offer_made 면 partStage 를 그대로 보존 (역행 차단).
        const newPartStage = normalizeStage(stage);
        const existingPartStage = partExisting
          ? normalizeStage(partExisting.participationStage)
          : null;
        const finalPartStage =
          existingPartStage && stageRank(existingPartStage) > stageRank(newPartStage)
            ? existingPartStage
            : newPartStage;

        const partUpdates = {
          brokerId,
          brokerUid,
          propertyId,
          displayName: partDisplayName,
          participationStage: finalPartStage,
          buyerInquiryId,
          type: "buyer_match",
          relatedGrantId: grantId,
          updatedAt: grantedAt,
        };
        if (!partExisting || !partExisting.declaredAt) {
          partUpdates.declaredAt = grantedAt;
          partUpdates.publiclyVisibleAt = grantedAt;
        }
        tx.set(participationRef, partUpdates, { merge: true });

        // 9-1) participation audit log — declared (첫 발급) / 동등(skip)
        if (!partExisting) {
          const partAuditRef = newAuditLogRef();
          tx.set(partAuditRef, {
            eventId: partAuditRef.id,
            eventType: "participation_declared",
            actorUid: request.auth.uid,
            propertyId,
            brokerId,
            grantId,
            inputs: {
              propertyId,
              brokerId,
              stage: finalPartStage,
              trigger: "createBuyerMatchGrant",
            },
            outputs: {
              displayName: partDisplayName,
              orderIndex: partOrderIndex,
              publiclyVisibleAt: grantedAt.toMillis(),
            },
            rulebookVersion: RULEBOOK_VERSION,
            createdAt: grantedAt,
          });
        }

        // 10) audit log
        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType: "grant_issued",
          actorUid: request.auth.uid,
          propertyId,
          brokerId,
          grantId,
          inputs: {
            propertyId,
            brokerId,
            type: "buyer_match",
            stage,
            buyerInquiryId,
            confirmSwitch: confirmSwitch === true,
            replacedGrantId: revokedPreviousGrantId,
          },
          outputs: {
            grantId,
            expiresAt: expiresAt.toMillis(),
            score: compiled.score,
            matchingVersion: compiled.version,
            switched: revokedPreviousGrantId !== null,
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: grantedAt,
        });

        return {
          grantId,
          expiresAt: expiresAt.toMillis(),
          score: compiled.score,
          switched: revokedPreviousGrantId !== null,
          previousGrantId: revokedPreviousGrantId,
        };
      });

      console.log(`[createBuyerMatchGrant] success: ${result.grantId}`);
      return result;
    } catch (error) {
      // 실패 audit log (별도 트랜잭션)
      try {
        const failureAuditRef = newAuditLogRef();
        const msg = error.message || "";
        let failureEventType = "eligibility_check";
        if (msg.startsWith(REASON.CAP_EXCEEDED) || msg.includes("cap_blocked")) {
          failureEventType = "cap_blocked";
        }
        await failureAuditRef.set({
          eventId: failureAuditRef.id,
          eventType: failureEventType,
          actorUid: request.auth.uid,
          propertyId,
          brokerId,
          grantId: null,
          inputs: {
            propertyId,
            brokerId,
            type: "buyer_match",
            buyerInquiryId,
            confirmSwitch: confirmSwitch === true,
          },
          outputs: { error: msg || String(error) },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: Timestamp.now(),
        });
      } catch (auditError) {
        console.error(
          "[createBuyerMatchGrant] failed to write failure audit log:",
          auditError
        );
      }

      if (error instanceof HttpsError) throw error;
      console.error("[createBuyerMatchGrant] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

/**
 * P1-3 헬퍼: 활동 진척에 따라 broker 의 활성 grant activityScore 를 가산.
 *
 * Task 02 §3.2 정의:
 *   - participation 단계: 7일 내 임장 요청 1건 이상 → 0.8 / 매수자 컨택 추가 → 1.0
 *   - visit 단계: 14일 내 매수자 매칭 1건 → 0.8 / 의향서 단계 진척 → 1.0
 *
 * 동작:
 *   1. priority_grants where (propertyId, brokerId, status='active') — 단건 또는 무.
 *      stage 별 분리 발급 가능하므로 type='seller_match' 만 대상.
 *   2. delta 가산 (clamp 0~1). 가산 결과 차이가 0 이면 write skip (idempotent).
 *   3. priority_audit_logs append: eventType='activity_score_updated'.
 *
 * 본 함수는 *append-only* — 직접 감산이나 0 리셋 경로 미제공.
 * enforceActivityRule 만료 로직과 무충돌 (가산만 하므로 0.8 미달 grant 가
 * 7일 후에도 가산이 없으면 기존 expired 룰 그대로 동작).
 *
 * propertyRef 는 트랜잭션 외부 참조 — 본 함수가 자체적으로 새 트랜잭션을 연다.
 * 호출자는 await 만 한다 (트리거 본체 트랜잭션과 분리해 동시성 충돌 회피).
 *
 * @param {string} propertyId
 * @param {string} brokerId
 * @param {number} delta — 가산치 (0 ~ 1).
 * @param {string} triggerSource — 가산 trigger 식별자 (예: 'visit_request:approved', 'broker_offer:abc').
 * @returns {Promise<{updated: boolean, grantId?: string, oldScore?: number, newScore?: number}>}
 */
async function bumpActivityScoreForBroker(
  propertyId,
  brokerId,
  delta,
  triggerSource,
) {
  if (!propertyId || !brokerId || typeof delta !== "number" || delta <= 0) {
    return { updated: false };
  }
  // type='seller_match' 활성 grant 1건 (Task 02 단일 매물·단일 stage·단일 type 1:1).
  const candidates = await db
    .collection("priority_grants")
    .where("propertyId", "==", propertyId)
    .where("brokerId", "==", brokerId)
    .where("status", "==", "active")
    .where("type", "==", "seller_match")
    .limit(2)
    .get();
  if (candidates.empty) return { updated: false };
  // 다중 stage 동시 발급은 정상 시나리오 — 가장 최근 grant 1건에만 가산.
  let target = candidates.docs[0];
  if (candidates.size > 1) {
    let bestMs = -1;
    for (const d of candidates.docs) {
      const g = d.data() || {};
      const ms = g.grantedAt && typeof g.grantedAt.toMillis === "function"
        ? g.grantedAt.toMillis()
        : 0;
      if (ms > bestMs) {
        bestMs = ms;
        target = d;
      }
    }
  }
  const grantRef = target.ref;

  try {
    return await db.runTransaction(async (tx) => {
      const grantSnap = await tx.get(grantRef);
      if (!grantSnap.exists) return { updated: false };
      const grant = grantSnap.data();
      if (grant.status !== "active") return { updated: false };

      const oldScore = typeof grant.activityScore === "number" ? grant.activityScore : 0;
      const newScore = clamp01(oldScore + delta);
      // 차이 무시 가능 (이미 1.0 도달 등) — write skip.
      if (Math.abs(newScore - oldScore) < 1e-9) {
        return { updated: false, grantId: grantSnap.id, oldScore, newScore };
      }

      const now = Timestamp.now();
      tx.update(grantRef, {
        activityScore: newScore,
        lastActivityAt: now,
      });

      const auditRef = newAuditLogRef();
      tx.set(auditRef, {
        eventId: auditRef.id,
        eventType: "activity_score_updated",
        actorUid: null,
        propertyId,
        brokerId,
        grantId: grantSnap.id,
        sellerUid: grant.sellerUid || null,
        inputs: {
          delta,
          triggerSource: triggerSource || "unknown",
          stage: grant.stage || null,
        },
        outputs: {
          oldScore,
          newScore,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: now,
      });

      return { updated: true, grantId: grantSnap.id, oldScore, newScore };
    });
  } catch (e) {
    console.error(
      `[bumpActivityScoreForBroker] failed for property=${propertyId} broker=${brokerId} trigger=${triggerSource}:`,
      e.message,
    );
    return { updated: false };
  }
}

/**
 * 헬퍼: grant 1건을 만료 처리 + 카운터 감소 + audit log 기록.
 *
 * 트랜잭션 내부에서 호출되어야 한다.
 */
async function expireSingleGrantInTx(tx, grantRef, statusReason, eventType) {
  const grantSnap = await tx.get(grantRef);
  if (!grantSnap.exists) return false;
  const grant = grantSnap.data();
  if (grant.status !== "active") return false;

  const eligibilityRef = db.collection("broker_eligibility").doc(grant.brokerId);
  const eligibilitySnap = await tx.get(eligibilityRef);

  const now = Timestamp.now();
  tx.update(grantRef, {
    status: "expired",
    statusReason,
    revokedAt: now,
  });

  if (eligibilitySnap.exists) {
    tx.update(eligibilityRef, {
      activeGrantsCount: FieldValue.increment(-1),
      updatedAt: now,
    });
  }

  const auditRef = newAuditLogRef();
  tx.set(auditRef, {
    eventId: auditRef.id,
    eventType,
    actorUid: null,
    propertyId: grant.propertyId,
    brokerId: grant.brokerId,
    grantId: grant.id || grantRef.id,
    inputs: { statusReason },
    outputs: { previousStatus: grant.status, newStatus: "expired" },
    rulebookVersion: RULEBOOK_VERSION,
    createdAt: now,
  });
  return true;
}

/**
 * 1.2 expireGrantsScheduled
 *
 * 매 10분마다 실행. expiresAt이 지난 active grant를 expired로 변경.
 */
exports.expireGrantsScheduled = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every 10 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const now = Timestamp.now();
    const snapshot = await db
      .collection("priority_grants")
      .where("status", "==", "active")
      .where("expiresAt", "<=", now)
      .limit(200)
      .get();

    if (snapshot.empty) {
      console.log("[expireGrantsScheduled] no expired grants");
      return;
    }

    let processed = 0;
    let failed = 0;
    for (const doc of snapshot.docs) {
      try {
        await db.runTransaction(async (tx) => {
          const ok = await expireSingleGrantInTx(
            tx,
            doc.ref,
            "ttl_expired",
            "grant_expired"
          );
          if (ok) processed += 1;
        });
      } catch (e) {
        failed += 1;
        console.error(
          `[expireGrantsScheduled] failed to expire ${doc.id}:`,
          e.message
        );
      }
    }
    console.log(
      `[expireGrantsScheduled] processed=${processed} failed=${failed} total=${snapshot.size}`
    );
  }
);

/**
 * 1.3 enforceActivityRule
 *
 * 매 60분마다 실행. grantedAt + 7d < now 이고 activityScore < 0.8 인 active grant를
 * activity_below_threshold 사유로 expired 처리.
 */
exports.enforceActivityRule = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every 60 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const now = Timestamp.now();
    const cutoff = Timestamp.fromMillis(
      now.toMillis() - ACTIVITY_RULE_DAYS * 24 * 60 * 60 * 1000
    );

    const snapshot = await db
      .collection("priority_grants")
      .where("status", "==", "active")
      .where("grantedAt", "<", cutoff)
      .limit(200)
      .get();

    if (snapshot.empty) {
      console.log("[enforceActivityRule] no candidates");
      return;
    }

    let processed = 0;
    let skipped = 0;
    let failed = 0;

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const score = typeof data.activityScore === "number" ? data.activityScore : 0;
      if (score >= ACTIVITY_RULE_THRESHOLD) {
        skipped += 1;
        continue;
      }
      try {
        await db.runTransaction(async (tx) => {
          const ok = await expireSingleGrantInTx(
            tx,
            doc.ref,
            "activity_below_threshold",
            "grant_expired"
          );
          if (ok) processed += 1;
        });
      } catch (e) {
        failed += 1;
        console.error(
          `[enforceActivityRule] failed for ${doc.id}:`,
          e.message
        );
      }
    }
    console.log(
      `[enforceActivityRule] processed=${processed} skipped=${skipped} failed=${failed} total=${snapshot.size}`
    );
  }
);

/**
 * 헬퍼: 단일 broker에 대해 broker_eligibility upsert.
 *
 * - brokers/{brokerId} 문서에서 면허/주소/좌표 가져오기 (없으면 기본값)
 * - 외부 면허 검증 API 미구현이므로 brokers.licenseVerified 필드를 그대로 반영
 * - priority_grants에서 active count 정합 맞춤
 */
async function recomputeSingleBrokerEligibility(brokerId) {
  const brokerRef = db.collection("brokers").doc(brokerId);
  const eligibilityRef = db.collection("broker_eligibility").doc(brokerId);

  const brokerSnap = await brokerRef.get();
  const brokerData = brokerSnap.exists ? brokerSnap.data() : {};

  // 면허 상태: 외부 API 미구현 — brokers.licenseVerified 필드 반영
  // TODO: 실제 면허 검증 API 연동 시 여기에 호출 로직 추가
  let licenseStatus = "pending";
  if (brokerData.licenseVerified === true) {
    licenseStatus = "verified";
  } else if (brokerData.licenseVerified === false) {
    licenseStatus = "invalid";
  }

  // 활성 grant 카운트 정합
  const activeGrantsSnap = await db
    .collection("priority_grants")
    .where("brokerId", "==", brokerId)
    .where("status", "==", "active")
    .get();
  const activeGrantsCount = activeGrantsSnap.size;

  // P0-5: broker.region 비정규화. brokers.region 우선 → officeAddress 추출 fallback.
  // tier2/tier3 알림에서 N+1 brokers lookup 제거를 위함. (functions §2.4 fetchEligibleBrokersForTier 참조)
  const eligibilityRegion =
    brokerData.region || extractDongFromAddress(brokerData.officeAddress || "") || null;

  const now = Timestamp.now();
  const eligibilityData = {
    brokerId,
    brokerUid: brokerData.uid || brokerData.brokerUid || brokerId,
    licenseNumber: brokerData.licenseNumber || "",
    licenseVerifiedAt: brokerData.licenseVerifiedAt || now,
    licenseStatus,
    region: eligibilityRegion, // P0-5 비정규화 — null 가능 (broker가 region·officeAddress 미입력 시)
    jurisdictions: brokerData.jurisdictions || [],
    geofence: (() => {
      const lat = brokerData.latitude || 0;
      const lng = brokerData.longitude || 0;
      const radiusKm = brokerData.geofenceRadiusKm || 5;
      const geohash = (lat !== 0 && lng !== 0)
        ? ngeohash.encode(lat, lng, GEOHASH_PRECISION)
        : null;
      return geohash ? { lat, lng, radiusKm, geohash } : { lat, lng, radiusKm };
    })(),
    activeGrantsCount,
    activeGrantsCap: brokerData.activeGrantsCap || DEFAULT_ACTIVE_GRANTS_CAP,
    updatedAt: now,
  };

  await eligibilityRef.set(eligibilityData, { merge: true });

  // brokers.eligibilityRefreshedAt 업데이트 (문서 존재 시에만)
  if (brokerSnap.exists) {
    await brokerRef.update({ eligibilityRefreshedAt: now });
  }

  return { brokerId, activeGrantsCount, licenseStatus };
}

/**
 * 1.4-a recomputeBrokerEligibility (callable)
 *
 * 관리자만 호출 가능. brokerId가 주어지면 단일 재계산, 없으면 전체 재계산.
 */
exports.recomputeBrokerEligibility = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    if (request.auth.token.admin !== true) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const { brokerId } = request.data || {};

    try {
      if (brokerId) {
        const result = await recomputeSingleBrokerEligibility(brokerId);
        console.log(`[recomputeBrokerEligibility] single: ${brokerId}`);
        return { success: true, results: [result] };
      }

      // 전체 재계산
      const brokersSnap = await db.collection("brokers").get();
      const results = [];
      for (const brokerDoc of brokersSnap.docs) {
        try {
          const r = await recomputeSingleBrokerEligibility(brokerDoc.id);
          results.push(r);
        } catch (e) {
          console.error(
            `[recomputeBrokerEligibility] failed for ${brokerDoc.id}:`,
            e.message
          );
          results.push({ brokerId: brokerDoc.id, error: e.message });
        }
      }
      console.log(
        `[recomputeBrokerEligibility] total=${results.length}`
      );
      return { success: true, results };
    } catch (error) {
      console.error("[recomputeBrokerEligibility] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

/**
 * 1.4-c onBrokerJurisdictionsUpdated (Task 003)
 *
 * brokers/{brokerId} onUpdate 트리거. jurisdictions 필드 *값이 실제로 바뀌었을 때만*
 * recomputeSingleBrokerEligibility 를 1회 호출하여 broker_eligibility 와 동기화.
 *
 * **왜 필요한가**:
 *   - recomputeBrokerEligibility callable 은 admin-only (request.auth.token.admin === true)
 *   - 따라서 중개사 본인이 self-service 로 jurisdictions 를 갱신해도 클라이언트 → callable 직접 호출 불가
 *   - onUpdate 트리거가 중개사 self-service 와 broker_eligibility 사이의 *유일한 동기화 경로*
 *
 * **무한 루프 방지**:
 *   - jurisdictions 의 정렬된 JSON 비교로 *실제 변경*만 발화
 *   - eligibilityRefreshedAt 자체 갱신은 jurisdictions 와 무관하므로 발화 X
 *
 * **race**: 트리거 발화는 비동기 (수 초 ~ 30초). 클라이언트는 SnackBar 로
 *          "최대 30초 안에 반영돼요" 안내 (copy-deck §JurisdictionPicker).
 */
exports.onBrokerJurisdictionsUpdated = onDocumentUpdated(
  { document: "brokers/{brokerId}", region: "asia-northeast3" },
  async (event) => {
    const before = event.data.before.data() || {};
    const after = event.data.after.data() || {};
    const beforeArr = Array.isArray(before.jurisdictions)
      ? [...before.jurisdictions].sort()
      : [];
    const afterArr = Array.isArray(after.jurisdictions)
      ? [...after.jurisdictions].sort()
      : [];
    if (JSON.stringify(beforeArr) === JSON.stringify(afterArr)) {
      return null;
    }
    try {
      const result = await recomputeSingleBrokerEligibility(
        event.params.brokerId
      );
      console.log(
        `[onBrokerJurisdictionsUpdated] synced brokerId=${event.params.brokerId}`,
        `before=${beforeArr.length} after=${afterArr.length}`,
        `activeGrants=${result.activeGrantsCount}`
      );
    } catch (e) {
      console.error(
        `[onBrokerJurisdictionsUpdated] failed brokerId=${event.params.brokerId}:`,
        e.message
      );
    }
    return null;
  }
);

/**
 * 1.4-b recomputeBrokerEligibilityScheduled
 *
 * 매일 03:00 KST에 모든 brokers 재계산.
 */
exports.recomputeBrokerEligibilityScheduled = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "0 3 * * *",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const brokersSnap = await db.collection("brokers").get();
    let success = 0;
    let failed = 0;
    for (const brokerDoc of brokersSnap.docs) {
      try {
        await recomputeSingleBrokerEligibility(brokerDoc.id);
        success += 1;
      } catch (e) {
        failed += 1;
        console.error(
          `[recomputeBrokerEligibilityScheduled] failed for ${brokerDoc.id}:`,
          e.message
        );
      }
    }
    console.log(
      `[recomputeBrokerEligibilityScheduled] success=${success} failed=${failed} total=${brokersSnap.size}`
    );
  }
);

/**
 * 1.5 migrateTargetBrokerIds (onRequest)
 *
 * 1회용 마이그레이션 — 실행 후 삭제 가능.
 *
 * 모든 활성 mlsProperties 매물의 기존 targetBrokerIds 배열을 priority_grants 문서로 변환.
 * 이미 과거 시점의 배포이므로 즉시 expired(statusReason='migrated_legacy') 처리.
 *
 * 사용법:
 *   - dryRun (기본): GET /migrateTargetBrokerIds?secret=<ADMIN_SECRET>
 *     → 실제 쓰기 없이 영향 통계만 반환. 운영자가 결과 검토 후 dryRun=false 호출.
 *   - 실제 실행: GET /migrateTargetBrokerIds?secret=<ADMIN_SECRET>&dryRun=false
 *
 * 안전 기본값: dryRun이 명시적으로 'false' 가 아니면 *항상* dryRun.
 */
exports.migrateTargetBrokerIds = onRequest(
  {
    region: "asia-northeast3",
    secrets: [adminSecret],
  },
  async (req, res) => {
    cors(req, res, async () => {
      try {
        // 관리자 시크릿 검증
        const providedSecret = req.query.secret || req.headers["x-admin-secret"];
        if (!providedSecret || providedSecret !== adminSecret.value()) {
          res.status(403).json({ error: "Invalid or missing admin secret" });
          return;
        }

        // 안전 기본값: dryRun=true (명시적 false만 실제 실행)
        const dryRun = String(req.query.dryRun || "true").toLowerCase() !== "false";

        // 활성 매물만 페이지 처리
        const propertiesSnap = await db
          .collection("mlsProperties")
          .where("isDeleted", "==", false)
          .where("isActive", "==", true)
          .get();

        let migratedProperties = 0;
        let createdGrants = 0;
        let skippedNoTargets = 0;
        let skippedNoSellerUid = 0;
        const sampleProperties = [];

        for (const propertyDoc of propertiesSnap.docs) {
          const property = propertyDoc.data();
          const targetBrokerIds = Array.isArray(property.targetBrokerIds)
            ? property.targetBrokerIds
            : [];
          if (targetBrokerIds.length === 0) {
            skippedNoTargets += 1;
            continue;
          }
          const sellerUid = property.userId || null;
          if (!sellerUid) skippedNoSellerUid += 1;

          // grantedAt 결정: broadcastedAt → createdAt → now
          let grantedAt;
          if (property.broadcastedAt && property.broadcastedAt.toMillis) {
            grantedAt = property.broadcastedAt;
          } else if (property.createdAt && property.createdAt.toMillis) {
            grantedAt = property.createdAt;
          } else {
            grantedAt = Timestamp.now();
          }
          const expiresAt = addDaysToTimestamp(grantedAt, DEFAULT_GRANT_TTL_DAYS);

          // dryRun: 통계 + 샘플 5개만 수집 후 다음 매물로 진행
          if (dryRun) {
            createdGrants += targetBrokerIds.filter(
              (b) => b && typeof b === "string"
            ).length;
            migratedProperties += 1;
            if (sampleProperties.length < 5) {
              sampleProperties.push({
                propertyId: propertyDoc.id,
                sellerUid,
                targetBrokerCount: targetBrokerIds.length,
              });
            }
            continue;
          }

          // batch로 묶음 처리 (최대 500 ops/batch)
          let batch = db.batch();
          let batchOps = 0;

          for (const brokerId of targetBrokerIds) {
            if (!brokerId || typeof brokerId !== "string") continue;

            const grantId = `pg_legacy_${propertyDoc.id}_${brokerId}`;
            const grantRef = db.collection("priority_grants").doc(grantId);
            const auditRef = newAuditLogRef();

            const grantData = {
              id: grantId,
              propertyId: propertyDoc.id,
              brokerId,
              brokerUid: brokerId, // legacy: uid 매핑 정보 없음
              sellerUid, // Rules priority_grants 매도자 권한 검사용
              type: "seller_match",
              buyerInquiryId: null,
              stage: "participation",
              grantedAt,
              expiresAt,
              status: "expired",
              statusReason: "migrated_legacy",
              activityScore: 0,
              lastActivityAt: null,
              scoringInputs: { source: "targetBrokerIds_migration" },
              revokedAt: Timestamp.now(),
              fulfilledAt: null,
            };
            batch.set(grantRef, grantData);

            batch.set(auditRef, {
              eventId: auditRef.id,
              eventType: "grant_issued",
              actorUid: null,
              propertyId: propertyDoc.id,
              sellerUid, // P0-4 정합: 매도자 audit timeline 가시 보장
              brokerId,
              grantId,
              inputs: {
                propertyId: propertyDoc.id,
                brokerId,
                type: "seller_match",
                stage: "participation",
                source: "migrateTargetBrokerIds",
              },
              outputs: { grantId, status: "expired", statusReason: "migrated_legacy" },
              rulebookVersion: "legacy_migration",
              createdAt: Timestamp.now(),
            });

            batchOps += 2;
            createdGrants += 1;

            // batch 한도 보호 (500 ops)
            if (batchOps >= 480) {
              await batch.commit();
              batch = db.batch();
              batchOps = 0;
            }
          }

          if (batchOps > 0) {
            await batch.commit();
          }
          migratedProperties += 1;
        }

        const result = {
          dryRun,
          migratedProperties,
          createdGrants,
          skippedNoTargets,
          skippedNoSellerUid,
          totalScanned: propertiesSnap.size,
          ...(dryRun ? { sampleProperties } : {}),
        };
        console.log(
          `[migrateTargetBrokerIds] dryRun=${dryRun} migratedProperties=${migratedProperties} createdGrants=${createdGrants} skippedNoTargets=${skippedNoTargets} skippedNoSellerUid=${skippedNoSellerUid}`
        );
        res.status(200).json(result);
      } catch (error) {
        console.error("[migrateTargetBrokerIds] error:", error);
        res.status(500).json({ error: error.message || String(error) });
      }
    });
  }
);

// ============================================================================
// Task 04 — Tiered Release (지역 단계 노출)
//
// 신규 매물이 등록되면 1km → 같은 동 → 인접 동(시군구 내 다른 동) → 시군구 전체
// 순서로 단계적으로 알림을 발송한다. 각 단계 진입 시 broker_eligibility 의 활성
// 중개사를 후보로 추출하고, notifications 컬렉션에 문서를 생성하여 FCM 트리거를
// 발생시킨다. tier_releases/{step} 서브컬렉션에 각 단계의 발송 이력을 누적 기록.
//
// 불변 규칙:
//  - listingMode === "exclusive" 매물은 전 단계 skip.
//  - 매물에 활성 priority_grant 가 1건 이상이면 단계 진척 정지.
//  - audit log (priority_audit_logs) 는 성공/skip/error 모든 경로에 기록.
//  - 거절 코드 신규 추가 없음 (Task 04는 알림/단계 진척 흐름).
// ============================================================================

/**
 * Haversine 거리 (단위: km).
 */
function distanceKm(lat1, lng1, lat2, lng2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

/**
 * geohash precision-N 의 9-cell prefix 반환 (중심 + 8 이웃).
 */
function geohashNeighborsPrefixes(lat, lng, precision) {
  const center = ngeohash.encode(lat, lng, precision);
  const neighbors = ngeohash.neighbors(center);
  return [center, ...neighbors];
}

/**
 * 주소 문자열에서 동/읍/면 추출. brokers.region 미존재 시 fallback.
 */
function extractDongFromAddress(address) {
  if (!address) return null;
  const m = address.match(/([가-힣]+(동|읍|면))/);
  return m ? m[1] : null;
}

/**
 * candidates 중 broker.region (또는 officeAddress 추출) 이 propertyRegion 과 동일한 항목만 반환.
 */
async function filterByMatchingRegion(candidates, propertyRegion) {
  if (!propertyRegion) return [];
  const result = [];
  for (const c of candidates) {
    const brokerSnap = await db.collection("brokers").doc(c.id).get();
    if (!brokerSnap.exists) continue;
    const broker = brokerSnap.data();
    const brokerRegion =
      broker.region || extractDongFromAddress(broker.officeAddress || "");
    if (brokerRegion === propertyRegion) result.push(c);
  }
  return result;
}

/**
 * candidates 중 broker.region 이 propertyRegion 과 다른 항목만 반환.
 */
async function filterByDifferentRegion(candidates, propertyRegion) {
  if (!propertyRegion) return candidates;
  const result = [];
  for (const c of candidates) {
    const brokerSnap = await db.collection("brokers").doc(c.id).get();
    if (!brokerSnap.exists) continue;
    const broker = brokerSnap.data();
    const brokerRegion =
      broker.region || extractDongFromAddress(broker.officeAddress || "");
    if (brokerRegion && brokerRegion !== propertyRegion) result.push(c);
  }
  return result;
}

/**
 * Tier 별로 후보 broker_eligibility 문서 조회.
 * 반환: [{ id, data }] (licenseStatus === "verified" 인 항목만)
 */
async function fetchEligibleBrokersForTier(propertySnap, tier) {
  const property = propertySnap.data();
  const lat = property.latitude;
  const lng = property.longitude;
  const region = property.region; // 동 (예: "역삼동")
  const district = property.district; // 시군구 (예: "강남구")
  if (!lat || !lng || !district) return [];

  const eligRef = db.collection("broker_eligibility");
  let candidates = [];

  if (tier === "tier1_1km") {
    // 1km 반경 — geohash 9-cell prefix scan + Haversine 정확 거리 필터.
    const prefixes = geohashNeighborsPrefixes(lat, lng, GEOHASH_PRECISION);
    const tasks = prefixes.map((p) =>
      eligRef
        .where("geofence.geohash", ">=", p)
        .where("geofence.geohash", "<=", p + "~")
        .get()
    );
    const snaps = await Promise.all(tasks);
    const seen = new Set();
    snaps.forEach((s) =>
      s.forEach((d) => {
        if (seen.has(d.id)) return;
        seen.add(d.id);
        const e = d.data();
        if (e.licenseStatus !== "verified") return;
        const g = e.geofence;
        if (!g || g.lat == null || g.lng == null) return;
        const dist = distanceKm(lat, lng, g.lat, g.lng);
        if (dist <= TIER_RADIUS_KM) candidates.push({ id: d.id, data: e });
      })
    );
  } else {
    // tier2_dong / tier3_adjacent / tier4_district — jurisdictions(시군구) 기반.
    const snap = await eligRef
      .where("jurisdictions", "array-contains", district)
      .get();
    snap.forEach((d) => {
      const e = d.data();
      if (e.licenseStatus !== "verified") return;
      candidates.push({ id: d.id, data: e });
    });
    if (tier === "tier2_dong") {
      // 매물 동(region) 과 동일한 broker.region 만 통과.
      candidates = await filterByMatchingRegion(candidates, region);
    } else if (tier === "tier3_adjacent") {
      // 시군구는 같지만 동이 다른 broker (= "인접" v1 정의).
      candidates = await filterByDifferentRegion(candidates, region);
    }
    // tier4_district: 시군구 일치 전체 (이미 위 query 결과 그대로).
  }
  return candidates;
}

/**
 * 단일 tier 의 후보 중개사 전원에게 신규 매물 알림 문서 생성.
 * 반환: 알림이 생성된 brokerId 배열.
 */
async function notifyTierBrokers(propertyId, tier, brokerCandidates, propertyData) {
  if (!brokerCandidates || brokerCandidates.length === 0) return [];
  const tierLabels = {
    tier1_1km: "1km 신규 매물",
    tier2_dong: "같은 동 신규 매물",
    tier3_adjacent: "인접 동 신규 매물",
    tier4_district: "시·군 전체 신규 매물",
  };
  const title = "신규 매물 알림";
  const body = `${propertyData.region || propertyData.district || ""} · ${tierLabels[tier] || tier}`;
  const tasks = brokerCandidates.map((c) =>
    db.collection("notifications").add({
      userId: c.data.brokerUid || c.id,
      title,
      message: body,
      type: "tier_release",
      relatedId: propertyId,
      tier,
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    })
  );
  await Promise.all(tasks);
  return brokerCandidates.map((c) => c.id);
}

/**
 * mlsProperties/{id}/tier_releases/{step} 누적 기록.
 */
async function recordTierRelease(propertyId, step, tier, notifiedBrokerIds) {
  await db
    .collection("mlsProperties")
    .doc(propertyId)
    .collection("tier_releases")
    .doc(String(step))
    .set(
      {
        step,
        tier,
        enteredAt: FieldValue.serverTimestamp(),
        notifiedBrokerIds: notifiedBrokerIds || [],
      },
      { merge: true }
    );
}

/**
 * priority_audit_logs 에 tiered_release_step 이벤트 기록.
 */
async function logTierAuditEvent(propertyId, tier, step, notifiedCount, skipped, skipReason) {
  await db.collection("priority_audit_logs").add({
    eventId: `audit_${Date.now()}_tier_${propertyId}_${step}`,
    eventType: "tiered_release_step",
    propertyId,
    inputs: { tier: tier || null, step },
    outputs: {
      notifiedCount: notifiedCount || 0,
      skipped: !!skipped,
      skipReason: skipReason || null,
    },
    rulebookVersion: RULEBOOK_VERSION,
    createdAt: FieldValue.serverTimestamp(),
  });
}

/**
 * 4.1 onMlsPropertyCreated — 신규 매물 생성 시 tier1_1km 즉시 발송.
 */
exports.onMlsPropertyCreated = onDocumentCreated(
  { region: "asia-northeast3", document: "mlsProperties/{propertyId}" },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const propertyId = event.params.propertyId;

    // exclusive 매물은 전 단계 skip.
    if (data.listingMode === "exclusive") {
      try {
        await logTierAuditEvent(propertyId, null, 1, 0, true, "exclusive_listing");
      } catch (e) {
        console.error("[onMlsPropertyCreated] audit log failed:", e.message);
      }
      return;
    }

    // draft 등 초기 상태는 skip — 활성화 시점에는 별도 트리거가 필요하나 본 task 범위 외.
    if (data.status !== "active" && data.status !== "pending") {
      return;
    }

    try {
      // 1. releaseTier 초기 설정.
      await snap.ref.set(
        {
          releaseTier: "tier1_1km",
          releaseTierAdvancedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // 2. 1km 반경 중개사 조회.
      const candidates = await fetchEligibleBrokersForTier(snap, "tier1_1km");

      // 3. 알림 발송.
      const notifiedIds = await notifyTierBrokers(
        propertyId,
        "tier1_1km",
        candidates,
        data
      );

      // 4. tier_releases/1 기록.
      await recordTierRelease(propertyId, 1, "tier1_1km", notifiedIds);

      // 5. audit log.
      await logTierAuditEvent(propertyId, "tier1_1km", 1, notifiedIds.length, false);
    } catch (err) {
      console.error("[onMlsPropertyCreated]", err);
      try {
        await logTierAuditEvent(
          propertyId,
          "tier1_1km",
          1,
          0,
          true,
          "error:" + (err.message || String(err))
        );
      } catch (e) {
        console.error("[onMlsPropertyCreated] audit log failed:", e.message);
      }
    }
  }
);

/**
 * 4.2 advanceReleaseTierScheduled — 30분 간격 단계 진척.
 *
 * 각 활성 매물의 releaseTier 가 TIER_DURATIONS_MS 를 경과했고, 활성 grant 가
 * 1건 이상 없으면 다음 tier 로 이동시킨다.
 */
exports.advanceReleaseTierScheduled = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "every 30 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const now = Date.now();
    const propsSnap = await db
      .collection("mlsProperties")
      .where("status", "==", "active")
      .where("releaseTier", "in", ["tier1_1km", "tier2_dong", "tier3_adjacent"])
      .get();

    let processed = 0;
    for (const doc of propsSnap.docs) {
      const data = doc.data();
      if (data.listingMode === "exclusive") continue;
      const tier = data.releaseTier;
      const advancedAtMillis = data.releaseTierAdvancedAt &&
        typeof data.releaseTierAdvancedAt.toMillis === "function"
        ? data.releaseTierAdvancedAt.toMillis()
        : 0;
      const dur = TIER_DURATIONS_MS[tier];
      if (!dur) continue;
      if (now - advancedAtMillis < dur) continue;

      // 활성 grant 1건 이상 — 단계 진척 정지.
      const activeGrantSnap = await db
        .collection("priority_grants")
        .where("propertyId", "==", doc.id)
        .where("status", "==", "active")
        .limit(1)
        .get();
      if (!activeGrantSnap.empty) {
        try {
          await logTierAuditEvent(
            doc.id,
            tier,
            TIER_ORDER.indexOf(tier) + 1,
            0,
            true,
            "active_grant_present"
          );
        } catch (e) {
          console.error("[advanceReleaseTierScheduled] audit failed:", e.message);
        }
        continue;
      }

      // 다음 tier 결정.
      const nextIdx = TIER_ORDER.indexOf(tier) + 1;
      if (nextIdx >= TIER_ORDER.length) continue;
      const nextTier = TIER_ORDER[nextIdx];

      try {
        const candidates = await fetchEligibleBrokersForTier(doc, nextTier);
        const notifiedIds = await notifyTierBrokers(
          doc.id,
          nextTier,
          candidates,
          data
        );
        await recordTierRelease(doc.id, nextIdx + 1, nextTier, notifiedIds);
        await doc.ref.set(
          {
            releaseTier: nextTier,
            releaseTierAdvancedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        await logTierAuditEvent(
          doc.id,
          nextTier,
          nextIdx + 1,
          notifiedIds.length,
          false
        );
        processed += 1;
      } catch (err) {
        console.error("[advanceReleaseTierScheduled] property", doc.id, err);
        try {
          await logTierAuditEvent(
            doc.id,
            nextTier,
            nextIdx + 1,
            0,
            true,
            "error:" + (err.message || String(err))
          );
        } catch (e) {
          console.error("[advanceReleaseTierScheduled] audit failed:", e.message);
        }
      }
    }
    console.log(`[advanceReleaseTierScheduled] processed=${processed}`);
  }
);

// ============================================================================
// Task 05 — M2 시간기록 공개 (broker_participations)
//
// arXiv 모델 — *공개 자체가 우선권 보호*. 분쟁 시 누가 먼저 기여했는지 객관 증거.
//
// 핵심 원칙:
//  - 매도자에게도 displayName(중개사 A/B/C...)만 노출. 실명/연락처는 active grant
//    보유 중개사에 한해서만 callable이 추가 노출.
//  - participationStage 는 'declared' < 'visit_scheduled' < 'offer_made' 단조 증가만.
//  - declaredAt 등 시간기록은 *불변*. 한 번 set되면 후속 호출은 skip.
//  - 모든 쓰기 경로는 callable/trigger(Cloud Functions)만. Rules에서 클라 직접
//    create/update/delete 차단.
//  - audit log 1:1 — declared / stage_advanced / stage_rejected / query_seller /
//    query_self 5종 eventType.
// ============================================================================

const PARTICIPATION_STAGES = ["declared", "visit_scheduled", "offer_made"];

/**
 * 헬퍼: 입력 stage 문자열을 명세 어휘로 정규화.
 * 호환성: 레거시 'participation' / 'visit' / 'offer' 도 매핑.
 */
function normalizeStage(stage) {
  if (!stage) return "declared";
  const s = String(stage).toLowerCase();
  if (s === "declared" || s === "participation") return "declared";
  if (s === "visit_scheduled" || s === "visit") return "visit_scheduled";
  if (s === "offer_made" || s === "offer") return "offer_made";
  return "declared";
}

/**
 * 헬퍼: stage 우선순위 (단조 증가 비교용).
 */
function stageRank(stage) {
  const idx = PARTICIPATION_STAGES.indexOf(normalizeStage(stage));
  return idx < 0 ? 0 : idx;
}

/**
 * 헬퍼: 매물별 등록 순서 비식별 라벨. 0→"중개사 A", 25→"중개사 Z",
 * 26→"중개사 AA", 27→"중개사 AB"... (Excel 컬럼 명명).
 */
function buildAnonymousDisplayName(orderIndex) {
  if (typeof orderIndex !== "number" || orderIndex < 0) orderIndex = 0;
  let n = orderIndex;
  let label = "";
  while (true) {
    label = String.fromCharCode(65 + (n % 26)) + label;
    n = Math.floor(n / 26) - 1;
    if (n < 0) break;
  }
  return `중개사 ${label}`;
}

/**
 * 헬퍼: 트랜잭션 안에서 broker_participations 도큐먼트 보강.
 *
 * 목적:
 *  - 첫 발급 시점에 displayName 자동 발급 (매물별 등록 순서, 비식별).
 *  - declaredAt / publiclyVisibleAt 은 *첫 set 1회만* (즉시 공개 정책).
 *  - stage 는 단조 증가만 — 역행 차단.
 *  - visit_scheduled / offer_made 시점 timestamp 도 1회만 set.
 *
 * 입력:
 *   - tx: Firestore Transaction
 *   - propertyRef: mlsProperties/{propertyId} ref
 *   - propertyId: string
 *   - brokerId: string (sub-collection doc id 로 사용)
 *   - brokerUid: string
 *   - stage: 'declared'|'visit_scheduled'|'offer_made' (정규화 전 값 허용)
 *   - relatedGrantId: string|null
 *   - now: Timestamp
 *   - actorUid: string|null  — audit log actor
 *   - trigger: string         — audit log inputs.trigger
 *
 * 트랜잭션 read-before-write 규약을 지키기 위해, 호출자는 본 함수를
 * **모든 tx.set/update 호출 *이전*** 에 호출해야 한다. 트랜잭션 내부에서
 * 본 함수가 participationRef + collection counter 를 read 한 뒤 set/update
 * 까지 직접 수행하므로, 호출자는 이후 다른 tx.get 을 새로 시도하지 않는다.
 *
 * 반환: { ref, displayName, previousStage, newStage, isFirstWrite, audit: {...} }
 *   호출자가 여러 audit log 를 묶을 수 있도록 audit payload 만 반환하고
 *   실제 audit log set 도 본 함수가 동일 트랜잭션에 기록한다.
 */
async function upsertBrokerParticipationInTx({
  tx,
  propertyRef,
  propertyId,
  brokerId,
  brokerUid,
  stage,
  relatedGrantId,
  now,
  actorUid,
  trigger,
}) {
  const normalizedStage = normalizeStage(stage);
  const participationRef = propertyRef
    .collection("broker_participations")
    .doc(brokerId);

  const existingSnap = await tx.get(participationRef);
  const existing = existingSnap.exists ? existingSnap.data() : null;

  // 기존 displayName 보존; 첫 발급이면 매물별 카운터로 신규 발급.
  let displayName = existing && existing.displayName ? existing.displayName : null;
  let isFirstWrite = !existingSnap.exists;
  let orderIndex = null;

  if (!displayName) {
    // 트랜잭션 내 collection size 산출은 비용이 크므로 외부 사전 카운트가
    // 필요하나, broker_participations 는 1매물당 수십건 이내라 트랜잭션 내
    // get 으로도 안전하다. 다만 tx.get(collectionRef) 는 admin SDK 에서
    // get(query) 형태로 지원되므로 정렬·페이징 없는 단일 query 사용.
    const colRef = propertyRef.collection("broker_participations");
    const colSnap = await tx.get(colRef);
    orderIndex = colSnap.size; // 본인 자신 미포함(아직 set 전)
    displayName = buildAnonymousDisplayName(orderIndex);
  }

  const previousStage = existing ? normalizeStage(existing.participationStage) : null;
  const previousRank = previousStage ? stageRank(previousStage) : -1;
  const newRank = stageRank(normalizedStage);

  // stage 역행 차단 — 단조 증가만. 동등은 허용 (중복 trigger 시 idempotent).
  if (previousRank > newRank) {
    // 역행 시도 — 기록만 남기고 set 은 skip.
    const auditRef = newAuditLogRef();
    tx.set(auditRef, {
      eventId: auditRef.id,
      eventType: "participation_stage_rejected",
      actorUid: actorUid || null,
      propertyId,
      brokerId,
      grantId: relatedGrantId || null,
      inputs: {
        propertyId,
        brokerId,
        attemptedStage: normalizedStage,
        currentStage: previousStage,
        trigger: trigger || "unknown",
      },
      outputs: { rejected: true, reason: "stage_regression" },
      rulebookVersion: RULEBOOK_VERSION,
      createdAt: now,
    });
    return {
      ref: participationRef,
      displayName,
      previousStage,
      newStage: previousStage,
      isFirstWrite: false,
      rejected: true,
    };
  }

  // 시간기록 1회 set 정책. set 시점에만 timestamp 채움.
  const updates = {
    brokerId,
    brokerUid,
    propertyId,
    displayName,
    participationStage: normalizedStage,
    updatedAt: now,
  };

  // declaredAt + publiclyVisibleAt 는 첫 발급 시점만.
  if (!existing || !existing.declaredAt) {
    updates.declaredAt = now;
    updates.publiclyVisibleAt = now;
  }

  // stage 별 시간기록 — 신규 stage 진입 시점에 1회만.
  if (normalizedStage === "visit_scheduled") {
    if (!existing || !existing.visitScheduledAt) {
      updates.visitScheduledAt = now;
    }
  } else if (normalizedStage === "offer_made") {
    if (!existing || !existing.offerMadeAt) {
      updates.offerMadeAt = now;
    }
    // visit 단계를 거치지 않고 바로 offer 인 경우 visit timestamp 도 보정.
    if (!existing || !existing.visitScheduledAt) {
      updates.visitScheduledAt = updates.visitScheduledAt || now;
    }
  }

  if (relatedGrantId) {
    updates.relatedGrantId = relatedGrantId;
  }

  tx.set(participationRef, updates, { merge: true });

  // audit log — 첫 발급이면 declared, 아니면 stage_advanced.
  const auditRef = newAuditLogRef();
  if (isFirstWrite) {
    tx.set(auditRef, {
      eventId: auditRef.id,
      eventType: "participation_declared",
      actorUid: actorUid || null,
      propertyId,
      brokerId,
      grantId: relatedGrantId || null,
      inputs: {
        propertyId,
        brokerId,
        stage: normalizedStage,
        trigger: trigger || "unknown",
      },
      outputs: {
        displayName,
        orderIndex,
        publiclyVisibleAt: now.toMillis(),
      },
      rulebookVersion: RULEBOOK_VERSION,
      createdAt: now,
    });
  } else if (previousRank < newRank) {
    tx.set(auditRef, {
      eventId: auditRef.id,
      eventType: "participation_stage_advanced",
      actorUid: actorUid || null,
      propertyId,
      brokerId,
      grantId: relatedGrantId || null,
      inputs: {
        propertyId,
        brokerId,
        previousStage,
        newStage: normalizedStage,
        trigger: trigger || "unknown",
      },
      outputs: { displayName },
      rulebookVersion: RULEBOOK_VERSION,
      createdAt: now,
    });
  }
  // previousRank === newRank 인 경우 idempotent — audit log 생략.

  return {
    ref: participationRef,
    displayName,
    previousStage,
    newStage: normalizedStage,
    isFirstWrite,
    rejected: false,
  };
}

/**
 * 5.1 getBrokerParticipationsForSeller (callable)
 *
 * 매도자가 자기 매물의 참여 중개사 목록을 조회한다.
 * 비식별성 보장: brokerId/brokerUid/실명/연락처는 *기본 마스킹*.
 * 단, 해당 매물에 대해 *active grant* 보유 중개사에 한해서만 brokerName / brokerPhone /
 * officeName 4필드 추가 노출 (명세 §2.2).
 *
 * 입력: { propertyId: string }
 * 인증: request.auth 필수. mlsProperties/{id}.userId === uid 또는 admin 만 허용.
 *
 * 반환: {
 *   participants: [
 *     {
 *       displayName, participationStage,
 *       declaredAt, visitScheduledAt, offerMadeAt, publiclyVisibleAt,
 *       hasActiveGrant: boolean,
 *       brokerName?, brokerPhone?, officeName?  // active grant 보유 시만
 *     }
 *   ],
 *   total: number
 * }
 */
exports.getBrokerParticipationsForSeller = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const { propertyId } = request.data || {};
    if (!propertyId || typeof propertyId !== "string") {
      throw new HttpsError("invalid-argument", "propertyId is required");
    }

    // 매물 소유자 검증.
    const propertyRef = db.collection("mlsProperties").doc(propertyId);
    const propertySnap = await propertyRef.get();
    if (!propertySnap.exists) {
      throw new HttpsError("not-found", `mlsProperties/${propertyId} not found`);
    }
    const propertyData = propertySnap.data();
    const isOwner = propertyData.userId === request.auth.uid;
    const isAdmin = request.auth.token && request.auth.token.admin === true;
    if (!isOwner && !isAdmin) {
      throw new HttpsError(
        "permission-denied",
        "Only the property owner or admin can view participations"
      );
    }

    // 참여 목록 + 활성 grant 조회를 병렬.
    const [partSnap, activeGrantsSnap] = await Promise.all([
      propertyRef
        .collection("broker_participations")
        .orderBy("declaredAt", "asc")
        .get(),
      db
        .collection("priority_grants")
        .where("propertyId", "==", propertyId)
        .where("status", "==", "active")
        .get(),
    ]);

    // active grant brokerId set.
    const activeBrokerIds = new Set();
    activeGrantsSnap.forEach((d) => {
      const data = d.data();
      if (data && data.brokerId) activeBrokerIds.add(data.brokerId);
    });

    // active broker 의 brokers/{brokerId} 문서를 batch get (실명·연락처용).
    const brokerProfileMap = new Map();
    if (activeBrokerIds.size > 0) {
      const refs = Array.from(activeBrokerIds).map((id) =>
        db.collection("brokers").doc(id)
      );
      const profileSnaps = await db.getAll(...refs);
      profileSnaps.forEach((s) => {
        if (s.exists) brokerProfileMap.set(s.id, s.data());
      });
    }

    const tsMillis = (t) => (t && typeof t.toMillis === "function" ? t.toMillis() : null);

    const participants = partSnap.docs.map((doc) => {
      const p = doc.data() || {};
      const brokerId = p.brokerId || doc.id;
      const hasActiveGrant = activeBrokerIds.has(brokerId);

      // 기본 응답 — brokerId/brokerUid/실명/연락처 *절대 미포함*.
      const out = {
        displayName: p.displayName || null,
        participationStage: normalizeStage(p.participationStage),
        declaredAt: tsMillis(p.declaredAt),
        visitScheduledAt: tsMillis(p.visitScheduledAt),
        offerMadeAt: tsMillis(p.offerMadeAt),
        publiclyVisibleAt: tsMillis(p.publiclyVisibleAt),
        hasActiveGrant,
      };

      if (hasActiveGrant) {
        const profile = brokerProfileMap.get(brokerId) || {};
        // 명세 §2.2 — grant 보유 중개사에 한해 4필드 추가 (brokerId 본 응답에서는 그대로 비공개).
        out.brokerName = profile.ownerName || profile.brokerName || null;
        out.brokerPhone = profile.phoneNumber || profile.brokerPhone || null;
        out.officeName = profile.officeName || profile.companyName || null;
      }

      return out;
    });

    // audit log — query_seller (매도자 조회 추적).
    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "participation_query_seller",
        actorUid: request.auth.uid,
        propertyId,
        brokerId: null,
        grantId: null,
        inputs: { propertyId, isAdmin: !!isAdmin },
        outputs: {
          returnedCount: participants.length,
          activeGrantCount: activeBrokerIds.size,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: Timestamp.now(),
      });
    } catch (e) {
      console.error("[getBrokerParticipationsForSeller] audit failed:", e.message);
    }

    return { participants, total: participants.length };
  }
);

/**
 * 5.2 getMyParticipations (callable)
 *
 * 본인(중개사) 의 시간기록만 collectionGroup 으로 조회.
 * 다른 중개사 데이터는 절대 반환하지 않음.
 *
 * 입력: { propertyId?: string } — 지정 시 단일 매물로 필터.
 * 인증: request.auth 필수.
 *
 * 반환: {
 *   participations: [
 *     {
 *       propertyId, displayName, participationStage,
 *       declaredAt, visitScheduledAt, offerMadeAt, relatedGrantId
 *     }
 *   ],
 *   total: number
 * }
 */
exports.getMyParticipations = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const { propertyId } = request.data || {};
    const callerUid = request.auth.uid;

    let query = db
      .collectionGroup("broker_participations")
      .where("brokerUid", "==", callerUid);
    if (propertyId && typeof propertyId === "string") {
      query = query.where("propertyId", "==", propertyId);
    }

    const snap = await query.orderBy("declaredAt", "desc").get();

    const tsMillis = (t) => (t && typeof t.toMillis === "function" ? t.toMillis() : null);

    const participations = snap.docs
      .map((d) => {
        const p = d.data() || {};
        // 본인 brokerUid 이중 검증 (방어적).
        if (p.brokerUid !== callerUid) return null;
        return {
          propertyId: p.propertyId || null,
          displayName: p.displayName || null,
          participationStage: normalizeStage(p.participationStage),
          declaredAt: tsMillis(p.declaredAt),
          visitScheduledAt: tsMillis(p.visitScheduledAt),
          offerMadeAt: tsMillis(p.offerMadeAt),
          relatedGrantId: p.relatedGrantId || null,
        };
      })
      .filter((x) => x !== null);

    // audit log — query_self.
    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "participation_query_self",
        actorUid: callerUid,
        propertyId: propertyId || null,
        brokerId: null,
        grantId: null,
        inputs: { propertyId: propertyId || null },
        outputs: { returnedCount: participations.length },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: Timestamp.now(),
      });
    } catch (e) {
      console.error("[getMyParticipations] audit failed:", e.message);
    }

    return { participations, total: participations.length };
  }
);

/**
 * 5.3 onMlsPropertyVisitRequestUpdated (트리거)
 *
 * 매물의 visitRequests 배열이 변경되면, 신규로 status='approved'(또는 사전 단계의
 * status 진입)인 항목을 찾아 broker_participations.stage 를 'visit_scheduled' 로
 * 승급한다. visitRequests 는 sub-collection 이 아니라 mlsProperties/{id} 문서의
 * 배열 필드이므로 문서 update 트리거를 사용한다.
 *
 * 어떤 status 값을 visit_scheduled 로 매핑할지:
 *  - 'approved'    — 매도자가 방문 요청을 승인한 시점 (확정 일정).
 *  - 'pending'     — 중개사 요청 직후. visit_scheduled 보다는 약하지만 *예약 의사*
 *                    표명이라 이 단계로 간주한다 (명세 §2.1 어휘 'visit_scheduled').
 *
 * 본 트리거는 idempotent 하다. 동일 brokerId 가 이미 visit_scheduled 또는
 * offer_made 라면 upsertBrokerParticipationInTx 가 stage 단조 증가 정책으로
 * 안전하게 skip 한다.
 */
exports.onMlsPropertyVisitRequestUpdated = onDocumentUpdated(
  { region: "asia-northeast3", document: "mlsProperties/{propertyId}" },
  async (event) => {
    const before = event.data && event.data.before ? event.data.before.data() : null;
    const after = event.data && event.data.after ? event.data.after.data() : null;
    if (!after) return;

    const propertyId = event.params.propertyId;
    const beforeRequests = Array.isArray(before && before.visitRequests)
      ? before.visitRequests
      : [];
    const afterRequests = Array.isArray(after.visitRequests) ? after.visitRequests : [];
    if (afterRequests.length === 0) return;

    // beforeRequests 를 (id → status) 맵으로.
    const beforeStatusById = new Map();
    for (const r of beforeRequests) {
      if (r && r.id) beforeStatusById.set(r.id, r.status);
    }

    // 신규 또는 status 변경된 visit request 만 처리.
    const trackedStatuses = new Set([
      "pending",
      "approved",
      "scheduled",
      "confirmed",
    ]);

    const propertyRef = db.collection("mlsProperties").doc(propertyId);

    for (const r of afterRequests) {
      if (!r || !r.brokerId) continue;
      if (!trackedStatuses.has(r.status)) continue;
      const prevStatus = beforeStatusById.get(r.id);
      if (prevStatus === r.status) continue; // 변화 없음.

      try {
        await db.runTransaction(async (tx) => {
          const now = Timestamp.now();
          // brokerUid 추정: visit_request 안에 명시 없으면 brokerId 그대로 사용.
          // (방문 요청 생성은 caller uid 와 brokerId 가 일치하는 정책: firestore.rules visitRequests).
          const brokerUid = r.brokerUid || r.brokerId;
          await upsertBrokerParticipationInTx({
            tx,
            propertyRef,
            propertyId,
            brokerId: r.brokerId,
            brokerUid,
            stage: "visit_scheduled",
            relatedGrantId: r.grantId || null,
            now,
            actorUid: null, // 트리거는 actor 없음.
            trigger: `visit_request:${r.status}`,
          });
        });
      } catch (e) {
        console.error(
          `[onMlsPropertyVisitRequestUpdated] failed for property=${propertyId} broker=${r.brokerId}:`,
          e.message
        );
      }

      // P1-3: visit_request 진척 시 broker 활성 grant activityScore +0.4 가산.
      // status 가 'approved' 또는 'scheduled' 인 경우만 (pending 은 의사 표명만, 진척 약함).
      // 분리된 트랜잭션 — 위 upsert 와 충돌 없음. 실패 시 안전하게 swallow (헬퍼 내부 로깅).
      if (r.status === "approved" || r.status === "scheduled") {
        await bumpActivityScoreForBroker(
          propertyId,
          r.brokerId,
          ACTIVITY_SCORE_DELTA_VISIT,
          `visit_request:${r.status}`,
        );
      }
    }
  }
);

/**
 * 5.4 onBrokerOfferCreated (트리거)
 *
 * brokerOffers 문서 생성 시, 동일 (propertyId, brokerId) 의 broker_participations
 * stage 를 'offer_made' 로 승급. brokerOffers 는 매물 sub-collection 이 아니라
 * 루트 컬렉션이므로 propertyId 필드로 매물 ref 를 찾는다.
 */
exports.onBrokerOfferCreated = onDocumentCreated(
  { region: "asia-northeast3", document: "brokerOffers/{offerId}" },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    if (!data) return;
    const propertyId = data.propertyId;
    const brokerId = data.brokerId;
    if (!propertyId || !brokerId) return;

    const propertyRef = db.collection("mlsProperties").doc(propertyId);

    try {
      await db.runTransaction(async (tx) => {
        const now = Timestamp.now();
        const brokerUid = data.brokerUid || brokerId;
        await upsertBrokerParticipationInTx({
          tx,
          propertyRef,
          propertyId,
          brokerId,
          brokerUid,
          stage: "offer_made",
          relatedGrantId: data.relatedGrantId || null,
          now,
          actorUid: brokerUid,
          trigger: `broker_offer:${snap.id}`,
        });
      });
    } catch (e) {
      console.error(
        `[onBrokerOfferCreated] failed for property=${propertyId} broker=${brokerId}:`,
        e.message
      );
    }

    // P1-3: brokerOffer 생성 시 broker 활성 grant activityScore +0.6 가산.
    // offer 는 의향서 단계 — visit 보다 더 큰 진척이라 가산치도 크다.
    // 분리된 트랜잭션 — 위 upsert 와 충돌 없음.
    await bumpActivityScoreForBroker(
      propertyId,
      brokerId,
      ACTIVITY_SCORE_DELTA_OFFER,
      `broker_offer:${snap.id}`,
    );
  }
);

// ============================================================================
// Task 05 (집계 비정규화): broker_participations write → mlsProperties 집계 갱신
// ============================================================================
//
// 비로그인 공개 페이지에서 "참여 중개사 N명, 첫 참여 D-7" 정보를 노출하기 위해
// broker_participations 컬렉션의 read 권한을 풀지 않고 부모 mlsProperties 도큐먼트에
// 두 필드를 비정규화한다:
//   - participantCount: number (broker_participations 총 개수)
//   - firstParticipantDeclaredAt: Timestamp | null (가장 빠른 declaredAt)
//
// firestore.rules 의 mlsProperties read 는 비로그인 허용이므로 이 두 필드는
// 공개 컨슈머가 직접 읽는다. 매도자 본인의 직접 수정은 affectedKeys 룰로 차단됨.
//
// 무한루프 안전성: 본 트리거는 broker_participations 변경 시에만 발화하고,
// mlsProperties 자체 update 는 트리거 발화시키지 않는다.
exports.onBrokerParticipationWritten = onDocumentWritten(
  { region: "asia-northeast3", document: "mlsProperties/{propertyId}/broker_participations/{partId}" },
  async (event) => {
    const propertyId = event.params.propertyId;
    if (!propertyId) return;

    const propertyRef = db.collection("mlsProperties").doc(propertyId);
    const partsRef = propertyRef.collection("broker_participations");

    try {
      const snap = await partsRef.get();
      const newCount = snap.size;

      let firstDeclaredAt = null;
      for (const doc of snap.docs) {
        const d = doc.data() || {};
        const declared = d.declaredAt;
        if (!declared) continue;
        // Timestamp 비교 — Firestore Timestamp 는 toMillis() 보유.
        if (firstDeclaredAt === null || declared.toMillis() < firstDeclaredAt.toMillis()) {
          firstDeclaredAt = declared;
        }
      }

      // 이전 값 확인 (집계 변화 시에만 audit 기록).
      const propSnap = await propertyRef.get();
      if (!propSnap.exists) {
        // 부모 매물이 사라진 경우 (cascade 삭제 등) — 갱신 skip.
        return;
      }
      const prev = propSnap.data() || {};
      const previousCount = typeof prev.participantCount === "number" ? prev.participantCount : 0;
      const prevFirst = prev.firstParticipantDeclaredAt || null;

      const countChanged = previousCount !== newCount;
      const firstChanged =
        (prevFirst === null) !== (firstDeclaredAt === null) ||
        (prevFirst !== null &&
          firstDeclaredAt !== null &&
          prevFirst.toMillis() !== firstDeclaredAt.toMillis());

      if (!countChanged && !firstChanged) {
        // 변화 없음 — write skip 으로 추가 트리거 절약.
        return;
      }

      await propertyRef.update({
        participantCount: newCount,
        firstParticipantDeclaredAt: firstDeclaredAt, // null 가능
      });

      // audit log: 집계 변동 시 1회만 기록 (노이즈 절감).
      await db.collection("priority_audit_logs").add({
        eventId: newAuditLogRef().id,
        eventType: "participation_count_recomputed",
        propertyId,
        inputs: { trigger: "broker_participation_written" },
        outputs: {
          previousCount,
          newCount,
          firstParticipantDeclaredAt: firstDeclaredAt,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: FieldValue.serverTimestamp(),
      });
    } catch (e) {
      console.error(
        `[onBrokerParticipationWritten] failed for property=${propertyId}:`,
        e.message
      );
    }
  }
);

// ============================================================================
// Task 06 — 알고리즘 투명성 (Transparency)
//
// 핵심:
//   - algorithm_config/active 가 가중치/임계값/버전의 *진실원* (Task 06 §A1).
//   - replayDecision: 과거 grant 의 raw inputs 를 현재 weights 로 재계산해 검증.
//   - computeDailyMetricsScheduled: 일일 활성 매물/중개사/시장점유율 집계 + 알람.
//   - onPriorityAppealCreated: 이의제기 생성 시 자동 replay 첨부.
//   - resolveAppeal: 관리자 검토 후 status='resolved'|'rejected' 로 종결.
// ============================================================================

/**
 * 헬퍼: replayDecision 의 핵심 로직을 callable 외부에서도 재사용 (트리거에서 호출).
 *
 * 입력: grantId
 * 반환: { grantId, propertyId, brokerId, type, stage, grantedAt(ms),
 *         originalScore, originalWeightsVersion,
 *         recomputedScore, recomputedWeightsVersion,
 *         match, divergenceReason,
 *         weights, threshold, breakdown, rawInputs }
 *
 * 예외: not-found / invalid-argument 의 경우 HttpsError 던짐.
 */
async function _replayDecisionInternal(grantId) {
  if (!grantId || typeof grantId !== "string") {
    throw new HttpsError("invalid-argument", "grantId is required");
  }
  const grantRef = db.collection("priority_grants").doc(grantId);
  const grantSnap = await grantRef.get();
  if (!grantSnap.exists) {
    throw new HttpsError("not-found", `priority_grants/${grantId} not found`);
  }
  const grant = grantSnap.data() || {};
  const original = grant.scoringInputs || {};
  const cfg = await loadMatchingConfig();

  const rawInputs = original.rawInputs || null;
  let recomputed = null;
  let divergenceReason = null;

  if (!rawInputs || typeof rawInputs !== "object") {
    divergenceReason = "inputs_unavailable";
    recomputed = {
      score: null,
      breakdown: null,
      weights: cfg.weights,
      threshold: cfg.threshold,
      version: cfg.version,
      rawInputs: null,
    };
  } else {
    recomputed = computeMatchingScoreFromRawInputs(rawInputs, cfg);
  }

  const originalScore = typeof original.score === "number" ? original.score : null;
  const recomputedScore = typeof recomputed.score === "number" ? recomputed.score : null;
  const match =
    originalScore !== null &&
    recomputedScore !== null &&
    Math.abs(originalScore - recomputedScore) < 1e-6;

  if (divergenceReason === null) {
    if (match) {
      divergenceReason = null;
    } else if (cfg.version !== original.version) {
      divergenceReason = "weights_changed";
    } else if (
      typeof original.threshold === "number" &&
      cfg.threshold !== original.threshold
    ) {
      divergenceReason = "threshold_changed";
    } else {
      divergenceReason = "unknown";
    }
  }

  const grantedAtMs =
    grant.grantedAt && typeof grant.grantedAt.toMillis === "function"
      ? grant.grantedAt.toMillis()
      : null;

  return {
    grantId,
    propertyId: grant.propertyId || null,
    brokerId: grant.brokerId || null,
    sellerUid: grant.sellerUid || null,
    type: grant.type || null,
    stage: grant.stage || null,
    grantedAt: grantedAtMs,
    originalScore,
    originalWeightsVersion: original.version || null,
    recomputedScore,
    recomputedWeightsVersion: cfg.version,
    match,
    divergenceReason,
    weights: cfg.weights,
    threshold: cfg.threshold,
    breakdown: recomputed.breakdown,
    rawInputs: rawInputs,
  };
}

/**
 * Task 06 §A3 — replayDecision (callable, admin only)
 *
 * 과거 grant 결정의 재현성을 검증한다. 가중치 변경 후 과거 결정이 어떻게 바뀌는지
 * 보고 싶을 때 admin 이 호출.
 */
exports.replayDecision = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth || !request.auth.token || request.auth.token.admin !== true) {
      throw new HttpsError("permission-denied", "admin only");
    }
    const { grantId } = request.data || {};
    if (!grantId) {
      throw new HttpsError("invalid-argument", "grantId required");
    }

    const result = await _replayDecisionInternal(grantId);

    // audit log — 항상 기록 (admin 행동 추적).
    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "decision_replayed",
        actorUid: request.auth.uid,
        propertyId: result.propertyId,
        brokerId: result.brokerId,
        sellerUid: result.sellerUid,
        grantId,
        inputs: {
          grantId,
          originalVersion: result.originalWeightsVersion,
          currentVersion: result.recomputedWeightsVersion,
        },
        outputs: {
          originalScore: result.originalScore,
          recomputedScore: result.recomputedScore,
          match: result.match,
          divergenceReason: result.divergenceReason,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: Timestamp.now(),
      });
    } catch (e) {
      console.error("[replayDecision] audit failed:", e.message);
    }

    return result;
  }
);

/**
 * Task 06 §A4 — computeDailyMetricsScheduled
 *
 * 매일 03:00 KST. 활성 매물/중개사/(임시) 시장점유율 집계 후 platform_metrics/{yyyymmdd} 저장.
 *
 * 점유율 휴리스틱: estimatedRegionMarketShare ≈ totalActiveListings / max(totalActiveBrokers * 5, 1)
 *   - 한국감정원/공공데이터 거래량 미연동 상태이므로 임시 추정값.
 *   - TODO: 실거래 데이터 연동 시 weighted share 로 대체.
 *
 * alertLevel:
 *   share < 0.30 → 'green'
 *   0.30 ≤ share < 0.40 → 'yellow'
 *   share ≥ 0.40 → 'red'
 *
 * red 도달 시 console.error (Slack/이메일 webhook 미구현, 다음 task 인계).
 */
exports.computeDailyMetricsScheduled = onSchedule(
  {
    region: "asia-northeast3",
    schedule: "0 3 * * *",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const ACTIVE_STATUSES = ["active", "inquiry", "underOffer", "depositTaken"];

    // 1) 활성 매물.
    const propsSnap = await db
      .collection("mlsProperties")
      .where("status", "in", ACTIVE_STATUSES)
      .get();
    const activeProps = propsSnap.docs.filter((d) => {
      const v = d.data() || {};
      return v.isDeleted !== true;
    });
    const totalActiveListings = activeProps.length;

    // 2) 활성 중개사 (verified).
    const eligSnap = await db
      .collection("broker_eligibility")
      .where("licenseStatus", "==", "verified")
      .get();
    const totalActiveBrokers = eligSnap.size;

    // 3) 시도/시군구 별 매물 수.
    const regionCounts = {};
    const districtCounts = {};
    for (const doc of activeProps) {
      const d = doc.data() || {};
      const region = d.region || null;
      const district = d.district || null;
      if (region) regionCounts[region] = (regionCounts[region] || 0) + 1;
      if (district) districtCounts[district] = (districtCounts[district] || 0) + 1;
    }

    // 4) 임시 시장점유율 휴리스틱.
    const denom = Math.max(totalActiveBrokers * 5, 1);
    const estimatedRegionMarketShare = totalActiveListings / denom;

    // 5) alertLevel.
    let alertLevel = "green";
    if (estimatedRegionMarketShare >= 0.4) alertLevel = "red";
    else if (estimatedRegionMarketShare >= 0.3) alertLevel = "yellow";

    // 6) docId = YYYYMMDD (Asia/Seoul).
    // Asia/Seoul 은 UTC+9 (DST 없음). UTC ms 에 9시간 더해 시점 계산.
    const nowMs = Date.now();
    const seoulMs = nowMs + 9 * 60 * 60 * 1000;
    const seoulDate = new Date(seoulMs);
    const yyyy = seoulDate.getUTCFullYear();
    const mm = String(seoulDate.getUTCMonth() + 1).padStart(2, "0");
    const dd = String(seoulDate.getUTCDate()).padStart(2, "0");
    const yyyymmdd = `${yyyy}${mm}${dd}`;

    const metricsDoc = {
      date: yyyymmdd,
      computedAt: Timestamp.now(),
      totalActiveListings,
      totalActiveBrokers,
      regionCounts,
      districtCounts,
      estimatedRegionMarketShare,
      alertLevel,
      heuristicNote:
        "estimatedRegionMarketShare = totalActiveListings / max(totalActiveBrokers*5, 1). " +
        "한국감정원 거래량 미연동, 임시 휴리스틱 (TODO: 실데이터 연동).",
      rulebookVersion: RULEBOOK_VERSION,
    };

    try {
      await db
        .collection("platform_metrics")
        .doc(yyyymmdd)
        .set(metricsDoc, { merge: false });
    } catch (e) {
      console.error("[computeDailyMetricsScheduled] write failed:", e.message);
      return;
    }

    // 7) audit log.
    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "metrics_computed",
        actorUid: null,
        propertyId: null,
        brokerId: null,
        sellerUid: null,
        grantId: null,
        inputs: { date: yyyymmdd },
        outputs: {
          totalActiveListings,
          totalActiveBrokers,
          estimatedRegionMarketShare,
          alertLevel,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: Timestamp.now(),
      });
    } catch (e) {
      console.error("[computeDailyMetricsScheduled] audit failed:", e.message);
    }

    // 8) red 도달 — 알람 hook (현재는 console.error 만).
    if (alertLevel === "red") {
      console.error(
        `[computeDailyMetricsScheduled] ALERT level=red date=${yyyymmdd} share=${estimatedRegionMarketShare.toFixed(3)} listings=${totalActiveListings} brokers=${totalActiveBrokers}`
      );
      // TODO: Slack / 이메일 webhook 연동 (다음 task 인계).
    }

    console.log(
      `[computeDailyMetricsScheduled] date=${yyyymmdd} listings=${totalActiveListings} brokers=${totalActiveBrokers} share=${estimatedRegionMarketShare.toFixed(3)} level=${alertLevel}`
    );
  }
);

/**
 * Task 06 §A5 — onPriorityAppealCreated (Firestore 트리거)
 *
 * 이의제기 생성 시 자동 replay 결과 첨부 + audit log.
 */
exports.onPriorityAppealCreated = onDocumentCreated(
  { region: "asia-northeast3", document: "priority_appeals/{appealId}" },
  async (event) => {
    const appealId = event.params.appealId;
    const snap = event.data;
    if (!snap) return;
    const data = snap.data() || {};
    const grantId = data.grantId || null;
    const filerUid = data.filerUid || null;

    // 1) audit log — appeal_filed.
    let appealPropertyId = null;
    let appealBrokerId = null;
    let appealSellerUid = null;
    try {
      if (grantId) {
        const grantSnap = await db.collection("priority_grants").doc(grantId).get();
        if (grantSnap.exists) {
          const g = grantSnap.data() || {};
          appealPropertyId = g.propertyId || null;
          appealBrokerId = g.brokerId || null;
          appealSellerUid = g.sellerUid || null;
        }
      }
    } catch (_) {
      // audit log enrichment 실패 시 null 로 진행.
    }

    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "appeal_filed",
        actorUid: filerUid,
        propertyId: appealPropertyId,
        brokerId: appealBrokerId,
        sellerUid: appealSellerUid,
        grantId,
        inputs: {
          appealId,
          grantId,
          reason: typeof data.reason === "string" ? data.reason.slice(0, 200) : null,
        },
        outputs: { status: data.status || "open" },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: Timestamp.now(),
      });
    } catch (e) {
      console.error("[onPriorityAppealCreated] audit failed:", e.message);
    }

    // 2) replay 시도 후 priority_appeals/{id} 에 결과 첨부.
    //
    // P1-12 — listing_mode_dispute 카테고리는 grantId 부재 허용 (propertyId 만으로
    // 제기). replay 알고리즘은 grantId 기반이므로 본 카테고리에서는 replay skip 하고
    // 분쟁 카테고리 표식만 기록 — admin 검토 시 분쟁 분류 즉시 식별 가능.
    const appealCategory = data.appealCategory || "grant_decision";
    let replayedDecision = null;
    try {
      if (appealCategory === "listing_mode_dispute") {
        replayedDecision = {
          skipped: true,
          reason: "listing_mode_dispute: replay not applicable (no grantId)",
        };
      } else if (grantId) {
        replayedDecision = await _replayDecisionInternal(grantId);
      } else {
        replayedDecision = { error: "grantId missing in appeal" };
      }
    } catch (e) {
      replayedDecision = { error: e.message || String(e) };
    }

    try {
      await snap.ref.update({
        replayedDecision,
        replayedAt: Timestamp.now(),
      });
    } catch (e) {
      console.error("[onPriorityAppealCreated] update appeal failed:", e.message);
    }
  }
);

/**
 * Task 06 §A6 — resolveAppeal (callable, admin only)
 *
 * 관리자가 이의제기를 검토 후 status='resolved'|'rejected' 로 종결.
 *
 * P1-12 — 이의 제기와 listingMode 통합:
 *   * optional `action` 입력 — `{ type: 'override_listing_mode', newMode,
 *     newExclusiveBrokerIds?, reason }`. 분쟁이 인정되어 매물 모드를 강제
 *     변경해야 할 때 별도 callable 호출 없이 단일 흐름으로 처리.
 *   * action 처리는 P1-11 `_executeAdminListingModeOverride` 헬퍼를 호출 —
 *     adminOverrideListingMode 와 *동일한 검증·audit·알림* 보장.
 *   * action 적용 시 audit eventType `appeal_resolved_with_listing_mode_override`
 *     로 기록 (기존 `appeal_resolved` audit 와 별도 1건 추가 적재 — admin
 *     override audit 와 함께 *3-레이어* 흔적 보존).
 *   * 기존 단순 resolution 흐름은 영향 0 — action 미지정 시 종전과 동일.
 */
exports.resolveAppeal = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth || !request.auth.token || request.auth.token.admin !== true) {
      throw new HttpsError("permission-denied", "admin only");
    }
    const { appealId, decision, resolution } = request.data || {};
    if (!appealId || !["resolved", "rejected"].includes(decision) || !resolution) {
      throw new HttpsError(
        "invalid-argument",
        "appealId/decision/resolution required"
      );
    }
    if (typeof resolution !== "string" || resolution.length < 1 || resolution.length > 1000) {
      throw new HttpsError("invalid-argument", "resolution length 1~1000");
    }

    // P1-12 — action 분기 사전 검증 (transaction 진입 전 필수 입력 가드).
    // 본 변수는 transaction 종료 후에만 사용 — transaction 본체에 영향 0.
    const _appealAction = (request.data && request.data.action) || null;
    if (_appealAction !== null) {
      if (typeof _appealAction !== "object") {
        throw new HttpsError("invalid-argument", "action must be an object");
      }
      if (_appealAction.type !== "override_listing_mode") {
        throw new HttpsError(
          "invalid-argument",
          `action.type must be 'override_listing_mode' (got ${_appealAction.type})`
        );
      }
      // action.reason 은 admin override audit 의 사유 필드 — 비어있으면 거절
      // (adminOverrideListingMode 와 동일한 정책 — 우회 불가).
      if (typeof _appealAction.reason !== "string" || _appealAction.reason.trim().length === 0) {
        throw new HttpsError(
          "invalid-argument",
          "action.reason is required (audit trail)"
        );
      }
      // decision === 'resolved' 인 경우에만 모드 강제 변경 의미 — rejected 시
      // mode override 적용은 의미 모순 (이의 제기 기각 + 모드 변경은 동시 불가).
      if (decision !== "resolved") {
        throw new HttpsError(
          "failed-precondition",
          "action requires decision='resolved' (cannot override mode while rejecting appeal)"
        );
      }
    }

    const appealRef = db.collection("priority_appeals").doc(appealId);
    const auditRef = newAuditLogRef();

    try {
      const result = await db.runTransaction(async (tx) => {
        const appealSnap = await tx.get(appealRef);
        if (!appealSnap.exists) {
          throw new HttpsError("not-found", `priority_appeals/${appealId} not found`);
        }
        const appeal = appealSnap.data() || {};
        const currentStatus = appeal.status || null;
        if (currentStatus !== "open" && currentStatus !== "reviewing") {
          throw new HttpsError(
            "failed-precondition",
            `appeal status must be 'open' or 'reviewing' (current=${currentStatus})`
          );
        }

        // 연관 grant 정보 capture (audit log enrichment 용).
        let appealPropertyId = null;
        let appealBrokerId = null;
        let appealSellerUid = null;
        if (appeal.grantId) {
          try {
            const gSnap = await tx.get(
              db.collection("priority_grants").doc(appeal.grantId)
            );
            if (gSnap.exists) {
              const g = gSnap.data() || {};
              appealPropertyId = g.propertyId || null;
              appealBrokerId = g.brokerId || null;
              appealSellerUid = g.sellerUid || null;
            }
          } catch (_) {
            // ignore
          }
        }

        const now = Timestamp.now();
        tx.update(appealRef, {
          status: decision,
          resolution,
          resolvedAt: now,
          resolvedBy: request.auth.uid,
        });

        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType: "appeal_resolved",
          actorUid: request.auth.uid,
          propertyId: appealPropertyId,
          brokerId: appealBrokerId,
          sellerUid: appealSellerUid,
          grantId: appeal.grantId || null,
          inputs: { appealId, decision },
          outputs: { resolution, previousStatus: currentStatus },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: now,
        });

        return {
          appealId,
          status: decision,
          resolvedAt: now.toMillis(),
        };
      });

      // P1-12 — action 분기 처리 (transaction 외부, 1차 transaction 성공 후만 실행)
      //
      // 1차 transaction (이의 제기 종결) 이 성공했을 때만 listing mode override
      // 를 시도. 두 단계로 분리한 이유:
      //   * 기존 resolveAppeal transaction 본체 라인 *0 변경* 보장
      //   * P1-11 _executeAdminListingModeOverride 헬퍼는 자체 transaction
      //     수행 — *모드 변경 + audit + 매도자 알림* 일관성을 보장.
      //   * 두 transaction 사이 짧은 갭이 존재하나, audit 가 양쪽 모두 적재
      //     되므로 추적 가능 (3-레이어 audit: appeal_resolved + admin_override
      //     _listing_mode + appeal_resolved_with_listing_mode_override).
      if (_appealAction !== null && _appealAction.type === "override_listing_mode") {
        // 분쟁 대상 propertyId 결정 — appeal.propertyId (listing_mode_dispute)
        // 또는 grant.propertyId (grant_decision) 또는 action.propertyId (명시).
        let actionPropertyId = _appealAction.propertyId || null;
        if (!actionPropertyId) {
          // appeal 문서를 다시 읽어 propertyId 결정 (transaction 후 read 안전).
          const appealAfterSnap = await appealRef.get();
          const appealAfter = appealAfterSnap.data() || {};
          actionPropertyId = appealAfter.propertyId || null;
          if (!actionPropertyId && appealAfter.grantId) {
            const gSnap = await db.collection("priority_grants")
              .doc(appealAfter.grantId).get();
            if (gSnap.exists) {
              actionPropertyId = (gSnap.data() || {}).propertyId || null;
            }
          }
        }
        if (!actionPropertyId) {
          throw new HttpsError(
            "failed-precondition",
            "action requires propertyId (resolvable from appeal.propertyId, action.propertyId, or grant)"
          );
        }

        // P1-11 헬퍼 재사용 — adminOverrideListingMode 와 동일한 검증·audit·알림.
        // _executeAdminListingModeOverride 내부에서 자체 transaction + audit +
        // notification 처리. 본 호출이 throw 시 외부 catch 가 HttpsError 변환.
        const overrideResult = await _executeAdminListingModeOverride({
          adminUid: request.auth.uid,
          propertyId: actionPropertyId,
          newMode: _appealAction.newMode,
          newExclusiveBrokerIds: _appealAction.newExclusiveBrokerIds,
          reason: _appealAction.reason,
        });

        // P1-12 신규 audit eventType — 이의 제기 인용 + 모드 변경 동시 처리 흔적.
        // 기존 appeal_resolved (1차 transaction) + admin_override_listing_mode
        // (헬퍼 내부) audit 와 함께 *3-레이어* 흔적 보존.
        const linkAuditRef = newAuditLogRef();
        await linkAuditRef.set({
          eventId: linkAuditRef.id,
          eventType: "appeal_resolved_with_listing_mode_override",
          actorUid: request.auth.uid,
          propertyId: actionPropertyId,
          brokerId: null,
          sellerUid: null,
          grantId: null,
          inputs: {
            appealId,
            decision,
            actionType: "override_listing_mode",
            newMode: _appealAction.newMode,
            reason: _appealAction.reason.trim().slice(0, 200),
          },
          outputs: {
            modeChanged: overrideResult.listingMode !== null,
            newListingMode: overrideResult.listingMode,
            exclusiveBrokerCount: Array.isArray(overrideResult.exclusiveBrokerIds)
              ? overrideResult.exclusiveBrokerIds.length
              : 0,
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: Timestamp.now(),
        });

        // 응답 페이로드 확장 — 클라이언트가 모드 변경 결과까지 한 번에 수신.
        return {
          ...result,
          actionApplied: {
            type: "override_listing_mode",
            propertyId: actionPropertyId,
            listingMode: overrideResult.listingMode,
            exclusiveBrokerIds: overrideResult.exclusiveBrokerIds,
            changedAt: overrideResult.changedAt,
          },
        };
      }

      return result;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("[resolveAppeal] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

// ============================================================================
// Task 07 — 매도자 자율 단독 지정 (Open / Exclusive Listing)
//
// 명세 [docs/task/07-seller-autonomy.md]
//
// changeListingMode callable:
//   매도자가 *자율적으로* listingMode / exclusiveBrokerIds 를 변경할 수 있는
//   유일한 경로. mlsProperties 문서 update 는 Rules 차원에서 listingMode /
//   exclusiveBrokerIds / exclusiveSelectedAt / exclusiveLastChangedAt 4개
//   필드를 직접 변경 불가하도록 차단한다 — 본 callable 만 보호 필드 set.
//
// 안전 장치:
//   1. 매도자(propertyData.userId === auth.uid) 만 호출 가능 (admin 도 차단).
//   2. open → exclusive: 활성 grant 1건이라도 있으면 거부 (기득권 보호).
//   3. exclusive → open: 즉시 가능 (매도자 자율).
//   4. exclusiveBrokerIds 변경(같은 모드 내 재지정): 24h 쿨다운.
//   5. 모든 지정 brokerId 는 broker_eligibility.licenseStatus === 'verified' 검증.
//   6. exclusive 모드 진입 시 사용자가 자율 동의 플래그(consent=true) 명시 필요.
//   7. 모든 변경은 priority_audit_logs 에 기록 — eventType:
//        'listing_mode_changed' (mode 전환)
//        'exclusive_brokers_changed' (같은 모드 내 brokerIds 만 변경)
//
// 응답 schema:
//   {
//     propertyId: string,
//     listingMode: 'open' | 'exclusive',
//     exclusiveBrokerIds: string[],     // open 모드면 []
//     exclusiveSelectedAt: number|null, // millis (exclusive 진입 시각)
//     changedAt: number,                // millis (이번 변경 시각)
//     cooldownUntil: number             // millis (다음 변경 가능 시각)
//   }
// ============================================================================

exports.changeListingMode = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }
    const callerUid = request.auth.uid;

    const {
      propertyId,
      listingMode,
      exclusiveBrokerIds,
      consent,
    } = request.data || {};

    // === 입력 검증 ===
    if (!propertyId || typeof propertyId !== "string") {
      throw new HttpsError("invalid-argument", "propertyId is required");
    }
    if (!["open", "exclusive"].includes(listingMode)) {
      throw new HttpsError(
        "invalid-argument",
        `${REASON.INVALID_LISTING_MODE}: listingMode must be 'open' or 'exclusive'`
      );
    }
    const requestedIds = Array.isArray(exclusiveBrokerIds)
      ? exclusiveBrokerIds.filter((s) => typeof s === "string" && s.length > 0)
      : [];
    if (listingMode === "exclusive") {
      if (requestedIds.length < 1) {
        throw new HttpsError(
          "invalid-argument",
          `exclusive_at_least_one_required: at least one broker required`
        );
      }
      if (requestedIds.length > EXCLUSIVE_BROKER_MAX) {
        throw new HttpsError(
          "failed-precondition",
          `${REASON.EXCLUSIVE_BROKER_LIMIT_EXCEEDED}: max ${EXCLUSIVE_BROKER_MAX} brokers, got ${requestedIds.length}`
        );
      }
      // 자율 동의 명시 필수 — 법무 라인 (§33①9호 회피).
      if (consent !== true) {
        throw new HttpsError(
          "failed-precondition",
          `${REASON.EXCLUSIVE_CONSENT_REQUIRED}: seller self-attestation required`
        );
      }
      // 중복 제거
      const uniq = Array.from(new Set(requestedIds));
      if (uniq.length !== requestedIds.length) {
        throw new HttpsError(
          "invalid-argument",
          `exclusiveBrokerIds contains duplicates`
        );
      }
    }

    // === 면허 검증 (트랜잭션 외부 사전 조회 + 트랜잭션 내 재검증) ===
    // broker_eligibility 는 매물 수정과 다른 컬렉션이므로 트랜잭션 내 read 후
    // mlsProperties 만 update — 단일 트랜잭션으로 묶지 않아도 안전성 확보 (eligibility 는 read-only 검증).
    const eligibilitySnaps = [];
    for (const bid of requestedIds) {
      const snap = await db.collection("broker_eligibility").doc(bid).get();
      if (!snap.exists) {
        throw new HttpsError(
          "failed-precondition",
          `${REASON.EXCLUSIVE_BROKER_NOT_VERIFIED}: broker_eligibility/${bid} not found`
        );
      }
      const e = snap.data() || {};
      if (e.licenseStatus !== "verified") {
        throw new HttpsError(
          "failed-precondition",
          `${REASON.EXCLUSIVE_BROKER_NOT_VERIFIED}: broker(${bid}) license not verified (status=${e.licenseStatus})`
        );
      }
      eligibilitySnaps.push({ id: bid, data: e });
    }

    const propertyRef = db.collection("mlsProperties").doc(propertyId);
    const auditRef = newAuditLogRef();

    try {
      const result = await db.runTransaction(async (tx) => {
        const propertySnap = await tx.get(propertyRef);
        if (!propertySnap.exists) {
          throw new HttpsError("not-found", `mlsProperties/${propertyId} not found`);
        }
        const propertyData = propertySnap.data() || {};
        const sellerUid = propertyData.userId || null;

        // 1) 본인 매도자만 호출 가능. admin 우회도 차단 — 매도자 자발 의사 보호.
        if (sellerUid !== callerUid) {
          throw new HttpsError(
            "permission-denied",
            `${REASON.NOT_PROPERTY_OWNER}: caller(${callerUid}) is not property owner(${sellerUid})`
          );
        }

        const previousMode = propertyData.listingMode || "open";
        const previousIds = Array.isArray(propertyData.exclusiveBrokerIds)
          ? propertyData.exclusiveBrokerIds
          : [];
        const nowMs = Date.now();

        // 2) 24h 쿨다운 검증 — 직전 변경 시각 기준.
        // exclusiveLastChangedAt 가 없으면 쿨다운 없음 (최초 진입).
        const lastChangedAt = propertyData.exclusiveLastChangedAt;
        let cooldownEndMs = 0;
        if (lastChangedAt && typeof lastChangedAt.toMillis === "function") {
          cooldownEndMs =
            lastChangedAt.toMillis() +
            LISTING_MODE_CHANGE_COOLDOWN_HOURS * 60 * 60 * 1000;
        }

        // 같은 mode 내 brokerIds 변경 또는 mode 전환 자체에 쿨다운 적용.
        // 단, exclusive → open 은 매도자 자율 (기득권 미생성) → 쿨다운 면제.
        const isExclusiveExit = previousMode === "exclusive" && listingMode === "open";
        if (!isExclusiveExit && cooldownEndMs > nowMs) {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.EXCLUSIVE_COOLDOWN}: cooldown active until ${new Date(cooldownEndMs).toISOString()}`
          );
        }

        // 3) open → exclusive 전환: 활성 grant 1건이라도 있으면 거부 (기득권 보호).
        // exclusive → exclusive (brokerIds 변경) 도 동일하게 활성 grant 영향 검토.
        if (listingMode === "exclusive") {
          const activeGrantSnap = await db
            .collection("priority_grants")
            .where("propertyId", "==", propertyId)
            .where("status", "==", "active")
            .limit(1)
            .get();
          if (!activeGrantSnap.empty) {
            // 기존 active grant 의 brokerId 가 새 exclusiveBrokerIds 에 포함되면 OK.
            const activeBrokerIds = new Set(
              activeGrantSnap.docs.map((d) => d.data().brokerId)
            );
            const allCovered = Array.from(activeBrokerIds).every((b) =>
              requestedIds.includes(b)
            );
            if (!allCovered) {
              throw new HttpsError(
                "failed-precondition",
                `${REASON.EXCLUSIVE_HAS_ACTIVE_GRANT}: active grants exist for brokers not in new exclusive list`
              );
            }
          }
        }

        // 4) update 적용
        const nowTs = Timestamp.now();
        const update = {
          listingMode,
          exclusiveBrokerIds: listingMode === "exclusive" ? requestedIds : [],
          exclusiveLastChangedAt: nowTs,
          updatedAt: nowTs,
        };
        // exclusive 진입 시각은 *최초 exclusive 변환* 시점만 기록.
        // exclusive 모드 내 brokerIds 변경은 exclusiveSelectedAt 유지.
        if (listingMode === "exclusive" && previousMode !== "exclusive") {
          update.exclusiveSelectedAt = nowTs;
          update.exclusiveSelfAttestedAt = nowTs;
        } else if (listingMode === "open") {
          update.exclusiveSelectedAt = null;
          update.exclusiveSelfAttestedAt = null;
        }

        tx.update(propertyRef, update);

        // 5) audit log — eventType 두 종 분기.
        const isModeSwitch = previousMode !== listingMode;
        const eventType = isModeSwitch
          ? "listing_mode_changed"
          : "exclusive_brokers_changed";

        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType,
          actorUid: callerUid,
          propertyId,
          brokerId: null,
          sellerUid,
          grantId: null,
          inputs: {
            previousMode,
            newMode: listingMode,
            previousExclusiveBrokerIds: previousIds,
            newExclusiveBrokerIds: requestedIds,
            consent: !!consent,
          },
          outputs: {
            modeChanged: isModeSwitch,
            exclusiveBrokerCount: requestedIds.length,
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: nowTs,
        });

        const cooldownUntilMs =
          nowTs.toMillis() +
          LISTING_MODE_CHANGE_COOLDOWN_HOURS * 60 * 60 * 1000;

        return {
          propertyId,
          listingMode,
          exclusiveBrokerIds: listingMode === "exclusive" ? requestedIds : [],
          exclusiveSelectedAt:
            listingMode === "exclusive"
              ? (update.exclusiveSelectedAt
                  ? update.exclusiveSelectedAt.toMillis()
                  : (propertyData.exclusiveSelectedAt
                      && typeof propertyData.exclusiveSelectedAt.toMillis === "function"
                      ? propertyData.exclusiveSelectedAt.toMillis()
                      : null))
              : null,
          changedAt: nowTs.toMillis(),
          cooldownUntil: cooldownUntilMs,
        };
      });
      return result;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("[changeListingMode] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

// ============================================================================
// P1-11 — adminOverrideListingMode callable
//
// 명세 [docs/task/2026-05-03-MASTER-v1.3-mvp-handoff.md §3.2 P1-11]
//      [docs/task/2026-05-02-task-07-seller-autonomy-handoff.md §5.3 #25]
//
// 운영자가 분쟁 처리 또는 매물 검증 과정에서 매도자 동의 없이 listingMode /
// exclusiveBrokerIds 를 강제로 변경할 수 있는 경로. Task 07 changeListingMode
// 와 분리되어 있으며, 본 callable 은 다음 보호 장치 *우회* 가 가능하다:
//   - 24h 쿨다운 우회 (admin 권한)
//   - 활성 grant 보호 무시 가능 (분쟁 해결용)
//
// 단, 다음 검증은 우회 불가:
//   - admin claim (request.auth.token.admin === true)
//   - reason 필드 (운영 결정 사유 audit 필수, 비어있으면 거절)
//   - newMode 필드 ('open' | 'exclusive')
//   - newMode='exclusive' 시 newExclusiveBrokerIds 1~3건 + 면허 검증
//
// 모든 변경은 priority_audit_logs 에 'admin_override_listing_mode' eventType
// 으로 적재 (before/after 상태 + actor + reason 보관). 매도자에게 notifications
// 컬렉션에 doc 1건 적재 — sendPushNotification 트리거 자동 발화.
//
// 매도자 알림 카피는 [docs/common/operator-to-user-copy-gate.md §3] 7원칙 준수:
//   - 일상 한국어 (영문 0)
//   - "분쟁 사유 함께" 표현 — MyHome 의지 개입 인상 차단
//   - 30자 이내 (사유 본문은 별도 필드로 분리)
//
// 응답 schema:
//   {
//     propertyId: string,
//     listingMode: 'open' | 'exclusive',
//     exclusiveBrokerIds: string[],
//     exclusiveSelectedAt: number|null,
//     changedAt: number,
//   }
// ============================================================================

// ----------------------------------------------------------------------------
// P1-12 — _executeAdminListingModeOverride (internal helper)
//
// adminOverrideListingMode 의 transaction 본체와 *동일한 검증·audit·알림*
// 로직을 외부 호출 가능한 형태로 추출한 헬퍼. P1-12 resolveAppeal 의 action
// 분기가 모드 강제 변경을 위임할 때 사용한다.
//
// 입력:
//   { adminUid, propertyId, newMode, newExclusiveBrokerIds, reason }
//   * adminUid: 호출자(이미 admin 검증된 callable 의 request.auth.uid)
//   * 나머지 필드: adminOverrideListingMode 와 동일 시맨틱
//
// 응답:
//   { propertyId, listingMode, exclusiveBrokerIds, exclusiveSelectedAt, changedAt }
//   adminOverrideListingMode 의 응답 schema 와 1:1 동일.
//
// 안전 장치:
//   * admin claim 은 *호출자가 검증* — 본 헬퍼는 admin 검증 *생략* (헬퍼는
//     callable 외부 노출 0). resolveAppeal 시작부에서 admin 검증 완료.
//   * 그 외 모든 검증 (newMode 화이트리스트, reason 필수, 면허 검증, 24h
//     쿨다운 우회, 활성 grant 보호 무시) 은 adminOverrideListingMode 와 동일.
//   * audit eventType: 'admin_override_listing_mode' (동일 이벤트 적재).
//   * 매도자 알림 1건 (동일 카피 — grant_messages.dart 와 동기).
//
// 본 헬퍼 신설 이유 — adminOverrideListingMode (P1-11) 본체 0 변경 보장
// (명세 P1-12 §3 "기존 함수 0 변경, 호출만").
// ----------------------------------------------------------------------------
async function _executeAdminListingModeOverride({
  adminUid,
  propertyId,
  newMode,
  newExclusiveBrokerIds,
  reason,
}) {
  // === 입력 검증 (admin claim 은 호출자 책임) ===
  if (!propertyId || typeof propertyId !== "string") {
    throw new HttpsError("invalid-argument", "propertyId is required");
  }
  if (!["open", "exclusive"].includes(newMode)) {
    throw new HttpsError(
      "invalid-argument",
      `${REASON.INVALID_LISTING_MODE}: newMode must be 'open' or 'exclusive'`
    );
  }
  if (typeof reason !== "string" || reason.trim().length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "reason is required for admin override (audit trail)"
    );
  }
  if (reason.length > 500) {
    throw new HttpsError("invalid-argument", "reason exceeds 500 characters");
  }
  const requestedIds = Array.isArray(newExclusiveBrokerIds)
    ? newExclusiveBrokerIds.filter((s) => typeof s === "string" && s.length > 0)
    : [];
  if (newMode === "exclusive") {
    if (requestedIds.length < 1) {
      throw new HttpsError(
        "invalid-argument",
        `exclusive_at_least_one_required: at least one broker required`
      );
    }
    if (requestedIds.length > EXCLUSIVE_BROKER_MAX) {
      throw new HttpsError(
        "failed-precondition",
        `${REASON.EXCLUSIVE_BROKER_LIMIT_EXCEEDED}: max ${EXCLUSIVE_BROKER_MAX} brokers, got ${requestedIds.length}`
      );
    }
    const uniq = Array.from(new Set(requestedIds));
    if (uniq.length !== requestedIds.length) {
      throw new HttpsError("invalid-argument", "newExclusiveBrokerIds contains duplicates");
    }
  }

  // === 면허 검증 (exclusive 모드 한정) ===
  if (newMode === "exclusive") {
    for (const bid of requestedIds) {
      const snap = await db.collection("broker_eligibility").doc(bid).get();
      if (!snap.exists) {
        throw new HttpsError(
          "failed-precondition",
          `${REASON.EXCLUSIVE_BROKER_NOT_VERIFIED}: broker_eligibility/${bid} not found`
        );
      }
      const e = snap.data() || {};
      if (e.licenseStatus !== "verified") {
        throw new HttpsError(
          "failed-precondition",
          `${REASON.EXCLUSIVE_BROKER_NOT_VERIFIED}: broker(${bid}) license not verified (status=${e.licenseStatus})`
        );
      }
    }
  }

  const propertyRef = db.collection("mlsProperties").doc(propertyId);
  const auditRef = newAuditLogRef();
  const notificationRef = db.collection("notifications").doc();

  return await db.runTransaction(async (tx) => {
    const propertySnap = await tx.get(propertyRef);
    if (!propertySnap.exists) {
      throw new HttpsError("not-found", `mlsProperties/${propertyId} not found`);
    }
    const propertyData = propertySnap.data() || {};
    const sellerUid = propertyData.userId || null;

    const previousMode = propertyData.listingMode || "open";
    const previousIds = Array.isArray(propertyData.exclusiveBrokerIds)
      ? propertyData.exclusiveBrokerIds
      : [];

    const nowTs = Timestamp.now();
    const update = {
      listingMode: newMode,
      exclusiveBrokerIds: newMode === "exclusive" ? requestedIds : [],
      exclusiveLastChangedAt: nowTs,
      updatedAt: nowTs,
    };
    if (newMode === "exclusive" && previousMode !== "exclusive") {
      update.exclusiveSelectedAt = nowTs;
      update.exclusiveSelfAttestedAt = null;
    } else if (newMode === "open") {
      update.exclusiveSelectedAt = null;
      update.exclusiveSelfAttestedAt = null;
    }

    tx.update(propertyRef, update);

    tx.set(auditRef, {
      eventId: auditRef.id,
      eventType: "admin_override_listing_mode",
      actorUid: adminUid,
      propertyId,
      brokerId: null,
      sellerUid,
      grantId: null,
      inputs: {
        previousMode,
        newMode,
        previousExclusiveBrokerIds: previousIds,
        newExclusiveBrokerIds: newMode === "exclusive" ? requestedIds : [],
        reason: reason.trim(),
      },
      outputs: {
        modeChanged: previousMode !== newMode,
        exclusiveBrokerCount: newMode === "exclusive" ? requestedIds.length : 0,
      },
      rulebookVersion: RULEBOOK_VERSION,
      createdAt: nowTs,
    });

    if (sellerUid) {
      const previousModeLabel =
        previousMode === "exclusive" ? "단독 지정" : "모든 중개사 공개";
      const newModeLabel =
        newMode === "exclusive" ? "단독 지정" : "모든 중개사 공개";
      const title = "관리자가 매물 모드를 변경했어요";
      const body = `${previousModeLabel} → ${newModeLabel} (분쟁 사유 함께)`;
      tx.set(notificationRef, {
        userId: sellerUid,
        title,
        message: body,
        type: "admin_override_listing_mode",
        relatedId: propertyId,
        overrideReason: reason.trim(),
        previousMode,
        newMode,
        createdAt: nowTs,
        read: false,
      });
    }

    return {
      propertyId,
      listingMode: newMode,
      exclusiveBrokerIds: newMode === "exclusive" ? requestedIds : [],
      exclusiveSelectedAt:
        newMode === "exclusive"
          ? (update.exclusiveSelectedAt
              ? update.exclusiveSelectedAt.toMillis()
              : (propertyData.exclusiveSelectedAt
                  && typeof propertyData.exclusiveSelectedAt.toMillis === "function"
                  ? propertyData.exclusiveSelectedAt.toMillis()
                  : null))
          : null,
      changedAt: nowTs.toMillis(),
    };
  });
}

exports.adminOverrideListingMode = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    // === 1) admin claim 검증 ===
    if (!request.auth || !request.auth.token || request.auth.token.admin !== true) {
      throw new HttpsError("permission-denied", "admin only");
    }
    const adminUid = request.auth.uid;

    const {
      propertyId,
      newMode,
      newExclusiveBrokerIds,
      reason,
    } = request.data || {};

    // === 2) 입력 검증 ===
    if (!propertyId || typeof propertyId !== "string") {
      throw new HttpsError("invalid-argument", "propertyId is required");
    }
    if (!["open", "exclusive"].includes(newMode)) {
      throw new HttpsError(
        "invalid-argument",
        `${REASON.INVALID_LISTING_MODE}: newMode must be 'open' or 'exclusive'`
      );
    }
    // reason 비어있지 않음 — admin 결정 사유 audit 필수.
    if (typeof reason !== "string" || reason.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "reason is required for admin override (audit trail)"
      );
    }
    if (reason.length > 500) {
      throw new HttpsError(
        "invalid-argument",
        "reason exceeds 500 characters"
      );
    }
    const requestedIds = Array.isArray(newExclusiveBrokerIds)
      ? newExclusiveBrokerIds.filter((s) => typeof s === "string" && s.length > 0)
      : [];
    if (newMode === "exclusive") {
      if (requestedIds.length < 1) {
        throw new HttpsError(
          "invalid-argument",
          `exclusive_at_least_one_required: at least one broker required`
        );
      }
      if (requestedIds.length > EXCLUSIVE_BROKER_MAX) {
        throw new HttpsError(
          "failed-precondition",
          `${REASON.EXCLUSIVE_BROKER_LIMIT_EXCEEDED}: max ${EXCLUSIVE_BROKER_MAX} brokers, got ${requestedIds.length}`
        );
      }
      const uniq = Array.from(new Set(requestedIds));
      if (uniq.length !== requestedIds.length) {
        throw new HttpsError(
          "invalid-argument",
          `newExclusiveBrokerIds contains duplicates`
        );
      }
    }

    // === 3) 면허 검증 (exclusive 모드 한정) ===
    // admin 도 미검증 broker 지정 차단 — 면허 라인은 우회 불가 (법무 라인).
    if (newMode === "exclusive") {
      for (const bid of requestedIds) {
        const snap = await db.collection("broker_eligibility").doc(bid).get();
        if (!snap.exists) {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.EXCLUSIVE_BROKER_NOT_VERIFIED}: broker_eligibility/${bid} not found`
          );
        }
        const e = snap.data() || {};
        if (e.licenseStatus !== "verified") {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.EXCLUSIVE_BROKER_NOT_VERIFIED}: broker(${bid}) license not verified (status=${e.licenseStatus})`
          );
        }
      }
    }

    const propertyRef = db.collection("mlsProperties").doc(propertyId);
    const auditRef = newAuditLogRef();
    const notificationRef = db.collection("notifications").doc();

    try {
      const result = await db.runTransaction(async (tx) => {
        const propertySnap = await tx.get(propertyRef);
        if (!propertySnap.exists) {
          throw new HttpsError("not-found", `mlsProperties/${propertyId} not found`);
        }
        const propertyData = propertySnap.data() || {};
        const sellerUid = propertyData.userId || null;

        const previousMode = propertyData.listingMode || "open";
        const previousIds = Array.isArray(propertyData.exclusiveBrokerIds)
          ? propertyData.exclusiveBrokerIds
          : [];

        // 24h 쿨다운 우회 + 활성 grant 보호 무시 (admin 분쟁 해결 권한).
        // changeListingMode 와 다른 점: 본 callable 은 위 두 검증을 *생략*.
        // Task 07 §5.3 #25 — admin override 는 매도자 동의 없이 강제 변경 가능.

        // === 4) update 적용 ===
        const nowTs = Timestamp.now();
        const update = {
          listingMode: newMode,
          exclusiveBrokerIds: newMode === "exclusive" ? requestedIds : [],
          exclusiveLastChangedAt: nowTs,
          updatedAt: nowTs,
        };
        if (newMode === "exclusive" && previousMode !== "exclusive") {
          update.exclusiveSelectedAt = nowTs;
          // admin override 시 self-attestation 은 *부재* — 매도자 동의 없이 설정.
          // exclusiveSelfAttestedAt 를 null 로 남겨 *매도자 자율 vs admin 강제* 구분.
          update.exclusiveSelfAttestedAt = null;
        } else if (newMode === "open") {
          update.exclusiveSelectedAt = null;
          update.exclusiveSelfAttestedAt = null;
        }

        tx.update(propertyRef, update);

        // === 5) audit log — admin_override_listing_mode eventType ===
        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType: "admin_override_listing_mode",
          actorUid: adminUid,
          propertyId,
          brokerId: null,
          sellerUid,
          grantId: null,
          inputs: {
            previousMode,
            newMode,
            previousExclusiveBrokerIds: previousIds,
            newExclusiveBrokerIds: newMode === "exclusive" ? requestedIds : [],
            reason: reason.trim(),
          },
          outputs: {
            modeChanged: previousMode !== newMode,
            exclusiveBrokerCount:
              newMode === "exclusive" ? requestedIds.length : 0,
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: nowTs,
        });

        // === 6) 매도자 알림 — 운영자→사용자 통지 경로 ===
        // 카피는 grant_messages.dart adminOverrideListingMode* 상수와 동기.
        // sellerUid 가 있을 때만 알림 생성 (orphan 매물 방지).
        if (sellerUid) {
          const previousModeLabel =
            previousMode === "exclusive" ? "단독 지정" : "모든 중개사 공개";
          const newModeLabel =
            newMode === "exclusive" ? "단독 지정" : "모든 중개사 공개";
          // grant_messages.dart adminOverrideListingModeNotificationTitle 와 동기.
          const title = "관리자가 매물 모드를 변경했어요";
          // grant_messages.dart adminOverrideListingModeNotificationBodyTemplate 동기.
          // "분쟁 사유 함께" 표현 — MyHome 의지 개입 인상 차단 (사실 + 사유 별도).
          const body = `${previousModeLabel} → ${newModeLabel} (분쟁 사유 함께)`;
          tx.set(notificationRef, {
            userId: sellerUid,
            title,
            message: body,
            type: "admin_override_listing_mode",
            relatedId: propertyId,
            // 사유는 본문 외 별도 필드로 저장 — 매도자가 인앱에서 펼쳐 볼 수 있음.
            // 푸시 본문은 30자 한도 통과 (분쟁 사유 함께 표기로 별도 보기 안내).
            overrideReason: reason.trim(),
            previousMode,
            newMode,
            createdAt: nowTs,
            read: false,
          });
        }

        return {
          propertyId,
          listingMode: newMode,
          exclusiveBrokerIds: newMode === "exclusive" ? requestedIds : [],
          exclusiveSelectedAt:
            newMode === "exclusive"
              ? (update.exclusiveSelectedAt
                  ? update.exclusiveSelectedAt.toMillis()
                  : (propertyData.exclusiveSelectedAt
                      && typeof propertyData.exclusiveSelectedAt.toMillis === "function"
                      ? propertyData.exclusiveSelectedAt.toMillis()
                      : null))
              : null,
          changedAt: nowTs.toMillis(),
        };
      });
      return result;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("[adminOverrideListingMode] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

// ============================================================================
// P1-10 — updateAlgorithmConfig (admin callable)
//
// 원천: docs/task/2026-05-03-MASTER-v1.3-mvp-handoff.md §3.2 P1-10 + §6.8
//      docs/task/2026-05-02-task-06-transparency-handoff.md §5.1 #4
//
// 목적:
//   Task 06 의 algorithm_config/active 진실원을 운영자가 *안전하게* 갱신할 수 있는
//   유일한 admin 경로. 가중치/임계값 변경 시 항상:
//     1) 새 버전 archive doc 생성: `algorithm_config/{newVersion}` (불변)
//     2) `algorithm_config/active` reference 업데이트 (가장 최근 active 만 가리킴)
//     3) audit log 1건 추가: eventType='algorithm_config_updated'
//        (before/after weights + threshold + actor)
//     4) 인스턴스 메모리 캐시 강제 무효화 — 다음 read 시 새 값 자동 반영.
//
//   prevVersion 의 archive 보존: bootstrap/이전 update 시 이미 `algorithm_config/{prevVersion}`
//   문서로 set 되어 있으므로 별도 archive 불필요. *active 만* 덮어쓰며 historical
//   doc 은 *절대* 손대지 않는다.
//
// 안전 장치 (마스터 §6.8 RULEBOOK_VERSION vs MATCHING_VERSION 분리):
//   * 본 callable 은 MATCHING_VERSION 변경 *전용* — 가중치 *값* 변경.
//   * RULEBOOK_VERSION (룰북 의미 변경) 변경은 별도 후속 callable
//     (또는 RULEBOOK_VERSION 상수 bump + Functions 재배포). 본 callable 은 RULEBOOK
//     의미를 *변경하지 않음* — `rulebookVersion` 필드는 현재 RULEBOOK_VERSION 그대로 기록.
//
// 검증:
//   * admin only (`request.auth.token.admin === true`)
//   * version 신규 (기존 algorithm_config/active.version 과 달라야 함, 빈 문자열 거부)
//   * version 형식 'matching_v' prefix 권장 — 형식 위반 거부
//   * 동일 version 으로 archive doc 이 이미 존재하면 거부 (불변성)
//   * weights 키 = 정확히 6종 (time, jurisdiction, license, activity, distance, capHeadroom)
//   * 각 weight 0~1 범위
//   * 가중치 합 = 1.0 ± 0.001 (clamp)
//   * threshold 0~1 범위
//   * changelog 필수 (1~500자) — 운영 추적용
//
// 절대 금지:
//   * 기존 archive doc 강제 덮어쓰기 X (already-exists 거부)
//   * 가중치 합 != 1.0 거부 (HttpsError 'invalid-argument')
//   * admin 외 호출 거부 (HttpsError 'permission-denied')
//   * Task 06 loadMatchingConfig 의 read/bootstrap 로직 *불변*
//
// 반환:
//   {
//     version: string (new),
//     previousVersion: string|null,
//     weights: { ... },
//     threshold: number,
//     updatedAt: number (millis),
//     auditLogId: string,
//   }
// ============================================================================

const _MATCHING_WEIGHT_KEYS = [
  "time",
  "jurisdiction",
  "license",
  "activity",
  "distance",
  "capHeadroom",
];
const _MATCHING_WEIGHT_SUM_TOLERANCE = 0.001;

/**
 * P1-10 — algorithm_config 메모리 캐시 강제 무효화.
 *
 * `let _matchingConfigCache` / `_matchingConfigCachedAt` 는 같은 모듈 closure 이므로
 * 본 함수에서 직접 재할당 가능. updateAlgorithmConfig 트랜잭션 commit 직후 호출 →
 * 다음 loadMatchingConfig() 호출이 Firestore 에서 새 active 를 읽도록 강제.
 *
 * 다중 인스턴스: 본 함수는 *호출 인스턴스* 만 무효화한다. 다른 인스턴스는 자체 5분 TTL
 * 만료 시점에 자연 갱신 — Task 06 의 캐시 전파 정책과 동일.
 */
function _invalidateMatchingConfigCache() {
  _matchingConfigCache = null;
  _matchingConfigCachedAt = 0;
}

/**
 * P1-10 — 가중치 객체 검증 (키 집합 + 범위 + 합 1.0 ± tolerance).
 * 통과 시 정규화된 weights 반환, 실패 시 HttpsError throw.
 */
function _validateWeights(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new HttpsError("invalid-argument", "weights must be an object");
  }
  const keys = Object.keys(input).sort();
  const expected = _MATCHING_WEIGHT_KEYS.slice().sort();
  if (keys.length !== expected.length || keys.some((k, i) => k !== expected[i])) {
    throw new HttpsError(
      "invalid-argument",
      `weights keys must be exactly [${_MATCHING_WEIGHT_KEYS.join(", ")}]`
    );
  }
  const normalized = {};
  let sum = 0;
  for (const k of _MATCHING_WEIGHT_KEYS) {
    const v = input[k];
    if (typeof v !== "number" || !isFinite(v) || v < 0 || v > 1) {
      throw new HttpsError(
        "invalid-argument",
        `weight '${k}' must be a finite number in [0, 1] (got ${v})`
      );
    }
    normalized[k] = v;
    sum += v;
  }
  if (Math.abs(sum - 1.0) > _MATCHING_WEIGHT_SUM_TOLERANCE) {
    throw new HttpsError(
      "invalid-argument",
      `weights must sum to 1.0 ± ${_MATCHING_WEIGHT_SUM_TOLERANCE} (got ${sum.toFixed(6)})`
    );
  }
  return normalized;
}

exports.updateAlgorithmConfig = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    // 1) admin only
    if (!request.auth || !request.auth.token || request.auth.token.admin !== true) {
      throw new HttpsError("permission-denied", "admin only");
    }

    const { version, weights, threshold, changelog } = request.data || {};

    // 2) version 검증 (형식 + 비공백)
    if (!version || typeof version !== "string" || version.trim().length === 0) {
      throw new HttpsError("invalid-argument", "version is required (non-empty string)");
    }
    const trimmedVersion = version.trim();
    if (!trimmedVersion.startsWith("matching_v")) {
      throw new HttpsError(
        "invalid-argument",
        "version must start with 'matching_v' (e.g., matching_v1.4.0)"
      );
    }
    if (trimmedVersion.length > 64) {
      throw new HttpsError("invalid-argument", "version length must be <= 64 chars");
    }

    // 3) threshold 검증
    if (typeof threshold !== "number" || !isFinite(threshold) || threshold < 0 || threshold > 1) {
      throw new HttpsError(
        "invalid-argument",
        `threshold must be a finite number in [0, 1] (got ${threshold})`
      );
    }

    // 4) changelog 검증 (운영 추적용 필수)
    if (typeof changelog !== "string" || changelog.length < 1 || changelog.length > 500) {
      throw new HttpsError(
        "invalid-argument",
        "changelog is required (1~500 chars) for audit trail"
      );
    }

    // 5) weights 검증 (키/범위/합)
    const normalizedWeights = _validateWeights(weights);

    const activeRef = db.collection("algorithm_config").doc("active");
    const newVersionRef = db.collection("algorithm_config").doc(trimmedVersion);
    const auditRef = newAuditLogRef();

    let resultPayload;
    try {
      resultPayload = await db.runTransaction(async (tx) => {
        // active 문서 read — bootstrap 미실행 상태면 거부 (선 bootstrap 후 update 권장)
        const activeSnap = await tx.get(activeRef);
        if (!activeSnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            "algorithm_config/active not bootstrapped yet — call loadMatchingConfig once first"
          );
        }
        const prev = activeSnap.data() || {};
        const previousVersion = prev.version || null;
        const previousWeights = prev.weights || null;
        const previousThreshold = typeof prev.threshold === "number" ? prev.threshold : null;

        // version 신규성 검증 — 동일 version 거부
        if (previousVersion === trimmedVersion) {
          throw new HttpsError(
            "failed-precondition",
            `version '${trimmedVersion}' is identical to current active version — bump version for any change`
          );
        }

        // 동일 version archive doc 이 이미 존재하면 거부 (불변성 보호)
        const newVersionSnap = await tx.get(newVersionRef);
        if (newVersionSnap.exists) {
          throw new HttpsError(
            "already-exists",
            `algorithm_config/${trimmedVersion} already exists — cannot overwrite archive doc`
          );
        }

        const now = Timestamp.now();
        const newConfig = {
          version: trimmedVersion,
          weights: normalizedWeights,
          threshold,
          updatedAt: now,
          updatedBy: request.auth.uid,
          changelog,
          previousVersion,
        };

        // 새 버전 archive doc 생성 (불변)
        tx.set(newVersionRef, newConfig);
        // active reference 업데이트 — prev 는 이미 {prevVersion} 에 보존되어 있음
        tx.set(activeRef, newConfig);

        // audit log — before/after 가중치 + actor
        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType: "algorithm_config_updated",
          actorUid: request.auth.uid,
          propertyId: null,
          brokerId: null,
          sellerUid: null,
          grantId: null,
          inputs: {
            previousVersion,
            previousWeights,
            previousThreshold,
            changelog,
          },
          outputs: {
            version: trimmedVersion,
            weights: normalizedWeights,
            threshold,
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: now,
        });

        return {
          version: trimmedVersion,
          previousVersion,
          weights: normalizedWeights,
          threshold,
          updatedAt: now.toMillis(),
          auditLogId: auditRef.id,
        };
      });
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("[updateAlgorithmConfig] transaction failed:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }

    // 6) 인스턴스 캐시 강제 무효화 (다음 read 시 새 active 자동 반영)
    _invalidateMatchingConfigCache();

    return resultPayload;
  }
);

// ============================================================================
// P1-8 — Slack/Email Webhook (platform_metrics red alertLevel 도달 시 운영 알림)
//
// MASTER v1.3 §3.2 P1-8 + Task 06 §5.1 #3 — 출시 후 1~4주 운영 보강.
//
// 설계 원칙:
//  1. computeDailyMetricsScheduled 의 platform_metrics/{yyyymmdd} write 를 트리거로 사용
//     (onDocumentCreated). 별도 cron 분리 시 race condition 발생 가능 → 트리거가 단일 진실원.
//  2. 채널 3종 graceful degradation:
//     - Slack: SLACK_WEBHOOK_URL 부재 시 skip + warn log
//     - Email: SMTP_HOST/USER/PASS 부재 시 skip (axios 기반 SendGrid HTTP API 채택 — nodemailer 추가 회피)
//     - 폴백: notifications 컬렉션에 admin 알림 문서 생성 (운영자가 admin UI에서 확인 — 항상 작동)
//  3. webhook 실패 시 트리거 throw 금지 — 무한 재시도 폭주 차단. catch + console.error 후 다음 채널 진행.
//  4. 메시지 카피: copy-deck §6 운영자 화법 OK (사용자 노출 0). admin 명확성 우선.
//  5. audit log 1:1 — 신규 eventType `platform_alert_sent` (3-레이어 동기:
//     functions audit ↔ grant_messages.platformAlertSentLabel ↔ copy-deck §4).
//  6. 신규 의존성 0 — axios(기존)·firebase-admin(기존) 만 사용.
// ============================================================================

/**
 * Slack incoming webhook 호출 (graceful — 부재/실패 시 skip).
 * 환경 변수: SLACK_WEBHOOK_URL (예: https://hooks.slack.com/services/T.../B.../xxx)
 *
 * @param {string} text Slack 메시지 본문 (mrkdwn 지원)
 * @returns {Promise<{ok: boolean, skipped?: boolean, reason?: string}>}
 */
async function _sendSlackAlert(text) {
  const url = process.env.SLACK_WEBHOOK_URL;
  if (!url || typeof url !== "string" || url.trim().length === 0) {
    console.warn("[platformAlert] SLACK_WEBHOOK_URL not set — skip Slack channel");
    return { ok: false, skipped: true, reason: "no_webhook_url" };
  }
  try {
    await axios.post(
      url,
      { text },
      { timeout: 5000, headers: { "Content-Type": "application/json" } }
    );
    return { ok: true };
  } catch (e) {
    // graceful — throw 하지 않음. webhook 실패가 트리거 retry 폭주 유발 차단.
    console.error("[platformAlert] Slack webhook failed:", e.message || e);
    return { ok: false, skipped: false, reason: e.message || "slack_post_failed" };
  }
}

/**
 * Email 알림 발송 (SendGrid HTTP API — nodemailer 의존성 추가 회피).
 * 환경 변수: SENDGRID_API_KEY, ALERT_EMAIL_RECIPIENT, ALERT_EMAIL_SENDER
 * (또는 SMTP_HOST/USER/PASS 설정 시 추후 SMTP 모드로 확장 가능)
 *
 * @param {string} subject 메일 제목
 * @param {string} body 메일 본문 (text/plain)
 * @returns {Promise<{ok: boolean, skipped?: boolean, reason?: string}>}
 */
async function _sendEmailAlert(subject, body) {
  const apiKey = process.env.SENDGRID_API_KEY;
  const recipient = process.env.ALERT_EMAIL_RECIPIENT;
  const sender = process.env.ALERT_EMAIL_SENDER;
  if (!apiKey || !recipient || !sender) {
    console.warn(
      "[platformAlert] SENDGRID_API_KEY/ALERT_EMAIL_RECIPIENT/ALERT_EMAIL_SENDER not all set — skip Email channel"
    );
    return { ok: false, skipped: true, reason: "no_smtp_config" };
  }
  try {
    await axios.post(
      "https://api.sendgrid.com/v3/mail/send",
      {
        personalizations: [{ to: [{ email: recipient }] }],
        from: { email: sender, name: "MyHome Alerts" },
        subject,
        content: [{ type: "text/plain", value: body }],
      },
      {
        timeout: 5000,
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
      }
    );
    return { ok: true };
  } catch (e) {
    console.error("[platformAlert] Email send failed:", e.message || e);
    return { ok: false, skipped: false, reason: e.message || "email_send_failed" };
  }
}

/**
 * 폴백: notifications 컬렉션에 admin 알림 문서 생성.
 * Slack/Email 모두 skip/실패해도 운영자가 admin UI 에서 확인 가능 — *항상 작동*.
 *
 * userId='__admin__' 특수 토큰: admin 화면이 이 토큰으로 폴링하여 알림 표시.
 *
 * @param {string} title
 * @param {string} body
 * @param {object} metadata
 * @returns {Promise<{ok: boolean, notificationId: string|null}>}
 */
async function _writeAdminFallbackNotification(title, body, metadata) {
  try {
    const ref = db.collection("notifications").doc();
    await ref.set({
      notificationId: ref.id,
      userId: "__admin__",
      title,
      body,
      type: "platform_alert",
      data: metadata || {},
      isRead: false,
      createdAt: Timestamp.now(),
    });
    return { ok: true, notificationId: ref.id };
  } catch (e) {
    console.error("[platformAlert] admin fallback notification write failed:", e.message || e);
    return { ok: false, notificationId: null };
  }
}

/**
 * 시군구 점유율 경고 메시지 빌드 (운영자 화법 — copy-deck §6 OK).
 *
 * @param {string} alertLevel 'red' | 'yellow'
 * @param {string} district 시군구명 (없으면 'N/A')
 * @param {number} share 점유율 0~1
 * @param {number} listings totalActiveListings
 * @param {number} brokers totalActiveBrokers
 * @returns {{title: string, body: string, slackText: string}}
 */
function _buildPlatformAlertMessage(alertLevel, district, share, listings, brokers) {
  const districtLabel = district || "전체";
  const percent = (share * 100).toFixed(1);
  // 운영자 알림 카피 — admin 화법 (사용자 노출 X).
  // copy-deck §6 운영자 화면 별도 룰: 정확한 수치·기술 용어 OK.
  const title = `MyHome 점유율 경고 — ${districtLabel} ${alertLevel} (${percent}%)`;
  const body =
    `시군구: ${districtLabel}\n` +
    `점유율: ${percent}% (${alertLevel})\n` +
    `누적 활성 매물: ${listings}건\n` +
    `활성 중개사: ${brokers}명\n` +
    `자체 감사 권고 — admin/metrics 페이지에서 추세 확인 후 algorithm_config 가중치 조정 검토.`;
  // Slack mrkdwn — *bold* + 코드블록.
  const slackText =
    `:rotating_light: *${title}*\n\`\`\`\n${body}\n\`\`\``;
  return { title, body, slackText };
}

/**
 * platform_alert_sent audit log 기록 (3-레이어 동기 신규 eventType).
 * 채널별 succcess 기록 — 운영 디버깅 + 통계.
 *
 * @param {string} alertLevel
 * @param {string} district
 * @param {string} channel 'slack' | 'email' | 'admin_fallback'
 * @param {boolean} success
 * @param {string|null} reason
 * @param {string} metricsDate yyyymmdd
 */
async function _writePlatformAlertAudit(alertLevel, district, channel, success, reason, metricsDate) {
  try {
    const auditRef = newAuditLogRef();
    await auditRef.set({
      eventId: auditRef.id,
      eventType: "platform_alert_sent",
      actorUid: null,
      propertyId: null,
      brokerId: null,
      sellerUid: null,
      grantId: null,
      inputs: {
        alertLevel,
        district: district || null,
        channel,
        metricsDate,
      },
      outputs: {
        success,
        reason: reason || null,
      },
      rulebookVersion: RULEBOOK_VERSION,
      createdAt: Timestamp.now(),
    });
  } catch (e) {
    // audit 실패도 graceful — 트리거 throw 금지.
    console.error("[platformAlert] audit write failed:", e.message || e);
  }
}

/**
 * P1-8 — onPlatformMetricsCreated (Firestore 트리거)
 *
 * platform_metrics/{yyyymmdd} 문서 생성 시 (computeDailyMetricsScheduled 출력)
 * alertLevel 에 따라 운영자 알림 발송:
 *  - red    → 모든 채널 (Slack + Email + admin_fallback)
 *  - yellow → Slack + admin_fallback (Email 생략 — 낮은 우선순위)
 *  - green  → 발송 없음 (skip)
 *
 * 시군구별 districtCounts 가 있으면 가장 높은 점유율 시군구를 메시지에 명시.
 * 채널 실패 시 throw 0 — 트리거 무한 재시도 폭주 차단.
 */
exports.onPlatformMetricsCreated = onDocumentCreated(
  { region: "asia-northeast3", document: "platform_metrics/{date}" },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.warn("[onPlatformMetricsCreated] event.data missing — skip");
      return;
    }
    const data = snap.data() || {};
    const alertLevel = data.alertLevel || "green";
    const metricsDate = data.date || event.params.date || "unknown";

    // green 은 발송 0 — early return.
    if (alertLevel === "green") {
      console.log(
        `[onPlatformMetricsCreated] date=${metricsDate} level=green — no alert sent`
      );
      return;
    }

    // 시군구별 districtCounts 에서 max 시군구 추출 (운영자가 어디 점유율이 높은지 즉시 인지).
    const districtCounts = data.districtCounts || {};
    let topDistrict = null;
    let topCount = 0;
    for (const [d, c] of Object.entries(districtCounts)) {
      if (typeof c === "number" && c > topCount) {
        topDistrict = d;
        topCount = c;
      }
    }

    const share = data.estimatedRegionMarketShare || 0;
    const listings = data.totalActiveListings || 0;
    const brokers = data.totalActiveBrokers || 0;

    const { title, body, slackText } = _buildPlatformAlertMessage(
      alertLevel,
      topDistrict,
      share,
      listings,
      brokers
    );

    // 1) Slack — red/yellow 둘 다 발송.
    const slackResult = await _sendSlackAlert(slackText);
    await _writePlatformAlertAudit(
      alertLevel,
      topDistrict,
      "slack",
      slackResult.ok,
      slackResult.reason || null,
      metricsDate
    );

    // 2) Email — red 만 발송 (yellow 는 낮은 우선순위 → skip).
    if (alertLevel === "red") {
      const emailResult = await _sendEmailAlert(title, body);
      await _writePlatformAlertAudit(
        alertLevel,
        topDistrict,
        "email",
        emailResult.ok,
        emailResult.reason || null,
        metricsDate
      );
    }

    // 3) admin_fallback — 항상 작동 (Slack/Email skip/실패해도 운영자가 admin UI 에서 인지).
    const fallbackResult = await _writeAdminFallbackNotification(title, body, {
      alertLevel,
      district: topDistrict,
      share,
      listings,
      brokers,
      metricsDate,
    });
    await _writePlatformAlertAudit(
      alertLevel,
      topDistrict,
      "admin_fallback",
      fallbackResult.ok,
      fallbackResult.ok ? null : "fallback_write_failed",
      metricsDate
    );

    console.log(
      `[onPlatformMetricsCreated] date=${metricsDate} level=${alertLevel} district=${topDistrict || "N/A"} ` +
        `slack=${slackResult.ok ? "ok" : "skip/fail"} email=${alertLevel === "red" ? "attempted" : "n/a"} ` +
        `fallback=${fallbackResult.ok ? "ok" : "fail"}`
    );
  }
);

// ============================================================================
// P1-4 — Grant Fulfillment (거래 성사 시 우선권 종료 경로)
// ============================================================================
//
// **배경**: Task 02 §5.5 #13 — `status='fulfilled'` 전이 함수 부재.
// 현재 priority_grants 의 status enum 은 active|expired|revoked|fulfilled 인데,
// fulfilled 로 가는 *유일한 정상 경로* 가 없어 거래 성사 매물도 expired/revoked
// 두 경로 중 하나로 강제 분류되어 audit 분석 시 "거래 성사" / "활동 미달" 구분 불가.
//
// **본 phase 추가 함수**:
//   1. fulfillGrant (callable) — 매도자 또는 admin이 명시적으로 거래 성사 통지.
//      contractId 는 옵션 (계약 문서 ID 가 있으면 함께 기록).
//   2. onContractCreated (트리거) — contracts/{id} 신규 생성 시 자동 매핑.
//      contracts 컬렉션은 firestore.rules L179 에 정의되어 있으나 v1.3 신규 흐름에
//      적극 사용되지 않는 *레거시* 컬렉션. 미래 호환성 + 매도자 수동 호출 부담 완화.
//      contracts 문서가 propertyId 를 갖고 있을 때만 동작 (없으면 silent no-op).
//
// **3-레이어 동기**:
//   functions audit eventType 'grant_fulfilled' ↔ grant_messages.auditEventLabel
//   ↔ docs/common/copy-deck.md §4. 본 commit 에서 3개 모두 일관 갱신.
//
// **enforceActivityRule / expireGrantsScheduled 회귀 0**:
//   두 함수 모두 .where("status","==","active") 로 쿼리하므로 fulfilled 상태는
//   자연 제외. expireSingleGrantInTx 내부에도 이중 가드(status!=='active' return false) 있음.
//
// **broker_eligibility.activeGrantsCount 감소**:
//   fulfillment 도 active grant 종결이므로 카운터 감소 필요 (5개 한도 회복).
//   expireSingleGrantInTx / revokeOwnGrant 와 동일한 -1 패턴 적용.
//
// **단일 grant 1회 fulfilled — 동일 매물·broker 재매칭 가능**:
//   매물별 grant 가 fulfilled 되어도 새 grant 발급 제약 없음.
//   현실적으로 거래 성사 매물은 status='sold' 로 가서 더 이상 거래 안 일어남.

/**
 * P1-4.a fulfillGrant (callable)
 *
 * 매도자 또는 admin 이 명시적으로 grant 를 거래 성사로 종결한다.
 *
 * 입력:
 *   - grantId: string (필수)
 *   - contractId: string (선택, contracts/{id})
 *
 * 인증:
 *   - request.auth 필수
 *   - 호출자 uid 가 grant.sellerUid 와 일치 OR admin Custom Claim 보유
 *
 * 트랜잭션:
 *   1) priority_grants/{grantId} 로드 → status === 'active' 검증
 *   2) 권한 검증 (seller || admin)
 *   3) priority_grants update: status='fulfilled', fulfilledAt=now,
 *      fulfillmentSource='manual', contractId? 기록
 *   4) broker_eligibility/{brokerId}.activeGrantsCount -= 1 (5개 한도 회복)
 *   5) priority_audit_logs append: eventType='grant_fulfilled'
 */
exports.fulfillGrant = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication required");
    }

    const { grantId, contractId } = request.data || {};
    if (!grantId || typeof grantId !== "string") {
      throw new HttpsError("invalid-argument", "grantId is required");
    }
    if (contractId !== undefined && contractId !== null && typeof contractId !== "string") {
      throw new HttpsError("invalid-argument", "contractId must be a string when provided");
    }

    const callerUid = request.auth.uid;
    const isAdminCaller = request.auth.token && request.auth.token.admin === true;
    const grantRef = db.collection("priority_grants").doc(grantId);

    try {
      const result = await db.runTransaction(async (tx) => {
        const grantSnap = await tx.get(grantRef);
        if (!grantSnap.exists) {
          throw new HttpsError("not-found", `priority_grants/${grantId} not found`);
        }
        const grant = grantSnap.data();

        // 권한: 매도자 본인 또는 admin
        if (!isAdminCaller && grant.sellerUid !== callerUid) {
          throw new HttpsError(
            "permission-denied",
            `${REASON.NOT_PROPERTY_OWNER}: caller uid(${callerUid}) is neither sellerUid(${grant.sellerUid || "null"}) nor admin`
          );
        }

        if (grant.status !== "active") {
          throw new HttpsError(
            "failed-precondition",
            `${REASON.GRANT_NOT_ACTIVE}: grant status is ${grant.status}`
          );
        }

        const eligibilityRef = db
          .collection("broker_eligibility")
          .doc(grant.brokerId);
        const eligibilitySnap = await tx.get(eligibilityRef);

        const now = Timestamp.now();
        const updateFields = {
          status: "fulfilled",
          fulfilledAt: now,
          fulfillmentSource: "manual",
        };
        if (contractId) {
          updateFields.contractId = contractId;
        }
        tx.update(grantRef, updateFields);

        if (eligibilitySnap.exists) {
          tx.update(eligibilityRef, {
            activeGrantsCount: FieldValue.increment(-1),
            updatedAt: now,
          });
        }

        const auditRef = newAuditLogRef();
        tx.set(auditRef, {
          eventId: auditRef.id,
          eventType: "grant_fulfilled",
          actorUid: callerUid,
          propertyId: grant.propertyId,
          brokerId: grant.brokerId,
          grantId,
          sellerUid: grant.sellerUid || null,
          inputs: {
            grantId,
            contractId: contractId || null,
            fulfillmentSource: "manual",
            actorRole: isAdminCaller ? "admin" : "seller",
          },
          outputs: {
            previousStatus: "active",
            newStatus: "fulfilled",
            fulfilledAt: now.toMillis(),
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: now,
        });

        return {
          grantId,
          fulfilledAt: now.toMillis(),
          contractId: contractId || null,
          fulfillmentSource: "manual",
        };
      });

      console.log(
        `[fulfillGrant] success: grant=${result.grantId} actor=${callerUid} contract=${result.contractId || "none"}`
      );
      return result;
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("[fulfillGrant] error:", error);
      throw new HttpsError("internal", error.message || "internal error");
    }
  }
);

/**
 * P1-4.b onContractCreated (Firestore 트리거)
 *
 * contracts/{contractId} 신규 생성 시 자동으로 관련 active grant 를 fulfilled 로 종결.
 *
 * **레거시 컬렉션 대응**:
 *   contracts 컬렉션은 v1.2 이전 흐름의 잔재로 v1.3 MLS 신규 경로에서는
 *   적극 사용되지 않음. 단, firestore.rules L179 에 여전히 정의되어 있고
 *   미래에 부활할 가능성이 있어 *defensive* 트리거로 추가.
 *
 * **동작**:
 *   - contract.propertyId 가 없으면 silent no-op (레거시 contract 호환)
 *   - 같은 propertyId 의 active seller_match grant 가 있으면 자동 fulfilled 처리
 *   - buyer_match grant 는 별도 — 매수자 단위 흐름이라 자동 fulfillment 보류
 *     (매수자 의도와 분리된 trigger 가 매수자 grant 에 영향 주지 않도록)
 *   - actorUid 는 contract.brokerId 또는 contract.sellerId (있는 쪽) 사용
 *
 * **회귀 방지**:
 *   - active 가 아닌 grant 는 이미 종료된 상태이므로 silent skip
 *   - 동일 매물에 multi seller_match active 는 정상 시나리오 아님이지만
 *     모두 fulfillment 처리 (반복 트랜잭션)
 */
exports.onContractCreated = onDocumentCreated(
  {
    region: "asia-northeast3",
    document: "contracts/{contractId}",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log("[onContractCreated] no snapshot data");
      return;
    }

    const contract = snap.data() || {};
    const contractId = event.params.contractId;
    const propertyId = contract.propertyId;

    if (!propertyId) {
      // 레거시 contract — propertyId 없으면 silent no-op
      console.log(
        `[onContractCreated] contract=${contractId} has no propertyId, skipping`
      );
      return;
    }

    // 자동 actor 식별: brokerId > sellerId > null (audit 추적용)
    const inferredActorUid =
      contract.brokerId || contract.sellerId || null;

    try {
      const candidates = await db
        .collection("priority_grants")
        .where("propertyId", "==", propertyId)
        .where("status", "==", "active")
        .where("type", "==", "seller_match")
        .limit(10)
        .get();

      if (candidates.empty) {
        console.log(
          `[onContractCreated] contract=${contractId} property=${propertyId} no active seller_match grants`
        );
        return;
      }

      let processed = 0;
      let failed = 0;
      for (const doc of candidates.docs) {
        try {
          await db.runTransaction(async (tx) => {
            const grantSnap = await tx.get(doc.ref);
            if (!grantSnap.exists) return;
            const grant = grantSnap.data();
            if (grant.status !== "active") return;

            const eligibilityRef = db
              .collection("broker_eligibility")
              .doc(grant.brokerId);
            const eligibilitySnap = await tx.get(eligibilityRef);

            const now = Timestamp.now();
            tx.update(doc.ref, {
              status: "fulfilled",
              fulfilledAt: now,
              fulfillmentSource: "trigger",
              contractId,
            });

            if (eligibilitySnap.exists) {
              tx.update(eligibilityRef, {
                activeGrantsCount: FieldValue.increment(-1),
                updatedAt: now,
              });
            }

            const auditRef = newAuditLogRef();
            tx.set(auditRef, {
              eventId: auditRef.id,
              eventType: "grant_fulfilled",
              actorUid: inferredActorUid,
              propertyId,
              brokerId: grant.brokerId,
              grantId: doc.id,
              sellerUid: grant.sellerUid || null,
              inputs: {
                grantId: doc.id,
                contractId,
                fulfillmentSource: "trigger",
                actorRole: "system",
              },
              outputs: {
                previousStatus: "active",
                newStatus: "fulfilled",
                fulfilledAt: now.toMillis(),
              },
              rulebookVersion: RULEBOOK_VERSION,
              createdAt: now,
            });
            processed += 1;
          });
        } catch (e) {
          failed += 1;
          console.error(
            `[onContractCreated] failed grant=${doc.id} contract=${contractId}:`,
            e.message
          );
        }
      }

      console.log(
        `[onContractCreated] contract=${contractId} property=${propertyId} processed=${processed} failed=${failed} total=${candidates.size}`
      );
    } catch (e) {
      console.error(
        `[onContractCreated] query failed contract=${contractId} property=${propertyId}:`,
        e.message
      );
    }
  }
);

// ============================================================================
// 라운드 2D P1-9 — onPriorityAppealResolved (이의 제기 처리 결과 push 알림)
// ============================================================================
//
// 정책 출처: docs/task/2026-05-02-task-06-transparency-handoff.md §5.1 #5
//   "현재: resolveAppeal 후 신청자에게 push notification 발송 없음.
//    보강: notifications 컬렉션에 doc create — userId: filerUid,
//    title: GrantMessages.appealResolutionNotificationTitle, body: resolution.
//    기존 sendPushNotification 트리거 자동 발화."
//
// 설계 결정 — 트리거 분리(=resolveAppeal 본체 보강 X)의 이유:
//   1) resolveAppeal 본체 *0 변경* 보장 — Task 06 §A6 본체 + P1-12 action 분기
//      모두 라인 그대로 유지 (transaction 본체 회귀 위험 0).
//   2) onDocumentUpdated 가 status 전이를 감지하므로 *향후 다른 경로* (admin
//      직접 update / 다른 callable) 로 status 가 바뀌어도 알림이 일관 발화.
//   3) resolveAppeal transaction commit 후 Firestore 가 트리거 자동 발화 →
//      transaction 외부에서 notifications create 하던 P1-11 패턴과 동일 시점.
//
// 동작:
//   * 트리거: priority_appeals/{appealId} onUpdate
//   * 조건: status 이전값 ∈ {'open','reviewing'} & 이후값 ∈ {'resolved','rejected'}
//           (그 외 update — replayedDecision 첨부 등 — 는 무시)
//   * 알림 1건: notifications/{auto-id} create
//       - userId: appeal.filerUid
//       - title: '이의 신청 결과가 나왔어요' (GrantMessages.appealResolutionNotificationTitle 와 1:1)
//       - message: appeal.resolution (운영자 입력)
//       - type: 'appeal_resolution'
//       - relatedId: appealId
//   * sendPushNotification 트리거 (notifications onCreate) 가 자동 FCM 발송.
//   * audit log 1건: eventType='appeal_resolution_notified'
//       - inputs: { appealId, decision, filerUid }
//       - outputs: { notificationId, titleSent }
//       - sellerUid enrichment (priority_grants 조회) — Task 06 §A6 동일 패턴.
//
// 80세 화법:
//   * title 은 시스템 자동 카피 — 본 파일에 *고정 문자열* (3-레이어 동기 — Dart
//     constants/grant_messages.dart::appealResolutionNotificationTitle ↔ 본 트리거
//     ↔ docs/common/copy-deck.md §2.7).
//   * message(resolution) 는 운영자 입력 — operator-to-user-copy-gate.md §3
//     7원칙 *권고* (현재 강제 X, 자동 게이트 validateOperatorMessage callable
//     은 별도 phase).
//
// 멱등성:
//   * status 가 한 번 'resolved'|'rejected' 로 들어가면 이후 update 는 trigger
//     의 condition (이전값 ∈ {'open','reviewing'}) 에서 막힘 → 중복 알림 0.
//   * filerUid 누락 시 (이론상 0) 즉시 return — notification 미생성.
exports.onPriorityAppealResolved = onDocumentUpdated(
  { region: "asia-northeast3", document: "priority_appeals/{appealId}" },
  async (event) => {
    const appealId = event.params.appealId;
    const before = event.data?.before?.data() || null;
    const after = event.data?.after?.data() || null;
    if (!before || !after) {
      console.log(`[onPriorityAppealResolved] skip ${appealId}: before/after missing`);
      return;
    }

    const prevStatus = before.status || null;
    const newStatus = after.status || null;
    const wasOpen = prevStatus === "open" || prevStatus === "reviewing";
    const isResolved = newStatus === "resolved" || newStatus === "rejected";
    if (!wasOpen || !isResolved) {
      // 상태 전이 아님 (예: replayedDecision 첨부, resolution 수정) — 무시.
      return;
    }
    if (prevStatus === newStatus) {
      // 동일 상태 — no-op (이론상 발화 X 이지만 방어).
      return;
    }

    const filerUid = after.filerUid || before.filerUid || null;
    if (!filerUid) {
      console.warn(
        `[onPriorityAppealResolved] skip ${appealId}: filerUid missing (cannot route notification)`
      );
      return;
    }

    // 운영자 입력 resolution — body 카피로 사용. 비어있어도 빈 문자열로 발송
    // (title 만으로도 사용자가 결과를 인지할 수 있음).
    const resolutionRaw = typeof after.resolution === "string" ? after.resolution : "";
    const resolution = resolutionRaw.length > 1000 ? resolutionRaw.slice(0, 1000) : resolutionRaw;

    // 알림 카피 (3-레이어 동기 — grant_messages.dart::appealResolutionNotificationTitle).
    const title = "이의 신청 결과가 나왔어요";

    // 연관 grant 정보 capture (audit log enrichment 용).
    let appealSellerUid = null;
    let appealPropertyId = null;
    let appealBrokerId = null;
    if (after.grantId) {
      try {
        const gSnap = await db.collection("priority_grants").doc(after.grantId).get();
        if (gSnap.exists) {
          const g = gSnap.data() || {};
          appealSellerUid = g.sellerUid || null;
          appealPropertyId = g.propertyId || null;
          appealBrokerId = g.brokerId || null;
        }
      } catch (_) {
        // ignore — audit enrichment 실패가 알림 발송을 막지 않음.
      }
    }

    // notifications 컬렉션 doc create — sendPushNotification 트리거 자동 발화.
    // FCM 직접 호출 X (Task 06 §5.1 #5 "기존 sendPushNotification 트리거 자동 발화" 규정).
    const notifRef = db.collection("notifications").doc();
    const nowTs = Timestamp.now();
    try {
      await notifRef.set({
        notificationId: notifRef.id,
        userId: filerUid,
        title,
        message: resolution,
        type: "appeal_resolution",
        relatedId: appealId,
        appealId,
        decision: newStatus,
        createdAt: nowTs,
        read: false,
      });
    } catch (e) {
      console.error(
        `[onPriorityAppealResolved] notification create failed ${appealId}:`,
        e.message
      );
      return;
    }

    // audit log 1건 — appeal_resolution_notified.
    // 3-레이어 동기 — grant_messages.dart::auditEventLabel 'appeal_resolution_notified'
    // ↔ copy-deck §4 ↔ 본 eventType.
    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "appeal_resolution_notified",
        actorUid: after.resolvedBy || null,
        propertyId: appealPropertyId,
        brokerId: appealBrokerId,
        sellerUid: appealSellerUid,
        grantId: after.grantId || null,
        inputs: {
          appealId,
          decision: newStatus,
          filerUid,
        },
        outputs: {
          notificationId: notifRef.id,
          titleSent: title,
          bodyLength: resolution.length,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: nowTs,
      });
    } catch (e) {
      console.error(
        `[onPriorityAppealResolved] audit failed ${appealId}:`,
        e.message
      );
      // audit 실패는 알림 발송 결과에 영향 X (이미 notification 적재 완료).
    }

    console.log(
      `[onPriorityAppealResolved] notified appeal=${appealId} filer=${filerUid} decision=${newStatus} notif=${notifRef.id}`
    );
  }
);

// ============================================================================
// 라운드 2D P1-5 — broker_participations publicView 분리 (Rules 마스킹 한계 보완)
// ============================================================================
//
// 배경:
//   Firestore Rules 는 *필드 단위 마스킹*이 불가능하다. broker_participations
//   문서는 brokerId/brokerUid 등 식별 정보와 displayName/시간기록 같은 공개
//   가능 정보가 한 문서 안에 섞여 있어, Rules read 권한을 풀면 식별 정보도
//   같이 노출된다. Task 05 핸드오프 §5.1 #1 항목.
//
// 해결:
//   `mlsProperties/{id}/broker_participations_public/{partId}` 미러 서브컬렉션
//   신설. public-safe 필드만 보관 (displayName, participationStage, declaredAt,
//   visitScheduledAt, offerMadeAt, publiclyVisibleAt). brokerId/brokerUid/실명
//   등 *식별 정보 일절 미포함*. Rules 에서 `broker_participations` 의 직접
//   read 는 차단하고, public 미러만 인증 사용자 read 허용.
//
// 트리거:
//   원본 broker_participations 의 onWritten 이벤트로 자동 동기화. delete 시
//   미러도 삭제.
//
// 무한루프 안전성:
//   미러는 다른 서브컬렉션 (broker_participations_public) 이므로 본 함수가
//   broker_participations 트리거를 재귀 발화시키지 않는다.
//   기존 onBrokerParticipationWritten (집계 비정규화) 와는 *서로 독립* 하게
//   같은 onWritten 이벤트를 구독한다. 두 트리거는 각자 다른 컬렉션
//   (broker_participations_public vs mlsProperties 부모 도큐먼트) 에 쓰므로
//   순서 의존성도 없다.
//
// 보호 — Task 05 자산:
//   - 원본 broker_participations 컬렉션은 admin SDK (callable·트리거) 만 쓰기
//     가능. 본 트리거도 admin SDK 라 Rules 차단과 충돌 없음.
//   - displayName 자동 발급 로직 (upsertBrokerParticipationInTx 안의
//     buildAnonymousDisplayName) 은 한 줄도 수정하지 않는다. 본 트리거는
//     원본이 이미 채워 둔 displayName 을 그대로 미러링.
//   - getBrokerParticipationsForSeller / getMyParticipations callable 동작 무변경.
exports.onBrokerParticipationWrittenSyncPublicView = onDocumentWritten(
  {
    region: "asia-northeast3",
    document: "mlsProperties/{propertyId}/broker_participations/{partId}",
  },
  async (event) => {
    const propertyId = event.params.propertyId;
    const partId = event.params.partId;
    if (!propertyId || !partId) return;

    const publicRef = db
      .collection("mlsProperties")
      .doc(propertyId)
      .collection("broker_participations_public")
      .doc(partId);

    try {
      const after = event.data && event.data.after;
      const exists = after && after.exists;

      if (!exists) {
        // 원본 삭제 → 미러도 삭제. 존재하지 않으면 noop.
        await publicRef.delete().catch(() => {});
        return;
      }

      const src = after.data() || {};

      // public-safe 필드만 화이트리스트로 추출. 그 외 필드 (brokerId/brokerUid/
      // brokerName/brokerPhone/officeName/orderIndex/relatedGrantId/type 등) 는
      // *절대* 미러하지 않는다.
      const mirror = {
        displayName: typeof src.displayName === "string" ? src.displayName : "",
        participationStage:
          typeof src.participationStage === "string"
            ? src.participationStage
            : "declared",
        declaredAt: src.declaredAt || null,
        visitScheduledAt: src.visitScheduledAt || null,
        offerMadeAt: src.offerMadeAt || null,
        publiclyVisibleAt: src.publiclyVisibleAt || null,
        // 미러 자체의 마지막 동기 시각 (디버깅용 — 식별 정보 아님).
        mirroredAt: FieldValue.serverTimestamp(),
      };

      await publicRef.set(mirror, { merge: true });
    } catch (e) {
      console.error(
        `[onBrokerParticipationWrittenSyncPublicView] failed for property=${propertyId} part=${partId}:`,
        e.message
      );
    }
  }
);

// ============================================================================
// 라운드 2D P2-6 — brokerStats 카운터 누적 (Reputation Pool 기본 골격)
// ============================================================================
//
// 정책 출처:
//   - docs/goal/multi_agent_competition_solutions_cross_industry.md §4.2
//     (Reputation Pool — *후행 메커니즘*, 차별화 X, 베이스라인)
//   - docs/task/2026-05-03-MASTER-v1.3-mvp-handoff.md §3.3 P2-6
//
// 설계 신중함 — *데이터 누적 기반 골격만*:
//   * 본 phase 는 "fulfilled grant 누적 카운터" + "단계 진척 카운터" 만 적재.
//   * 상대평가 산식 / 정렬 알고리즘 / 카테고리화 ("이 동네 활동 많은 분") 는
//     P2-7 후행 phase 로 분리. 본 phase 에서 *어떤 상대비교·정렬·노출 가중치
//     계산도 하지 않는다*.
//   * 카카오 회피 — 고정 우대 패턴 X. 카운터는 *전체 broker 분포* 기반 후행
//     카테고리화에만 사용 (후행 phase 책임).
//
// 사용자 노출 정책 (★중요★):
//   * 본 카운터들은 *admin 화면에만* 노출. 사용자/매도자/broker 본인 노출 0.
//   * copy-deck §1.4 "백분율(%) UI 노출 절대 금지. 점수·가중치 절대 금지" 준수.
//   * 따라서 신규 사용자 노출 카피 0건 — copy-deck §2 영역 변경 0.
//   * 본 phase 는 audit eventType 1종 (broker_stats_updated) 만 추가하며,
//     해당 audit 라벨도 *admin/디버깅 추적용* (copy-deck §4 표 1행).
//
// 기존 자산 보호:
//   * lib/api_request/broker_stats_service.dart — *훼손 0* (append-only).
//     본 트리거가 추가하는 4종 카운터 필드는 broker_stats_service 의 기존
//     onVisitRequest* / onDealCompleted 와 *서로 독립*. 같은 doc 에 merge 됨.
//   * lib/models/broker_stats.dart — append-only (4 필드 추가).
//   * fulfillGrant transaction (P1-4.a) / onContractCreated transaction (P1-4.b)
//     본체 수정 0. 본 phase 는 priority_grants onUpdated 트리거 1개 신설하여
//     status active→fulfilled 전이 시 *별도 비-tx write* 로 brokerStats 증분.
//   * upsertBrokerParticipationInTx (Task 05) 본체 수정 0. 본 phase 는
//     broker_participations onWritten 트리거 1개 신설하여 stage 전이 시
//     *별도 비-tx write* 로 brokerStats 증분.
//
// 무한루프 안전성:
//   * onPriorityGrantFulfilled — priority_grants onUpdate. brokerStats 에만 쓰므로
//     priority_grants 트리거 재귀 발화 0.
//   * onBrokerParticipationStageAdvanced — broker_participations onWritten.
//     brokerStats 에만 쓰므로 broker_participations 트리거 재귀 발화 0.
//     기존 onBrokerParticipationWritten / onBrokerParticipationWrittenSyncPublicView
//     2개와 *서로 독립* — 각자 다른 컬렉션에 쓰므로 순서 의존성 0.
//
// 멱등성:
//   * onPriorityGrantFulfilled — before.status='active' && after.status='fulfilled'
//     인 경우만 1회 발화. 한 번 fulfilled 가 된 grant 가 다시 update 되어도
//     before.status 가 'active' 가 아니라 trigger 가 skip.
//   * onBrokerParticipationStageAdvanced — stage rank 가 *증가* 한 경우만 1회
//     발화. 동등·역행 시 skip (역행은 upsertBrokerParticipationInTx 에서 이미
//     차단되어 본 트리거에 도달조차 X 이지만 방어).
//
// 3-레이어 동기:
//   functions audit eventType 'broker_stats_updated'
//   ↔ lib/constants/grant_messages.dart::auditEventLabel 'broker_stats_updated'
//   ↔ docs/common/copy-deck.md §4 표 1행.

/**
 * P2-6.a onPriorityGrantFulfilled (Firestore 트리거)
 *
 * priority_grants/{grantId} onUpdate. status active→fulfilled 전이 감지 시
 * brokerStats/{brokerId} 의 fulfilledGrantsCount 증분 + lastFulfilledAt 기록.
 *
 * 동작:
 *   - before.status='active' && after.status='fulfilled' 일 때만 발화
 *   - brokerStats/{brokerId} merge:
 *       fulfilledGrantsCount += 1
 *       lastFulfilledAt = serverTimestamp
 *       updatedAt = serverTimestamp
 *       (brokerId / brokerName 도 함께 set — 신규 doc 인 경우 대비)
 *   - audit eventType 'broker_stats_updated' 1건 적재
 *       inputs: { trigger: 'grant_fulfilled', grantId, brokerId }
 *       outputs: { counterField: 'fulfilledGrantsCount', delta: 1 }
 *       — 사용자 노출 0, admin/디버깅 추적용
 *
 * 회귀 방지:
 *   - fulfillGrant transaction / onContractCreated transaction 본체 수정 0.
 *     두 함수 모두 status='fulfilled' 로 update 후 commit → Firestore 가
 *     본 트리거 자동 발화 → transaction 외부에서 brokerStats 증분.
 *   - 본 트리거가 brokerStats 만 쓰므로 priority_grants 트리거 재귀 발화 0.
 */
exports.onPriorityGrantFulfilled = onDocumentUpdated(
  { region: "asia-northeast3", document: "priority_grants/{grantId}" },
  async (event) => {
    const grantId = event.params.grantId;
    const before = event.data && event.data.before ? event.data.before.data() : null;
    const after = event.data && event.data.after ? event.data.after.data() : null;
    if (!before || !after) {
      return;
    }

    // 멱등성 가드 — active→fulfilled 전이만 1회 발화.
    const prevStatus = before.status || null;
    const newStatus = after.status || null;
    if (prevStatus !== "active" || newStatus !== "fulfilled") {
      return;
    }

    const brokerId = after.brokerId || before.brokerId || null;
    if (!brokerId) {
      console.warn(
        `[onPriorityGrantFulfilled] skip ${grantId}: brokerId missing`
      );
      return;
    }

    const now = Timestamp.now();
    const statsRef = db.collection("brokerStats").doc(brokerId);

    try {
      // brokerStats merge — neighbouring fields (brokerName 등) 는 기존 값
      // 보존 (broker_stats_service.onVisitRequestCreated 등 다른 경로가 채움).
      // 본 phase 는 fulfilledGrantsCount / lastFulfilledAt 만 책임.
      await statsRef.set(
        {
          brokerId,
          fulfilledGrantsCount: FieldValue.increment(1),
          lastFulfilledAt: now,
          updatedAt: now,
        },
        { merge: true }
      );
    } catch (e) {
      console.error(
        `[onPriorityGrantFulfilled] brokerStats write failed grant=${grantId} broker=${brokerId}:`,
        e.message
      );
      return;
    }

    // audit log 1건 — broker_stats_updated.
    // 3-레이어 동기 — grant_messages.dart::auditEventLabel 'broker_stats_updated'
    // ↔ copy-deck §4 ↔ 본 eventType.
    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "broker_stats_updated",
        actorUid: null, // system (트리거)
        propertyId: after.propertyId || before.propertyId || null,
        brokerId,
        grantId,
        sellerUid: after.sellerUid || before.sellerUid || null,
        inputs: {
          trigger: "grant_fulfilled",
          grantId,
          brokerId,
        },
        outputs: {
          counterField: "fulfilledGrantsCount",
          delta: 1,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: now,
      });
    } catch (e) {
      console.error(
        `[onPriorityGrantFulfilled] audit failed grant=${grantId}:`,
        e.message
      );
      // audit 실패가 brokerStats 증분을 되돌리지 않음 (이미 적재 완료).
    }

    console.log(
      `[onPriorityGrantFulfilled] brokerStats updated broker=${brokerId} grant=${grantId} field=fulfilledGrantsCount`
    );
  }
);

/**
 * P2-6.b onBrokerParticipationStageAdvanced (Firestore 트리거)
 *
 * mlsProperties/{propertyId}/broker_participations/{brokerId} onWritten.
 * stage rank 증가 시 brokerStats/{brokerId} 의 단계별 카운터 증분.
 *
 * 동작:
 *   - before 가 없거나 (신규 declared) before.participationStage rank <
 *     after.participationStage rank 인 경우 1회 증분.
 *   - 단계별 카운터:
 *       declared       → declaredCount += 1 (첫 발급 1회)
 *       visit_scheduled → visitScheduledCount += 1
 *       offer_made     → offerMadeCount += 1
 *   - audit eventType 'broker_stats_updated' 1건 적재
 *       inputs: { trigger: 'participation_stage_advanced', stage,
 *                 propertyId, brokerId }
 *       outputs: { counterField, delta: 1 }
 *
 * 회귀 방지:
 *   - upsertBrokerParticipationInTx 본체 수정 0. 트랜잭션 commit 후 Firestore
 *     가 본 트리거 자동 발화 → transaction 외부에서 brokerStats 증분.
 *   - 본 트리거가 brokerStats 만 쓰므로 broker_participations 트리거 재귀 발화 0.
 *   - 기존 onBrokerParticipationWritten (집계 비정규화) /
 *     onBrokerParticipationWrittenSyncPublicView (publicView 미러) 와
 *     *서로 독립* — 각자 다른 컬렉션에 쓰므로 순서 의존성 0.
 *
 * 멱등성:
 *   - 동등 stage (예: declared → declared 재set) 는 newRank > prevRank 가
 *     아니므로 skip.
 *   - 역행은 upsertBrokerParticipationInTx 에서 차단되므로 트리거에 도달 X
 *     (방어적으로 skip 처리).
 */
exports.onBrokerParticipationStageAdvanced = onDocumentWritten(
  {
    region: "asia-northeast3",
    document: "mlsProperties/{propertyId}/broker_participations/{partId}",
  },
  async (event) => {
    const propertyId = event.params.propertyId;
    const partId = event.params.partId;
    if (!propertyId || !partId) return;

    const before = event.data && event.data.before && event.data.before.exists
      ? event.data.before.data()
      : null;
    const after = event.data && event.data.after && event.data.after.exists
      ? event.data.after.data()
      : null;

    // 삭제 시 brokerStats 감산 0 — 본 phase 는 누적 카운터만 (감산 정책은
    // 후행 phase 에서 정의).
    if (!after) return;

    const brokerId = after.brokerId || partId;
    if (!brokerId) return;

    const newStage = normalizeStage(after.participationStage);
    const newRank = stageRank(newStage);

    // 첫 발급 (before 없음) 인 경우 prevRank = -1 으로 처리 → declared 1회 발화.
    let prevRank;
    if (!before) {
      prevRank = -1;
    } else {
      const prevStage = normalizeStage(before.participationStage);
      prevRank = stageRank(prevStage);
    }

    // 단조 증가만 — 동등·역행 skip.
    if (newRank <= prevRank) return;

    // 카운터 필드 결정 — *현재 newStage* 에 해당하는 카운터 1종만 증분.
    // (다단계 점프 — declared → offer_made — 시 visit_scheduled 도 같이
    // 증분할지는 후행 phase 결정. 본 phase 는 현재 도달 stage 1종만.)
    let counterField;
    if (newStage === "declared") {
      counterField = "declaredCount";
    } else if (newStage === "visit_scheduled") {
      counterField = "visitScheduledCount";
    } else if (newStage === "offer_made") {
      counterField = "offerMadeCount";
    } else {
      // 알 수 없는 stage — skip.
      return;
    }

    const now = Timestamp.now();
    const statsRef = db.collection("brokerStats").doc(brokerId);

    try {
      const update = {
        brokerId,
        updatedAt: now,
      };
      update[counterField] = FieldValue.increment(1);

      await statsRef.set(update, { merge: true });
    } catch (e) {
      console.error(
        `[onBrokerParticipationStageAdvanced] brokerStats write failed property=${propertyId} broker=${brokerId} stage=${newStage}:`,
        e.message
      );
      return;
    }

    // audit log 1건 — broker_stats_updated.
    try {
      const auditRef = newAuditLogRef();
      await auditRef.set({
        eventId: auditRef.id,
        eventType: "broker_stats_updated",
        actorUid: null, // system (트리거)
        propertyId,
        brokerId,
        grantId: after.relatedGrantId || null,
        inputs: {
          trigger: "participation_stage_advanced",
          stage: newStage,
          propertyId,
          brokerId,
        },
        outputs: {
          counterField,
          delta: 1,
        },
        rulebookVersion: RULEBOOK_VERSION,
        createdAt: now,
      });
    } catch (e) {
      console.error(
        `[onBrokerParticipationStageAdvanced] audit failed property=${propertyId} broker=${brokerId}:`,
        e.message
      );
      // audit 실패가 brokerStats 증분을 되돌리지 않음.
    }

    console.log(
      `[onBrokerParticipationStageAdvanced] brokerStats updated broker=${brokerId} property=${propertyId} stage=${newStage} field=${counterField}`
    );
  }
);

// =============================================================================
// P0-9: bulkVerifyBrokerEligibility — admin only callable
// =============================================================================
// 목적: P0-2 시드는 broker_eligibility.licenseStatus='pending' 으로 채움.
//       모든 broker가 issuePriorityGrant 호출 시 거부됨 → admin이 *수동 검증 후*
//       일괄 'verified'로 전환하는 callable. 운영자가 admin UI 또는 직접 호출.
// 입력: { brokerIds: string[] } (1~500건) 또는 { all: true } (모든 'pending' 일괄)
// 출력: { verifiedCount, skippedCount, failedCount }
// audit: 'broker_eligibility_bulk_verified' 이벤트 (3-레이어 동기 — grant_messages·copy-deck §4)
// =============================================================================
exports.bulkVerifyBrokerEligibility = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }
    if (request.auth.token.admin !== true) {
      throw new HttpsError(
        "permission-denied",
        "관리자만 호출 가능합니다 (admin claim 필요)"
      );
    }

    const data = request.data || {};
    const allMode = data.all === true;
    const brokerIds = Array.isArray(data.brokerIds) ? data.brokerIds : [];
    if (!allMode && (brokerIds.length === 0 || brokerIds.length > 500)) {
      throw new HttpsError(
        "invalid-argument",
        "brokerIds는 1~500건 또는 all=true 명시 필요"
      );
    }

    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const actorUid = request.auth.uid;

    let targets = [];
    if (allMode) {
      const pendingSnap = await db
        .collection("broker_eligibility")
        .where("licenseStatus", "==", "pending")
        .limit(500) // 안전 한도
        .get();
      targets = pendingSnap.docs;
    } else {
      const docs = await Promise.all(
        brokerIds.map((id) =>
          db.collection("broker_eligibility").doc(id).get()
        )
      );
      targets = docs.filter((d) => d.exists);
    }

    let verifiedCount = 0;
    let skippedCount = 0;
    let failedCount = 0;

    // 청크 분할 (Firestore batch 500 한도)
    const CHUNK = 400;
    for (let i = 0; i < targets.length; i += CHUNK) {
      const chunk = targets.slice(i, i + CHUNK);
      const batch = db.batch();
      const verifiedIds = [];
      for (const docSnap of chunk) {
        const data = docSnap.data();
        if (data.licenseStatus === "verified") {
          skippedCount++;
          continue;
        }
        try {
          batch.update(docSnap.ref, {
            licenseStatus: "verified",
            licenseVerifiedAt: now,
            updatedAt: now,
          });
          verifiedIds.push(docSnap.id);
        } catch (e) {
          failedCount++;
        }
      }
      try {
        await batch.commit();
        verifiedCount += verifiedIds.length;

        // audit log 1건 — 일괄 검증은 단일 audit (3-레이어 동기 eventType)
        await db.collection("priority_audit_logs").add({
          eventType: "broker_eligibility_bulk_verified",
          actorUid,
          inputs: {
            mode: allMode ? "all_pending" : "explicit_ids",
            requestedCount: targets.length,
          },
          outputs: {
            verifiedCount: verifiedIds.length,
            skippedCount,
            failedCount,
            verifiedBrokerIds: verifiedIds.slice(0, 50), // 너무 많으면 50건 truncate
          },
          rulebookVersion: RULEBOOK_VERSION,
          createdAt: now,
        });
      } catch (e) {
        failedCount += chunk.length;
        console.error(
          `[bulkVerifyBrokerEligibility] batch commit failed: ${e.message}`
        );
      }
    }

    console.log(
      `[bulkVerifyBrokerEligibility] verified=${verifiedCount} skipped=${skippedCount} failed=${failedCount} actor=${actorUid}`
    );
    return { verifiedCount, skippedCount, failedCount };
  }
);

// =============================================================================
// 회원가입 단계 — 중개업 등록번호 중복 체크 (비로그인 호출 가능 callable)
// =============================================================================
// 목적: brokers 컬렉션은 firestore.rules 에서 read=isAuthenticated() 이므로
//       회원가입 *전* 중복체크 쿼리를 클라이언트에서 직접 실행할 수 없다.
//       이 callable 은 admin SDK 로 검사하고 { exists: bool } 만 반환한다.
// 입력: { registrationNumber: string }  — 형식: 숫자/하이픈, 5~30자
// 출력: { exists: boolean }
// 보안:
//   - 데이터 누출 없음 (boolean 만 반환)
//   - 입력 형식 강제로 임의 컬렉션 스캐닝 차단
//   - Cloud Functions IP 기반 quota 가 자동 throttle
// =============================================================================
exports.checkBrokerRegistrationNumber = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    const data = request.data || {};
    const raw = data.registrationNumber;

    if (typeof raw !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "registrationNumber는 문자열이어야 합니다"
      );
    }

    const trimmed = raw.trim();
    // 형식: 숫자/하이픈만, 5~30자
    if (!/^[0-9-]{5,30}$/.test(trimmed)) {
      throw new HttpsError(
        "invalid-argument",
        "유효한 등록번호 형식이 아닙니다"
      );
    }

    try {
      const snap = await db
        .collection("brokers")
        .where("brokerRegistrationNumber", "==", trimmed)
        .limit(1)
        .get();
      return { exists: !snap.empty };
    } catch (err) {
      console.error("[checkBrokerRegistrationNumber] lookup failed:", err);
      throw new HttpsError("internal", "등록번호 조회에 실패했습니다");
    }
  }
);

// =============================================================================
// 회원탈퇴 — 본인 계정과 관련 Firestore 데이터를 admin SDK 로 일괄 삭제
// =============================================================================
// 보안 모델:
//   * Firebase Auth recent-login 검사는 client SDK 측에서만 발생하므로
//     본 callable 은 admin SDK delete 로 우회한다.
//   * 호출 전에 클라이언트가 비밀번호 또는 소셜 provider 재인증을 *반드시*
//     선행해야 한다 (UI 흐름 책임).
//   * 본인 (request.auth.uid) 만 자기 계정을 삭제할 수 있다.
// 정리 대상:
//   * users/{uid}                — 사용자 프로필
//   * brokers/{uid}              — 중개사 정보 (해당 시)
//   * broker_eligibility/{uid}   — 면허/관할 캐시 (해당 시)
//   * Firebase Auth user
// 정리 *제외* (감사·이력 보존):
//   * mlsProperties              — 매물 (분쟁/계약 추적)
//   * priority_grants            — 우선권 부여 원장 (불변)
//   * priority_audit_logs        — 감사 로그
//   * contracts                  — 계약 (삭제 금지 정책)
//   * notifications              — 본인분은 자동 만료 처리 권장
// =============================================================================
exports.deleteOwnAccount = onCall(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다");
    }
    const uid = request.auth.uid;

    try {
      // 0) 레거시 email-keyed doc 식별 — 옛 가입자는 users/{email} 형태로
      //    저장됐을 수 있다. Auth 삭제 *전*에 email 을 캡처해 함께 정리.
      let userEmail = null;
      try {
        const userRecord = await auth.getUser(uid);
        userEmail = userRecord.email || null;
      } catch (_) {
        // Auth user 가 이미 삭제됐을 수 있음 — 무시
      }

      // 1) Firestore 정리 — admin SDK 라 rules 우회
      const batch = db.batch();
      batch.delete(db.collection("users").doc(uid));
      batch.delete(db.collection("brokers").doc(uid));
      batch.delete(db.collection("broker_eligibility").doc(uid));
      if (userEmail) {
        // 레거시 email-keyed doc 동시 정리
        batch.delete(db.collection("users").doc(userEmail));
        batch.delete(db.collection("brokers").doc(userEmail));
      }
      await batch.commit();

      // 2) Auth user 삭제 — recent-login 검사 없음 (admin SDK)
      try {
        await auth.deleteUser(uid);
      } catch (authErr) {
        if (authErr.code !== "auth/user-not-found") {
          throw authErr;
        }
        // 이미 삭제된 경우 무시
      }

      console.log(
        `[deleteOwnAccount] uid=${uid} email=${userEmail || "(none)"} deleted`
      );
      return { success: true };
    } catch (err) {
      console.error(`[deleteOwnAccount] uid=${uid} failed:`, err);
      throw new HttpsError(
        "internal",
        err.message || "회원탈퇴에 실패했습니다"
      );
    }
  }
);
