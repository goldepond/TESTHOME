// 웹 전용 파일 - 웹 빌드에서만 사용됩니다.
// ignore: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import 'dart:js_interop';

/// 웹 전용: 메시지 리스너 초기화
dynamic initWebMessageListener(Function(Map<String, dynamic>) onMessage) {
  return web.window.onMessage.listen((event) {
    try {
      // iframe에서 온 메시지인지 확인
      final origin = event.origin;
      final windowOrigin = web.window.location.origin;
      final isFromIframe = origin == windowOrigin || 
                           origin == 'null' || 
                           origin.isEmpty;
      
      if (!isFromIframe) {
        return;
      }
      
      // event.data를 Map으로 변환 시도
      Map<String, dynamic>? dataMap;
      final eventData = event.data;
      
      if (eventData != null) {
        // JSObject인 경우 dartify()를 사용하여 Dart Map으로 변환
        if (eventData.isA<JSObject>()) {
          try {
            final jsObj = eventData as JSObject;
            final dartified = jsObj.dartify();
            if (dartified is Map) {
              dataMap = Map<String, dynamic>.from(dartified);
            }
          } catch (e) {
            // 변환 실패 시 무시
          }
        } else if (eventData.isA<JSString>()) {
          // 문자열인 경우 - 일반적으로 postMessage는 객체를 전달하므로 이 경우는 드뭅니다
          // 필요시 JSON 파싱 구현 가능하지만, 현재는 스킵
        }
      }
      
      if (dataMap != null && dataMap['type'] == 'MAP_LOCATION_CHANGED') {
        onMessage(dataMap);
      }
    } catch (e) {
      // 에러 무시
    }
  });
}

/// 웹 전용: 지도에 메시지 전송
void postMessageToMap(Map<String, dynamic> message) {
  final iframes = web.document.querySelectorAll('iframe');
  web.HTMLIFrameElement? targetIframe;
  
  // NodeList를 리스트로 변환 (item() 메서드 사용)
  final iframeList = <web.HTMLIFrameElement>[];
  for (var i = 0; i < iframes.length; i++) {
    final iframe = iframes.item(i);
    if (iframe != null && iframe.isA<web.HTMLIFrameElement>()) {
      iframeList.add(iframe as web.HTMLIFrameElement);
    }
  }
  
  for (final element in iframeList) {
    final srcdoc = element.srcdoc;
    if (srcdoc.isA<JSString>()) {
      final srcdocStr = (srcdoc as JSString).toDart;
      if (srcdocStr.isNotEmpty) {
        targetIframe = element;
        break;
      }
    }
  }
  
  if (targetIframe != null && targetIframe.contentWindow != null) {
    // Map을 JSObject로 변환하여 전송
    final jsMessage = message.jsify() as JSObject;
    targetIframe.contentWindow!.postMessage(jsMessage, '*'.toJS);
  }
}

