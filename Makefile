.PHONY: build serve format format-check lint verify studio-tests

build:
	mkdir -p build
	rojo build default.project.json -o build/StealAnEggs.rbxlx

serve:
	rojo serve default.project.json

format:
	stylua src tests

format-check:
	stylua --check src tests

lint:
	selene src tests

verify: format-check lint build
	git diff --check

studio-tests:
	@printf '%s\n' 'Open build/StealAnEggs.rbxlx in Roblox Studio and press Test > Run; TestService AutoRuns is enabled.'
