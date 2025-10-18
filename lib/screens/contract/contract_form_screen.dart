import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:webview_flutter/webview_flutter.dart';  // 임시로 주석 처리
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

// 더미 WebView 클래스들 정의
class WebViewController {
  void setJavaScriptMode(dynamic mode) {}
  void setNavigationDelegate(dynamic delegate) {}
  void addJavaScriptChannel(String name, {required Function onMessageReceived}) {}
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {}
  Future<void> runJavaScript(String script) async {}
}

class NavigationDelegate {
  final Function(String)? onPageStarted;
  final Function(String)? onPageFinished;
  
  NavigationDelegate({this.onPageStarted, this.onPageFinished});
}

class JavaScriptMessage {
  final String message;
  JavaScriptMessage(this.message);
}

class WebViewWidget extends StatelessWidget {
  final WebViewController controller;
  
  WebViewWidget({super.key, required this.controller});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Text('WebView 미리보기 (더미 모드)'),
      ),
    );
  }
}

enum JavaScriptMode { unrestricted }

class ContractFormScreen extends StatefulWidget {
  final String contractType;
  final String? htmlAssetPath;
  
  const ContractFormScreen({
    Key? key,
    this.contractType = 'monthly',
    this.htmlAssetPath,
  }) : super(key: key);

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  WebViewController? controller;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() async {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('WebView onPageStarted: $url');
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            print('WebView onPageFinished: $url');
            setState(() {
              isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'saveContract',
        onMessageReceived: (JavaScriptMessage message) {
          _handleSaveContract(message.message);
        },
      );

    // HTML 파일 로드
    await _loadHtmlFile();
    setState(() {}); // controller 초기화 후 build 갱신
  }

  // 모바일 대응: viewport 메타 태그 + 모바일 CSS 강제 삽입 함수 (최신 권장안)
  String patchHtmlForMobile(String html) {
    const viewport = '<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">';
    const mobileCss = '''
    <style>
      body, html { max-width: 100vw; overflow-x: auto; font-size: 15px; word-break: break-all; }
      table { width: 100% !important; max-width: 100vw !important; }
      td, th { font-size: 13px; padding: 2px 4px; }
    </style>
    ''';
    String patched = html;
    if (!patched.contains('viewport')) {
      patched = patched.replaceFirst('<head>', '<head>$viewport');
    }
    if (!patched.contains('max-width: 100vw')) {
      patched = patched.replaceFirst('<head>', '<head>$mobileCss');
    }
    return patched;
  }

  Future<void> _loadHtmlFile() async {
    try {
      final assetPath = widget.htmlAssetPath ?? 'assets/contracts/House_Lease_Agreement/House_Lease_Agreement_1.html';
      print('HTML 파일 로드 시도: $assetPath');
      String htmlContent = await rootBundle.loadString(assetPath);
      // 모바일 대응: viewport 메타 태그 동적 삽입
      htmlContent = patchHtmlForMobile(htmlContent);
      await controller!.loadHtmlString(
        htmlContent,
        baseUrl: assetPath.substring(0, assetPath.lastIndexOf('/') + 1),
      );
      print('HTML 파일 정상 로드 완료');
    } catch (e) {
      print('HTML 파일 로드 오류: $e');
      // 기본 HTML로 대체
      await controller!.loadHtmlString(_getDefaultHtml());
    } finally {
      // 혹시라도 onPageFinished가 호출되지 않으면 강제로 로딩 해제
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && isLoading) {
          print('onPageFinished가 호출되지 않아 강제 로딩 해제');
          setState(() {
            isLoading = false;
          });
        }
      });
    }
  }

  void _handleSaveContract(String contractData) {
    // 계약서 데이터 저장 로직
    print('계약서 데이터 저장: $contractData');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('계약서가 저장되었습니다.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _getDefaultHtml() {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>계약서 로딩 오류</title>
        <style>
            body { 
                font-family: Arial, sans-serif; 
                text-align: center; 
                padding: 50px; 
                color: #666; 
            }
        </style>
    </head>
    <body>
        <h2>계약서 로딩 중 오류가 발생했습니다</h2>
        <p>잠시 후 다시 시도해 주세요.</p>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('계약서 작성'),
          backgroundColor: Colors.blue.shade100,
        ),
        body: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('계약서 미리보기(새 창)'),
            onPressed: () async {
              await launchUrl(
                Uri.parse('/contract_sample.html'),
                webOnlyWindowName: '_blank',
              );
            },
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('계약서 작성'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadHtmlFile(),
            tooltip: '새로고침',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () async {
              if (controller != null) {
                await controller!.runJavaScript('saveContract()');
              }
            },
            tooltip: '저장',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (controller == null)
            const Center(child: CircularProgressIndicator())
          else
            WebViewWidget(controller: controller!),
          if (controller != null && isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('계약서 로딩 중...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 