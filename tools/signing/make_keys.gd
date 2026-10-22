extends SceneTree
## 하늘 오피스 업데이트 서명 키 만들기 (한 번만, 오버랜드 키와 별개): 비밀 키(update_private.key)는 이 PC에만 보관, 공개 키(update_public.pem)는 게임 코드에 넣음
## 실행: godot --headless --script SkyOffice/tools/signing/make_keys.gd [-- <폴더>]
##   폴더를 안 주면 프로젝트 밖 기본 경로 ~/.skyoffice-signing (build_release.sh 와 같음, M4 5세션째). 프로젝트 안에는 만들지 말 것

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OS.get_environment("USERPROFILE" if OS.get_name() == "Windows" else "HOME").path_join(".skyoffice-signing")
	DirAccess.make_dir_recursive_absolute(dir)
	if FileAccess.file_exists(dir.path_join("update_private.key")):
		print("이미 키가 있어요 — 덮어쓰지 않음 (바꾸면 이미 배포한 버전이 업데이트를 못 받아요)")
		quit(1)
		return
	var key := Crypto.new().generate_rsa(2048)
	key.save(dir.path_join("update_private.key"))
	key.save(dir.path_join("update_public.pem"), true)
	print("키 생성 완료")
	quit()
