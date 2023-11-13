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
import 'dashboard_screen.dart'; // DashboardScreen 위젯을 import
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
//TODO 1. 쓸데없는 엑셀 출력기능 전부 지우고 json파일 압축기능만 추가
//TODO 2. 엑셀파일 출력은 PC에서 진행
//TODO 3. no item data 없애기
//TODO 4. 메뉴 권한 부여 에러



class EntryScreen extends StatefulWidget {
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    requestAllPermissions();
  }

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
            color: Colors.grey[300], // 경계선의 색상을 설정합니다.
            height: 0.5, // 경계선의 높이를 설정합니다.
          ),
          preferredSize: Size.fromHeight(0.5),
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      drawer: Drawer(
        // Drawer의 child 프로퍼티
        child: FutureBuilder<List<String>>(
          future: findFoldersContainingString(context), // 비동기 함수 호출
          builder:
              (BuildContext context, AsyncSnapshot<List<String>> snapshot) {
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
                            builder: (context) =>
                                DashboardScreen(inputText: folderName),
                          ),
                        );
                      },
                      trailing: IconButton(
                        icon: Icon(Icons.folder_zip), // 아이콘 버튼에 사용할 아이콘을 지정합니다.
                        onPressed: () {
                          zipJsonFilesInDirectory(folderName);
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
            SizedBox(height: 20), // TextField와 버튼 사이에 간격을 추가
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
        final String subFolderPath =
            path.join(selectedDirectory, _controller.text);
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
                  exit(
                      0); // iOS에서는 SystemNavigator.pop()이 동작하지 않으므로 exit를 사용합니다.
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDialog(
      BuildContext context, String msg, VoidCallback onConfirmed) async {
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

    // 저장 권한의 현재 상태를 확인합니다.
    var storageStatus = await Permission.storage.status;

    // 권한이 아직 부여되지 않았다면 사용자에게 요청합니다.
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        // 권한이 거부되었다면 경고 메시지를 표시하고 함수를 종료합니다.
        _showDialogAndExit(context, '설정>애플리케이션>해당어플>권한 으로 이동하여 앱권한 설정을 진행해주세요.');
        return [];
      }
    }

    // PicPlotter 폴더 생성했는지 확인
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasParentFolderBeenCreated =
        prefs.getBool('hasParentFolderBeenCreated') ?? false;

    if (!hasParentFolderBeenCreated) {
      _tryCreatingFolder(context);
    }
    //폴더의 경로를 가져옵니다.
    final Directory targetDirectory =
    Directory('/storage/emulated/0/Documents/PicPlotter');

    // 상위 디렉토리에서 모든 엔티티를 나열합니다.
    List<FileSystemEntity> entities = await targetDirectory.list().toList();

    for (FileSystemEntity entity in entities) {
      String folderName = entity.path.split('/').last;
      folderNames.add(folderName);
      print('entity: ${folderName}');
    }

    return folderNames;
  }
}

Future<void> zipJsonFilesInDirectory(String folderName) async {
  //폴더의 경로를 가져옵니다.
  final directory =
      Directory('/storage/emulated/0/Documents/PicPlotter/$folderName');
  final archive = Archive();

  // 디렉토리 내의 모든 파일들을 나열합니다.
  List<FileSystemEntity> files = await directory.list().toList();

  print("압축할 파일 목록: \n ${files.toList()}");
  print("directory: \n ${directory.path}");
  // JSON 파일이 있는지 확인합니다.
  bool hasJsonFiles =
      files.any((file) => file is File && file.path.endsWith('.json'));

  if (!hasJsonFiles) {
    // JSON 파일이 없으면 함수를 종료합니다.
    showMsgToast('압축할 파일이 존재하지 않습니다.');
    return;
  }

  for (final file in files) {
    if (file is File && file.path.endsWith('.json')) {
      // JSON 파일을 읽어 압축 파일에 추가합니다.
      final data = await file.readAsBytes();
      final filename = file.path.split("/").last;
      archive.addFile(ArchiveFile(filename, data.length, data));
    }

    // ZIP 파일을 생성합니다.
    final zipData = ZipEncoder().encode(archive);



    // ZIP 파일을 디스크에 저장합니다.
    final zipFilePath = '${directory.path}/$folderName.zip';
    File(zipFilePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(zipData!);
  }
}

void showMsgToast(String msg) {
  Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0);
}

Future<void> requestAllPermissions() async {
  // 필요한 권한을 나열합니다.
  List<Permission> permissions = [
    Permission.storage,
    Permission.manageExternalStorage
    // 필요한 다른 권한들도 여기에 추가할 수 있습니다.
  ];

  // 모든 권한을 요청합니다.
  await Future.forEach(permissions, (Permission permission) async {
    var status = await permission.status;
    if (!status.isGranted) {
      await permission.request();
    }
  });

  print("All permissions requested.");
}
