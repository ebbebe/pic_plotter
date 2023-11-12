import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_screen.dart';  // DashboardScreen 위젯을 import
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;

class EntryScreen extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('테스트 앱', style: TextStyle(color: Colors.black)),
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
        iconTheme: IconThemeData(color: Colors.black),
      ),
      drawer: Drawer(
        // Drawer의 child 프로퍼티
        child: FutureBuilder<List<String>>(
          future: findFoldersContainingString(context), // 비동기 함수 호출
          builder: (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // 로딩 상태일 때의 UI
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              // 에러 발생 시의 UI
              return Text('Error: ${snapshot.error}');
            } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              // 데이터가 있고 리스트가 비어있지 않을 때의 UI
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    currentAccountPicture: CircleAvatar(
                      backgroundImage: AssetImage('assets/avatar.png'),
                      backgroundColor: Colors.white,
                    ),
                    accountName: Text('UserA'),
                    accountEmail: Text('UserA@gmail.com'),
                  ),
                  // ListTile 동적 생성
                  for (var folderName in snapshot.data!)
                    ListTile(
                      leading: Icon(Icons.folder),
                      title: Text(folderName),
                      onTap: () {
                        // 리스트 타일 클릭시의 동작
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DashboardScreen(inputText: folderName),
                          ),
                        );
                      },
                      trailing: IconButton(
                        icon: Icon(Icons.document_scanner),  // 아이콘 버튼에 사용할 아이콘을 지정합니다.
                        onPressed: () {
                          exportDataToExcelNew(folderName);
                        },
                      ),
                    ),
                ],
              );
            } else {
              // 데이터가 비어있을 때의 UI
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    currentAccountPicture: CircleAvatar(
                      backgroundImage: AssetImage('assets/avatar.png'),
                      backgroundColor: Colors.white,
                    ),
                    accountName: Text('UserA'),
                    accountEmail: Text('UserA@gmail.com'),
                  ),
                  ListTile(
                    title: Text("생성된 폴더가 없습니다."),
                  ),
                ],
              );
            }
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: '아파트명 또는 공사명을 입력해주세요.',
                hintText: '아파트명 또는 공사명을 입력해주세요.',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),  // TextField와 버튼 사이에 간격을 추가
            ElevatedButton(
              child: Text('입력'),
              onPressed: () => _handleRequest(context),
            ),
          ],
        ),
      ),
    );
  }

  void _pickFolder(BuildContext context) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      // 선택된 폴더 경로를 사용
      print("Selected directory: $selectedDirectory");
    } else {
      // 사용자가 폴더 선택을 취소한 경우
      print("Folder selection canceled");
    }
  }

  // 권한 요청 및 다음 화면으로 이동하는 함수
  void _handleRequest(BuildContext context) async {
    if (_controller.text.isEmpty) {
      // 아파트명 또는 공사명 입력이 비어있는 경우 알림을 표시
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('알림'),
            content: Text('아파트명 또는 공사명을 입력해주세요.'),
            actions: <Widget>[
              TextButton(
                child: Text('확인'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    } else {
      // 파일 선택기를 통해 사용자에게 폴더 선택을 요청합니다.
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // 'PicPlotter' 폴더 내에 텍스트필드 값으로 하위 폴더를 생성합니다.
        final String subFolderPath = path.join(
            selectedDirectory, _controller.text);
        final Directory subFolder = Directory(subFolderPath);
        if (!await subFolder.exists()) {
          await subFolder.create(recursive: true);
          print('Subfolder created: $subFolderPath');
        } else {
          print('Subfolder already exists');
        }

        // 선택된 폴더 경로를 사용하여 다음 화면으로 이동
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(inputText: _controller.text),
          ),
        );
      }
    }
  }
  void _showDialogAndExit(BuildContext context, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false, // 사용자가 다이얼로그 바깥을 터치하여 닫을 수 없도록 설정
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('알림'),
          // content: Text('설정>애플리케이션>해당어플>권한 으로 이동하여 앱권한 설정을 진행해주세요.'),
          content: Text(msg),
          actions: <Widget>[
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.of(context).pop(); // 대화상자를 닫습니다.
                if (Platform.isAndroid) {
                  SystemNavigator.pop(); // 앱을 종료합니다.
                } else if (Platform.isIOS) {
                  exit(0); // iOS에서는 SystemNavigator.pop()이 동작하지 않으므로 exit를 사용합니다.
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDialog(BuildContext context, String msg, VoidCallback onConfirmed) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('알림'),
          content: Text(msg),
          actions: <Widget>[
            TextButton(
              child: Text('확인'),
              onPressed: () {
                Navigator.of(context).pop(); // 대화상자 닫기
                onConfirmed(); // 콜백 실행
              },
            ),
          ],
        );
      },
    );
  }

  void _tryCreatingFolder(BuildContext context) async {
    // 사용자에게 폴더 선택을 유도하는 대화상자를 띄웁니다.
    _showDialog(context, 'Documents 폴더에서 "이 폴더 사용" 버튼을 눌러주세요.', () async {
      // 사용자가 '확인'을 누른 후 폴더 선택기를 띄웁니다.
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory != null) {
        // 선택된 폴더 경로를 이용해 PicPlotter 폴더를 생성합니다.
        var picPlotterPath = path.join(selectedDirectory, 'PicPlotter');
        var picPlotterDirectory = Directory(picPlotterPath);

        if (!await picPlotterDirectory.exists()) {
          // 폴더가 없으면 생성
          await picPlotterDirectory.create();
          print('PicPlotterDirectory folder created at $picPlotterPath');
          // 상태 저장
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('hasParentFolderBeenCreated', true);
        }
      } else {
        // 사용자가 폴더 선택을 취소한 경우
        _showDialogAndExit(context, 'PicPlotter 폴더 생성이 취소되었습니다.');
      }
    });
  }

  Future<List<String>> findFoldersContainingString(BuildContext context) async {
    List<String> folderNames = [];

    // PicPlotter 폴더 생성했는지 확인
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasParentFolderBeenCreated = prefs.getBool('hasParentFolderBeenCreated') ?? false;

    if(!hasParentFolderBeenCreated){
      _tryCreatingFolder(context);
    }

    // 저장 권한 요청
    var storageStatus = await Permission.storage.request();
    if (storageStatus.isGranted) {
      //폴더의 경로를 가져옵니다.
      final Directory targetDirectory = Directory('/storage/emulated/0/Documents/PicPlotter');

      // 상위 디렉토리에서 모든 엔티티를 나열합니다.
      List<FileSystemEntity> entities = await targetDirectory.list().toList();

      for(FileSystemEntity entity in entities){
        String folderName = entity.path.split('/').last;
        folderNames.add(folderName);
        print('entity: ${folderName}');
      }

    } else {
      _showDialogAndExit(context, '설정>애플리케이션>해당어플>권한 으로 이동하여 앱권한 설정을 진행해주세요.');
      print('Storage Permission Denied');
    }

    return folderNames;
  }
}

Future<String> copyAssetExcelToFile(String assetExcelPath, String targetFolderPath, String targetFileName) async {
  try {
    // 에셋에서 엑셀 파일의 바이트 데이터를 로드합니다.
    final byteData = await rootBundle.load(assetExcelPath);
    final buffer = byteData.buffer;

    // 새 파일의 경로를 지정합니다.
    final String fullPath = '$targetFolderPath/$targetFileName';

    // 특정 폴더 경로가 존재하는지 확인하고, 없다면 생성합니다.
    print("테스트: assetExcelPath: ${assetExcelPath}");
    print("테스트: targetFolderPath: ${targetFolderPath}");
    print("테스트: targetFileName: ${targetFileName}");
    print("테스트: fullPath: ${fullPath}");
    final Directory targetDirectory = Directory(targetFolderPath);
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    // 새 파일을 생성하고 바이트 데이터를 씁니다.
    final file = File(fullPath);

    // 파일이 이미 존재하는 경우를 확인하고, 덮어쓰기 여부를 결정
    if (await file.exists()) {
      print('파일이 이미 존재합니다. 덮어쓰기를 진행합니다.');
    }

    await file.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));

    print('Excel file copied to $fullPath');
    return fullPath;
  } catch (e) {
    print('Error copying excel file: $e');
    return '$e';
  }
}






Future<void> copyExcelFile(String folderName) async {
  try {
    // 앱의 문서 디렉토리 경로를 얻습니다.
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/PicPlotter/excel_layout.xlsx';

    // 원본 파일 인스턴스를 생성합니다.
    final originalFile = File(filePath);

    // 복사본 파일 경로를 설정합니다. 여기서는 같은 디렉토리에 '_copy'를 붙여 새 이름을 생성합니다.
    final newFileName = '${directory.path}/PicPlotter/${folderName}/${folderName}.xlsx';
    final newFile = File(newFileName);

    // 파일 복사를 시도합니다.
    await originalFile.copy(newFile.path);

    print('File copied to $newFileName');
  } catch (e) {
    print('Error copying file: $e');
    // 에러 처리를 적절히 수행합니다.
  }
}


// 사용자가 선택한 폴더에서 JSON 데이터를 Excel 파일로 변환하는 함수
Future<void> exportDataToExcel(String folderName) async {
  final appDocDir = await getApplicationDocumentsDirectory();
  final appDocPath = appDocDir.path;
  final dataDirectory = Directory('$appDocPath/$folderName');
  final excelFilePath = '$appDocPath/$folderName.xlsx';

  // Excel 파일이 이미 존재하는지 확인합니다. 없으면 새로 생성합니다.
  var excel = File(excelFilePath).existsSync() ? await loadExcelFile(excelFilePath) : Excel.createExcel();
  var sheetName = 'Sheet1';

  // JSON 파일을 처리하고 Excel 파일로 저장합니다.
  await processJsonFiles(dataDirectory, excel, sheetName);
}

// 사용자가 선택한 폴더에서 JSON 데이터를 Excel 파일로 변환하는 함수
Future<void> exportDataToExcelNew(String folderName) async {
  String assetPath = 'assets/excel_layout.xlsx';
  String targetPath = '/storage/emulated/0/Documents/PicPlotter/${folderName}';
  Directory targetDirectory = Directory(targetPath);
  String excelFilePath = await copyAssetExcelToFile(assetPath, targetPath, '${folderName}.xlsx');
  print('excelFilePath: ${excelFilePath}');
  Excel excel = await loadExcelFile(excelFilePath);
  processJsonFiles(targetDirectory, excel, folderName);
}




Future<Excel> loadExcelFile(String filePath) async {
  var bytes = await File(filePath).readAsBytes(); // 비동기식으로 파일 읽기
  var excel = Excel.decodeBytes(bytes);
  return excel;
}



void addHeadersToSheet(Sheet sheet, List<String> headers) {
  for (int i = 0; i < headers.length; i++) {
    sheet.updateCell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0), headers[i]);
  }
}

// JSON 파일을 처리하고 Excel 시트에 데이터를 추가하는 함수
Future<void> processJsonFiles(Directory directory, Excel excel, String folderName) async {


  // json 파일들 로드
  final jsonFiles = directory.listSync().where((element) => element.path.endsWith('.json')).toList();

  // 엑셀파일 열기
  var allSheets = excel.tables.keys;

  // 첫 번째 시트의 이름을 가져옵니다.
  String firstSheetName = allSheets.elementAt(0);

  // 첫 번째 시트를 참조합니다.
  var sheet = excel.tables[firstSheetName];

  // 엑셀파일 수정
  int nameRow = 2;
  int nameColumn = 1;
  var nameCellIndex = CellIndex.indexByColumnRow(columnIndex: nameColumn, rowIndex: nameRow); // A1 셀
  sheet!.updateCell(nameCellIndex, "${folderName} 공사 체크리스트");



  // int startRow = 0; // 데이터를 쓸 시작 행입니다.
  // for (var jsonFile in jsonFiles) {
  //   final Map<String, dynamic> json = jsonDecode(await File(jsonFile.path).readAsString());
  //   // JSON 구조를 토대로 데이터를 시트에 추가하는 코드...
  //   startRow++;
  // }


  // 엑셀 저장
  saveExcelFile(directory, folderName, excel);
}

// 변경사항을 적용한 Excel 파일을 저장하는 함수
Future<void> saveExcelFile(Directory directory, String fileName, Excel excel) async {
  String outputFile = path.join(directory.path, '$fileName.xlsx');
  File(outputFile)
    ..createSync(recursive: true)
    ..writeAsBytesSync(excel.encode()!);
  print('Excel file saved: $outputFile');
}

void showExcelFileSavedToast() {
  Fluttertoast.showToast(
      msg: "엑셀 파일이 저장되었습니다.",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0
  );
}


