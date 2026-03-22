// 웹 전용 파일 - 웹 빌드에서만 사용됩니다.
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui;
import 'dart:js_interop';

/// 웹 전용: iframe 생성
web.HTMLIFrameElement createBrokerMapIframe() {
  return web.HTMLIFrameElement()
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.border = 'none'
    ..allowFullscreen = true;
}

/// 웹 전용: iframe 설정
void setupBrokerMapIframe(web.HTMLIFrameElement iframe, String htmlContent) {
  iframe.srcdoc = htmlContent.toJS;
}

/// 웹 전용: 플랫폼 뷰 등록
void registerBrokerMapView(String viewId, web.HTMLIFrameElement iframe) {
  ui.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewId) => iframe as web.Element,
  );
}

/// 웹 전용: iframe 찾기 (viewId 기반)
web.HTMLIFrameElement? findBrokerMapIframe(String viewId) {
  final iframes = web.document.querySelectorAll('iframe');
  for (var i = 0; i < iframes.length; i++) {
    final iframe = iframes.item(i);
    if (iframe != null && iframe.isA<web.HTMLIFrameElement>()) {
      return iframe as web.HTMLIFrameElement;
    }
  }
  return null;
}

/// 웹 전용: iframe에 메시지 전송
void postMessageToBrokerMap(web.HTMLIFrameElement iframe, Map<String, dynamic> message) {
  final jsMessage = message.jsify();
  iframe.contentWindow?.postMessage(jsMessage, '*'.toJS);
}
