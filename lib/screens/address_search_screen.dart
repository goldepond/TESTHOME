import 'package:flutter/material.dart';
import 'dart:async';

import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/address_service.dart';


class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // 최소 2글자 이상일 때만 실제 API 호출 (너무 짧은 검색은 에러 안내)
    if (trimmed.length < 2) {
      setState(() {
        _searchResults = [];
        _errorMessage = '도로명, 건물명, 지번 등을 최소 2글자 이상 입력해 주세요.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await AddressService().searchRoadAddress(trimmed, page: 1);

      setState(() {
        _searchResults = result.fullData;
        _errorMessage = result.errorMessage;
        _isLoading = false;
      });
      if (mounted &&
          result.errorMessage == null &&
          result.fullData.length == 1) {
        final singleAddress = result.fullData.first;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _selectAddress(singleAddress);
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  void _selectAddress(Map<String, String> address) {
    Navigator.pop(context, {
      'roadAddress': address['roadAddr'],
      'jibunAddress': address['jibunAddr'],
      'zipCode': address['zipNo'],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '주소를 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.kBrown.withAlpha((0.2 * 255).toInt())),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.kBrown.withAlpha((0.1 * 255).toInt())),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.kBrown, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      // 실시간 자동완성: 2글자 이상 입력 시, 디바운스로 검색
                      _debounce?.cancel();

                      final trimmed = value.trim();
                      if (trimmed.length < 2) {
                        setState(() {
                          _searchResults = [];
                          _errorMessage = null; // 짧은 입력에서는 에러 없이 비우기
                          _isLoading = false;
                        });
                        return;
                      }

                      _debounce = Timer(const Duration(milliseconds: 400), () {
                        _searchAddress(trimmed);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _searchAddress(_controller.text);
                  },
                  child: const Text('검색'),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final address = _searchResults[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: ListTile(
                      title: Text(address['roadAddr'] ?? ''),
                      subtitle: Text(address['jibunAddr'] ?? ''),
                      onTap: () => _selectAddress(address),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
} 