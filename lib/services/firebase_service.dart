
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/property.dart';
import '../models/chat_message.dart';
import '../models/visit_request.dart';
import '../models/quote_request.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collectionName = 'properties';
  final String _usersCollectionName = 'users';
  final String _chatCollectionName = 'chat_messages';
  final String _visitRequestsCollectionName = 'visit_requests';
  final String _quoteRequestsCollectionName = 'quoteRequests';

  // 사용자 인증 관련 메서드들
  /// 사용자 로그인 (Firebase Authentication 사용)
  /// [emailOrId] 이메일 또는 ID (ID는 @myhouse.com 도메인 추가)
  /// [password] 비밀번호
  Future<Map<String, dynamic>?> authenticateUser(String emailOrId, String password) async {
    try {
      print('🔐 [Firebase] 사용자 인증 시작 - Email/ID: $emailOrId');
      
      // ID를 이메일 형식으로 변환 (@ 없으면 도메인 추가)
      String email = emailOrId;
      if (!emailOrId.contains('@')) {
        email = '$emailOrId@myhouse.com';
      }
      
      // Firebase Authentication으로 로그인 시도
      try {
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
          print('✅ [Firebase] 사용자 인증 성공 (Firebase Auth)');
          return doc.data();
        } else {
          print('⚠️ [Firebase] Firestore에 사용자 정보 없음, 기본값 반환');
          return {
            'id': emailOrId,
            'name': userCredential.user?.displayName ?? emailOrId,
            'email': userCredential.user?.email ?? email,
            'role': 'user',
          };
        }
      } on FirebaseAuthException catch (authError) {
        // Firebase Auth 실패 시, 기존 방식으로 fallback (마이그레이션 기간 동안)
        if (authError.code == 'user-not-found' || authError.code == 'wrong-password') {
          print('⚠️ [Firebase] Auth 실패, 기존 방식으로 fallback 시도');
          
          // 기존 Firestore 방식으로 확인
          final doc = await _firestore.collection(_usersCollectionName).doc(emailOrId).get();
          
          if (doc.exists) {
            final userData = doc.data()!;
            if (userData['password'] == password) {
              print('✅ [Firebase] 사용자 인증 성공 (Fallback - 구버전)');
              print('💡 [Firebase] 힌트: 다음 로그인부터는 Firebase Auth를 사용하려면 회원가입을 다시 해주세요.');
              return userData;
            }
          }
        }
        
        print('❌ [Firebase] 인증 실패 (Auth & Fallback 모두 실패)');
        return null;
      }
    } catch (e) {
      print('❌ [Firebase] 사용자 인증 실패: $e');
      return null;
    }
  }

  // 사용자 조회
  Future<Map<String, dynamic>?> getUser(String id) async {
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

  /// 사용자 등록 (Firebase Authentication 사용)
  /// [id] 사용자 ID (이메일 형식으로 자동 변환)
  /// [password] 비밀번호 (Firebase에서 자동 암호화)
  /// [name] 이름
  /// [email] 실제 이메일 (선택사항, 없으면 id@myhouse.com 사용)
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
      print('🔥 [Firebase] 사용자 등록 시작 - ID: $id');
      
      // 이메일 형식 생성 (실제 이메일이 없으면 id@myhouse.com)
      final authEmail = email ?? '$id@myhouse.com';
      
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
      
      print('✅ [Firebase] 사용자 등록 성공 - UID: $uid');
      return true;
    } on FirebaseAuthException catch (e) {
      print('❌ [Firebase] 등록 오류: ${e.code} - ${e.message}');
      if (e.code == 'email-already-in-use') {
        print('   이미 존재하는 이메일/ID입니다');
      } else if (e.code == 'weak-password') {
        print('   비밀번호가 너무 약합니다');
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
      print('📧 [Firebase] 비밀번호 재설정 이메일 발송 시작');
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ [Firebase] 이메일 발송 성공');
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
    print('👋 [Firebase] 로그아웃 완료');
  }

  // 사용자 이름 업데이트
  Future<bool> updateUserName(String id, String newName) async {
    try {
      print('🔄 [Firebase] 사용자 이름 업데이트 시작 - ID: $id, 새 이름: $newName');
      
      await _firestore.collection(_usersCollectionName).doc(id).update({
        'name': newName,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ [Firebase] 사용자 이름 업데이트 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 사용자 이름 업데이트 실패: $e');
      return false;
    }
  }

  // 모든 사용자 조회
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      print('📊 [Firebase] 모든 사용자 조회 시작');
      
      final querySnapshot = await _firestore.collection(_usersCollectionName).get();
      final users = querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['firestoreId'] = doc.id;
        return data;
      }).toList();
      
      print('✅ [Firebase] 모든 사용자 조회 성공 - ${users.length}명');
      return users;
    } catch (e) {
      print('❌ [Firebase] 모든 사용자 조회 실패: $e');
      return [];
    }
  }

  // Create
  Future<DocumentReference?> addProperty(Property property) async {
    try {
      print('🔥 [Firebase] 부동산 데이터 저장 시작');
      print('🔥 [Firebase] 저장할 데이터: ${property.toMap()}');
      
      final docRef = await _firestore.collection(_collectionName).add(property.toMap());
      
      print('✅ [Firebase] 부동산 데이터 저장 성공 - 문서 ID: ${docRef.id}');
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
          print('📊 [Firebase] 부동산 목록 조회 - ${snapshot.docs.length}개 문서');
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
    try {
      print('📊 [Firebase] 사용자별 부동산 목록 조회 시작 - userId: $userId');
      
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      print('📊 [Firebase] 사용자별 부동산 목록 조회 - ${querySnapshot.docs.length}개 문서');
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
          print('📊 [Firebase] 전체 부동산 목록 조회 - ${snapshot.docs.length}개 문서');
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
      
      print('📊 [Firebase] 전체 부동산 목록 조회 - ${querySnapshot.docs.length}개 문서');
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
      print('🔄 [Firebase] 부동산 데이터 업데이트 시작 - ID: $id');
      
      await _firestore.collection(_collectionName).doc(id).update({
        ...property.toMap(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ [Firebase] 부동산 데이터 업데이트 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 부동산 데이터 업데이트 실패: $e');
      return false;
    }
  }

  // Update - 부분 업데이트
  Future<bool> updatePropertyFields(String id, Map<String, dynamic> fields) async {
    try {
      print('🔄 [Firebase] 부동산 부분 업데이트 시작 - ID: $id');
      print('🔄 [Firebase] 업데이트할 필드: $fields');
      
      await _firestore.collection(_collectionName).doc(id).update({
        ...fields,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ [Firebase] 부동산 부분 업데이트 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 부동산 부분 업데이트 실패: $e');
      return false;
    }
  }

  // Delete
  Future<bool> deleteProperty(String id) async {
    try {
      print('🗑️ [Firebase] 부동산 데이터 삭제 시작 - ID: $id');
      
      await _firestore.collection(_collectionName).doc(id).delete();
      
      print('✅ [Firebase] 부동산 데이터 삭제 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 부동산 데이터 삭제 실패: $e');
      return false;
    }
  }

  // 매물 삭제 (연계 데이터 포함)
  Future<bool> deletePropertyWithRelatedData(String propertyId) async {
    try {
      print('🗑️ [Firebase] 매물 및 연계 데이터 삭제 시작 - ID: $propertyId');
      
      // 1. 해당 매물의 채팅 메시지 삭제
      final chatQuery = await _firestore
          .collection(_chatCollectionName)
          .where('propertyId', isEqualTo: propertyId)
          .get();
      
      for (final doc in chatQuery.docs) {
        await doc.reference.delete();
        print('💬 [Firebase] 채팅 메시지 삭제: ${doc.id}');
      }
      
      // 2. 해당 매물의 방문 신청 삭제
      final visitQuery = await _firestore
          .collection(_visitRequestsCollectionName)
          .where('propertyId', isEqualTo: propertyId)
          .get();
      
      for (final doc in visitQuery.docs) {
        await doc.reference.delete();
        print('📅 [Firebase] 방문 신청 삭제: ${doc.id}');
      }
      
      // 3. 매물 자체 삭제
      await _firestore.collection(_collectionName).doc(propertyId).delete();
      
      print('✅ [Firebase] 매물 및 연계 데이터 삭제 완료');
      return true;
    } catch (e) {
      print('❌ [Firebase] 매물 및 연계 데이터 삭제 실패: $e');
      return false;
    }
  }

  // 특정 매물의 채팅 대화 삭제
  Future<bool> deleteChatConversation(String propertyId) async {
    try {
      print('🗑️ [Firebase] 채팅 대화 삭제 시작 - 매물 ID: $propertyId');
      
      final querySnapshot = await _firestore
          .collection(_chatCollectionName)
          .where('propertyId', isEqualTo: propertyId)
          .get();
      
      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
        print('💬 [Firebase] 채팅 메시지 삭제: ${doc.id}');
      }
      
      print('✅ [Firebase] 채팅 대화 삭제 완료 - ${querySnapshot.docs.length}개 메시지');
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
      print('🔥 [Firebase] 배치 저장 시작 - ${properties.length}개 데이터');
      
      final batch = _firestore.batch();
      final docRefs = <DocumentReference>[];
      
      for (final property in properties) {
        final docRef = _firestore.collection(_collectionName).doc();
        batch.set(docRef, property.toMap());
        docRefs.add(docRef);
      }
      
      await batch.commit();
      
      final ids = docRefs.map((ref) => ref.id).toList();
      print('✅ [Firebase] 배치 저장 성공 - ${ids.length}개 문서');
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
      print('💬 [Firebase] 채팅 메시지 전송 시작');
      print('💬 [Firebase] 메시지: ${message.message}');
      
      final docRef = await _firestore.collection(_chatCollectionName).add(message.toMap());
      
      print('✅ [Firebase] 채팅 메시지 전송 성공 - 문서 ID: ${docRef.id}');
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
          print('💬 [Firebase] 채팅 메시지 조회 - ${snapshot.docs.length}개 메시지');
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
      print('👁️ [Firebase] 메시지 읽음 처리 시작 - ID: $messageId');
      
      await _firestore.collection(_chatCollectionName).doc(messageId).update({
        'isRead': true,
      });
      
      print('✅ [Firebase] 메시지 읽음 처리 성공');
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
      print('🏠 [Firebase] 방문 신청 생성 시작');
      print('🏠 [Firebase] 신청 정보: ${request.toMap()}');
      
      final docRef = await _firestore.collection(_visitRequestsCollectionName).add(request.toMap());
      
      print('✅ [Firebase] 방문 신청 생성 성공 - 문서 ID: ${docRef.id}');
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
          print('🏠 [Firebase] 판매자 방문 신청 조회 - ${snapshot.docs.length}개');
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
          print('🏠 [Firebase] 구매자 방문 신청 조회 - ${snapshot.docs.length}개');
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
      print('🔄 [Firebase] 방문 신청 상태 업데이트 시작 - ID: $requestId, 상태: $status');
      
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
      
      print('✅ [Firebase] 방문 신청 상태 업데이트 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 방문 신청 상태 업데이트 실패: $e');
      return false;
    }
  }

  // 방문 신청 메시지 업데이트
  Future<bool> updateVisitRequestMessage(String requestId, String message) async {
    try {
      print('💬 [Firebase] 방문 신청 메시지 업데이트 시작 - ID: $requestId');
      
      await _firestore.collection(_visitRequestsCollectionName).doc(requestId).update({
        'lastMessage': message,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ [Firebase] 방문 신청 메시지 업데이트 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 방문 신청 메시지 업데이트 실패: $e');
      return false;
    }
  }

  // 방문 신청 삭제
  Future<bool> deleteVisitRequest(String requestId) async {
    try {
      print('🗑️ [Firebase] 방문 신청 삭제 시작 - ID: $requestId');
      
      await _firestore.collection(_visitRequestsCollectionName).doc(requestId).delete();
      
      print('✅ [Firebase] 방문 신청 삭제 성공');
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
      print('🗑️ [Firebase] 모든 매물 및 연계 데이터 삭제 시작');
      
      // 1. 모든 매물 조회
      final propertiesQuery = await _firestore.collection(_collectionName).get();
      final propertyIds = propertiesQuery.docs.map((doc) => doc.id).toList();
      
      print('📊 [Firebase] 삭제할 매물 수: ${propertyIds.length}개');
      
      // 2. 모든 채팅 메시지 삭제
      final chatQuery = await _firestore.collection(_chatCollectionName).get();
      final chatBatch = _firestore.batch();
      for (final doc in chatQuery.docs) {
        chatBatch.delete(doc.reference);
      }
      await chatBatch.commit();
      print('💬 [Firebase] 모든 채팅 메시지 삭제 완료 - ${chatQuery.docs.length}개');
      
      // 3. 모든 방문 신청 삭제
      final visitQuery = await _firestore.collection(_visitRequestsCollectionName).get();
      final visitBatch = _firestore.batch();
      for (final doc in visitQuery.docs) {
        visitBatch.delete(doc.reference);
      }
      await visitBatch.commit();
      print('📅 [Firebase] 모든 방문 신청 삭제 완료 - ${visitQuery.docs.length}개');
      
      // 4. 모든 매물 삭제
      final propertyBatch = _firestore.batch();
      for (final doc in propertiesQuery.docs) {
        propertyBatch.delete(doc.reference);
      }
      await propertyBatch.commit();
      
      print('✅ [Firebase] 모든 매물 및 연계 데이터 삭제 성공');
      print('   - 매물: ${propertiesQuery.docs.length}개');
      print('   - 채팅: ${chatQuery.docs.length}개');
      print('   - 방문신청: ${visitQuery.docs.length}개');
      
      return true;
    } catch (e) {
      print('❌ [Firebase] 모든 매물 및 연계 데이터 삭제 실패: $e');
      return false;
    }
  }

  // 특정 사용자의 모든 매물 삭제
  Future<bool> deleteAllPropertiesByUser(String userName) async {
    try {
      print('🗑️ [Firebase] 사용자 매물 삭제 시작 - 사용자: $userName');
      
      final querySnapshot = await _firestore
          .collection(_collectionName)
          .where('mainContractor', isEqualTo: userName)
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        print('⚠️ [Firebase] 삭제할 매물이 없습니다');
        return true;
      }
      
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [Firebase] 사용자 매물 삭제 성공 - ${querySnapshot.docs.length}개 문서');
      return true;
    } catch (e) {
      print('❌ [Firebase] 사용자 매물 삭제 실패: $e');
      return false;
    }
  }

  // 모든 채팅 메시지 삭제 (관리자용)
  Future<bool> deleteAllChatMessages() async {
    try {
      print('🗑️ [Firebase] 모든 채팅 메시지 삭제 시작');
      
      final querySnapshot = await _firestore.collection(_chatCollectionName).get();
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [Firebase] 모든 채팅 메시지 삭제 성공 - ${querySnapshot.docs.length}개 문서');
      return true;
    } catch (e) {
      print('❌ [Firebase] 모든 채팅 메시지 삭제 실패: $e');
      return false;
    }
  }

  // 모든 방문 신청 삭제 (관리자용)
  Future<bool> deleteAllVisitRequests() async {
    try {
      print('🗑️ [Firebase] 모든 방문 신청 삭제 시작');
      
      final querySnapshot = await _firestore.collection(_visitRequestsCollectionName).get();
      final batch = _firestore.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      print('✅ [Firebase] 모든 방문 신청 삭제 성공 - ${querySnapshot.docs.length}개 문서');
      return true;
    } catch (e) {
      print('❌ [Firebase] 모든 방문 신청 삭제 실패: $e');
      return false;
    }
  }

  // 사용자 자주 가는 위치 업데이트 (firstZone 필드로 저장)
  Future<bool> updateUserFrequentLocation(String userId, String frequentLocation) async {
    try {
      print('📍 [Firebase] 사용자 자주 가는 위치 업데이트 시작 - 사용자: $userId');
      
      await _firestore.collection(_usersCollectionName).doc(userId).update({
        'firstZone': frequentLocation,
        'frequentLocation': frequentLocation, // 기존 필드도 유지
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ [Firebase] 사용자 자주 가는 위치 업데이트 성공 (firstZone: $frequentLocation)');
      return true;
    } catch (e) {
      print('❌ [Firebase] 사용자 자주 가는 위치 업데이트 실패: $e');
      return false;
    }
  }

  // 중개업자 정보 업데이트
  Future<bool> updateUserBrokerInfo(String userId, Map<String, dynamic> brokerInfo) async {
    try {
      print('🏢 [Firebase] 중개업자 정보 업데이트 시작 - 사용자: $userId');
      
      await _firestore.collection(_usersCollectionName).doc(userId).update({
        'brokerInfo': brokerInfo,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      
      print('✅ [Firebase] 중개업자 정보 업데이트 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 중개업자 정보 업데이트 실패: $e');
      return false;
    }
  }

  // 중개업자별 매물 조회 (broker_license_number 기준)
  Future<List<Property>> getPropertiesByBroker(String brokerLicenseNumber) async {
    try {
      print('🏠 [Firebase] 중개업자별 매물 조회 시작 - broker_license_number: $brokerLicenseNumber');
      
      // 모든 매물을 조회해서 brokerInfo.broker_license_number로 필터링
      final allPropertiesSnapshot = await _firestore
          .collection(_collectionName)
          .get();
      
      print('🔍 [Firebase] 전체 매물 수: ${allPropertiesSnapshot.docs.length}');
      
      final matchingProperties = <Property>[];
      
      for (var doc in allPropertiesSnapshot.docs) {
        final data = doc.data();
        final brokerInfo = data['brokerInfo'];
        
        print('🔍 [Firebase] 매물 ID: ${doc.id}');
        print('🔍 [Firebase] brokerInfo: $brokerInfo');
        
        if (brokerInfo != null && brokerInfo['broker_license_number'] == brokerLicenseNumber) {
          print('✅ [Firebase] 매칭된 매물 발견: ${doc.id}');
          data['id'] = doc.id;
          matchingProperties.add(Property.fromMap(data));
        }
      }
      
      print('🔍 [Firebase] broker_license_number=$brokerLicenseNumber로 필터링된 매물 수: ${matchingProperties.length}');
      print('✅ [Firebase] 중개업자별 매물 조회 성공 - ${matchingProperties.length}개 매물');
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
      print('💬 [Firebase] 견적문의 저장 시작');
      final docRef = await _firestore.collection(_quoteRequestsCollectionName).add(quoteRequest.toMap());
      print('✅ [Firebase] 견적문의 저장 성공 - ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ [Firebase] 견적문의 저장 실패: $e');
      return null;
    }
  }

  /// 모든 견적문의 조회 (관리자용)
  Stream<List<QuoteRequest>> getAllQuoteRequests() {
    try {
      print('📊 [Firebase] 모든 견적문의 조회 시작 (Stream)');
      return _firestore
          .collection(_quoteRequestsCollectionName)
          .orderBy('requestDate', descending: true)
          .snapshots()
          .map((snapshot) {
            print('✅ [Firebase] 견적문의 데이터 수신 - ${snapshot.docs.length}개');
            return snapshot.docs
                .map((doc) => QuoteRequest.fromMap(doc.id, doc.data()))
                .toList();
          });
    } catch (e) {
      print('❌ [Firebase] 견적문의 조회 실패: $e');
      return Stream.value([]);
    }
  }

  /// 특정 사용자의 견적문의 조회
  Stream<List<QuoteRequest>> getQuoteRequestsByUser(String userId) {
    try {
      print('📊 [Firebase] 사용자별 견적문의 조회 시작 - userId: $userId');
      return _firestore
          .collection(_quoteRequestsCollectionName)
          .where('userId', isEqualTo: userId)
          .orderBy('requestDate', descending: true)
          .snapshots()
          .map((snapshot) {
            print('✅ [Firebase] 견적문의 데이터 수신 - ${snapshot.docs.length}개');
            return snapshot.docs
                .map((doc) => QuoteRequest.fromMap(doc.id, doc.data()))
                .toList();
          });
    } catch (e) {
      print('❌ [Firebase] 사용자별 견적문의 조회 실패: $e');
      return Stream.value([]);
    }
  }

  /// 견적문의 상태 업데이트
  Future<bool> updateQuoteRequestStatus(String requestId, String newStatus) async {
    try {
      print('🔄 [Firebase] 견적문의 상태 업데이트 시작 - ID: $requestId, 새 상태: $newStatus');
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ [Firebase] 견적문의 상태 업데이트 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 견적문의 상태 업데이트 실패: $e');
      return false;
    }
  }

  /// 공인중개사 이메일 첨부 (관리자용)
  Future<bool> attachEmailToBroker(String requestId, String brokerEmail) async {
    try {
      print('📧 [Firebase] 공인중개사 이메일 첨부 시작 - ID: $requestId');
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).update({
        'brokerEmail': brokerEmail,
        'emailAttachedAt': FieldValue.serverTimestamp(),
        'emailAttachedBy': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ [Firebase] 이메일 첨부 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 이메일 첨부 실패: $e');
      return false;
    }
  }

  /// 견적문의 삭제
  Future<bool> deleteQuoteRequest(String requestId) async {
    try {
      print('🗑️ [Firebase] 견적문의 삭제 시작 - ID: $requestId');
      await _firestore.collection(_quoteRequestsCollectionName).doc(requestId).delete();
      print('✅ [Firebase] 견적문의 삭제 성공');
      return true;
    } catch (e) {
      print('❌ [Firebase] 견적문의 삭제 실패: $e');
      return false;
    }
  }

}
