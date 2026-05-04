// =============================================================================
// 01_m1_seller_broker.test.js — Task 02 M1.1 매도자-중개사 우선권 통합 시나리오
// =============================================================================
//
// 흐름:
//   1. 매도자 매물 등록 (listingMode='open')
//   2. broker 자격 시드 (broker_eligibility — licenseStatus='verified', jurisdictions 포함)
//   3. broker가 issuePriorityGrant 호출 → grant 14일 발급 + audit log 'grant_issued'
//   4. 같은 broker 두 번째 issuePriorityGrant → 'already_granted' 거부
//   5. 7일 timestamp 시뮬레이션 + activityScore < 0.8 상태 유지
//   6. enforceActivityRule 수동 호출 → grant 'expired' 전이 + audit log 'grant_expired'
//   7. 만료 후 두 번째 broker issuePriorityGrant → 새 grant 정상 발급
//
// 실행:
//   firebase emulators:exec --only firestore,auth,functions \
//     "npx mocha test/emulator_integration/01_m1_seller_broker.test.js --timeout 30000"
//
// =============================================================================

const { expect } = require('chai');
const admin = require('firebase-admin');
const test = require('firebase-functions-test')({
  projectId: 'demo-myhome-emulator',
});

// emulator 환경 설정
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: 'demo-myhome-emulator' });
}

const db = admin.firestore();
const myFunctions = require('../../functions/index.js');

const SELLER_UID = 'seller_test_001';
const BROKER_UID_A = 'broker_test_a';
const BROKER_UID_B = 'broker_test_b';
const BROKER_ID_A = 'broker_a_id';
const BROKER_ID_B = 'broker_b_id';
const PROPERTY_ID = 'mls_test_001';
const DISTRICT_CODE = '11680'; // 강남구

describe('Task 02 — M1.1 매도자-중개사 우선권 통합', () => {
  beforeEach(async () => {
    // emulator clear
    const collections = [
      'mlsProperties', 'priority_grants', 'priority_audit_logs',
      'broker_eligibility', 'brokers', 'users'
    ];
    for (const col of collections) {
      const docs = await db.collection(col).get();
      const batch = db.batch();
      docs.forEach(doc => batch.delete(doc.ref));
      await batch.commit();
    }

    // 매도자·broker 시드
    await db.collection('users').doc(SELLER_UID).set({
      uid: SELLER_UID, role: 'seller', displayName: '테스트 매도자'
    });
    await db.collection('users').doc(BROKER_UID_A).set({
      uid: BROKER_UID_A, role: 'broker', displayName: '테스트 중개사 A'
    });
    await db.collection('users').doc(BROKER_UID_B).set({
      uid: BROKER_UID_B, role: 'broker', displayName: '테스트 중개사 B'
    });
    await db.collection('brokers').doc(BROKER_ID_A).set({
      brokerId: BROKER_ID_A, uid: BROKER_UID_A, licenseNumber: 'LIC-A-001'
    });
    await db.collection('brokers').doc(BROKER_ID_B).set({
      brokerId: BROKER_ID_B, uid: BROKER_UID_B, licenseNumber: 'LIC-B-001'
    });
    await db.collection('broker_eligibility').doc(BROKER_ID_A).set({
      brokerId: BROKER_ID_A, brokerUid: BROKER_UID_A,
      licenseStatus: 'verified', licenseNumber: 'LIC-A-001',
      jurisdictions: [DISTRICT_CODE],
      geofence: { lat: 37.4979, lng: 127.0276, radiusKm: 5 },
      activeGrantsCount: 0, activeGrantsCap: 5,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    await db.collection('broker_eligibility').doc(BROKER_ID_B).set({
      brokerId: BROKER_ID_B, brokerUid: BROKER_UID_B,
      licenseStatus: 'verified', licenseNumber: 'LIC-B-001',
      jurisdictions: [DISTRICT_CODE],
      geofence: { lat: 37.4979, lng: 127.0276, radiusKm: 5 },
      activeGrantsCount: 0, activeGrantsCap: 5,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // 매물 시드
    await db.collection('mlsProperties').doc(PROPERTY_ID).set({
      id: PROPERTY_ID, userId: SELLER_UID, status: 'active',
      address: '서울 강남구 테헤란로 1', district: '강남구',
      latitude: 37.4979, longitude: 127.0276,
      desiredPrice: 1000000000, transactionType: '매매',
      listingMode: 'open',
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });

  after(async () => {
    test.cleanup();
    await admin.app().delete();
  });

  it('Step 3 — broker A가 issuePriorityGrant → grant 14일 발급', async () => {
    const wrapped = test.wrap(myFunctions.issuePriorityGrant);
    const result = await wrapped(
      { propertyId: PROPERTY_ID, type: 'seller_match', stage: 'participation' },
      { auth: { uid: BROKER_UID_A } }
    );

    expect(result).to.have.property('grantId');
    expect(result.status).to.equal('active');

    const grantSnap = await db.collection('priority_grants').doc(result.grantId).get();
    const grant = grantSnap.data();
    expect(grant.brokerId).to.equal(BROKER_ID_A);
    expect(grant.propertyId).to.equal(PROPERTY_ID);
    expect(grant.type).to.equal('seller_match');
    expect(grant.status).to.equal('active');

    // 14일 expiresAt 검증 (grantedAt + 14d ± 1초)
    const grantedMs = grant.grantedAt.toMillis();
    const expiresMs = grant.expiresAt.toMillis();
    const diffDays = (expiresMs - grantedMs) / (24 * 60 * 60 * 1000);
    expect(diffDays).to.be.closeTo(14, 0.01);

    // audit log 'grant_issued' 동시 기록 검증
    const auditSnap = await db.collection('priority_audit_logs')
      .where('grantId', '==', result.grantId)
      .where('eventType', '==', 'grant_issued')
      .get();
    expect(auditSnap.size).to.equal(1);
  });

  it('Step 4 — broker A 중복 시도 → already_granted 거부', async () => {
    const wrapped = test.wrap(myFunctions.issuePriorityGrant);
    const first = await wrapped(
      { propertyId: PROPERTY_ID, type: 'seller_match', stage: 'participation' },
      { auth: { uid: BROKER_UID_A } }
    );
    expect(first).to.have.property('grantId');

    try {
      await wrapped(
        { propertyId: PROPERTY_ID, type: 'seller_match', stage: 'participation' },
        { auth: { uid: BROKER_UID_A } }
      );
      throw new Error('Expected already_granted rejection');
    } catch (err) {
      expect(err.message).to.include('already_granted');
    }
  });

  it('Step 5-6 — 7일 시뮬레이션 + activityScore<0.8 → enforceActivityRule 만료', async () => {
    const wrappedIssue = test.wrap(myFunctions.issuePriorityGrant);
    const issueResult = await wrappedIssue(
      { propertyId: PROPERTY_ID, type: 'seller_match', stage: 'participation' },
      { auth: { uid: BROKER_UID_A } }
    );

    // 7일 + 1초 전으로 grantedAt 조작 (activityScore 0 유지)
    const sevenDaysAgoMs = Date.now() - (7 * 24 * 60 * 60 * 1000) - 1000;
    await db.collection('priority_grants').doc(issueResult.grantId).update({
      grantedAt: admin.firestore.Timestamp.fromMillis(sevenDaysAgoMs),
      activityScore: 0.5
    });

    // enforceActivityRule 수동 호출 (scheduled function)
    const wrappedEnforce = test.wrap(myFunctions.enforceActivityRule);
    await wrappedEnforce({});

    // grant 만료 검증
    const grantSnap = await db.collection('priority_grants').doc(issueResult.grantId).get();
    const grant = grantSnap.data();
    expect(grant.status).to.equal('expired');
    expect(grant.statusReason).to.match(/activity|inactivity/);

    // audit log 'grant_expired' 검증
    const auditSnap = await db.collection('priority_audit_logs')
      .where('grantId', '==', issueResult.grantId)
      .where('eventType', '==', 'grant_expired')
      .get();
    expect(auditSnap.size).to.equal(1);
  });

  it('Step 7 — 만료 후 broker B 새 grant 정상 발급', async () => {
    const wrappedIssue = test.wrap(myFunctions.issuePriorityGrant);

    // broker A grant 발급 후 강제 만료
    const aResult = await wrappedIssue(
      { propertyId: PROPERTY_ID, type: 'seller_match', stage: 'participation' },
      { auth: { uid: BROKER_UID_A } }
    );
    await db.collection('priority_grants').doc(aResult.grantId).update({
      status: 'expired', statusReason: 'manual_test_expire'
    });

    // broker B 새 grant 발급
    const bResult = await wrappedIssue(
      { propertyId: PROPERTY_ID, type: 'seller_match', stage: 'participation' },
      { auth: { uid: BROKER_UID_B } }
    );
    expect(bResult).to.have.property('grantId');
    expect(bResult.grantId).to.not.equal(aResult.grantId);

    const grantSnap = await db.collection('priority_grants').doc(bResult.grantId).get();
    expect(grantSnap.data().brokerId).to.equal(BROKER_ID_B);
    expect(grantSnap.data().status).to.equal('active');
  });
});
