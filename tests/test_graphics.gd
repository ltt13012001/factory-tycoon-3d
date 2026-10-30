## Starting graphics level picked from a browser's graphics chip and memory.
extends TestCase


func test_weak_chips_start_low() -> void:
	for gpu in [
		"Google SwiftShader", "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero)), SwiftShader driver)",
		"llvmpipe (LLVM 15.0.7, 256 bits)", "Mali-T720", "Mali-G52", "Adreno (TM) 506", "Adreno (TM) 610",
		"PowerVR Rogue GE8320", "ANGLE (Intel, Intel(R) HD Graphics 4000 Direct3D11 vs_5_0 ps_5_0, D3D11)",
		"Intel(R) HD Graphics", "Microsoft Basic Render Driver",
	]:
		check_eq(Graphics.tier_for(gpu, 0.0, true), Graphics.LOW, gpu)


func test_small_memory_starts_low() -> void:
	check_eq(Graphics.tier_for("Adreno (TM) 730", 2.0, true), Graphics.LOW, "2 GB phone")
	check_eq(Graphics.tier_for("Adreno (TM) 730", 8.0, true), Graphics.MEDIUM, "8 GB phone")


func test_other_chips() -> void:
	check_eq(Graphics.tier_for("Apple GPU", 0.0, true), Graphics.MEDIUM, "iPhone / iPad")
	check_eq(Graphics.tier_for("Mali-G78", 8.0, true), Graphics.MEDIUM, "recent Mali")
	check_eq(Graphics.tier_for("ANGLE (Intel, Intel(R) UHD Graphics 620 Direct3D11 vs_5_0 ps_5_0, D3D11)", 8.0, false), Graphics.MEDIUM, "laptop UHD 620")
	check_eq(Graphics.tier_for("ANGLE (Intel, Intel(R) HD Graphics 620 Direct3D11 vs_5_0 ps_5_0, D3D11)", 8.0, false), Graphics.MEDIUM, "laptop HD 620")
	check_eq(Graphics.tier_for("ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)", 8.0, false), Graphics.HIGH, "desktop GeForce")
	check_eq(Graphics.tier_for("Apple M2", 8.0, false), Graphics.HIGH, "Mac M2")
	check_eq(Graphics.tier_for("", 0.0, false), Graphics.MEDIUM, "unknown")
