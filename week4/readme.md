# 4주차 과제 
--
## 작업 내용
- CI/CD 파이프라인 구축

## 동작 방식
- 동작 방식은 다음과 같습니다.
1. Github action Trigger 발동
2. podman Build 및 원격 저장소(quay.io)에 push
3. 빌드 이미지 내에 포함된 변경감지 프로세스가 git hash 변경여부를 5분 마다 확인 후 bootc switch를 자체적으로 진행


## 변경감지 프로세스
- systemd timer가 5분마다 업데이트 체크 트리거
- GitHub API를 통해 main 브랜치의 최신 commit 해시(7자리) 조회
- 현재 부팅된 이미지의 해시와 비교
- 해시가 다르면 새 이미지(`quay.io/ansdudgh980/bootc:$HASH`) pull 후 `bootc switch` 실행
- staged 상태 확인 후 10초 뒤 자동 재부팅


## 결과물
아래의 github ci 내에서 확인 가능
https://github.com/ansdudgh98/bootc/actions/workflows/ci.yml
