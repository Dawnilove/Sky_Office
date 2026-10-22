extends Translation
## 한글 줄바꿈: 낱말 가운데("잠들|어요")에서 끊기지 않게, 붙어 있는 한글 글자 사이에
## 폭 0인 '단어 이음 문자'(U+2060)를 끼워 넣어요 → 띄어쓰기에서만 줄이 바뀌어요.
## Label·Button 등은 글자를 화면에 그리기 전에 번역(tr)을 거치므로, 번역 하나로 모든 UI에 한 번에 적용돼요.
## (원래 글자 .text 는 그대로라 비교·저장에는 영향 없음)

const WJ := 0x2060
var _cache := {}


func _init() -> void:
	locale = "ko"


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if _cache.has(s):
		return _cache[s]
	var out := s
	var n := s.length()
	if n > 1:
		var b := PackedInt32Array()
		var changed := false
		for i in n:
			var c := s.unicode_at(i)
			b.append(c)
			if i + 1 < n and ((_hangul(c) and _joins(s.unicode_at(i + 1))) or (_alnum(c) and _hangul(s.unicode_at(i + 1)))):
				b.append(WJ)
				changed = true
		if changed:
			out = _from(b)
	if _cache.size() > 2000:   # HUD 시각처럼 계속 바뀌는 글자로 끝없이 쌓이지 않게
		_cache.clear()
	_cache[s] = StringName(out)
	return _cache[s]


func _hangul(c: int) -> bool:
	return c >= 0xAC00 and c <= 0xD7A3


## 한글 바로 뒤에 붙은 글자: 한글·숫자·영문·닫는 괄호/문장부호는 앞 글자와 같이 다녀요
func _joins(c: int) -> bool:
	return _hangul(c) or (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A) \
			or c in [0x29, 0x5D, 0x2E, 0x2C, 0x21, 0x3F, 0x7E, 0x2019, 0x201D, 0x27, 0x22]


func _alnum(c: int) -> bool:
	return (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A)


func _from(codes: PackedInt32Array) -> String:
	var t := ""
	for c in codes:
		t += char(c)
	return t
