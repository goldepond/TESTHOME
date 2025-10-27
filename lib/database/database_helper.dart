import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:property/models/property.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    try {
      if (kIsWeb) {
        // 웹 환경에서의 초기화
        var factory = databaseFactoryFfiWeb;
        var db = await factory.openDatabase(
          'property.db',
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: _createDB,
          ),
        );
        print('웹 데이터베이스 초기화 성공');
        return db;
      } else if (identical(0, 0.0)) { // 임시: 데스크톱 환경 분기
        // 데스크톱 환경에서의 초기화
        sqfliteFfiInit();
        var factory = databaseFactoryFfi;
        String path = join(await getDatabasesPath(), 'property.db');
        print('★★★ 실제 사용하는 DB 파일 경로: $path');
        var db = await factory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: 3,
            onCreate: _createDB,
            onUpgrade: _onUpgrade,
          ),
        );
        print('데스크톱 데이터베이스 초기화 성공');
        return db;
      } else {
        // 모바일(Android/iOS) 환경에서의 초기화
        String path = join(await getDatabasesPath(), 'property.db');
        print('★★★ 실제 사용하는 DB 파일 경로: $path');
        var db = await openDatabase(
          path,
          version: 1,
          onCreate: _createDB,
        );
        print('모바일 데이터베이스 초기화 성공');
        return db;
      }
    } catch (e) {
      print('데이터베이스 초기화 중 오류 발생: $e');
      rethrow;
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS properties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL,
        transactionType TEXT NOT NULL,
        price INTEGER NOT NULL,
        description TEXT,
        registerData TEXT,
        registerSummary TEXT,
        contractStatus TEXT DEFAULT '대기',
        mainContractor TEXT DEFAULT '',
        contractor TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    // 사용자 정보 테이블 생성
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        createdAt DATETIME DEFAULT CURRENT_TIMESTAMP,
        updatedAt DATETIME
      )
    ''');

    // 테스트용 더미 JSON 예시
    const dummyRegisterData = '{"result":{"code":"CF-00000","extraMessage":"정상 처리되었습니다."},"data":{"resRegisterEntriesList":[{"resDocTitle":"등기사항증명서(집합건물)","resRealty":"[집합건물] 서울특별시 강남구 테헤란로 123","resPublishNo":"12345-2024-67890","resPublishDate":"2024.03.21","commCompetentRegistryOffice":"서울지방법원 등기과","resRegistrationHisList":[]}]}}';
    const dummyRegisterSummary = '{"header":{"publishNo":"12345-2024-67890","publishDate":"2024.03.21","docTitle":"등기사항증명서(집합건물)","realtyDesc":"[집합건물] 서울특별시 강남구 테헤란로 123","officeName":"서울지방법원 등기과","issueNo":"","uniqueNo":""}}';

    await db.insert('properties', {
      'address': '서울특별시 강남구 테헤란로 123',
      'transactionType': '매매',
      'price': 85000,
      'description': '강남 역세권 신축 아파트',
      'registerData': dummyRegisterData,
      'registerSummary': dummyRegisterSummary,
      'contractStatus': '대기',
      'mainContractor': '김철수'
    });

    await db.insert('properties', {
      'address': '서울특별시 서초구 반포대로 456',
      'transactionType': '매매',
      'price': 95000,
      'description': '반포 한강뷰 아파트',
      'registerData': dummyRegisterData,
      'registerSummary': dummyRegisterSummary,
      'contractStatus': '대기',
      'mainContractor': '김태형'
    });

    await db.insert('properties', {
      'address': '서울특별시 송파구 올림픽로 789',
      'transactionType': '전세',
      'price': 45000,
      'description': '잠실 신축 오피스텔',
      'registerData': dummyRegisterData,
      'registerSummary': dummyRegisterSummary,
      'contractStatus': '진행중',
      'mainContractor': '김태형'
    });

    await db.insert('properties', {
      'address': '경기도 성남시 분당구 정자로 321',
      'transactionType': '매매',
      'price': 72000,
      'description': '분당 신도시 타워팰리스',
      'registerData': dummyRegisterData,
      'registerSummary': dummyRegisterSummary,
      'contractStatus': '완료',
      'mainContractor': '김태형'
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE properties ADD COLUMN registerSummary TEXT;');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE properties ADD COLUMN contractor TEXT;');
    }
  }

  Future<List<Property>> readAll() async {
    final db = await instance.database;
    final result = await db.query('properties', orderBy: 'createdAt DESC');
    return result.map((json) => Property.fromMap(json)).toList();
  }

  Future<int> create(Property property) async {
    final db = await instance.database;
    return db.insert('properties', property.toMap());
  }

  Future<int> update(Property property) async {
    final db = await instance.database;
    return db.update(
      'properties',
      property.toMap(),
      where: 'id = ?',
      whereArgs: [property.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return db.delete(
      'properties',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAll() async {
    final db = await instance.database;
    return db.delete('properties');
  }

  // 사용자 정보 저장
  Future<void> insertUser(Map<String, dynamic> user) async {
    final db = await instance.database;
    await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // 사용자 정보 조회 (id로)
  Future<Map<String, dynamic>?> getUser(String id) async {
    final db = await instance.database;
    final result = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // 사용자 전체 삭제 (테스트용)
  Future<void> deleteAllUsers() async {
    final db = await instance.database;
    await db.delete('users');
  }
} 