import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:property/models/property.dart';
import 'package:property/models/chat_message.dart';
import 'package:property/models/visit_request.dart';
import 'package:property/models/quote_request.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collectionName = 'properties';
  final String _usersCollectionName = 'users';
  final String _brokersCollectionName = 'brokers'; // 공인중개사 컬렉션
  final String _chatCollectionName = 'chat_messages';
  final String _visitRequestsCollectionName = 'visit_requests';
  final String _quoteRequestsCollectionName = 'quoteRequests';

  // 사용자 인증 관련 메서드들
  /// 사용자 로그인 (Firebase Authentication 사용)
  /// [emailOrId] 이메일 또는 ID (ID는 @myhome.com 도메인 추가)
  /// [password] 비밀번호
  Future<Map<String, dynamic>?> authenticateUser(String emailOrId, String password) async {
    try {
      
      // ID를 이메일 형식으로 변환 (@ 없으면 도메인 추가)
      String email = emailOrId;
      if (!emailOrId.contains('@')) {
        email = '$emailOrId@myhome.com';
      }
      
      
      // Firebase Authentication으로만 로그인 (Fallback 제거 - 보안상 위험)
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        print('❌ [Firebase] UID가 없습니다');
        return null;
      }
      
      
      // Firestore에서 추가 사용자 정보 가져오기
      final doc = await _firestore.collection(_usersCollectionName).doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        // 항상 uid/id/email/name을 보장해서 반환
        return {
          ...data,
          'uid': uid,
          'id': data['id'] ?? (userCredential.user?.email?.split('@').first ?? uid),
          'email': data['email'] ?? userCredential.user?.email ?? email,
          'name': data['name'] ?? userCredential.user?.displayName ?? (data['id'] ?? uid),
        };
      } else {
        print('❌ [Firebase] Firestore에 사용자 정보 없음');
        return null;
      }
    } on FirebaseAuthException catch (e) {
      print('❌ [Firebase] 사용자 인증 실패: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('❌ [Firebase] 사용자 인증 실패: $e');
      return null;
    }
  }

  // 사용자 조회
  Future<Map<String, dynamic>?> getUser(String id) async {
    // id 체크 - 빈 문자열이면 null 반환
    if (id.isEmpty) {
      return null;
    }
    
    try {
      final doc = await _firestore.collection(_usersCollectionName).doc(id).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('❌ [Firebase] 사용자 조회 실패: $e');
      return null;
    }
  }

  /// 관리자 권한 확인
  /// [userId] 사용자 ID (uid)
  Future<bool> isAdmin(String userId) async {
    try {
      
      if (userId.isEmpty) {
        return false;
      }

      // users 컬렉션에서 role 확인
      final userDoc = await _firestore.collection(_usersCollectionName).doc(userId).get();
      
      if (!userDoc.exists) {
        return false;
      }

      final userData = userDoc.data();
      final role = userData?['role'] as String?;
      final isAdminUser = role == 'admin';
      
      return isAdminUser;
    } catch (e) {
      print('❌ [Firebase] 관리자 권한 확인 실패: $e');
      return false;
    }
  }

  /// 사용자 등록 (Firebase Authentication 사용)
  /// [id] 사용자 ID (이메일 형식으로 자동 변환)
  /// [password] 비밀번호 (Firebase에서 자동 암호화)
  /// [name] 이름
  /// [email] 실제 이메일 (선택사항, 없으면 id@myhome.com 사용)
  /// [phone] 휴대폰 번호 (선택사항)
  Future<bool> registerUser(
    String id, 
    String password, 
    String name, {
    String? email,
    String? phone,
    String role = 'user',
  }) async {
    try {
      
      // 이메일 형식 생성 (실제 이메일이 없으면 id@myhome.com)
      final authEmail = email ?? '$id@myhome.com';
      
      // Firebase Authentication으로 계정 생성
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,  // Firebase가 자동으로 암호화!
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        print('❌ [Firebase] UID 생성 실패');
        return false;
      }
      
      // displayName 설정
      await userCredential.user?.updateDisplayName(name);
      
      // Firestore에 추가 사용자 정보 저장 (비밀번호 제외!)
      await _firestore.collection(_usersCollectionName).doc(uid).set({
        'uid': uid,
        'id': id,
        'name': name,
        'email': email ?? authEmail,
        'phone': phone,
        'role': role,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ [Firebase] 등록 오류: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
      } else if (e.code == 'weak-password') {
      }
      return false;
    } catch (e) {
      print('❌ [Firebase] 사용자 등록 실패: $e');
      return false;
    }
  }
  
  /// 비밀번호 재설정 이메일 발송 (Firebase Authentication 내장 기능)
  Future<bool> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ [Firebase] 이메일 발송 실패: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('❌ [Firebase] 이메일 발송 실패: $e');
      return false;
    }
  }
  
  /// 현재 로그인된 사용자 가져오기
  User? get currentUser => _auth.currentUser;
  
  /// 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 회원탈퇴
  /// [userId] 사용자 UID
  /// 반환: String? - 성공 시 null, 실패 시 에러 메시지
  Future<String?> deleteUserAccount(String userId) async {
    try {
      
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return '로그인된 사용자가 없습니다.';
      }
      
      // 현재 사용자가 본인인지 확인
      if (currentUser.uid != userId) {
        return '본인의 계정만 삭제할 수 있습니다.';
      }
      
      // 1. Firestore에서 사용자 데이터 삭제
      try {
        await _firestore.collection(_usersCollectionName).doc(userId).delete();
      } catch (e) {
        print('⚠️ [Firebase] Firestore 데이터 삭제 실패 (계속 진행): $e');
        // Firestore 삭제 실패해도 계속 진행
      }
      
      // 2. Firebase Authentication에서 사용자 삭제
      await currentUser.delete();
      
      // 3. 로그아웃 처리
      await _auth.signOut();
      
      return null; // 성공
    } on FirebaseAuthException catch (e) {
      print('❌ [Firebase] 회원탈퇴 실패: ${e.code} - ${e.message}');
      
      if (e.code == 'requires-recent-login') {
        return '보안을 위해 다시 로그인한 후 탈퇴해주세요.';
      } else {
        return '회원탈퇴 중 오류가 발생했습니다.\n${e.message ?? '알 수 없는 오류'}';
      }
    } catch (e) {
      print('❌ [Firebase] 회원탈퇴 실패: $e');
      return '회원탈퇴 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
    }
  }

  // 사용자 이름 업데이트
  Future<bool> updateUserName(String id, String newName) async {
    try {
      
      await _firestore.collection(_usersCollectionName).doc(id).update({
        'name': newName,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 사용자 이름 업데이트 실패: $e');
      return false;
    }
  }

  // 모든 사용자 조회
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      
      final querySnapshot = await _firestore.collection(_usersCollectionName).get();
      final users = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['firestoreId'] = doc.id;
        return data;
      }).toList();
      
      return users;
    } catch (e) {
      print('❌ [Firebase] 모든 사용자 조회 실패: $e');
      return [];
    }
  }

  // Create
  Future<DocumentReference?> addProperty(Property property) async {
    try {
      
      final docRef = await _firestore.collection(_collectionName).add(property.toMap());
      
      return docRef;
    } catch (e) {
      print('❌ [Firebase] 부동산 데이터 저장 실패: $e');
      return null;
    }
  }

  // Read - 사용자별 부동산 목록
  Stream<List<Property>> getProperties(String userName) {
    return _firestore
        .collection(_collectionName)
        .where('mainContractor', isEqualTo: userName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
                data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
                data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
                return Property.fromMap(data);
              })
              .toList();
        });
  }

  // Read - 사용자별 부동산 목록 (Future 버전)
  Future<List<Property>> getPropertiesByUserId(String userId) async {
    // userId 체크 - 빈 문자열이면 빈 리스트 반환
    if (userId.isEmpty) {
      return [];
    }
    
    try {
      
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
            data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
            data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
            return Property.fromMap(data);
          })
          .toList();
    } catch (e) {
      print('❌ [Firebase] 사용자별 부동산 목록 조회 실패: $e');
      return [];
    }
  }

  // Read - 모든 사용자의 부동산 목록 (내집사기 페이지용) - Stream 버전
  Stream<List<Property>> getAllProperties() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) {
                final data = doc.data();
                // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
                data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
                data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
                return Property.fromMap(data);
              })
              .toList();
        });
  }

  // Read - 모든 사용자의 부동산 목록 (내집사기 페이지용) - Future 버전
  Future<List<Property>> getAllPropertiesList() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
            data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
            data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
            return Property.fromMap(data);
          })
          .toList();
    } catch (e) {
      print('❌ [Firebase] 전체 부동산 목록 조회 실패: $e');
      return [];
    }
  }

  // Read - 특정 부동산 조회
  Future<Property?> getProperty(String propertyId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(propertyId).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
        data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
        data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
        return Property.fromMap(data);
      }
      return null;
    } catch (e) {
      print('❌ [Firebase] 부동산 조회 실패: $e');
      return null;
    }
  }

  // Read - 주소로 부동산 검색
  Future<List<Property>> searchPropertiesByAddress(String address) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('address', isGreaterThanOrEqualTo: address)
          .where('address', isLessThan: '$address\uf8ff')
          .get();
      
      return querySnapshot.docs
          .map((doc) {
            final data = doc.data();
            // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
            data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
            data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
            return Property.fromMap(data);
          })
          .toList();
    } catch (e) {
      print('❌ [Firebase] 주소 검색 실패: $e');
      return [];
    }
  }

  // Read - 거래 유형별 부동산 조회
  Stream<List<Property>> getPropertiesByType(String userName, String transactionType) {
    return _firestore
        .collection(_collectionName)
        .where('mainContractor', isEqualTo: userName)
        .where('transactionType', isEqualTo: transactionType)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
              data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
              data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
              return Property.fromMap(data);
            })
            .toList());
  }

  // Read - 상태별 부동산 조회
  Stream<List<Property>> getPropertiesByStatus(String userName, String status) {
    return _firestore
        .collection(_collectionName)
        .where('mainContractor', isEqualTo: userName)
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Firestore 문서 ID는 별도 필드로 저장하고, SQLite ID는 null로 설정
              data['firestoreId'] = doc.id; // Firestore 문서 ID 추가
              data['id'] = null; // SQLite ID는 null로 설정 (Firebase에서는 사용하지 않음)
              return Property.fromMap(data);
            })
            .toList());
  }

  // Update
  Future<bool> updateProperty(String id, Property property) async {
    try {
      
      await _firestore.collection(_collectionName).doc(id).update({
        ...property.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 부동산 데이터 업데이트 실패: $e');
      return false;
    }
  }

  // Update - 부분 업데이트
  Future<bool> updatePropertyFields(String id, Map<String, dynamic> fields) async {
    try {
      
      await _firestore.collection(_collectionName).doc(id).update({
        ...fields,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 부동산 부분 업데이트 실패: $e');
      return false;
    }
  }

  // Delete
  Future<bool> deleteProperty(String id) async {
    try {
      
      await _firestore.collection(_collectionName).doc(id).delete();
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 부동산 데이터 삭제 실패: $e');
      return false;
    }
  }

  // 매물 삭제 (연계 데이터 포함)
  Future<bool> deletePropertyWithRelatedData(String propertyId) async {
    try {
      
      // 1. 해당 매물의 채팅 메시지 삭제
      final chatQuery = await _firestore
          .collection(_chatCollectionName)
          .where('propertyId', isEqualTo: propertyId)
          .get();
      
      for (final doc in chatQuery.docs) {
        await doc.reference.delete();
      }
      
      // 2. 해당 매물의 방문 신청 삭제
      final visitQuery = await _firestore
          .collection(_visitRequestsCollectionName)
          .where('propertyId', isEqualTo: propertyId)
          .get();
      
      for (final doc in visitQuery.docs) {
        await doc.reference.delete();
      }
      
      // 3. 매물 자체 삭제
      await _firestore.collection(_collectionName).doc(propertyId).delete();
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 매물 및 연계 데이터 삭제 실패: $e');
      return false;
    }
  }

  // 특정 매물의 채팅 대화 삭제
  Future<bool> deleteChatConversation(String propertyId) async {
    try {
      
      final querySnapshot = await _firestore
          .collection(_chatCollectionName)
          .where('propertyId', isEqualTo: propertyId)
          .get();
      
      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 채팅 대화 삭제 실패: $e');
      return false;
    }
  }

  // 통계 정보 조회
  Future<Map<String, dynamic>> getPropertyStats(String userName) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mainContractor', isEqualTo: userName)
          .get();
      
      final properties = querySnapshot.docs
          .map((doc) => Property.fromMap(doc.data()))
          .toList();
      
      final totalCount = properties.length;
      final byType = <String, int>{};
      final byStatus = <String, int>{};
      final totalValue = properties.fold<int>(0, (total, p) => total + p.price);
      
      for (final property in properties) {
        byType[property.transactionType] = (byType[property.transactionType] ?? 0) + 1;
        if (property.status != null) {
          byStatus[property.status!] = (byStatus[property.status!] ?? 0) + 1;
        }
      }
      
      return {
        'totalCount': totalCount,
        'totalValue': totalValue,
        'byType': byType,
        'byStatus': byStatus,
        'averageValue': totalCount > 0 ? totalValue ~/ totalCount : 0,
      };
    } catch (e) {
      print('❌ [Firebase] 통계 조회 실패: $e');
      return {
        'totalCount': 0,
        'totalValue': 0,
        'byType': {},
        'byStatus': {},
        'averageValue': 0,
      };
    }
  }

  // 배치 저장 (여러 부동산 데이터 한번에 저장)
  Future<List<String>> addPropertiesBatch(List<Property> properties) async {
    try {
      
      final batch = _firestore.batch();
      final docRefs = <DocumentReference>[];
      
      for (final property in properties) {
        final docRef = _firestore.collection(_collectionName).doc();
        batch.set(docRef, property.toMap());
        docRefs.add(docRef);
      }
      
      await batch.commit();
      
      final ids = docRefs.map((ref) => ref.id).toList();
      return ids;
    } catch (e) {
      print('❌ [Firebase] 배치 저장 실패: $e');
      return [];
    }
  }

  // ===== 채팅 관련 메서드들 =====

  // 채팅 메시지 전송
  Future<DocumentReference?> sendChatMessage(ChatMessage message) async {
    try {
      
      final docRef = await _firestore.collection(_chatCollectionName).add(message.toMap());
      
      return docRef;
    } catch (e) {
      print('❌ [Firebase] 채팅 메시지 전송 실패: $e');
      return null;
    }
  }

  // 특정 매물에 대한 채팅 메시지 스트림
  Stream<List<ChatMessage>> getChatMessagesForProperty(String propertyId) {
    return _firestore
        .collection(_chatCollectionName)
        .where('propertyId', isEqualTo: propertyId)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return ChatMessage.fromMap(data);
              })
              .toList();
          
          // 클라이언트에서 시간순 정렬
          messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return messages;
        });
  }

  // 사용자가 보낸 메시지 스트림
  Stream<List<ChatMessage>> getSentMessages(String userId) {
    return _firestore
        .collection(_chatCollectionName)
        .where('senderId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return ChatMessage.fromMap(data);
            })
            .toList());
  }

  // 사용자가 받은 메시지 스트림
  Stream<List<ChatMessage>> getReceivedMessages(String userId) {
    return _firestore
        .collection(_chatCollectionName)
        .where('receiverId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return ChatMessage.fromMap(data);
            })
            .toList());
  }

  // 사용자의 모든 채팅 메시지 (보낸 것 + 받은 것)
  Stream<List<ChatMessage>> getAllUserMessages(String userId) {
    return _firestore
        .collection(_chatCollectionName)
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['senderId'] == userId || data['receiverId'] == userId;
              })
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return ChatMessage.fromMap(data);
              })
              .toList();
          
          // 클라이언트에서 시간순 정렬 (최신순)
          messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return messages;
        });
  }

  // 메시지 읽음 처리
  Future<bool> markMessageAsRead(String messageId) async {
    try {
      
      await _firestore.collection(_chatCollectionName).doc(messageId).update({
        'isRead': true,
      });
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 메시지 읽음 처리 실패: $e');
      return false;
    }
  }

  // 읽지 않은 메시지 개수 조회
  Future<int> getUnreadMessageCount(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_chatCollectionName)
          .where('receiverId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      print('❌ [Firebase] 읽지 않은 메시지 개수 조회 실패: $e');
      return 0;
    }
  }

  // ===== 방문 신청 관련 메서드들 =====

  // 방문 신청 생성
  Future<DocumentReference?> createVisitRequest(VisitRequest request) async {
    try {
      
      final docRef = await _firestore.collection(_visitRequestsCollectionName).add(request.toMap());
      
      return docRef;
    } catch (e) {
      print('❌ [Firebase] 방문 신청 생성 실패: $e');
      return null;
    }
  }

  // 판매자의 방문 신청 목록 스트림
  Stream<List<VisitRequest>> getSellerVisitRequests(String sellerId) {
    return _firestore
        .collection(_visitRequestsCollectionName)
        .where('sellerId', isEqualTo: sellerId)
        // .orderBy('requestTimestamp', descending: true) // 임시로 주석 처리 - 인덱스 필요
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return VisitRequest.fromMap(data);
              })
              .toList();
          
          // 클라이언트에서 정렬
          requests.sort((a, b) => b.requestTimestamp.compareTo(a.requestTimestamp));
          return requests;
        });
  }

  // 구매자의 방문 신청 목록 스트림
  Stream<List<VisitRequest>> getBuyerVisitRequests(String buyerId) {
    return _firestore
        .collection(_visitRequestsCollectionName)
        .where('buyerId', isEqualTo: buyerId)
        // .orderBy('requestTimestamp', descending: true) // 임시로 주석 처리 - 인덱스 필요
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return VisitRequest.fromMap(data);
              })
              .toList();
          
          // 클라이언트에서 정렬
          requests.sort((a, b) => b.requestTimestamp.compareTo(a.requestTimestamp));
          return requests;
        });
  }

  // 특정 방문 신청 조회
  Future<VisitRequest?> getVisitRequest(String requestId) async {
    try {
      final doc = await _firestore.collection(_visitRequestsCollectionName).doc(requestId).get();
      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        return VisitRequest.fromMap(data);
      }
      return null;
    } catch (e) {
      print('❌ [Firebase] 방문 신청 조회 실패: $e');
      return null;
    }
  }

  // 방문 신청 상태 업데이트
  Future<bool> updateVisitRequestStatus(String requestId, String status, {String? confirmedBy}) async {
    try {
      
      final updateData = {
        'status': status,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (status == 'confirmed') {
        updateData['confirmedAt'] = DateTime.now().toIso8601String();
        if (confirmedBy != null) {
          updateData['confirmedBy'] = confirmedBy;
        }
      }

      await _firestore.collection(_visitRequestsCollectionName).doc(requestId).update(updateData);
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 방문 신청 상태 업데이트 실패: $e');
      return false;
    }
  }

  // 방문 신청 메시지 업데이트
  Future<bool> updateVisitRequestMessage(String requestId, String message) async {
    try {
      
      await _firestore.collection(_visitRequestsCollectionName).doc(requestId).update({
        'lastMessage': message,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 방문 신청 메시지 업데이트 실패: $e');
      return false;
    }
  }

  // 방문 신청 삭제
  Future<bool> deleteVisitRequest(String requestId) async {
    try {
      
      await _firestore.collection(_visitRequestsCollectionName).doc(requestId).delete();
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 방문 신청 삭제 실패: $e');
      return false;
    }
  }

  // 대기중인 방문 신청 개수 조회 (판매자용)
  Future<int> getPendingVisitRequestCount(String sellerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_visitRequestsCollectionName)
          .where('sellerId', isEqualTo: sellerId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      print('❌ [Firebase] 대기중인 방문 신청 개수 조회 실패: $e');
      return 0;
    }
  }

  // 확정된 방문 신청 개수 조회 (구매자용)
  Future<int> getConfirmedVisitRequestCount(String buyerId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_visitRequestsCollectionName)
          .where('buyerId', isEqualTo: buyerId)
          .where('status', isEqualTo: 'confirmed')
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      print('❌ [Firebase] 확정된 방문 신청 개수 조회 실패: $e');
      return 0;
    }
  }

  // ===== 관리자 기능 =====

  // 모든 매물 삭제 (관리자용) - 연계 데이터 포함
  Future<bool> deleteAllProperties() async {
    try {
      
      // 1. 모든 매물 조회
      final propertiesQuery = await _firestore.collection(_collectionName).get();
      
      
      // 2. 모든 채팅 메시지 삭제
      final chatQuery = await _firestore.collection(_chatCollectionName).get();
      final chatBatch = _firestore.batch();
      for (final doc in chatQuery.docs) {
        chatBatch.delete(doc.reference);
      }
      await chatBatch.commit();
      
      // 3. 모든 방문 신청 삭제
      final visitQuery = await _firestore.collection(_visitRequestsCollectionName).get();
      final visitBatch = _firestore.batch();
      for (final doc in visitQuery.docs) {
        visitBatch.delete(doc.reference);
      }
      await visitBatch.commit();
      
      // 4. 모든 매물 삭제
      final propertyBatch = _firestore.batch();
      for (final doc in propertiesQuery.docs) {
        propertyBatch.delete(doc.reference);
      }
      await propertyBatch.commit();
      
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 모든 매물 및 연계 데이터 삭제 실패: $e');
      return false;
    }
  }

  // 특정 사용자의 모든 매물 삭제
  Future<bool> deleteAllPropertiesByUser(String userName) async {
    try {
      
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mainContractor', isEqualTo: userName)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        return true;
      }
      
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 사용자 매물 삭제 실패: $e');
      return false;
    }
  }

  // 모든 채팅 메시지 삭제 (관리자용)
  Future<bool> deleteAllChatMessages() async {
    try {
      
      final querySnapshot = await _firestore.collection(_chatCollectionName).get();
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 모든 채팅 메시지 삭제 실패: $e');
      return false;
    }
  }

  // 모든 방문 신청 삭제 (관리자용)
  Future<bool> deleteAllVisitRequests() async {
    try {
      
      final querySnapshot = await _firestore.collection(_visitRequestsCollectionName).get();
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 모든 방문 신청 삭제 실패: $e');
      return false;
    }
  }

  // 사용자 자주 가는 위치 업데이트 (firstZone 필드로 저장)
  Future<bool> updateUserFrequentLocation(String userId, String frequentLocation) async {
    try {
      
      // 문서가 없을 수 있으므로 merge set으로 업서트 처리
      await _firestore.collection(_usersCollectionName).doc(userId).set({
        'firstZone': frequentLocation,
        'frequentLocation': frequentLocation, // 기존 필드도 유지
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 사용자 자주 가는 위치 업데이트 실패: $e');
      return false;
    }
  }

  // 중개업자 정보 업데이트
  Future<bool> updateUserBrokerInfo(String userId, Map<String, dynamic> brokerInfo) async {
    try {
      
      await _firestore.collection(_usersCollectionName).doc(userId).update({
        'brokerInfo': brokerInfo,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 중개업자 정보 업데이트 실패: $e');
      return false;
    }
  }

  /// 공인중개사 정보 업데이트 (brokers 컬렉션)
  /// [brokerIdOrUid] brokerId 또는 UID
  /// [brokerInfo] 업데이트할 정보
  Future<bool> updateBrokerInfo(String brokerIdOrUid, Map<String, dynamic> brokerInfo) async {
    try {
      
      // 먼저 UID로 조회
      final brokerDoc = await _firestore.collection(_brokersCollectionName).doc(brokerIdOrUid).get();
      
      String? docId;
      if (brokerDoc.exists) {
        docId = brokerIdOrUid; // UID로 찾음
      } else {
        // brokerId로 조회
        final querySnapshot = await _firestore
            .collection(_brokersCollectionName)
            .where('brokerId', isEqualTo: brokerIdOrUid)
            .limit(1)
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          docId = querySnapshot.docs.first.id;
        }
      }
      
      if (docId == null) {
        print('❌ [Firebase] 공인중개사를 찾을 수 없습니다: $brokerIdOrUid');
        return false;
      }
      
      // 업데이트할 데이터 준비 (기존 필드와 매핑)
      final updateData = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      // brokerInfo의 필드를 brokers 컬렉션의 필드로 매핑
      if (brokerInfo.containsKey('broker_name')) {
        updateData['ownerName'] = brokerInfo['broker_name'];
      }
      if (brokerInfo.containsKey('broker_phone')) {
        updateData['phoneNumber'] = brokerInfo['broker_phone'];
      }
      if (brokerInfo.containsKey('broker_address')) {
        updateData['address'] = brokerInfo['broker_address'];
      }
      if (brokerInfo.containsKey('broker_license_number')) {
        updateData['brokerRegistrationNumber'] = brokerInfo['broker_license_number'];
      }
      if (brokerInfo.containsKey('broker_office_name')) {
        updateData['businessName'] = brokerInfo['broker_office_name'];
      }
      if (brokerInfo.containsKey('broker_office_address')) {
        updateData['roadAddress'] = brokerInfo['broker_office_address'];
      }
      
      await _firestore.collection(_brokersCollectionName).doc(docId).update(updateData);
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 공인중개사 정보 업데이트 실패: $e');
      return false;
    }
  }

  // 중개업자별 매물 조회 (broker_license_number 기준)
  Future<List<Property>> getPropertiesByBroker(String brokerLicenseNumber) async {
    try {
      
      // 모든 매물을 조회해서 brokerInfo.broker_license_number로 필터링
      final allPropertiesSnapshot = await _firestore
          .collection(_collectionName)
          .get();
      
      
      final matchingProperties = <Property>[];
      
      for (var doc in allPropertiesSnapshot.docs) {
        final data = doc.data();
        final brokerInfo = data['brokerInfo'];
        
        
        if (brokerInfo != null && brokerInfo['broker_license_number'] == brokerLicenseNumber) {
          data['id'] = doc.id;
          matchingProperties.add(Property.fromMap(data));
        }
      }
      
      return matchingProperties;
    } catch (e) {
      print('❌ [Firebase] 중개업자별 매물 조회 실패: $e');
      return [];
    }
  }

  /* =========================================== */
  /* 견적문의 관리 메서드들 */
  /* =========================================== */

  /// 견적문의 저장
  Future<String?> saveQuoteRequest(QuoteRequest quoteRequest) async {
    try {
      final docRef = await _firestore.collection(_quoteRequestsCollectionName).add(quoteRequest.toMap());
      return docRef.id;
    } catch (e) {
      print('❌ [Firebase] 견적문의 저장 실패: $e');
      return null;
    }
  }

  /// 모든 견적문의 조회 (관리자용)
  Stream<List<QuoteRequest>> getAllQuoteRequests() {
    try {
      return _firestore
          .collection(_quoteRequestsCollectionName)
          .orderBy('requestDate', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => QuoteRequest.fromMap(doc.id, doc.data()))
                .toList();
          });
    } catch (e) {
      print('❌ [Firebase] 견적문의 조회 실패: $e');
      return Stream.value([]);
    }
  }

  /// 특정 사용자의 견적문의 조회 (userId가 userName으로 저장된 과거 데이터도 포함)
  Stream<List<QuoteRequest>> getQuoteRequestsByUser(String userId) async* {
    // userId 체크 - 빈 문자열이면 빈 스트림 반환
    if (userId.isEmpty) {
      yield* Stream.value([]);
      return;
    }
    
    try {
      
      // 현재 사용자 정보 조회 (userName 얻기 위해)
      // userId가 실제 userId인지 userName인지 확인
      Map<String, dynamic>? userData;
      String userName = '';
      String actualUserId = userId; // 실제 사용할 userId
      
      try {
        userData = await getUser(userId);
        userName = userData?['name'] ?? userData?['id'] ?? '';
        actualUserId = userData?['uid'] ?? userData?['id'] ?? userId;
      } catch (e) {
        // getUser 실패 시 userId가 userName일 수 있음
        print('⚠️ [Firebase] getUser 실패, userId를 userName으로 간주: $e');
        userName = userId; // userId가 실제로 userName일 수 있음
        actualUserId = userId; // userId를 그대로 사용
      }
      
      // userName이 비어있으면 userId를 userName으로 사용
      if (userName.isEmpty) {
        userName = userId;
      }
      
      
      // 두 가지 쿼리: 1) userId로 직접 조회, 2) userName으로 과거 데이터 조회
      yield* _firestore
          .collection(_quoteRequestsCollectionName)
          .orderBy('requestDate', descending: true)
          .snapshots()
          .map((snapshot) {
            final allDocs = snapshot.docs;
            
            // userId와 일치하거나 userName과 일치하는 문서만 필터링
            final filteredDocs = allDocs.where((doc) {
              final data = doc.data();
              final docUserId = data['userId'] as String? ?? '';
              final docUserName = data['userName'] as String? ?? '';
              
              // userId가 일치하거나 userName이 일치하는 경우
              final matchesUserId = docUserId.isNotEmpty && 
                  (docUserId == userId || docUserId == actualUserId);
              final matchesUserName = userName.isNotEmpty && docUserName == userName;
              
              return matchesUserId || matchesUserName;
            }).toList();
            
            return filteredDocs
                .map((doc) => QuoteRequest.fromMap(doc.id, doc.data()))
                .toList();
          });
    } catch (e) {
      print('❌ [Firebase] 사용자별 견적문의 조회 실패: $e');
      yield* Stream.value([]);
    }
  }

  /// 견적문의 상태 업데이트
  Future<bool> updateQuoteRequestStatus(String requestId, String newStatus) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('❌ [Firebase] 견적문의 상태 업데이트 실패: $e');
      return false;
    }
  }

  /// 공인중개사 이메일 첨부 (관리자용)
  Future<bool> attachEmailToBroker(String requestId, String brokerEmail) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'brokerEmail': brokerEmail,
        'emailAttachedAt': FieldValue.serverTimestamp(),
        'emailAttachedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('❌ [Firebase] 이메일 첨부 실패: $e');
      return false;
    }
  }

  /// 견적문의 링크 ID 업데이트
  Future<bool> updateQuoteRequestLinkId(String requestId, String linkId) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'inquiryLinkId': linkId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('❌ [Firebase] 링크 ID 업데이트 실패: $e');
      return false;
    }
  }
  
  /// 견적문의 답변 업데이트
  Future<bool> updateQuoteRequestAnswer(String requestId, String answer) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'brokerAnswer': answer,
        'answerDate': FieldValue.serverTimestamp(),
        'status': 'answered',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('❌ [Firebase] 답변 업데이트 실패: $e');
      return false;
    }
  }

  /// 공인중개사 상세 답변 업데이트 (회원용)
  Future<bool> updateQuoteRequestDetailedAnswer({
    required String requestId,
    String? recommendedPrice,
    String? minimumPrice,
    String? expectedDuration,
    String? promotionMethod,
    String? commissionRate,
    String? recentCases,
    String? brokerAnswer,
  }) async {
    try {
      
      final updateData = <String, dynamic>{
        'answerDate': FieldValue.serverTimestamp(),
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (recommendedPrice != null && recommendedPrice.isNotEmpty) {
        updateData['recommendedPrice'] = recommendedPrice;
      }
      if (minimumPrice != null && minimumPrice.isNotEmpty) {
        updateData['minimumPrice'] = minimumPrice;
      }
      if (expectedDuration != null && expectedDuration.isNotEmpty) {
        updateData['expectedDuration'] = expectedDuration;
      }
      if (promotionMethod != null && promotionMethod.isNotEmpty) {
        updateData['promotionMethod'] = promotionMethod;
      }
      if (commissionRate != null && commissionRate.isNotEmpty) {
        updateData['commissionRate'] = commissionRate;
      }
      if (recentCases != null && recentCases.isNotEmpty) {
        updateData['recentCases'] = recentCases;
      }
      if (brokerAnswer != null && brokerAnswer.isNotEmpty) {
        updateData['brokerAnswer'] = brokerAnswer;
      }

      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update(updateData);
      return true;
    } catch (e) {
      print('❌ [Firebase] 상세 답변 업데이트 실패: $e');
      return false;
    }
  }
  
  /// 링크 ID로 견적문의 조회
  Future<Map<String, dynamic>?> getQuoteRequestByLinkId(String linkId) async {
    try {
      final snapshot = await _firestore
          .collection(_quoteRequestsCollectionName)
          .where('inquiryLinkId', isEqualTo: linkId)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return null;
      }
      
      final doc = snapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    } catch (e) {
      print('❌ [Firebase] 견적문의 조회 실패: $e');
      return null;
    }
  }

  /// 견적문의 삭제
  Future<bool> deleteQuoteRequest(String requestId) async {
    try {
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).delete();
      return true;
    } catch (e) {
      print('❌ [Firebase] 견적문의 삭제 실패: $e');
      return false;
    }
  }

  /* =========================================== */
  /* 공인중개사 관련 메서드 */
  /* =========================================== */

  /// 공인중개사 등록
  /// [brokerId] 공인중개사 ID (이메일 또는 일반 ID)
  /// [password] 비밀번호
  /// [brokerInfo] 공인중개사 정보 (등록번호, 대표자명 등)
  /// 
  /// 반환: String? - 성공 시 null, 실패 시 에러 메시지
  Future<String?> registerBroker({
    required String brokerId,
    required String password,
    required Map<String, dynamic> brokerInfo,
  }) async {
    try {
      
      // 이메일 형식 생성
      String email = brokerId;
      if (!brokerId.contains('@')) {
        email = '$brokerId@myhome.com';
      }
      
      // Firebase Authentication으로 계정 생성
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        print('❌ [Firebase] UID 생성 실패');
        return '계정 생성에 실패했습니다. 다시 시도해주세요.';
      }
      
      // displayName 설정
      await userCredential.user?.updateDisplayName(
        brokerInfo['ownerName'] ?? brokerId,
      );
      
      // Firestore에 공인중개사 정보 저장
      await _firestore.collection(_brokersCollectionName).doc(uid).set({
        'brokerId': brokerId,
        'uid': uid,
        'email': email,
        'userType': 'broker',
        ...brokerInfo,
        'verified': brokerInfo['verified'] ?? false, // 검증 여부
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return null; // 성공
    } on FirebaseAuthException catch (e) {
      print('❌ [Firebase] 공인중개사 등록 오류: ${e.code} - ${e.message}');
      
      if (e.code == 'email-already-in-use') {
        return '이미 사용 중인 이메일입니다.\n로그인해주세요.';
      } else if (e.code == 'weak-password') {
        return '비밀번호가 너무 약합니다.\n6자 이상의 비밀번호를 사용해주세요.';
      } else if (e.code == 'invalid-email') {
        return '올바른 이메일 형식을 입력해주세요.';
      } else {
        return '회원가입에 실패했습니다.\n${e.message ?? '알 수 없는 오류가 발생했습니다.'}';
      }
    } catch (e) {
      print('❌ [Firebase] 공인중개사 등록 실패: $e');
      return '회원가입 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
    }
  }

  /// 공인중개사 로그인
  /// [emailOrId] 이메일 또는 ID
  /// [password] 비밀번호
  Future<Map<String, dynamic>?> authenticateBroker(String emailOrId, String password) async {
    try {
      
      // ID를 이메일 형식으로 변환
      String email = emailOrId;
      if (!emailOrId.contains('@')) {
        email = '$emailOrId@myhome.com';
      }
      
      
      // Firebase Authentication으로만 로그인
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final uid = userCredential.user?.uid;
      if (uid == null) {
        print('❌ [Firebase] UID가 없습니다');
        return null;
      }
      
      
      // Firestore에서 공인중개사 정보 가져오기
      final doc = await _firestore.collection(_brokersCollectionName).doc(uid).get();
      
      if (doc.exists) {
        final data = doc.data() ?? <String, dynamic>{};
        return {
          ...data,
          'uid': uid,
          'brokerId': data['brokerId'] ?? emailOrId,
          'email': data['email'] ?? email,
          'userType': 'broker',
        };
      } else {
        print('❌ [Firebase] 공인중개사 정보가 Firestore에 없음');
        return null;
      }
    } on FirebaseAuthException catch (e) {
      print('❌ [Firebase] 공인중개사 인증 실패: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('❌ [Firebase] 공인중개사 인증 실패: $e');
      return null;
    }
  }

  /// 전체 공인중개사 조회 (관리자용)
  Future<List<Map<String, dynamic>>> getAllBrokers() async {
    try {
      final snapshot = await _firestore.collection(_brokersCollectionName).get();
      
      final brokers = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      return brokers;
    } catch (e) {
      print('❌ [Firebase] 전체 공인중개사 조회 실패: $e');
      return [];
    }
  }

  /// 공인중개사 정보 조회
  Future<Map<String, dynamic>?> getBroker(String brokerId) async {
    try {
      // UID로 조회
      final doc = await _firestore.collection(_brokersCollectionName).doc(brokerId).get();
      if (doc.exists) {
        return doc.data();
      }
      
      // brokerId로 조회
      final querySnapshot = await _firestore
          .collection(_brokersCollectionName)
          .where('brokerId', isEqualTo: brokerId)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      
      return null;
    } catch (e) {
      print('❌ [Firebase] 공인중개사 조회 실패: $e');
      return null;
    }
  }

  /// 공인중개사에게 온 견적문의 조회
  /// [brokerRegistrationNumber] 공인중개사 등록번호
  Stream<List<QuoteRequest>> getBrokerQuoteRequests(String brokerRegistrationNumber) {
    try {
      return _firestore
          .collection(_quoteRequestsCollectionName)
          .where('brokerRegistrationNumber', isEqualTo: brokerRegistrationNumber)
          // orderBy 제거: 인덱스 없이도 작동하도록 메모리에서 정렬
          .snapshots()
          .map((snapshot) {
            try {
              final quotes = snapshot.docs
                  .map((doc) {
                    try {
                      return QuoteRequest.fromMap(doc.id, doc.data());
                    } catch (e) {
                      print('⚠️ [Firebase] 견적문의 데이터 파싱 오류 (문서 ID: ${doc.id}): $e');
                      return null;
                    }
                  })
                  .whereType<QuoteRequest>() // null 제거
                  .toList();
              
              // 메모리에서 날짜 기준 내림차순 정렬
              quotes.sort((a, b) => b.requestDate.compareTo(a.requestDate));
              
              return quotes;
            } catch (e) {
              print('❌ [Firebase] 스냅샷 데이터 처리 오류: $e');
              return <QuoteRequest>[]; // 오류 발생 시 빈 리스트 반환
            }
          });
    } catch (e) {
      print('❌ [Firebase] 공인중개사 견적문의 조회 실패: $e');
      // 초기 오류는 빈 Stream으로 반환
      return Stream.value(<QuoteRequest>[]);
    }
  }

  /// 공인중개사가 등록번호로 조회 (중복 가입 방지)
  Future<Map<String, dynamic>?> getBrokerByRegistrationNumber(String registrationNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection(_brokersCollectionName)
          .where('brokerRegistrationNumber', isEqualTo: registrationNumber)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('❌ [Firebase] 등록번호로 공인중개사 조회 실패: $e');
      return null;
    }
  }

}
