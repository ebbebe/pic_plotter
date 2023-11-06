import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeywordSettingScreen extends StatefulWidget {
  final String settingMenu;

  KeywordSettingScreen({required this.settingMenu});

  @override
  State<KeywordSettingScreen> createState() => _KeywordSettingScreenState();
}

class _KeywordSettingScreenState extends State<KeywordSettingScreen> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _keywords = [];
  int _selectedItemIndex = -1; // 선택된 아이템의 인덱스, 초기값은 -1로 설정

  late Map<String, dynamic> _keywordsMap = {
    '위치': [],
    '분류': [],
    '상세위치': [],
    '하자내용': [],
    '비고': []
  };

  @override
  void initState() {
    super.initState();
    _loadKeywordsMap();
    _loadKeywords();
  }


  _saveKeywords(String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (_keywords.length > 20) {
      _keywords.removeAt(0);
    }
    _keywords.add(value);

    if (_keywordsMap != null) {
      if (_keywordsMap.containsKey(widget.settingMenu)) {
        _keywordsMap[widget.settingMenu] = _keywords;
      }
    }

    String jsonString = json.encode(_keywordsMap);
    await prefs.setString('keywordsMap', jsonString);
    _loadKeywords(); // 새로 저장된 키워드 리스트 화면에 업데이트
  }

  _loadKeywordsMap() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('keywordsMap');

    if (jsonString != null) {
      _keywordsMap = json.decode(jsonString);
    }
  }

  _loadKeywords() async {
    _keywords = await _getKeywords();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? selectedText = prefs.getString(widget.settingMenu);

    if (selectedText != null && _keywords.contains(selectedText)) {
      _selectedItemIndex = _keywords.indexOf(selectedText);
    }

    setState(() {});
  }


  Future<List<String>> _getKeywords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? jsonString = prefs.getString('keywordsMap');
    if (jsonString != null) {
      Map<String, dynamic> map = json.decode(jsonString);

      if (map.containsKey(widget.settingMenu)) {
        List<dynamic> value = map[widget.settingMenu];
        return List<String>.from(value);
      }
    }
    return [];
  }

  void _onItemTapped(int index) {
    setState(() {
      // 선택된 아이템 토글 (클릭 시 선택 <-> 선택 해제)
      if (_selectedItemIndex == index) {
        _selectedItemIndex = -1; // 선택 해제
      } else {
        _selectedItemIndex = index; // 선택
        String selectedText = _keywords[index]; // 선택된 아이템의 텍스트 값을 가져옴
        _saveSelectedText(widget.settingMenu, selectedText);
      }
    });
  }

  _saveSelectedText(String key, String value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(key, value); // Key-Value 형태로 값을 저장합니다.
  }

  void _removeKeyword(int index) async {
    // 해당 아이템 제거
    if (index >= 0 && index < _keywords.length) {
      setState(() {
        _keywords.removeAt(index);
      });

      // SharedPreferences에도 반영
      SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_keywordsMap.containsKey(widget.settingMenu)) {
        _keywordsMap[widget.settingMenu] = _keywords;
        String jsonString = json.encode(_keywordsMap);
        await prefs.setString('keywordsMap', jsonString);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.settingMenu} 키워드 설정'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 1,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '저장할 키워드를 입력해주세요.',
                  contentPadding: EdgeInsets.all(20),
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.add),
                ),
                onSubmitted: (value) {
                  _saveKeywords(value);
                  _controller.clear();
                },
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _keywords.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text('${_keywords[index]}'),
                  tileColor:
                      _selectedItemIndex == index ? Colors.blue[200] : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.check),
                        onPressed: () {
                          // 수정 버튼을 눌렀을 때 처리
                          _onItemTapped(index); // 아이템을 탭했을 때 처리
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          // 삭제 버튼을 눌렀을 때 처리
                          _removeKeyword(index);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
