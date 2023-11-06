import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:intl/intl.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart' as imgPicker;
import 'package:image/image.dart' as img;

class DashboardScreen extends StatefulWidget {
  final String inputText;
  DashboardScreen({required this.inputText});

  @override
  _DashBoardScreenState createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<DashboardScreen> {
  File? _image;
  double _rotationAngle = 0;
  Alignment _imageAlignment = Alignment.bottomLeft;
  final GlobalKey _globalKey = GlobalKey();  // RepaintBoundary 키 추가


  List<TextEditingController> _controllers = List.generate(
    10,
        (index) => TextEditingController(),
  );

  List<FocusNode> _focusNodes = List.generate(10, (index) => FocusNode());
  String _suggestedText = '';

  Map<String, List<String>> _keywordsMap = {
    'KeywordField2' : [],
    'KeywordField4' : [],
    'KeywordField6' : [],
    'KeywordField8' : [],
    'KeywordField10' : []
  };

  @override
  void initState() {
    super.initState();
    _loadValues();
    _loadKeywordsMap();

    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          // 여기서 _suggestedText 값을 변경하고 setState()를 호출하여 화면을 갱신합니다.
          _suggestedText = 'Field ${i + 1}'; // 예시로 임의의 텍스트를 설정했습니다.

          print("포커싱 텍스트필드: ${_suggestedText}");
          setState(() {});
        }else{
          String newKeyword = _controllers[i].text;
          _addKeywordsMap('KeywordField${i}', newKeyword);
        }
      });
    }
  }
  _loadKeywordsMap() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('keywordsMap');
    if (jsonString != null) {
      Map<String, dynamic> map = json.decode(jsonString);
      map.forEach((key, value) {
        _keywordsMap[key] = List<String>.from(value);
      });
      setState(() {});
    }
  }


  _addKeywordsMap(String KeywordField, String newKeyword) async {
    List<String>? keywords = _keywordsMap[KeywordField];

    if(keywords == null){
      keywords = <String>[];
    }

    if(!keywords.contains(newKeyword)){
      keywords.add(newKeyword);
      if (keywords.length > 5) {
        keywords.removeAt(0);  // 요소가 5개를 넘으면 가장 오래된 요소 삭제
      }
      _keywordsMap[KeywordField] = keywords;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String jsonString = json.encode(_keywordsMap);
      prefs.setString('keywordsMap', jsonString);
      setState(() {});
    }
  }

  Future<void> _saveImageWithTable() async {
    print('Image saved');
    RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    Uint8List pngBytes = byteData!.buffer.asUint8List();

    final directory = (await getApplicationDocumentsDirectory()).path;
    // Adding timestamp to the file name
    String fileName = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    File imgFile = File('$directory/screenshot_$fileName.png');
    imgFile.writeAsBytes(pngBytes);

    GallerySaver.saveImage(imgFile.path, albumName: widget.inputText).then((bool? success) {
      print('Image with table saved to gallery: ${imgFile.path}');
      if (success!) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('파일이 성공적으로 저장되었습니다.'),
          duration: Duration(seconds: 2),
        ));
      }
    });
  }


  Future<void> _loadValues() async {
    for (int i = 0; i < _controllers.length; i++) {
      String value = await _loadValue(i);
      if (value.isEmpty) {
        switch (i) {
          case 0:
            value = '위치';
            break;
          case 2:
            value = '분류';
            break;
          case 4:
            value = '상세위치';
            break;
          case 6:
            value = '하자내용';
            break;
          case 8:
            value = '비고';
            break;
          default:
            value = '';
        }
      }
      _controllers[i].text = value;
    }

    setState(() {});
  }

  Future<void> _saveValue(int index, String value) async { // SharedPreferences에 값 저장하는 함수
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('input$index', value);
  }

  Future<String> _loadValue(int index) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('input$index') ?? '';
  }

  Future getImage() async {
    final image = await ImagePicker().pickImage(source: imgPicker.ImageSource.camera);

    setState(() {
      if (image != null) {
        _image = File(image.path);
      } else {
        print('No image selected.');
      }
    });
  }

  Future getImageFromGallery() async {
    final image = await ImagePicker().pickImage(source: imgPicker.ImageSource.gallery);

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





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.inputText}',
            style: TextStyle(color: Colors.black)),
        elevation: 0,
        centerTitle: true,
        backgroundColor: Color(0xFFFAFAFA),
        bottom: PreferredSize(
          child: Container(
            color: Colors.grey[300],  // 경계선의 색상을 설정합니다.
            height: 0.5,  // 경계선의 높이를 설정합니다.
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
                        child: TextField(
                          controller: _controllers[index * 2],
                          onChanged: (value) {
                            _saveValue(index * 2, value);
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            contentPadding:
                            EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                            // hintText: 'Input ${index * 2 + 1}',
                            border: OutlineInputBorder(),
                          ),
                          style: TextStyle(fontSize: 10),
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
                            focusNode: _focusNodes[index * 2 + 1],
                            onChanged: (value){
                              // _saveValue(index * 2 + 1, value);
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              contentPadding:
                              EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                              // hintText: 'Input ${index * 2 + 2}',
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 10),
                          ),
                          suggestionsCallback: (pattern) async {
                            // TODO: 여기에 실제로 제안을 가져오는 로직을 추가
                            List<String> keywords = _keywordsMap['KeywordField${index * 2 + 1}'] ?? <String>[];

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
                            _controllers[index * 2 + 1].text = suggestion.toString();
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
                        flex:1,
                        child: IconButton(
                          icon: Icon(Icons.arrow_drop_down_circle_outlined),
                          onPressed: (){

                          },
                        )
                    )
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
                onPressed: (){
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
                onPressed: () {
                },
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
                onPressed: () {
                  _saveImageWithTable();
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
                  Container(
                    color: Colors.white.withOpacity(1),
                    child: DataTable(
                      columnSpacing: 8,
                      dataRowHeight: 20,
                      headingRowHeight: 0,
                      columns: const <DataColumn>[
                        DataColumn(
                          label: Text('Input Number'),
                        ),
                        DataColumn(
                          label: Text('Value'),
                        ),
                      ],
                      rows: List<DataRow>.generate(
                        5,
                            (index) => DataRow(
                          cells: <DataCell>[
                            DataCell(
                              Container(
                                alignment: Alignment.centerLeft,
                                child: Text(_controllers[index * 2].text),
                              ),
                            ),
                            DataCell(
                              Container(
                                alignment: Alignment.centerLeft,
                                child: Text(_controllers[index * 2 + 1].text),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )

        ],
      ),
    );
  }
}