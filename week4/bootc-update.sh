#!/bin/bash

# Quay.io 레지스트리 정보
REGISTRY="quay.io/ansdudgh980/bootc"
GITHUB_API="https://api.github.com/repos/ansdudgh98/bootc/commits/main"

# GitHub에서 최신 commit hash 가져오기
echo "Fetching latest commit hash from GitHub..."
LATEST_HASH=$(curl -s $GITHUB_API | jq -r '.sha[0:7]')

if [ -z "$LATEST_HASH" ] || [ "$LATEST_HASH" == "null" ]; then
    echo "Failed to get latest commit hash from GitHub"
    exit 1
fi

echo "Latest commit hash: $LATEST_HASH"

# 현재 실행 중인 이미지 확인
CURRENT_IMAGE=$(bootc status --json | jq -r '.status.booted.image.image.image' 2>/dev/null || echo "")

echo "Current image: $CURRENT_IMAGE"

# 현재 이미지의 태그에서 hash 추출
if [[ $CURRENT_IMAGE =~ :([a-f0-9]+)$ ]]; then
    CURRENT_HASH="${BASH_REMATCH[1]}"
    echo "Current hash: $CURRENT_HASH"
else
    CURRENT_HASH=""
    echo "Current hash: unknown"
fi

# hash가 같으면 업데이트 불필요
if [ "$CURRENT_HASH" == "$LATEST_HASH" ]; then
    echo "Already running the latest version ($LATEST_HASH)"
    exit 0
fi

# 새로운 이미지 확인
NEW_IMAGE="$REGISTRY:$LATEST_HASH"
echo "Checking for new image: $NEW_IMAGE"

# 새 이미지가 존재하는지 확인
if ! podman image exists $NEW_IMAGE; then
    echo "Pulling new image..."
    podman pull $NEW_IMAGE || {
        echo "Failed to pull image $NEW_IMAGE"
        exit 1
    }
fi

# bootc switch 실행
echo "Switching to new image: $NEW_IMAGE"
bootc switch $NEW_IMAGE

# 변경사항 확인
bootc status

# Reboot 필요 여부 확인
if bootc status --json | jq -e '.status.staged != null' > /dev/null; then
    echo "Update staged. Rebooting in 10 seconds..."
    sleep 10
    systemctl reboot
else
    echo "No changes staged"
fi