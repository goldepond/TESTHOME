/**
 * MyHome Cloud Functions
 *
 * Firestore notifications 컬렉션에 문서가 추가되면
 * 해당 사용자에게 FCM 푸시 알림을 전송합니다.
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const axios = require("axios");
const cors = require("cors")({ origin: true });

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
 */
exports.sendPushNotification = onDocumentCreated(
  "notifications/{notificationId}",
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
      // 사용자의 FCM 토큰 가져오기
      const userDoc = await db.collection("users").doc(userId).get();

      if (!userDoc.exists) {
        console.log(`User ${userId} not found`);
        return;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${userId}`);
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
        console.log(`Removing invalid token for user ${userId}`);
        await db.collection("users").doc(userId).update({
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

/**
 * 중개사(brokers) 컬렉션의 사용자에게도 푸시 알림 전송
 * (brokers 컬렉션에 별도로 토큰이 저장된 경우)
 */
exports.sendBrokerPushNotification = onDocumentCreated(
  "brokerNotifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const notification = snapshot.data();
    const brokerId = notification.brokerId;
    const title = notification.title || "알림";
    const body = notification.message || "";

    if (!brokerId) return;

    try {
      // 브로커 문서에서 FCM 토큰 가져오기
      const brokerDoc = await db.collection("brokers").doc(brokerId).get();

      if (!brokerDoc.exists) {
        // users 컬렉션에서도 확인
        const userDoc = await db.collection("users").doc(brokerId).get();
        if (!userDoc.exists) {
          console.log(`Broker ${brokerId} not found`);
          return;
        }

        const userData = userDoc.data();
        const fcmToken = userData.fcmToken;

        if (fcmToken) {
          await sendFCM(fcmToken, title, body, notification, event.params.notificationId, snapshot.ref);
        }
        return;
      }

      const brokerData = brokerDoc.data();
      const fcmToken = brokerData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for broker ${brokerId}`);
        return;
      }

      await sendFCM(fcmToken, title, body, notification, event.params.notificationId, snapshot.ref);

    } catch (error) {
      console.error(`Error sending push to broker ${brokerId}:`, error);
    }
  }
);

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
