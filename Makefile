DOCKER_DIR := configs/claude/docker
IMAGE_NAME := claude-code-sandbox

.PHONY: sandbox sandbox-build

# Docker サンドボックスで Claude Code を起動
# 使い方: make sandbox [PROJECT=~/projects/my-app]
sandbox:
	@exec bash $(DOCKER_DIR)/run.sh $(PROJECT)

# Docker イメージをビルド（初回 or Dockerfile 更新時に実行）
sandbox-build:
	docker buildx build -t $(IMAGE_NAME) $(DOCKER_DIR)
