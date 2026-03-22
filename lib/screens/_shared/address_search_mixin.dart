import 'dart:async';
import 'package:flutter/material.dart';
import '../../api_request/address_service.dart';

/// 주소 검색 + debounce 로직 공통 mixin
///
/// `mls_quick_registration_page.dart`, `admin_proxy_registration_page.dart`,
/// `market_price_page.dart` 등 주소 검색 기능이 필요한 State에 적용합니다.
///
/// 사용법:
/// ```dart
/// class _MyPageState extends State<MyPage> with AddressSearchMixin {
///   @override
///   void dispose() {
///     cancelAddressSearch();
///     super.dispose();
///   }
/// }
/// ```
mixin AddressSearchMixin<T extends StatefulWidget> on State<T> {
  Timer? _addressDebounceTimer;

  bool isAddressSearching = false;
  List<Map<String, String>> addressSearchResults = [];
  List<String> addressList = [];
  String? addressErrorMessage;

  static const Duration _kDebounceDelay = Duration(milliseconds: 500);

  /// 입력값이 바뀔 때 호출합니다. debounce 후 실제 검색을 수행합니다.
  void searchAddress(String keyword) {
    _addressDebounceTimer?.cancel();
    if (keyword.trim().isEmpty) {
      setState(() {
        addressSearchResults = [];
        addressList = [];
        addressErrorMessage = null;
        isAddressSearching = false;
      });
      return;
    }
    _addressDebounceTimer = Timer(_kDebounceDelay, () => _performAddressSearch(keyword.trim()));
  }

  /// 검색을 즉시 취소하고 결과를 초기화합니다.
  void cancelAddressSearch() {
    _addressDebounceTimer?.cancel();
    _addressDebounceTimer = null;
  }

  Future<void> _performAddressSearch(String keyword) async {
    if (!mounted) return;
    setState(() {
      isAddressSearching = true;
      addressErrorMessage = null;
    });

    try {
      final result = await AddressService().searchRoadAddress(keyword);
      if (!mounted) return;
      setState(() {
        isAddressSearching = false;
        if (result.addresses.isNotEmpty) {
          addressSearchResults = result.fullData;
          addressList = result.addresses;
          addressErrorMessage = null;
        } else {
          addressSearchResults = [];
          addressList = [];
          addressErrorMessage = '검색 결과가 없습니다';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isAddressSearching = false;
        addressSearchResults = [];
        addressList = [];
        addressErrorMessage = '주소 검색 중 오류가 발생했습니다';
      });
    }
  }
}
