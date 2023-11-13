import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:outsourcing/keyword_setting_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart' as imgPicker;
import 'package:excel/excel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';


class DashboardScreen extends StatefulWidget {
  final String inputText;
  String imageAndExcelFilename = "";

  DashboardScreen({required this.inputText});

  @override
  _DashBoardScreenState createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<DashboardScreen> {
  File? _image;
  double _rotationAngle = 0;
  Alignment _imageAlignment = Alignment.bottomLeft;
  final GlobalKey _globalKey = GlobalKey(); // RepaintBoundary 키 추가

  List<TextEditingController> _controllers = List.generate(
    10,
    (index) => TextEditingController(),
  );

  String _suggestedText = '';

  Map<String, List<String>> _keywordsMap = {
    '위치': [],
    '분류': [],
    '상세위치': [],
    '하자내용': [],
    '비고': []
  };


  @override
  void initState() {
    super.initState();
    _loadValues();
    _loadKeywordsMap();
  }



  Future<void> createFolderAndSaveExcel() async {
    // 권한 확인 및 요청
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }


    // 엑셀 파일 생성 및 데이터 쓰기
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Sheet1'];
    sheetObject.cell(CellIndex.indexByString("A1")).value = "Example Data"; // 예시 데이터
    // ... 데이터 추가 작업 ...

    // 엑셀 파일 저장
    String fileName = "${widget.imageAndExcelFilename}.xlsx"; // 파일 이름
    String filePath = path.join('/storage/emulated/0/prj_${widget.inputText }', fileName);
    File file = File(filePath);

    // 파일에 엑셀 내용 쓰기
    List<int>? excelBytes = excel.save();
    if (excelBytes != null) {
      await file.writeAsBytes(excelBytes);
    } else {
      // 적절한 예외 처리
      print('Unable to save excel file because the byte data is null.');
    }


    print("File saved at $filePath");
  }


  void saveExcel() async {
    // 권한 요청
    var status = await Permission.storage.request();
    if (status.isGranted) {
      // 외부 저장소 경로 얻기
      final directory = (await getExternalStorageDirectory())?.path;
      String filePath = '$directory/${widget.inputText}'; // 원하는 폴더명 지정
      final file = File('$filePath/my_excel_file.xlsx');

      // 폴더가 없다면 생성
      if (!await Directory(filePath).exists()) {
        await Directory(filePath).create(recursive: true);
      }

      // 엑셀 파일 데이터
      var bytes = <int>[]; // 엑셀 파일의 바이트 데이터를 여기에 넣으세요.

      // 파일 저장
      await file.writeAsBytes(bytes, flush: true);
      print('파일이 저장되었습니다: $filePath/my_excel_file.xlsx');
    } else {
      print('저장 권한이 거부되었습니다.');
    }
  }



  _loadKeywordsMap() async {
    print("_loadKeywordsMap()");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('keywordsMap');
    if (jsonString != null) {
      Map<String, dynamic> map = json.decode(jsonString);
      map.forEach((key, value) {
        _keywordsMap[key] = List<String>.from(value);
      });
      setState(() {});

      print("_loadKeywordsMap() ${jsonString}");
      print("_loadKeywordsMap() ${map.toString()}");
      print("_loadKeywordsMap() ${_keywordsMap}");
    }else{
      String jsonString = json.encode(_keywordsMap);
      prefs.setString('keywordsMap', jsonString);
      print("keywordsMap 존재하지 않아 새로 저장: ${jsonString}");
    }

  }

  // Future<void> _saveImageWithTable() async {
  //   print('Image saved');
  //   RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  //   ui.Image image = await boundary.toImage(pixelRatio: 3.0);
  //   ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  //   Uint8List pngBytes = byteData!.buffer.asUint8List();
  //
  //   final directoryPath = (await getApplicationDocumentsDirectory()).path;
  //   String baseFileName = '${_controllers[1].text}';
  //   String fileName = baseFileName;
  //
  //   // 파일이 존재하는지 확인하고 접미사 추가
  //   int count = 0;
  //   while (File('$directoryPath/$fileName.png').existsSync()) {
  //     count++;
  //     fileName = '${baseFileName}_$count';
  //   }
  //   widget.imageAndExcelFilename = fileName;
  //
  //   File imgFile = File('$directoryPath/$fileName.png');
  //   await imgFile.writeAsBytes(pngBytes);
  //
  //   GallerySaver.saveImage(imgFile.path, albumName: 'prj_${widget.inputText}')
  //       .then((bool? success) {
  //     print('Image with table saved to gallery: ${imgFile.path}');
  //     if (success!) {
  //       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
  //         content: Text('파일이 성공적으로 저장되었습니다.'),
  //         duration: Duration(seconds: 2),
  //       ));
  //     } else {
  //       print('이미지 저장에 실패했습니다.');
  //     }
  //   });
  //
  //   createFolderAndSaveExcel();
  // }



  Future<void> saveTextDataAsJson() async {
    // 텍스트 데이터 수집
    Map<String, dynamic> textData = {
      '위치': _controllers[1].text,
      '분류': _controllers[3].text,
      '상세위치': _controllers[5].text,
      '하자내용': _controllers[7].text,
      '비고': _controllers[9].text,
    };

    // JSON 형식으로 변환
    String jsonTextData = jsonEncode(textData);

    // JSON 파일 경로 생성 (이미지와 동일한 이름 사용)
    String jsonFilePath = '/storage/emulated/0/Documents/PicPlotter/${widget.inputText}/${widget.imageAndExcelFilename}.json';


    // JSON 파일 저장
    File(jsonFilePath).writeAsString(jsonTextData);
    print('텍스트 데이터가 JSON 파일로 저장되었습니다: $jsonFilePath');
  }

  Future<void> _saveImageAndTextData() async {
    // 이미지 캡처 및 저장 로직
    RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();


    final directoryPath = (await getApplicationDocumentsDirectory()).path;
    String baseFileName = '${_controllers[1].text}';
    String fileName = baseFileName;

    // 파일이 존재하는지 확인하고 접미사 추가
    int count = 0;
    while (File('$directoryPath/$fileName.png').existsSync()) {
      count++;
      fileName = '${baseFileName}_$count';
    }
    widget.imageAndExcelFilename = fileName;

    File imgFile = File('$directoryPath/$fileName.png');
    await imgFile.writeAsBytes(pngBytes);

    GallerySaver.saveImage(imgFile.path, albumName: 'prj_${widget.inputText}')
        .then((bool? success) {
      print('Image with table saved to gallery: ${imgFile.path}');
      if (success!) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('파일이 성공적으로 저장되었습니다.'),
          duration: Duration(seconds: 2),
        ));
      } else {
        print('이미지 저장에 실패했습니다.');
      }
    });

    // 이미지와 관련된 텍스트 데이터를 JSON 파일로 저장
    await saveTextDataAsJson();
  }

  Future<String> _getStackedImageName(String fileName) async {
    // 동일 이름 카운트 함수

    final directoryPath = (await getApplicationDocumentsDirectory()).path;

    // 파일이 존재하는지 확인하고 접미사 추가
    int count = 0;
    while (File('$directoryPath/$fileName.png').existsSync()) {
      count++;
      fileName = '${fileName}_$count';
    }

    return fileName;
  }

  Future<void> _saveImageAndJson() async {
  }

  Future<void> saveImage(String imageName) async {
    if (_image == null) {
      print('이미지가 선택되지 않았습니다.');
      return;
    }

    // 새로운 이미지 파일명 생성
    String stackedImageName = await _getStackedImageName(imageName);

    // 저장할 경로 설정
    final directoryPath = (await getApplicationDocumentsDirectory()).path;
    String newImagePath = '$directoryPath/$stackedImageName.png';

    
    // 원본 이미지 파일을 새로운 이름으로 복사
    File newImageFile = await _image!.copy(newImagePath);

    // GallerySaver를 사용하여 새로운 이미지 파일 저장
    GallerySaver.saveImage(newImageFile.path, albumName: 'prj_${widget.inputText}').then((bool? success) {
      if (success != null && success) {
        print('이미지가 갤러리에 저장되었습니다: $newImagePath');
      } else {
        print('갤러리에 이미지 저장 실패');
      }
    });
  }





  Future<void> _loadValues() async {
    final prefs = await SharedPreferences.getInstance();

    for (int i = 0; i < _controllers.length; i++) {
      String value = '';

      switch (i) {
        case 0:
          value = '위치';
          break;
        case 1:
          value = prefs.getString('위치') ?? ''; // SharedPreferences에서 값을 가져올 때, 값이 null이면 빈 문자열을 대신 사용합니다.
          break;
        case 2:
          value = '분류';
          break;
        case 3:
          value = prefs.getString('분류') ?? '';
          break;
        case 4:
          value = '상세위치';
          break;
        case 5:
          value = prefs.getString('상세위치') ?? '';
          break;
        case 6:
          value = '하자내용';
          break;
        case 7:
          value = prefs.getString('하자내용') ?? '';
          break;
        case 8:
          value = '비고';
          break;
        case 9:
          value = prefs.getString('비고') ?? '';
          break;
        default:
          value = '';
      }
      _controllers[i].text = value;
    }

    setState(() {});
  }






  Future getImage() async {
    final image =
        await ImagePicker().pickImage(source: imgPicker.ImageSource.camera);

    setState(() {
      if (image != null) {
        _image = File(image.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future getImageFromGallery() async {
    final image =
        await ImagePicker().pickImage(source: imgPicker.ImageSource.gallery);

    setState(() {
      if (image != null) {
        _image = File(image.path);
      } else {
        print('No image selected.');
      }
    });
  }

  void _rotateImage() {
    setState(() {
      _rotationAngle += 90;
      if (_rotationAngle >= 360) {
        _rotationAngle = 0;
      }
    });
  }

  String _generateHtml() {
    String htmlContent =
        '<table border="0.3" style="background-color: white;" cellspacing="0">';

    for (int i = 0; i < _controllers.length; i += 2) {
      htmlContent += '''
      <tr>
        <td>${_controllers[i].text}</td>
        <td>${_controllers[i + 1].text}</td>
      </tr>
      ''';
    }

    htmlContent += "</table>";
    return htmlContent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.black),
        title:
            Text('${widget.inputText}', style: TextStyle(color: Colors.black)),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFFFAFAFA),
        bottom: PreferredSize(
          child: Container(
            color: Colors.grey[300], // 경계선의 색상을 설정합니다.
            height: 0.5, // 경계선의 높이를 설정합니다.
          ),
          preferredSize: Size.fromHeight(0.5),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (context, index) => Container(
                height: 37,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 30, // Set the height of the TextField
                        child: ElevatedButton(
                          onPressed: () async {
                            print("ElevatedButton was clicked");
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => KeywordSettingScreen(
                                      settingMenu: _controllers[index * 2]
                                          .text), // 텍스트 필드의 값을 다음 화면으로 전달
                                ));
                            await _loadKeywordsMap();
                            await _loadValues();

                          },
                          child: Text(
                            '${_controllers[index * 2].text}',
                            style: TextStyle(color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 10),
                              side: BorderSide(
                                color: Colors.black,
                              ),
                              backgroundColor: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.0),
                    Expanded(
                      flex: 7,
                      child: Container(
                        height: 30, // Set the height of the TextField
                        child: TypeAheadFormField(
                          textFieldConfiguration: TextFieldConfiguration(
                            controller: _controllers[index * 2 + 1],
                            onChanged: (value) {
                              print("map: ${_keywordsMap}");
                              // _saveValue(index * 2 + 1, value);
                              setState(() {
                                print("map: ${_keywordsMap}");
                                print("${index}의 밸류값: ${value}");
                              });
                            },
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 10),
                              // hintText: 'Input ${index * 2 + 2}',
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 10),
                          ),
                          suggestionsCallback: (pattern) async {
                            // TODO: 여기에 실제로 제안을 가져오는 로직을 추가
                            List<String> keywords =
                                _keywordsMap['KeywordField${index * 2 + 1}'] ?? <String>[];

                            print('키워드 필드 확인: KeywordField${index * 2 + 1}');
                            print('키워드 리스트 확인: ${keywords.toString()}');
                            return keywords;
                          },
                          itemBuilder: (context, suggestion) {
                            return ListTile(
                              title: Text(suggestion.toString()),
                            );
                          },
                          onSuggestionSelected: (suggestion) {
                            _controllers[index * 2 + 1].text =
                                suggestion.toString();
                            setState(() {});
                          },
                          validator: (value) {
                            if (value!.isEmpty) {
                              return 'Please input the data';
                            }
                            return null;
                          },
                          onSaved: (value) => print('Value saved: $value'),
                        ),
                      ),
                    ),
                    Expanded(
                        flex: 1,
                        child: IconButton(
                          icon: Icon(Icons.arrow_drop_down_circle_outlined),
                          onPressed: () {},
                        ))
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.camera),
                onPressed: () {
                  getImage();
                  print('Camera icon pressed');
                },
              ),
              IconButton(
                icon: Icon(Icons.photo_album),
                onPressed: () {
                  getImageFromGallery();
                  print('Star icon pressedd');
                },
              ),
              IconButton(
                icon: Icon(Icons.settings),
                onPressed: () {},
              ),
              IconButton(
                icon: Icon(Icons.rotate_right),
                onPressed: () {
                  // _rotateImage(); 임시로 막아둠
                  print('rotate_right icon pressedd');
                },
              ),
              IconButton(
                icon: Icon(Icons.check),
                onPressed: () async {
                  saveImage(_controllers[1].text);
                  print('check icon pressedd');
                },
              ),
            ],
          ),
          Expanded(
            flex: 2,
            child: _image == null
                ? Center(child: Text('이미지를 선택해주세요.'))
                : RepaintBoundary(
                    key: _globalKey,
                    child: Stack(
                      alignment: _imageAlignment,
                      children: [
                        Transform.rotate(
                          angle: _rotationAngle * (3.141592653589793 / 180),
                          child: Image.file(_image!, fit: BoxFit.contain),
                        ),
                        Positioned(
                            left: 0, // 왼쪽 끝으로 이동
                            bottom: 0, // 아래쪽 끝으로 이동
                            child: HtmlWidget(
                              _generateHtml(),
                              key: ValueKey<String>(_generateHtml()),
                              textStyle: TextStyle(fontSize: 7),
                            )),
                      ],
                    ),
                  ),
          )
        ],
      ),
    );
  }
}
