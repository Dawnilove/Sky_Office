class_name Identity
## 하늘 오피스의 정체성 상수를 한곳에 모음 (오버랜드: 하늘 농장과 겹치면 안 되는 것 전부)
## 코드 밖에서 같은 값을 쓰는 곳 — 바꿀 때 같이 바꿔야 함 (scenario.gd 의 신원 점검이 어긋나면 알려 줌):
##   project.godot  config/name · config/custom_user_dir_name · dotnet/project/assembly_name
##   export_presets.cfg  exe 이름 · company_name · product_name
## WindowLayer.cs 는 이 파일의 상수를 직접 읽음 (Script.GetScriptConstantMap)

const NAME := "하늘 오피스"            ## 창 제목 · 트레이 (project.godot config/name 과 같게)
const USER_DIR := "SkyOffice"           ## 저장 폴더 %APPDATA%\SkyOffice (project.godot 과 같게)
const EXE := "SkyOffice.exe"                    ## 배포판 실행 파일 (export_presets.cfg 와 같게)
const COMPANY := "Sky Office"          ## exe 속성의 회사 이름

## 자동 업데이트 (GitHub 릴리스, 태그 v1.2.3)
const REPO := "Dawnilove/Sky_Office"   # 릴리스 저장소 (사용자 2026-10-16)
const UPDATE_API := "https://api.github.com/repos/" + REPO + "/releases?per_page=40"
const UPDATE_PAGE := "https://github.com/" + REPO + "/releases"
const ZIP_FORMAT := "SkyOffice-%s-windows-x64.zip"   ## 업데이트 파일명 (%s = 버전), 서명은 같은 이름 + .sig
const USER_AGENT := "SkyOffice"
## 업데이트 서명 공개 키 — 오피스 전용 (비밀 키는 프로젝트 밖 ~/.skyoffice-signing/update_private.key 또는 SKYOFFICE_SIGN_KEY, 이 PC 에만)
const UPDATE_PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsf9vf6vJ+vIr4gvp51CU
3JYnekTBpKKi0OB1/fGU3VrebcLjqBd/OlpStSzC/2V/7skDzol19WxEZ8TVYB3H
vR3TSus+Dk+Nxa2TQDzrrAfxmoEUopjdILY5Jo/Gtukcte6M1TrVYqkClGgg96cH
8ucLMP/ROW/sKlziXyoTkK6kUBmT6Q/esk591rcE+sUj28Qa2+ZOHOCIPypfDrfg
VYVUm7IFrlJ/IVkC8kqufio18dvfbyiyzmBHnEgIA62xhL0bwtVDHyZZa4W/NPU9
tY/Dt4yVKyWSXIfctqYnzqsN2XKuORlIE8VCl9xj8TcZ2Llu1t57gOAo3kVTBn3R
+wIDAQAB
-----END PUBLIC KEY-----
"""

## Windows
const MUTEX := "Local\\SkyOffice.Single"   ## 중복 실행 막기
const RUN_NAME := "SkyOffice"               ## 자동 실행 (HKCU ... \Run 값 이름)
const APP_ID := "Dawnilove.SkyOffice"       ## Windows 알림 · 작업 표시줄 앱 ID (AppUserModelID)
const PHOTO_DIR := "하늘 오피스"                     ## 사진 저장: 사진 폴더 > 하늘 오피스

## 저장 파일 암호 (오버랜드와 다른 값)
const SAVE_KEY := "SkyOffice:3470f5c638e99b5f63ae42ed"


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## "1.2.0" >= "1.1.10" 처럼 점으로 나눈 숫자 비교
static func version_at_least(have: String, need: String) -> bool:
	var a := have.split(".")
	var b := need.split(".")
	for i in 3:
		var x := int(a[i]) if i < a.size() else 0
		var y := int(b[i]) if i < b.size() else 0
		if x != y:
			return x > y
	return true
