extends SceneTree
## 파일 서명 (자동 업데이트용): <파일> → <파일>.sig (파일 전체 SHA-256 에 대한 RSA 서명, 오피스 전용 비밀 키)
## 실행: godot --headless --script SkyOffice/tools/signing/sign_file.gd -- <파일> <비밀 키>
## 게임(updater.gd)은 받은 zip 의 .sig 를 게임 안 공개 키로 확인한 뒤에만 설치해요

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var key := CryptoKey.new()
	var f := FileAccess.open(a[0], FileAccess.READ)
	if f == null or key.load(a[1]) != OK:
		print("실패: 파일 또는 키를 읽지 못함")
		quit(1)
		return
	var hc := HashingContext.new()
	hc.start(HashingContext.HASH_SHA256)
	while f.get_position() < f.get_length():
		hc.update(f.get_buffer(1 << 20))
	f.close()
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256, hc.finish(), key)
	var w := FileAccess.open(a[0] + ".sig", FileAccess.WRITE)
	w.store_buffer(sig)
	w.close()
	print("서명 완료: %s.sig (%d 바이트)" % [a[0].get_file(), sig.size()])
	quit()
