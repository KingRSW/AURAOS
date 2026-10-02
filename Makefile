# AURA-OS 构建入口
# make iso   = 构建可引导 ISO (需 Docker Desktop 运行; Apple Silicon 需注册 amd64 模拟)
# make run   = QEMU GUI 启动
# make test  = 无头自动化测试 (VNC 截图)
# make clean = 清理产物

ISO     := out/auraos-1.0-amd64.iso
BUILDER := aura-builder
CACHE   := aura-lb-cache
BUILDV  := aura-build

.PHONY: all iso docker run test clean

all: iso

docker:
	docker build --platform linux/amd64 -t $(BUILDER) docker/

iso: docker
	docker run --rm --privileged --platform linux/amd64 \
		-v "$(CURDIR)":/work -v $(CACHE):/var/cache/live -v $(BUILDV):/build \
		$(BUILDER) bash /work/docker/build.sh

run: $(ISO)
	qemu-system-x86_64 -m 4G -smp 2 -cdrom $(ISO) -boot d -display cocoa

test: $(ISO)
	bash tests/qemu-boot.sh

$(ISO):
	@echo "ISO 不存在, 先运行: make iso" && false

clean:
	rm -rf out 2>/dev/null || true
	docker run --rm --privileged -v "$(CURDIR)":/work -v $(BUILDV):/build $(BUILDER) bash -c 'cd /build && lb clean --all || true'
