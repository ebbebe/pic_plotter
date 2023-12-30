import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:outsourcing/entry_screen.dart';
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
import 'package:image/image.dart' as img;
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:exif/exif.dart';

class DashboardScreen extends StatefulWidget {
  final String inputText;
  String imageAndExcelFilename = "";

  DashboardScreen({required this.inputText});

  @override
  _DashBoardScreenState createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<DashboardScreen> {
  File? _image;
  List<File> _images = []; // 여러 이미지 파일을 저장할 리스트
  double _rotationAngle = 0;
  Alignment _imageAlignment = Alignment.bottomLeft;
  final GlobalKey _globalKey = GlobalKey(); // RepaintBoundary 키 추가
  bool _switchSingleMode = false;
  double _imageQuality = 20; // 화질 조정을 위한 변수, 초기값을 50%로 설정

  List<TextEditingController> _controllers = List.generate(
    10,
    (index) => TextEditingController(),
  );

  Map<String, List<String>> _keywordsMap = {
    '공간': [],
    '위치': [],
    '상세': [],
    '분류': [],
    '내용': []
  };

  @override
  void initState() {
    super.initState();
    loadImageQualityPreference();
    _loadAllValues();
    _loadKeywordsMap();
  }

  _loadKeywordsMap() async {
    // 키워드설정 화면에 저장된 키워드들 로드
    print("_loadKeywordsMap()");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('keywordsMap');
    print("jsonString: $jsonString");
    if (jsonString != null) {
      Map<String, dynamic> map = json.decode(jsonString);
      map.forEach((key, value) {
        _keywordsMap[key] = List<String>.from(value);
      });
      setState(() {});
    } else {
      String jsonString = json.encode(_keywordsMap);
      prefs.setString('keywordsMap', jsonString);
      print("keywordsMap 존재하지 않아 새로 저장: ${jsonString}");
    }
  }

  Future<void> saveImagesDataAsJson(List<String> baseFileNames) async {
    //TODO 파일명 제대로 참조하게 바꿀 것
    print('Pic_ saveImagesDataAsJson() baseFileNames 확인: $baseFileNames');

    // JSON 데이터 생성
    Map<String, dynamic> data = {
      '공간': _controllers[1].text,
      '위치': _controllers[3].text,
      '상세': _controllers[5].text,
      '분류': _controllers[7].text,
      '내용': _controllers[9].text,
      '파일명': baseFileNames,
    };

    // JSON 파일 경로 설정 및 저장
    String jsonFilePath =
        '/storage/emulated/0/Documents/PicPlotter/${widget.inputText}/${baseFileNames[0]}.json';
    String jsonTextData = jsonEncode(data);
    await File(jsonFilePath).writeAsString(jsonTextData);
    print('Pic_ 이미지 데이터가 JSON 파일로 저장되었습니다: $jsonFilePath');
  }

  Future<void> saveImageDataAsJpg(File image, String baseFileName) async {
    // EXIF 정보를 확인하고 이미지를 올바른 방향으로 회전
    File rotatedImage = await FlutterExifRotation.rotateAndSaveImage(path: image.path);

    // _image에서 이미지 파일을 불러옵니다.
    img.Image? originalImage = img.decodeImage(rotatedImage!.readAsBytesSync());
    if (originalImage != null) {
      // 해상도를 낮추기 위해 이미지 크기를 조정합니다.
      int newWidth = (originalImage.width * 0.5).round(); // 원래 너비의 50%로 조정
      int newHeight = (originalImage.height * 0.5).round(); // 원래 높이의 50%로 조정
      img.Image resizedImage =
          img.copyResize(originalImage, width: newWidth, height: newHeight);

      // 이미지 화질 처리
      int quality = _imageQuality.round(); // 화질 설정 적용
      // JPG 형식으로 이미지를 변환합니다.
      List<int> jpg = img.encodeJpg(resizedImage, quality: quality); // 품질 조정

      // 변환된 이미지를 저장합니다.
      String tempPath = (await getTemporaryDirectory()).path;
      String newFileName = baseFileName + '.jpg';
      File newFile = File('$tempPath/$newFileName')..writeAsBytesSync(jpg);

      // 변환된 이미지를 갤러리에 저장합니다.
      await GallerySaver.saveImage(newFile.path,
              albumName: 'prj_${widget.inputText}')
          .then((bool? success) {
        if (success != null && success) {
          showMsgToast('이미지가 갤러리에 저장되었습니다.');
          print('Pic_ Image saved to gallery: ${newFile.path}');
        } else {
          showMsgToast('이미지가 저장에 실패하였습니다.');
          print('Pic_ Failed to save image to gallery');
        }
      });

      showMsgToast('이미지가 갤러리에 저장되었습니다.');
      print("Pic_ Image and JSON saved at ${newFile.path}");
    } else {
      print('Pic_ No image selected or failed to load image.');
    }
  }

  Future<String> _getStackedImageName(
      String targetDirPath, String fileName) async {
    // 동일 이름 카운트 함수

    // 파일이 존재하는지 확인하고 접미사 추가
    String stackedFileName = fileName;
    int count = 0;
    while (File('$targetDirPath/$stackedFileName.jpg').existsSync()) {
      print("while문 돌아가는 중");
      count++;
      stackedFileName = '${fileName}_$count';
    }

    return stackedFileName;
  }

  Future<void> _loadValue(String FieldName) async {
    print('_pic _loadValue() 함수 실행');
    final prefs = await SharedPreferences.getInstance();
    String value = '';
    int index = -1;
    switch (FieldName) {
      case '공간':
        index = 1;
        value = prefs.getString('공간') ?? '';
        break;
      case '위치':
        index = 3;
        value = prefs.getString('위치') ?? '';
        break;
      case '상세':
        index = 5;
        value = prefs.getString('상세') ?? '';
        break;
      case '분류':
        index = 7;
        value = prefs.getString('분류') ?? '';
        break;
      case '내용':
        index = 9;
        value = prefs.getString('내용') ?? '';
        break;
      default:
        value = '';
    }

    if (index != -1 || value == '') {
      _controllers[index].text = value;

      setState(() {});
    }
  }

  Future<void> _loadAllValues() async {
    final prefs = await SharedPreferences.getInstance();

    for (int i = 0; i < _controllers.length; i++) {
      String value = '';

      switch (i) {
        case 0:
          value = '공간';
          break;
        case 1:
          value = prefs.getString('공간') ??
              ''; // SharedPreferences에서 값을 가져올 때, 값이 null이면 빈 문자열을 대신 사용합니다.
          break;
        case 2:
          value = '위치';
          break;
        case 3:
          value = prefs.getString('위치') ?? '';
          break;
        case 4:
          value = '상세';
          break;
        case 5:
          value = prefs.getString('상세') ?? '';
          break;
        case 6:
          value = '분류';
          break;
        case 7:
          value = prefs.getString('분류') ?? '';
          break;
        case 8:
          value = '내용';
          break;
        case 9:
          value = prefs.getString('내용') ?? '';
          break;
        default:
          value = '';
      }
      if (_controllers[i].text == "") {
        _controllers[i].text = value;
      }
    }

    setState(() {});
  }

  Future captureAndSavePhotos(String locationInfoText) async {
    if (locationInfoText == "") {
      print("위치 정보를 입력해주세요.");
      showMsgToast('위치 정보를 입력해주세요.');
      return;
    }

    List<String> savedFileNames = []; // 저장된 이미지의 이름
    List<File> tempImages = []; // 임시 이미지 저장소
    String targetDirPath =
        '/storage/emulated/0/Pictures/prj_${widget.inputText}'; // 사진이 저장될 앨범폴더 경로

    int loopCnt;
    if (_switchSingleMode) {
      loopCnt = 1;
    } else {
      loopCnt = 2;
    }

    // loopCnt번 사진을 찍을 수 있도록 카메라 열기를 반복
    for (int i = 0; i < loopCnt; i++) {
      final image =
          await ImagePicker().pickImage(source: imgPicker.ImageSource.camera);

      if (image != null) {
        tempImages.add(File(image.path)); // 임시 배열에 추가
      } else {
        print('No image selected or camera closed.');
        return; // 사용자가 카메라를 닫으면 함수 종료 (취소)
      }
    }

    // loopCnt 횟수 만큼 사진이 모두 찍혔을 때만 _images 배열에 추가
    if (tempImages.length == loopCnt) {
      _images.clear();
      setState(() {
        _images.addAll(tempImages);
      });

      for (var imageFile in tempImages) {
        // 각 이미지에 대해 저장 로직 실행
        String baseFileName =
            await _getStackedImageName(targetDirPath, locationInfoText)
                as String; // 실제 저장될 파일명 가져오기
        await saveImageDataAsJpg(imageFile, baseFileName); // 이미지 데이터 저장
        savedFileNames.add(baseFileName);
      }
      setState(() {});
      await saveImagesDataAsJson(savedFileNames); // JSON 데이터 저장
    }
  }

  Future saveImagesFromGallery() async {
    // _images 리스트의 이미지를 저장하는 함수

    List<String> savedFileNames = []; // 저장된 이미지의 이름
    String targetDirPath = '/storage/emulated/0/Pictures/prj_${widget.inputText}'; // 사진이 저장될 앨범폴더 경로
    int loopCnt;
    if (_switchSingleMode) {
      loopCnt = 1;
    } else {
      loopCnt = 2;
    }

    // loopCnt 횟수 만큼 사진이 모두 찍혔을 때만 _images 배열에 추가
    if (_images.length == loopCnt) {
      for (var imageFile in _images) {
        // 각 이미지에 대해 저장 로직 실행
        String baseFileName =
            await _getStackedImageName(targetDirPath, _controllers[1].text)
                as String; // 실제 저장될 파일명 가져오기
        await saveImageDataAsJpg(imageFile, baseFileName); // 이미지 데이터 저장
        savedFileNames.add(baseFileName);
      }
      setState(() {});
      await saveImagesDataAsJson(savedFileNames); // JSON 데이터 저장
    }
  }

  Future getImageFromGallery() async {
    // 갤러리에서 사진 가져오는 함수
    if (_controllers[1].text == "") {
      print("위치 정보를 입력해주세요.");
      showMsgToast('위치 정보를 입력해주세요.');
      return;
    }

    final image =
        await ImagePicker().pickImage(source: imgPicker.ImageSource.gallery);

    setState(() {
      if (image != null) {
        _images.clear();
        _images.add(File(image.path));
      } else {
        print('pic_ No image selected.');
      }
    });

    saveImagesFromGallery();
  }

  Future getTwoImagesFromGallery() async {
    if (_controllers[1].text == "") {
      print("위치 정보를 입력해주세요.");
      showMsgToast('위치 정보를 입력해주세요.');
      return;
    }

    final List<XFile>? images = await ImagePicker().pickMultiImage();

    if (images != null) {
      if (images.length != 2) {
        showMsgToast('2개의 이미지를 선택해주세요.');
        // 필요한 경우 여기서 초과된 이미지를 제거하는 로직을 추가할 수 있습니다.
      } else {
        setState(() {
          _images = images.map((image) => File(image.path)).toList();
          saveImagesFromGallery();
        });
      }
    } else {
      print('이미지가 선택되지 않았습니다.');
    }
  }

  Future<void> saveImageQualityPreference(double quality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('imageQuality', quality);
  }

  Future<void> loadImageQualityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    // 기본값을 20%로 설정합니다.
    double quality = prefs.getDouble('imageQuality') ?? 20.0;
    setState(() {
      _imageQuality = quality;
    });
  }

  void showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('설정'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    // 여기에 이미지 화질 조정 슬라이더 추가
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('이미지 화질 (${_imageQuality.round()}%)'),
                          Slider(
                            min: 0,
                            max: 100,
                            divisions: 5,
                            // 20% 단위로 설정
                            value: _imageQuality,
                            label: "${_imageQuality.round()}%",
                            onChanged: (double value) {
                              setState(() {
                                _imageQuality = value;
                                saveImageQualityPreference(value);
                              });
                            },
                          ),
                          SwitchListTile(
                            title: Text('싱글 모드'),
                            value: _switchSingleMode,
                            onChanged: (bool value) {
                              setState(() {
                                _switchSingleMode = value;
                                print('pic_ _switchSingleMode: $_switchSingleMode');
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    // 다른 설정 옵션들...
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('취소'),
                  onPressed: () {
                    Navigator.of(context).pop(); // 대화상자 닫기
                  },
                ),
                TextButton(
                  child: Text('확인'),
                  onPressed: () {
                    Navigator.of(context).pop(); // 대화상자 닫기
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 필요한 로직 추가 (예: 상태 초기화)
        return true; // 뒤로 가기 허용
      },
      child: Scaffold(
        appBar: AppBar(
          iconTheme: IconThemeData(color: Colors.black),
          title: Text('${widget.inputText}',
              style: TextStyle(color: Colors.black)),
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
                        flex: 3,
                        child: Container(
                          height: 30, // Set the height of the TextField
                          child: ElevatedButton(
                            onPressed: () async {
                              print("Pic_ ElevatedButton was clicked");
                              // KeywordSettingScreen으로 이동하고 변경 사항을 기다림
                              final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => KeywordSettingScreen(
                                        settingMenu: _controllers[index * 2]
                                            .text), // 텍스트 필드의 값을 다음 화면으로 전달
                                  ));

                              if (result != null) {
                                print("Pic_ 값 변경으로 로직 실행");
                                await _loadKeywordsMap();
                                await _loadValue(result);
                              }
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
                          child: TextField(
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
                                  vertical: 7.5, horizontal: 10),
                              // hintText: 'Input ${index * 2 + 2}',
                              border: OutlineInputBorder(),
                            ),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
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
                    // getImage();
                    captureAndSavePhotos(_controllers[1].text);
                    print('Camera icon pressed');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.photo_album),
                  onPressed: () {
                    if (_switchSingleMode) {
                      getImageFromGallery();
                    } else {
                      getTwoImagesFromGallery();
                    }
                    print('Star icon pressedd');
                  },
                ),
                IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: () => showSettingsDialog(context),
                ),
              ],
            ),
            Expanded(
              flex: 2,
              child: _images.isEmpty
                  ? Center(child: Text('이미지를 선택해주세요.'))
                  : PageView.builder(
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return Image.file(_images[index], fit: BoxFit.contain);
                      },
                    ),
            )
          ],
        ),
      ),
    );
  }
}
