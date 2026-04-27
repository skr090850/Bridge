import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:bridge/Server/server_url.dart';

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  DrawingPath({required this.points, required this.color, required this.strokeWidth});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;
  DrawingPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    for (var pathData in paths) {
      final paint = Paint()
        ..color = pathData.color
        ..strokeWidth = pathData.strokeWidth
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
      final path = Path();
      if (pathData.points.isNotEmpty) {
        path.moveTo(pathData.points.first.dx, pathData.points.first.dy);
        for (var i = 1; i < pathData.points.length; i++) {
          path.lineTo(pathData.points[i].dx, pathData.points[i].dy);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


class DocViewerScreenUsingApi extends StatefulWidget {
  final String fileUrl; // Yeh local file path ya internet URL ho sakta hai
  final String fileName;
  final int userId;
  final int fileId;

  const DocViewerScreenUsingApi({
    super.key,
    required this.fileUrl,
    required this.fileName,
    this.userId = 0,
    this.fileId = 0,
  });

  @override
  State<DocViewerScreenUsingApi> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<DocViewerScreenUsingApi> {
  // --- STATE VARIABLES ---
  bool _isLoading = true;
  String _loadingMessage = 'Viewer taiyaar kiya ja raha hai...';
  String _error = '';
  File? _convertedPdfFile;
  final PdfViewerController _pdfController = PdfViewerController();
  
  // --- FEATURE STATES ---
  bool _isDrawingMode = false;
  bool _isErasing = false;
  final Map<int, List<DrawingPath>> _drawingsByPage = {};
  DrawingPath? _currentPath;
  int _currentPage = 1;
  int _totalPages = 0;
  final Color _drawingColor = Colors.red;
  final double _strokeWidth = 3.0;
  final double _eraserSize = 20.0;
  
  String get _storageKey => 'pdf_page_${widget.fileUrl}';

  // TODO: ------------------ APNI CLOUCONVERT API KEY YAHAN DAALEIN ------------------
  // CloudConvert.com se free API key lekar yahan paste karein.
  final String _cloudConvertApiKey = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxIiwianRpIjoiZTAzMjE1YWEyOTcxMzZiYWI5ODhkYWFmZGM4MzkwYTRiMjRmMmUwOWE5N2Q0ZTg0YzY2ZDE3NzEwZDE2MjkyYTIwNmFmMjM1NDU0YjBkOTMiLCJpYXQiOjE3NTkzMDQ5NzEuMTAwMTU1LCJuYmYiOjE3NTkzMDQ5NzEuMTAwMTU2LCJleHAiOjQ5MTQ5Nzg1NzEuMDk1ODUzLCJzdWIiOiI3MzA2Mjc0MiIsInNjb3BlcyI6WyJ0YXNrLnJlYWQiLCJ0YXNrLndyaXRlIl19.LYGtmbuqPKgesPLTJk00zFfDCgLWWm7ksBDFhVSpvBI_pVAIUoWQaGUkWVQ99zFTrrvZFuG1M9a3UFSQxpxrlMNRfS-VVM7YIRDI1eErk8t96Wd23x_mKDONpSsNagwiHXpGwv7R66V-DNJ7FobHdWe_56b7CZjYBVOr6VJoPHnKN0topDkTP1-YHH1HEREUx5U89qRq2uA-tMWf1ArCVGaB6dcyyH2X1-8BcuoNjA91CQbYubKG8NiYWpxtVhlp6nlYMAD20XaImu1cjl2hOY6GPzqXUrIjccpVSD-_D25gHDFmCcoiHBrbHata_lGHSuOY-5rDE4HJuylDrOXi3mZy8RYCRNjctQYmkmR7NXYSmcRXZAlUUTmGZGowCZF_u4wZbgW9p86TZ8DOZSEtpa_A35w4dto8d6aSmP_bXIRB9QRQgN9PmG8nMcVx8zIGk1lxZQjUWIU2yp3FA5NPCq8Ta0EoOhpqrGWdbLuXLu-SL1YboKDVWPu3Az6UtsvFlSeAxikLpIvpArlHcMNlKNVfk8lJae4L8PhbMyDyQmxTJr5UGhoe1HPwKvoRaaRT1mW2r2btq3CG4YfqV9ilPRqyN4SBgkHcpa6HkUjKipyPUuXnCuL2qhRECnaMdRfR8UfTlEgYn6HIcbG2LE_hv0c-fB-lokCEaeHwxbwi2PQ';
  // ------------------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initiateFileLoad();
  }

  Future<void> _initiateFileLoad() async {
    final bool isPdfByName = p.extension(widget.fileName).toLowerCase() == '.pdf';
    
    if (isPdfByName) {
      debugPrint("[DEBUG] File ka naam .pdf hai. Conversion skip kiya ja raha hai.");
      await _loadDirectPdf();
    } else {
      debugPrint("[DEBUG] File ka naam .pdf nahi hai. Conversion process shuru kiya ja raha hai.");
      await _initiateConversion();
    }
  }
  
  Future<void> _loadDirectPdf() async {
    try {
      final bool isLocalFile = !widget.fileUrl.startsWith('http');
      File pdfFile;

      if (isLocalFile) {
        pdfFile = File(widget.fileUrl);
        if (!await pdfFile.exists()) {
          throw Exception('Local PDF file not found at path: ${widget.fileUrl}');
        }
      } else {
        setState(() => _loadingMessage = 'PDF file download ho rahi hai...');
        final response = await http.get(Uri.parse(widget.fileUrl));
        if (response.statusCode != 200) throw Exception('PDF download fail hua: ${response.reasonPhrase}');
        final tempDir = await getTemporaryDirectory();
        pdfFile = File('${tempDir.path}/${widget.fileName}');
        await pdfFile.writeAsBytes(response.bodyBytes);
      }

      if (mounted) {
        setState(() { _convertedPdfFile = pdfFile; _isLoading = false; });
        _loadProgressFromServer();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'PDF load karne mein error aayi: ${e.toString()}'; _isLoading = false; });
      }
    }
  }

  Future<void> _initiateConversion() async {
    if (_cloudConvertApiKey.contains('YAHAN_APNI')) {
        setState(() { _error = 'CloudConvert API Key code mein nahi daali gayi hai.'; _isLoading = false; });
      return;
    }
    
    try {
      final bool isLocalFile = !widget.fileUrl.startsWith('http');
      File sourceFile;
      String fileDownloadUrl = widget.fileUrl; 

      if (!isLocalFile && fileDownloadUrl.contains('docs.google.com/gview')) {
        debugPrint("[DEBUG] Google Docs Viewer URL detect hua. Asli URL nikal rahe hain...");
        try {
          final uri = Uri.parse(fileDownloadUrl);
          final actualUrl = uri.queryParameters['url'];
          if (actualUrl != null && actualUrl.isNotEmpty) {
            fileDownloadUrl = Uri.decodeComponent(actualUrl);
            debugPrint("[DEBUG] Asli file URL mil gaya: $fileDownloadUrl");
          } else {
            throw Exception('Google Docs URL se asli file URL nahi mil saka.');
          }
        } catch (e) {
            throw Exception('Google Docs URL ko parse karne mein error: ${e.toString()}');
        }
      }

      if (isLocalFile) {
        sourceFile = File(widget.fileUrl); 
        if (!await sourceFile.exists()) {
          throw Exception('Local file not found at path: ${widget.fileUrl}');
        }
      } else {
        setState(() => _loadingMessage = 'File download ho rahi hai...');
        debugPrint("[DEBUG] File is URL se download ho rahi hai: $fileDownloadUrl"); 
        final response = await http.get(Uri.parse(fileDownloadUrl)); 
        if (response.statusCode != 200) throw Exception('File download fail hua: ${response.reasonPhrase}');
        final tempDir = await getTemporaryDirectory();
        sourceFile = File('${tempDir.path}/${widget.fileName}');
        await sourceFile.writeAsBytes(response.bodyBytes);
        debugPrint("[DEBUG] File download ho gayi yahan: ${sourceFile.path}");
      }
      
      final fileBytes = await sourceFile.readAsBytes();
      
      bool isActuallyPdf = fileBytes.length > 4 &&
          fileBytes[0] == 37 &&
          fileBytes[1] == 80 &&
          fileBytes[2] == 68 &&
          fileBytes[3] == 70;

      if (isActuallyPdf) {
        debugPrint("[DEBUG] ROBUST CHECK: Downloaded file asal mein PDF hai! Conversion skip kiya ja raha hai.");
        if (mounted) {
          setState(() {
            _convertedPdfFile = sourceFile; 
            _isLoading = false;
          });
          _loadProgressFromServer();
        }
        return; 
      }
      
      // Aspose ki jagah ab CloudConvert istemal hoga
      final pdfBytes = await _convertFileToPdfCloudConvert(sourceFile);

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${p.basenameWithoutExtension(widget.fileName)}.pdf');
      await tempFile.writeAsBytes(pdfBytes);
      debugPrint("[DEBUG] PDF mein convert ho gayi: ${tempFile.path}");


      if (mounted) {
        setState(() { _convertedPdfFile = tempFile; _isLoading = false; });
        _loadProgressFromServer();
      }
    } catch (e) {
      if (mounted) {
        debugPrint("[DEBUG] ERROR CATCH HUA: ${e.toString()}");
        setState(() { _error = 'Ek error aayi: ${e.toString()}'; _isLoading = false; });
      }
    }
  }
 
  // --- NAYA FUNCTION: Aspose ko hatakar, CloudConvert ka istemal karenge ---
  Future<Uint8List> _convertFileToPdfCloudConvert(File sourceFile) async {
    // --- Step 1: Ek "job" banayein aur file upload karein ---
    setState(() => _loadingMessage = 'File upload ho rahi hai...');
    debugPrint("[CloudConvert] Step 1: Upload job create kar rahe hain...");

    // FIX: Job create karne ke liye MultipartRequest ki jagah normal POST request bhejein
    // Kyunki API yahan par JSON data expect karta hai, form data nahi.
    final jobCreateResponse = await http.post(
      Uri.parse('https://api.cloudconvert.com/v2/jobs'),
      headers: {
        'Authorization': 'Bearer $_cloudConvertApiKey',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'tasks': {
          'import-file': {
            'operation': 'import/upload',
          },
          'convert-file': {
            'operation': 'convert',
            'input': 'import-file',
            'output_format': 'pdf',
          },
          'export-file': {
            'operation': 'export/url',
            'input': 'convert-file',
          }
        }
      }),
    );
    
    if (jobCreateResponse.statusCode != 201) {
      throw Exception('CloudConvert job create fail hua: ${jobCreateResponse.body}');
    }
    
    final jobData = json.decode(jobCreateResponse.body)['data'];
    final uploadUrl = jobData['tasks'][0]['result']['form']['url'];
    final uploadParams = Map<String, String>.from(jobData['tasks'][0]['result']['form']['parameters']);

    // Ab file upload karne ke liye MultipartRequest ka istemal karein.
    var uploadRequest = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    uploadRequest.fields.addAll(uploadParams);
    uploadRequest.files.add(await http.MultipartFile.fromPath('file', sourceFile.path));
    
    var uploadResponse = await uploadRequest.send();
    // Successful upload returns a 2xx status code
    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception('CloudConvert file upload fail hua: ${await uploadResponse.stream.bytesToString()}');
    }
    debugPrint("[CloudConvert] Step 1 SAFAL! File upload ho gayi.");

    // --- Step 2: Conversion ke poora hone ka intezaar karein ---
    setState(() => _loadingMessage = 'File ko PDF mein convert kiya ja raha hai...');
    debugPrint("[CloudConvert] Step 2: Conversion ka intezaar kar rahe hain...");
    String jobStatus = '';
    String jobId = jobData['id'];
    
    while (jobStatus != 'finished') {
      await Future.delayed(const Duration(seconds: 2)); // Har 2 second mein check karein
      final statusResponse = await http.get(
        Uri.parse('https://api.cloudconvert.com/v2/jobs/$jobId'),
        headers: {'Authorization': 'Bearer $_cloudConvertApiKey'},
      );
      final statusData = json.decode(statusResponse.body)['data'];
      jobStatus = statusData['status'];
      debugPrint("[CloudConvert] Job status hai: $jobStatus");
      if(jobStatus == 'error') {
        throw Exception('CloudConvert conversion error: ${statusData['tasks'][0]['message']}');
      }
    }
    debugPrint("[CloudConvert] Step 2 SAFAL! Conversion poora hua.");
    
    // --- Step 3: Converted PDF file download karein ---
    setState(() => _loadingMessage = 'Converted file download ho rahi hai...');
    debugPrint("[CloudConvert] Step 3: PDF download kar rahe hain...");
    final finalJobResponse = await http.get(
        Uri.parse('https://api.cloudconvert.com/v2/jobs/$jobId'),
        headers: {'Authorization': 'Bearer $_cloudConvertApiKey'},
      );
    final finalJobData = json.decode(finalJobResponse.body)['data'];
    final downloadUrl = finalJobData['tasks'].firstWhere((task) => task['name'] == 'export-file')['result']['files'][0]['url'];

    final pdfResponse = await http.get(Uri.parse(downloadUrl));
    debugPrint("[CloudConvert] Step 3 SAFAL! PDF download ho gayi.");
    return pdfResponse.bodyBytes;
  }

  Future<void> _loadProgressFromServer() async {
    int page = 1;
    if (widget.userId != 0 && widget.fileId != 0) {
      try {
        final uri = Uri.parse('${baseUrl}bridge/GetFileReadingStatus?uid=${widget.userId}&fileid=${widget.fileId}');
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true && data['currentPage'] != null) {
            page = (data['currentPage'] as num).toInt();
            debugPrint("[LastVisit] Server se page mila: $page.");
          }
        }
      } catch (e) {
        debugPrint("Server progress fetch failed, trying local: $e");
      }
    }
    
    if (page == 1) page = await _loadLastPageFromLocal();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if(mounted) _pdfController.jumpToPage(page);
    });
  }

  Future<void> _updateProgressOnServer(int page) async {
      if (widget.userId == 0 || widget.fileId == 0) return;
    try {
      await http.post(
        Uri.parse('${baseUrl}Bridge/UpdateFileReadingStatus'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({ 'uid': widget.userId, 'fileId': widget.fileId, 'currentPage': page }),
      );
    } catch (e) {
      debugPrint("Server progress update failed: $e");
    }
  }

  Future<int> _loadLastPageFromLocal() async {
      try {
      final prefs = await SharedPreferences.getInstance();
      final int page = prefs.getInt(_storageKey) ?? 1;
      debugPrint("[LastVisit] Local storage se page mila: $page.");
      return page;
    } catch (e) {
      debugPrint("Error loading local page position: $e");
      return 1;
    }
  }

  Future<void> _saveCurrentPage(int page) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_storageKey, page);
      await _updateProgressOnServer(page);
      debugPrint("[LastVisit] Page $page save kiya gaya.");
  }
  
  void _handlePanStart(DragStartDetails details) {
    if (!_isDrawingMode) return;
    setState(() {
      if (_isErasing) {
        _eraseAtPoint(details.localPosition);
      } else {
        _currentPath = DrawingPath(points: [details.localPosition], color: _drawingColor, strokeWidth: _strokeWidth);
        _drawingsByPage.putIfAbsent(_currentPage, () => []).add(_currentPath!);
      }
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!_isDrawingMode) return;
    setState(() {
      if (_isErasing) {
        _eraseAtPoint(details.localPosition);
      } else if (_currentPath != null) {
        _currentPath!.points.add(details.localPosition);
      }
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!_isDrawingMode || _isErasing) return;
    setState(() { _currentPath = null; });
  }

  void _eraseAtPoint(Offset point) {
    _drawingsByPage[_currentPage]?.removeWhere((path) {
      return path.points.any((p) => (p - point).distance < _eraserSize);
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        elevation: 1,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: _isDrawingMode && !_isErasing ? Colors.blue : null),
            tooltip: 'Draw',
            onPressed: () => setState(() { _isDrawingMode = _isDrawingMode && !_isErasing ? false : true; _isErasing = false; }),
          ),
          IconButton(
            icon: Icon(Icons.cleaning_services, color: _isDrawingMode && _isErasing ? Colors.blue : null),
            tooltip: 'Eraser',
            onPressed: () => setState(() { _isDrawingMode = _isDrawingMode && _isErasing ? false : true; _isErasing = true; }),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsBottomSheet(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(_loadingMessage, style: const TextStyle(fontSize: 16)),
                ],
              ),
            )
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                  ),
                )
              : _convertedPdfFile == null
                  ? const Center(child: Text("Converted PDF file nahi mil saki."))
                  : Stack(
                      children: [
                        SfPdfViewer.file(
                          _convertedPdfFile!,
                          controller: _pdfController,
                          onPageChanged: (details) {
                            setState(() => _currentPage = details.newPageNumber);
                            _saveCurrentPage(_currentPage);
                          },
                          onDocumentLoaded: (details) {
                            setState(() => _totalPages = details.document.pages.count);
                          },
                        ),
                        if (_isDrawingMode)
                          GestureDetector(
                            onPanStart: _handlePanStart,
                            onPanUpdate: _handlePanUpdate,
                            onPanEnd: _handlePanEnd,
                            child: CustomPaint(
                              painter: DrawingPainter(paths: _drawingsByPage[_currentPage] ?? []),
                              child: Container(),
                            ),
                          ),
                      ],
                    ),
      bottomNavigationBar: _totalPages > 0
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('Page $_currentPage of $_totalPages', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              ),
            )
          : null,
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.warning_amber_rounded),
                title: Text('Font Size Not Available'),
                subtitle: Text('Font size cannot be changed for PDF files.'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.screen_rotation),
                title: const Text('Rotate Screen'),
                onTap: () {
                  final o = MediaQuery.of(context).orientation;
                  if (o == Orientation.portrait) {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
                  } else {
                    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:path/path.dart' as p;
// import 'package:path_provider/path_provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// // NOTE: To use this viewer, you need to add the following packages
// // to your pubspec.yaml file:
// //
// // dependencies:
// //   flutter:
// //     sdk: flutter
// //   http: ^1.2.1
// //   syncfusion_flutter_pdfviewer: ^25.1.35
// //   shared_preferences: ^2.2.2
// //   path_provider: ^2.1.2
// //   path: ^1.9.0
// //

// /// Helper classes for the drawing feature
// class DrawingPath {
//   final List<Offset> points;
//   final Color color;
//   final double strokeWidth;
//   DrawingPath({required this.points, required this.color, required this.strokeWidth});
// }

// class DrawingPainter extends CustomPainter {
//   final List<DrawingPath> paths;
//   DrawingPainter({required this.paths});

//   @override
//   void paint(Canvas canvas, Size size) {
//     for (var pathData in paths) {
//       final paint = Paint()
//         ..color = pathData.color
//         ..strokeWidth = pathData.strokeWidth
//         ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
//       final path = Path();
//       if (pathData.points.isNotEmpty) {
//         path.moveTo(pathData.points.first.dx, pathData.points.first.dy);
//         for (var i = 1; i < pathData.points.length; i++) {
//           path.lineTo(pathData.points[i].dx, pathData.points[i].dy);
//         }
//       }
//       canvas.drawPath(path, paint);
//     }
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
// }


// class DocViewerScreen extends StatefulWidget {
//   final String fileUrl;
//   final String fileName;
//   final int userId;
//   final int fileId;

//   const DocViewerScreen({
//     super.key,
//     required this.fileUrl,
//     required this.fileName,
//     this.userId = 0,
//     this.fileId = 0,
//   });

//   @override
//   State<DocViewerScreen> createState() => _DocViewerScreenState();
// }

// class _DocViewerScreenState extends State<DocViewerScreen> {
//   // --- STATE VARIABLES ---
//   bool _isLoading = true;
//   String _error = '';
//   File? _convertedPdfFile;
//   final PdfViewerController _pdfController = PdfViewerController();
//   double _progressValue = 0.0;
//   String _progressText = '0%';
  
//   // --- FEATURE STATES ---
//   bool _isDrawingMode = false;
//   bool _isErasing = false;
//   final Map<int, List<DrawingPath>> _drawingsByPage = {};
//   DrawingPath? _currentPath;
//   int _currentPage = 1;
//   int _totalPages = 0;
//   final Color _drawingColor = Colors.red;
//   final double _strokeWidth = 3.0;
//   final double _eraserSize = 20.0;
  
//   String get _storageKey => 'pdf_page_${widget.fileUrl}';

//   // TODO: ------------------ PASTE YOUR CLOUCONVERT API KEY HERE ------------------
//   // Get your free API key from CloudConvert.com and paste it here.
//   final String _cloudConvertApiKey = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJhdWQiOiIxIiwianRpIjoiZTAzMjE1YWEyOTcxMzZiYWI5ODhkYWFmZGM4MzkwYTRiMjRmMmUwOWE5N2Q0ZTg0YzY2ZDE3NzEwZDE2MjkyYTIwNmFmMjM1NDU0YjBkOTMiLCJpYXQiOjE3NTkzMDQ5NzEuMTAwMTU1LCJuYmYiOjE3NTkzMDQ5NzEuMTAwMTU2LCJleHAiOjQ5MTQ5Nzg1NzEuMDk1ODUzLCJzdWIiOiI3MzA2Mjc0MiIsInNjb3BlcyI6WyJ0YXNrLnJlYWQiLCJ0YXNrLndyaXRlIl19.LYGtmbuqPKgesPLTJk00zFfDCgLWWm7ksBDFhVSpvBI_pVAIUoWQaGUkWVQ99zFTrrvZFuG1M9a3UFSQxpxrlMNRfS-VVM7YIRDI1eErk8t96Wd23x_mKDONpSsNagwiHXpGwv7R66V-DNJ7FobHdWe_56b7CZjYBVOr6VJoPHnKN0topDkTP1-YHH1HEREUx5U89qRq2uA-tMWf1ArCVGaB6dcyyH2X1-8BcuoNjA91CQbYubKG8NiYWpxtVhlp6nlYMAD20XaImu1cjl2hOY6GPzqXUrIjccpVSD-_D25gHDFmCcoiHBrbHata_lGHSuOY-5rDE4HJuylDrOXi3mZy8RYCRNjctQYmkmR7NXYSmcRXZAlUUTmGZGowCZF_u4wZbgW9p86TZ8DOZSEtpa_A35w4dto8d6aSmP_bXIRB9QRQgN9PmG8nMcVx8zIGk1lxZQjUWIU2yp3FA5NPCq8Ta0EoOhpqrGWdbLuXLu-SL1YboKDVWPu3Az6UtsvFlSeAxikLpIvpArlHcMNlKNVfk8lJae4L8PhbMyDyQmxTJr5UGhoe1HPwKvoRaaRT1mW2r2btq3CG4YfqV9ilPRqyN4SBgkHcpa6HkUjKipyPUuXnCuL2qhRECnaMdRfR8UfTlEgYn6HIcbG2LE_hv0c-fB-lokCEaeHwxbwi2PQ';
//   // ------------------------------------------------------------------------------------

//   @override
//   void initState() {
//     super.initState();
//     _initiateFileLoad();
//   }

//   Future<void> _initiateFileLoad() async {
//     final bool isPdfByName = p.extension(widget.fileName).toLowerCase() == '.pdf';
    
//     if (isPdfByName) {
//       await _loadDirectPdf();
//     } else {
//       await _initiateConversion();
//     }
//   }
  
//   Future<void> _loadDirectPdf() async {
//     try {
//       final bool isLocalFile = !widget.fileUrl.startsWith('http');
//       File pdfFile;

//       if (isLocalFile) {
//         pdfFile = File(widget.fileUrl);
//         if (!await pdfFile.exists()) {
//           throw Exception('Local PDF file not found at path: ${widget.fileUrl}');
//         }
//       } else {
//         setState(() { _progressValue = 0.5; _progressText = 'Downloading...'; });
//         final response = await http.get(Uri.parse(widget.fileUrl));
//         if (response.statusCode != 200) throw Exception('PDF download failed: ${response.reasonPhrase}');
//         final tempDir = await getTemporaryDirectory();
//         pdfFile = File('${tempDir.path}/${widget.fileName}');
//         await pdfFile.writeAsBytes(response.bodyBytes);
//       }

//       if (mounted) {
//         setState(() { _convertedPdfFile = pdfFile; _isLoading = false; });
//         _loadProgressFromServer();
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() { _error = 'Error loading PDF file.'; _isLoading = false; });
//       }
//     }
//   }

//   Future<void> _initiateConversion() async {
//     if (_cloudConvertApiKey.contains('YAHAN_APNI_NAYI_API_KEY_PASTE_KAREIN')) {
//         setState(() { _error = 'CloudConvert API Key has not been set in the code.'; _isLoading = false; });
//       return;
//     }
    
//     try {
//       File sourceFile;
//       String fileDownloadUrl = widget.fileUrl; 

//       if (!fileDownloadUrl.startsWith('http')) { // Local file check
//         sourceFile = File(widget.fileUrl); 
//         if (!await sourceFile.exists()) {
//           throw Exception('Local file not found at path: ${widget.fileUrl}');
//         }
//       } else { // Remote file
//          if (fileDownloadUrl.contains('docs.google.com/gview')) {
//           try {
//             final uri = Uri.parse(fileDownloadUrl);
//             final actualUrl = uri.queryParameters['url'];
//             if (actualUrl != null && actualUrl.isNotEmpty) {
//               fileDownloadUrl = Uri.decodeComponent(actualUrl);
//             } else {
//               throw Exception('Could not extract original file URL from Google Docs URL.');
//             }
//           } catch (e) {
//               throw Exception('Error parsing Google Docs URL: ${e.toString()}');
//           }
//         }
        
//         setState(() { _progressValue = 0.1; _progressText = '10%'; });
//         final response = await http.get(Uri.parse(fileDownloadUrl)); 
//         if (response.statusCode != 200) throw Exception('File download failed: ${response.reasonPhrase}');
//         final tempDir = await getTemporaryDirectory();
//         sourceFile = File('${tempDir.path}/${widget.fileName}');
//         await sourceFile.writeAsBytes(response.bodyBytes);
//       }
      
//       final fileBytes = await sourceFile.readAsBytes();
      
//       bool isActuallyPdf = fileBytes.length > 4 &&
//           fileBytes[0] == 37 && fileBytes[1] == 80 &&
//           fileBytes[2] == 68 && fileBytes[3] == 70;

//       if (isActuallyPdf) {
//         if (mounted) {
//           setState(() { _convertedPdfFile = sourceFile; _isLoading = false; });
//           _loadProgressFromServer();
//         }
//         return; 
//       }
      
//       final pdfBytes = await _convertFileToPdfCloudConvert(sourceFile);

//       final tempDir = await getTemporaryDirectory();
//       final tempFile = File('${p.basenameWithoutExtension(widget.fileName)}.pdf');
//       await tempFile.writeAsBytes(pdfBytes);

//       if (mounted) {
//         setState(() { _convertedPdfFile = tempFile; _isLoading = false; });
//         _loadProgressFromServer();
//       }
//     } catch (e) {
//       if (mounted) {
//         String errorMessage = e.toString().toLowerCase();
//         if (errorMessage.contains('daily limit') || errorMessage.contains('payment required')) {
//           setState(() {
//             _error = 'Your daily free conversion limit has been reached. Please try again tomorrow.';
//             _isLoading = false;
//           });
//         } else {
//           setState(() {
//             _error = 'An error occurred while converting the file.';
//             _isLoading = false;
//           });
//         }
//       }
//     }
//   }
 
//   Future<Uint8List> _convertFileToPdfCloudConvert(File sourceFile) async {
//     // --- Step 1: Create a "job" and upload the file ---
//     setState(() { _progressValue = 0.2; _progressText = '20%'; });
//     final jobCreateResponse = await http.post(
//       Uri.parse('https://api.cloudconvert.com/v2/jobs'),
//       headers: {
//         'Authorization': 'Bearer $_cloudConvertApiKey',
//         'Content-Type': 'application/json',
//       },
//       body: json.encode({
//         'tasks': {
//           'import-file': { 'operation': 'import/upload' },
//           'convert-file': { 'operation': 'convert', 'input': 'import-file', 'output_format': 'pdf' },
//           'export-file': { 'operation': 'export/url', 'input': 'convert-file' }
//         }
//       }),
//     );
    
//     if (jobCreateResponse.statusCode != 201) throw Exception(jobCreateResponse.body);
    
//     final jobData = json.decode(jobCreateResponse.body)['data'];
//     final uploadUrl = jobData['tasks'][0]['result']['form']['url'];
//     final uploadParams = Map<String, String>.from(jobData['tasks'][0]['result']['form']['parameters']);

//     var uploadRequest = http.MultipartRequest('POST', Uri.parse(uploadUrl));
//     uploadRequest.fields.addAll(uploadParams);
//     uploadRequest.files.add(await http.MultipartFile.fromPath('file', sourceFile.path));
    
//     var uploadResponse = await uploadRequest.send();
//     if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) throw Exception(await uploadResponse.stream.bytesToString());
    
//     setState(() { _progressValue = 0.4; _progressText = '40%'; });

//     // --- Step 2: Wait for the conversion to complete ---
//     String jobStatus = '';
//     String jobId = jobData['id'];
    
//     while (jobStatus != 'finished') {
//       await Future.delayed(const Duration(seconds: 2));
//       final statusResponse = await http.get(
//         Uri.parse('https://api.cloudconvert.com/v2/jobs/$jobId'),
//         headers: {'Authorization': 'Bearer $_cloudConvertApiKey'},
//       );
//       final statusData = json.decode(statusResponse.body)['data'];
//       jobStatus = statusData['status'];
//       if(jobStatus == 'error') throw Exception(statusData['tasks'][0]['message']);
//     }
    
//     setState(() { _progressValue = 0.9; _progressText = '90%'; });

//     // --- Step 3: Download the converted PDF file ---
//     final finalJobResponse = await http.get(
//         Uri.parse('https://api.cloudconvert.com/v2/jobs/$jobId'),
//         headers: {'Authorization': 'Bearer $_cloudConvertApiKey'},
//       );
//     final finalJobData = json.decode(finalJobResponse.body)['data'];
//     final downloadUrl = finalJobData['tasks'].firstWhere((task) => task['name'] == 'export-file')['result']['files'][0]['url'];

//     final pdfResponse = await http.get(Uri.parse(downloadUrl));
//     setState(() { _progressValue = 1.0; _progressText = '100%'; });
//     return pdfResponse.bodyBytes;
//   }

//   Future<void> _loadProgressFromServer() async {
//     int page = 1;
//     if (widget.userId != 0 && widget.fileId != 0) {
//       try {
//         final uri = Uri.parse('${baseUrl}bridge/GetFileReadingStatus?uid=${widget.userId}&fileid=${widget.fileId}');
//         final response = await http.get(uri);
//         if (response.statusCode == 200) {
//           final data = json.decode(response.body);
//           if (data['status'] == true && data['currentPage'] != null) {
//             page = (data['currentPage'] as num).toInt();
//           }
//         }
//       } catch (e) {
//         // Fail silently
//       }
//     }
    
//     if (page == 1) page = await _loadLastPageFromLocal();
    
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if(mounted) _pdfController.jumpToPage(page);
//     });
//   }

//   Future<void> _updateProgressOnServer(int page) async {
//       if (widget.userId == 0 || widget.fileId == 0) return;
//     try {
//       await http.post(
//         Uri.parse('${baseUrl}Bridge/UpdateFileReadingStatus'),
//         headers: {'Content-Type': 'application/json'},
//         body: json.encode({ 'uid': widget.userId, 'fileId': widget.fileId, 'currentPage': page }),
//       );
//     } catch (e) {
//       // Fail silently
//     }
//   }

//   Future<int> _loadLastPageFromLocal() async {
//       try {
//       final prefs = await SharedPreferences.getInstance();
//       return prefs.getInt(_storageKey) ?? 1;
//     } catch (e) {
//       return 1;
//     }
//   }

//   Future<void> _saveCurrentPage(int page) async {
//       final prefs = await SharedPreferences.getInstance();
//       await prefs.setInt(_storageKey, page);
//       await _updateProgressOnServer(page);
//   }
  
//   void _handlePanStart(DragStartDetails details) {
//     if (!_isDrawingMode) return;
//     setState(() {
//       if (_isErasing) {
//         _eraseAtPoint(details.localPosition);
//       } else {
//         _currentPath = DrawingPath(points: [details.localPosition], color: _drawingColor, strokeWidth: _strokeWidth);
//         _drawingsByPage.putIfAbsent(_currentPage, () => []).add(_currentPath!);
//       }
//     });
//   }

//   void _handlePanUpdate(DragUpdateDetails details) {
//     if (!_isDrawingMode) return;
//     setState(() {
//       if (_isErasing) {
//         _eraseAtPoint(details.localPosition);
//       } else if (_currentPath != null) {
//         _currentPath!.points.add(details.localPosition);
//       }
//     });
//   }

//   void _handlePanEnd(DragEndDetails details) {
//     if (!_isDrawingMode || _isErasing) return;
//     setState(() { _currentPath = null; });
//   }

//   void _eraseAtPoint(Offset point) {
//     _drawingsByPage[_currentPage]?.removeWhere((path) {
//       return path.points.any((p) => (p - point).distance < _eraserSize);
//     });
//   }

//   @override
//   void dispose() {
//     SystemChrome.setPreferredOrientations(DeviceOrientation.values);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.fileName),
//         elevation: 1,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.edit, color: _isDrawingMode && !_isErasing ? Colors.blue : null),
//             tooltip: 'Draw',
//             onPressed: () => setState(() { _isDrawingMode = _isDrawingMode && !_isErasing ? false : true; _isErasing = false; }),
//           ),
//           IconButton(
//             icon: Icon(Icons.cleaning_services, color: _isDrawingMode && _isErasing ? Colors.blue : null),
//             tooltip: 'Eraser',
//             onPressed: () => setState(() { _isDrawingMode = _isDrawingMode && _isErasing ? false : true; _isErasing = true; }),
//           ),
//           IconButton(
//             icon: const Icon(Icons.settings),
//             onPressed: () => _showSettingsBottomSheet(context),
//           ),
//         ],
//       ),
//       body: _isLoading
//           ? Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(32.0),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     LinearProgressIndicator(
//                       value: _progressValue,
//                       minHeight: 10,
//                       borderRadius: BorderRadius.circular(5),
//                       backgroundColor: Colors.grey[300],
//                       valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
//                     ),
//                     const SizedBox(height: 20),
//                     Text(
//                       'Processing... $_progressText',
//                       style: const TextStyle(fontSize: 16)
//                     ),
//                   ],
//                 ),
//               ),
//             )
//           : _error.isNotEmpty
//               ? Center(
//                   child: Padding(
//                     padding: const EdgeInsets.all(16.0),
//                     child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
//                   ),
//                 )
//               : _convertedPdfFile == null
//                   ? const Center(child: Text("Could not prepare the file."))
//                   : Stack(
//                       children: [
//                         SfPdfViewer.file(
//                           _convertedPdfFile!,
//                           controller: _pdfController,
//                           onPageChanged: (details) {
//                             setState(() => _currentPage = details.newPageNumber);
//                             _saveCurrentPage(_currentPage);
//                           },
//                           onDocumentLoaded: (details) {
//                             setState(() => _totalPages = details.document.pages.count);
//                           },
//                         ),
//                         if (_isDrawingMode)
//                           GestureDetector(
//                             onPanStart: _handlePanStart,
//                             onPanUpdate: _handlePanUpdate,
//                             onPanEnd: _handlePanEnd,
//                             child: CustomPaint(
//                               painter: DrawingPainter(paths: _drawingsByPage[_currentPage] ?? []),
//                               child: Container(),
//                             ),
//                           ),
//                       ],
//                     ),
//       bottomNavigationBar: _totalPages > 0
//           ? BottomAppBar(
//               child: Padding(
//                 padding: const EdgeInsets.all(8.0),
//                 child: Text('Page $_currentPage of $_totalPages', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
//               ),
//             )
//           : null,
//     );
//   }

//   void _showSettingsBottomSheet(BuildContext context) {
//     showModalBottomSheet(
//       context: context,
//       builder: (BuildContext bc) {
//         return Container(
//           padding: const EdgeInsets.all(16.0),
//           child: Wrap(
//             children: <Widget>[
//               const ListTile(
//                 leading: Icon(Icons.warning_amber_rounded),
//                 title: Text('Font Size Not Available'),
//                 subtitle: Text('Font size cannot be changed for PDF files.'),
//               ),
//               const Divider(),
//               ListTile(
//                 leading: const Icon(Icons.screen_rotation),
//                 title: const Text('Rotate Screen'),
//                 onTap: () {
//                   final o = MediaQuery.of(context).orientation;
//                   if (o == Orientation.portrait) {
//                     SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
//                   } else {
//                     SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
//                   }
//                   Navigator.pop(context);
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }

