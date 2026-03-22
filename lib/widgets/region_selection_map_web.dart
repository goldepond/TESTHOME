// 웹 전용 파일 - 웹 빌드에서만 사용됩니다.
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui;
import 'dart:js_interop';

/// 웹 전용: iframe 생성
web.HTMLIFrameElement createIframeElement() {
  return web.HTMLIFrameElement()
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.border = 'none'
    ..allowFullscreen = true;
}

/// 웹 전용: iframe 설정
void setupIframe(web.HTMLIFrameElement iframe, String htmlContent) {
  iframe.srcdoc = htmlContent.toJS;
}

/// 웹 전용: 플랫폼 뷰 등록
void registerPlatformView(String viewId, web.HTMLIFrameElement iframe) {
  ui.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => iframe as web.Element,  // 명시적으로 web.Element로 캐스팅
  );
}

/// 웹 전용: iframe 찾기
web.HTMLIFrameElement? findMapIframe() {
  final iframes = web.document.querySelectorAll('iframe');
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
        return element;
      }
    }
  }
  return null;
}

/// 웹 전용: iframe에 메시지 전송
void postMessageToIframe(web.HTMLIFrameElement iframe, Map<String, dynamic> message) {
  if (iframe.contentWindow != null) {
    // Map을 JSObject로 변환하여 전송
    final jsMessage = message.jsify() as JSObject;
    iframe.contentWindow!.postMessage(jsMessage, '*'.toJS);
  }
}

