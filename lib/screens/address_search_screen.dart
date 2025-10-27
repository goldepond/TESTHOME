import 'package:flutter/material.dart';

import 'package:property/constants/app_constants.dart';
import 'package:property/api_request/address_service.dart';


class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('검색 시작: $query');
      final result = await AddressService.instance.searchRoadAddress(query, page: 1);

      setState(() {
        _searchResults = result.addresses;
        _errorMessage = result.errorMessage;
        _isLoading = false;
      });

      print('검색 결과 개수: ${_searchResults.length}');
    } catch (e) {
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
      print('오류 발생: $e');
    }
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
                      print('입력값 변경: $value');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    print('검색 버튼 클릭: ${_controller.text}');
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
                      onTap: () {
                        Navigator.pop(context, {
                          'roadAddress': address['roadAddr'],
                          'jibunAddress': address['jibunAddr'],
                          'zipCode': address['zipNo'],
                        });
                      },
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