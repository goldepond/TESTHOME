import 'package:flutter/material.dart';
// import 'package:flutter_pdfview/flutter_pdfview.dart';  // 임시로 주석 처리
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PdfViewScreen extends StatefulWidget {
  final String assetPath;
  const PdfViewScreen({Key? key, required this.assetPath}) : super(key: key);

  @override
  State<PdfViewScreen> createState() => _PdfViewScreenState();
}

class _PdfViewScreenState extends State<PdfViewScreen> {
  String? localPath;

  @override
  void initState() {
    super.initState();
    preparePdf();
  }

  Future<void> preparePdf() async {
    final bytes = await rootBundle.load(widget.assetPath);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/temp.pdf');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    setState(() {
      localPath = file.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('계약서 PDF 미리보기')),
      body: localPath == null
          ? Center(child: CircularProgressIndicator())
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('PDF 파일이 준비되었습니다'),
                  SizedBox(height: 8),
                  Text('경로: $localPath', style: TextStyle(fontSize: 12)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // PDF 뷰어 기능은 나중에 구현
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF 뷰어 기능은 현재 비활성화되어 있습니다')),
                      );
                    },
                    child: Text('PDF 보기 (임시)'),
                  ),
                ],
              ),
            ),
    );
  }
} 