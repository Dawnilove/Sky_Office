extends Node
## 실제 날씨: 설정한 도시의 현재 날씨를 open-meteo.com(무료, 키 불필요)에서 15분마다 가져와 섬에 반영
## 설정 > 시간·날씨에서 '실제 날씨'를 고른 경우에만 동작 (도시 이름만 전송)

signal weather_found(kind: String, label: String)

const GEO_URL := "https://geocoding-api.open-meteo.com/v1/search?name=%s&count=1&language=ko&format=json"
## 날씨 서비스(open-meteo)는 한글 도시 이름을 못 찾음 → 주요 도시는 영어 이름으로 바꿔 한국 안에서만 찾음
const KO_CITIES := {
	"서울": "Seoul", "부산": "Busan", "인천": "Incheon", "대구": "Daegu", "대전": "Daejeon", "광주": "Gwangju",
	"울산": "Ulsan", "세종": "Sejong", "수원": "Suwon", "성남": "Seongnam", "고양": "Goyang", "용인": "Yongin",
	"부천": "Bucheon", "안산": "Ansan", "안양": "Anyang", "남양주": "Namyangju", "화성": "Hwaseong-si", "평택": "Pyeongtaek",
	"의정부": "Uijeongbu", "시흥": "Siheung", "파주": "Paju", "김포": "Gimpo", "광명": "Gwangmyeong", "하남": "Hanam",
	"구리": "Guri", "오산": "Osan", "이천": "Icheon-si", "춘천": "Chuncheon", "원주": "Wonju", "강릉": "Gangneung",
	"속초": "Sokcho", "청주": "Cheongju", "충주": "Chungju", "천안": "Cheonan", "아산": "Asan", "공주": "Gongju",
	"전주": "Jeonju", "익산": "Iksan", "군산": "Gunsan", "목포": "Mokpo", "여수": "Yeosu", "순천": "Suncheon",
	"포항": "Pohang", "경주": "Gyeongju", "구미": "Gumi", "안동": "Andong", "창원": "Changwon", "김해": "Gimhae",
	"진주": "Jinju", "양산": "Yangsan", "거제": "Geoje", "통영": "Tongyeong", "제주": "Jeju", "서귀포": "Seogwipo",
}
const WX_URL := "https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f&current=weather_code"
const INTERVAL := 900.0

var last_label := ""
var _http: HTTPRequest
var _timer := 0.0
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)


func active() -> bool:
	return Game.settings.weather == "real" or "--weather=real" in Game.dev_args()


func _process(delta: float) -> void:
	if not active():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = INTERVAL
		refresh()


func refresh() -> void:
	if _busy:
		return
	var city: String = Game.settings.city
	for a in Game.dev_args():   # 개발용: `--city=서울`
		if a.begins_with("--city="):
			city = a.get_slice("=", 1)
	if city == "":
		Game.toast.emit("설정 → 시간·날씨에서 도시를 먼저 입력해 주세요")
		return
	_busy = true
	var geo: Dictionary = Game.settings.get("geo", {})
	if geo.get("city", "") != city:
		var q := search_name(city)
		_http.request(GEO_URL % q[0].uri_encode() + ("&countryCode=KR" if q[1] else ""))
		var res: Array = await _http.request_completed
		var data = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8()) if res[1] == 200 else null
		if typeof(data) != TYPE_DICTIONARY or not data.has("results") or data.results.is_empty():
			Game.toast.emit("도시를 찾지 못했어요: %s (영어로 입력해 보세요, 예: Seoul)" % city)
			_busy = false
			return
		var r: Dictionary = data.results[0]
		geo = {"city": city, "lat": float(r.latitude), "lon": float(r.longitude), "name": str(r.get("name", city))}
		Game.settings["geo"] = geo
	_http.request(WX_URL % [geo.lat, geo.lon])
	var res2: Array = await _http.request_completed
	_busy = false
	var wx = JSON.parse_string((res2[3] as PackedByteArray).get_string_from_utf8()) if res2[1] == 200 else null
	if typeof(wx) != TYPE_DICTIONARY or not wx.has("current"):
		Game.toast.emit("날씨를 가져오지 못했어요 (인터넷 연결 확인)")
		print("[WEATHER] 실패: 응답 %s" % res2[1])
		return
	var kind := code_to_kind(int(wx.current.weather_code))
	last_label = "%s의 실제 날씨" % geo.name
	print("[WEATHER] %s → 코드 %d → %s" % [geo.name, int(wx.current.weather_code), kind])
	weather_found.emit(kind, last_label)


## 검색할 이름: 한글 주요 도시는 [영어 이름, 한국에서만 찾기], 나머지는 입력 그대로
## "서울특별시", "수원시" 처럼 붙은 말은 떼고 찾음
static func search_name(city: String) -> Array:
	var c := city.strip_edges()
	for suf in ["특별자치시", "특별자치도", "특별시", "광역시", "시"]:
		if c.ends_with(suf) and c.length() > suf.length():
			c = c.trim_suffix(suf)
			break
	if KO_CITIES.has(c):
		return [KO_CITIES[c], true]
	return [city.strip_edges(), false]


## WMO 날씨 코드 → 섬 날씨
static func code_to_kind(code: int) -> String:
	if code in [71, 73, 75, 77, 85, 86]:
		return "snow"
	if code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99]:
		return "rain"
	if code in [2, 3, 45, 48]:
		return "cloudy"
	return "clear"
