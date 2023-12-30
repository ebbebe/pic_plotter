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
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class EntryScreen extends StatefulWidget {
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final TextEditingController _controller = TextEditingController();
  String userEmail = 'checkmaster1@naver.com';

  // 권한 요청 상태를 추적하는 변수
  bool _isPermissionRequestInProgress = false;

  @override
  void initState() {
    super.initState();
    // requestAllPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('체크 마스터', style: TextStyle(color: Colors.black)),
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
        child: FutureBuilder<List<String>?>(
          future: findFoldersContainingString(context), // 비동기 함수 호출
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              // 로딩 상태일 때의 UI
              return CircularProgressIndicator();
            } else if (snapshot.hasError) {
              // 에러 발생 시의 UI
              return Text('Error: ${snapshot.error}');
            } else{
              // 리스트가 비어있지 않을 때의 UI
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    currentAccountPicture: CircleAvatar(
                      backgroundImage: AssetImage('assets/avatar.png'),
                      backgroundColor: Colors.white,
                    ),
                    accountName: Text('UserName'),
                    accountEmail: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: userEmail,
                            style: TextStyle(
                                color: Colors.orangeAccent,
                                decoration: TextDecoration.underline),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                _sendEmail('$userEmail');
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ListTile 동적 생성
                  if (snapshot.data!.length != 0)
                    for (var folderName in snapshot.data!)
                      ListTile(
                        leading: Icon(Icons.folder),
                        title: Text(folderName),
                        onTap: () => navigateToDashboard(folderName),
                        trailing: IconButton(
                          icon: Icon(Icons.folder_zip), // 아이콘 버튼에 사용할 아이콘을 지정합니다.
                          onPressed: () {
                            zipJsonFilesInDirectory(folderName);
                          },
                        ),
                      )
                  else
                    ListTile(
                      title: Text("생성된 폴더가 없습니다."),
                    )
                ],
              );
            }
            // else {
            //   // 데이터가 비어있을 때의 UI
            //   return ListView(
            //     padding: EdgeInsets.zero,
            //     children: [
            //       UserAccountsDrawerHeader(
            //         currentAccountPicture: CircleAvatar(
            //           backgroundImage: AssetImage('assets/avatar.png'),
            //           backgroundColor: Colors.white,
            //         ),
            //         accountName: Text('UserName'),
            //         accountEmail: RichText(
            //           text: TextSpan(
            //             children: [
            //               TextSpan(
            //                 text: userEmail,
            //                 style: TextStyle(
            //                     color: Colors.orangeAccent,
            //                     decoration: TextDecoration.underline),
            //                 recognizer: TapGestureRecognizer()
            //                   ..onTap = () {
            //                     _launchURL('$userEmail');
            //                   },
            //               ),
            //             ],
            //           ),
            //         ),
            //       ),
            //       ListTile(
            //         title: Text("생성된 폴더가 없습니다."),
            //       ),
            //     ],
            //   );
            // }
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

  void _launchURL(String email) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
    );

    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      print('Could not launch $emailLaunchUri');
      // 필요한 경우 여기에 사용자에게 오류가 발생했음을 알리는 코드를 추가할 수 있습니다.
    }
  }

  void _sendEmail(String myEmail) async {
    print("AA");
    final Email email = Email(
      body: '',
      subject: '[체크마스터 파일전송]',
      recipients: [myEmail],
      cc: [],
      bcc: [],
      attachmentPaths: [],
      isHTML: false,
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (error) {
      String title = "기본 메일 앱을 사용할 수 없기 때문에 앱에서 바로 문의를 전송하기 어려운 상황입니다.";
      String message = "";
      // _showErrorAlert(title: title, message: message);
    }
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
    // 권한 확인
    var storageStatus = await Permission.manageExternalStorage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.manageExternalStorage.request();
    }

    if (storageStatus.isGranted) {
      // PicPlotter 폴더 확인 및 생성
      var documentsPath = '/storage/emulated/0/Documents';
      var picPlotterPath = '$documentsPath/PicPlotter';
      var picPlotterDirectory = Directory(picPlotterPath);

      if (!await picPlotterDirectory.exists()) {
        await picPlotterDirectory.create();
        // 로그: 폴더 생성됨
        print('PicPlotter folder created at $picPlotterPath');
      } else {
        // 로그: 폴더 이미 존재
        print('PicPlotter folder already exists');
      }

      // 입력된 아파트명 또는 공사명을 기반으로 하위 폴더 생성
      if (_controller.text.isNotEmpty) {
        var subFolderPath = path.join(picPlotterPath, _controller.text);
        var subFolder = Directory(subFolderPath);

        if (!await subFolder.exists()) {
          await subFolder.create();
          // 로그: 하위 폴더 생성됨
          print('Subfolder created at $subFolderPath');
        } else {
          // 로그: 하위 폴더 이미 존재
          print('Subfolder already exists at $subFolderPath');
        }

        // 다음 화면으로 이동 (예: DashboardScreen)
        navigateToDashboard(_controller.text);
      } else {
        // 입력값이 비어있을 때의 처리
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
      }
    } else {
      // 권한 거부 처리
      showDialogAndExit(context, '권한이 필요합니다.');
    }
  }

  void showDialogAndExit(BuildContext context, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false, // 사용자가 다이얼로그 바깥을 터치하여 닫을 수 없도록 설정
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('알림'),
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

  Future<void> requestAllPermissions() async {
    print('Pic_ requestAllPermissions()');
    // 이미 권한 요청이 진행 중인 경우, 중복 요청을 방지합니다.
    if (_isPermissionRequestInProgress) {
      return;
    }

    _isPermissionRequestInProgress = true;

    // 필요한 권한을 나열합니다.
    List<Permission> permissions = [
      Permission.storage,
      // 필요한 다른 권한들도 여기에 추가할 수 있습니다.
      // Permission.manageExternalStorage // 안드 11부터 생긴 모든 외부 저장소 권한 얻는 코드
    ];

    // 모든 권한을 요청합니다.
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    print("권한 요청 결과: $statuses"); // 권한 요청 결과를 로그로 출력

    // 권한이 부여되지 않은 경우 처리
    if (statuses.values.any((status) => !status.isGranted)) {
      // 권한이 부여되지 않은 경우에 대한 처리를 여기에 작성합니다.
      showDialogAndExit(context, '설정>애플리케이션>해당어플>권한 으로 이동하여 앱권한 설정을 진행해주세요.1');
    } else {
      print("Pic_ All permissions granted.");
    }
    _isPermissionRequestInProgress = false;
    print("Pic_ All permissions requested.");
  }

  void navigateToDashboard(String folderName) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(inputText: folderName),
      ),
    );
    _controller.clear();
    setState(() {}); // 상태 갱신
  }

  void _CreatingFolderWithoutGrant(BuildContext context) async {
    // 검사할 경로를 지정합니다.
    String targetFolderPath = '/storage/emulated/0/Documents/PicPlotter';

    // Directory 객체를 생성합니다.
    Directory targetDirectory = Directory(targetFolderPath);

    // 폴더가 존재하는지 확인합니다.
    if (targetDirectory.existsSync()) {
      print('pic_ 폴더가 존재합니다.');
    } else {
      targetDirectory.createSync(recursive: true);
    }
  }

  Future<List<String>?> findFoldersContainingString(BuildContext context) async {
    // 파일 목록 보여주는 함수

    print("pic_ findFoldersContainingString()");
    List<String> folderNames = [];

    var storageStatus =
        await Permission.manageExternalStorage.status; // 안드버전 11이상일때 권한요청 방법
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.manageExternalStorage.request();
    }

    if (storageStatus.isGranted) {
      // PicPlotter 폴더 생성했는지 확인
      SharedPreferences prefs = await SharedPreferences.getInstance();

      bool hasParentFolderBeenCreated =
          prefs.getBool('hasParentFolderBeenCreated') ?? false;

      print("값 확인하기: $hasParentFolderBeenCreated");

      if (!hasParentFolderBeenCreated) {
        // _tryCreatingFolder(context);
        _CreatingFolderWithoutGrant(context);
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
    } else {
      return null;
    }
  }
}

Future<bool> isDirectoryNotEmpty(Directory targetDirectory) async {
  // 특정 폴더의 경로를 생성합니다.
  final folder = targetDirectory;
  print("타겟: $targetDirectory");
  // 폴더가 존재하는지 확인합니다.
  if (!await folder.exists()) {
    return false;
  }
  // 폴더 내의 파일과 폴더를 리스트합니다.
  List<FileSystemEntity> entities = await folder.list().toList();
  print("엔티티 -> $entities");
  // 파일이 하나라도 있으면 true를 반환합니다.
  return entities.any((entity) => entity is File);
}

Future<void> zipJsonFilesInDirectory(String folderName) async {
  // Documents 폴더의 경로를 가져옵니다.
  final documentsDirectory =
      Directory('/storage/emulated/0/Documents/PicPlotter/$folderName');
  // Pictures 폴더의 경로를 가져옵니다.
  final picturesDirectory =
      Directory('/storage/emulated/0/Pictures/prj_$folderName');

  // 폴더에 파일이 존재하는지 체크
  bool isNotEmpty = await isDirectoryNotEmpty(documentsDirectory);
  print('isNotEmpty 값 확인: $isNotEmpty');
  if (!isNotEmpty) {
    showMsgToast("폴더에 파일이 없습니다.");
    return;
  }
  final archive = Archive();

  // Documents 폴더에서 JSON 파일을 찾아 압축 파일에 추가합니다.
  await addFilesToArchive(folderName, archive);

  // ZIP 파일을 생성합니다.
  final zipData = ZipEncoder().encode(archive);

  // ZIP 파일을 디스크에 저장합니다.
  final zipFilePath = '${documentsDirectory.path}/$folderName.zip';
  File(zipFilePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(zipData!);

  showMsgToast("파일을 압축했습니다.");
}

Future<void> addFilesToArchive(String folderName, Archive archive) async {
  print('Pic_ addFilesToArchive 함수 실행됨');

  // Documents 폴더의 경로를 가져옵니다.
  final documentsDirectory =
      Directory('/storage/emulated/0/Documents/PicPlotter/$folderName');
  // Pictures 폴더의 경로를 가져옵니다.
  final picturesDirectory =
      Directory('/storage/emulated/0/Pictures/prj_$folderName');

  // 삭제대상 비교 리스트 생성 (포함되지 않은 json 파일은 사진이 없는 파일이므로 삭제하기 위함)
  List<String> jsonWithImageNames = [];

  // Documents 폴더의 PicPlotter 파일마다 돌아가며 실행
  await for (var entity
      in picturesDirectory.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      // 만약 파일형태이면 (폴더가 아니기만 하면)
      String fileName = path.basenameWithoutExtension(entity.path);
      String fileExtension = path.extension(entity.path);

      if (fileExtension == '.jpg' || fileExtension == '.jpeg') {
        // .jpg 파일 처리

        // 사진 파일을 압축 대상에 추가
        var imageBytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(
            '${fileName}${fileExtension}', imageBytes.length, imageBytes));

        String correspondingJsonPath =
            path.join(documentsDirectory.path, '$fileName.json');
        // json 파일 가져오기
        var jsonFile = File(correspondingJsonPath);
        if (await jsonFile.exists()) {
          // 리스트에 json 파일명 추가
          jsonWithImageNames.add(fileName);

          // JSON 파일도 압축 대상에 추가
          var jsonBytes = await jsonFile.readAsBytes();
          archive.addFile(
              ArchiveFile('$fileName.json', jsonBytes.length, jsonBytes));
        }
      }

      // 리스트에 포함되지 않은 json파일은 삭제
      print('Pic_ jsonWithImageNames값 확인 ${jsonWithImageNames.toString()}');
    }
  }

  await for (var entity
      in documentsDirectory.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      String fileName = path.basenameWithoutExtension(entity.path);
      String fileExtension = path.extension(entity.path);

      if (fileExtension == '.json') {
        // 파일명이 jsonWithImageNames 리스트에 없으면 파일 삭제
        if (!jsonWithImageNames.contains(fileName)) {
          await entity.delete();
          print('Pic_ 삭제된 파일: ${entity.path}');
        }
      }
    }
  }
}

// 이미지 파일인지 확인하는 함수
bool isImageFile(String filePath) {
  return filePath.endsWith('.png') ||
      filePath.endsWith('.jpg') ||
      filePath.endsWith('.jpeg');
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
