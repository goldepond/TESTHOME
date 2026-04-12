import 'package:flutter/material.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/utils/network_status.dart';
import 'package:property/constants/typography.dart';

/// 오프라인 상태를 표시하는 배너 위젯
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({
    required this.child, super.key,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final NetworkStatus _networkStatus = NetworkStatus();
  bool? _isOnline;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkNetworkStatus();
    // 주기적으로 네트워크 상태 확인
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _checkNetworkStatus();
      }
    });
  }

  Future<void> _checkNetworkStatus() async {
    if (_isChecking) return;
    
    setState(() {
      _isChecking = true;
    });

    final isOnline = await _networkStatus.isOnline(forceCheck: true);
    
    if (mounted) {
      setState(() {
        _isOnline = isOnline;
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 오프라인 배너 (오프라인일 때만 표시)
        if (_isOnline == false)
          Material(
            color: AirbnbColors.orange,
            child: InkWell(
              onTap: _checkNetworkStatus,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off, color: AirbnbColors.background, size: 18),
                    const SizedBox(width: 8),
                      Expanded(
                      child: Text(
                        '인터넷 연결 끊김 - 탭하여 재시도',
                        style: AppTypography.captionLarge.copyWith(color: AirbnbColors.background, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (_isChecking)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AirbnbColors.background),
                        ),
                      )
                    else
                      const Icon(Icons.refresh, color: AirbnbColors.background, size: 18),
                  ],
                ),
              ),
            ),
          ),
        // 메인 콘텐츠 (Expanded로 나머지 공간 차지)
        Expanded(child: widget.child),
      ],
    );
  }
}

