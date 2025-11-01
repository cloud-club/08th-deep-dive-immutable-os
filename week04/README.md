# 4주차 과제

## 수행 과정
---
### 1. EC2 실행해서 Runner로 등록
- systemd 서비스 등록
  ``` bash
  sudo ./svc.sh install
  sudo ./svc.sh start

  ```

### 2. CI를 위한 Workflow YAML 작성 
- 컨테이너 이미지 빌드 후 AMI로 빌드하는 것까지

## 추후 CD 확장
---
### **Auto Scaling Group (ASG) + Launch Template**

- AMI ID를 Launch Template에 연결
- GitHub Actions에서 AMI 생성 후 Launch Template 업데이트
- Auto Scaling Group에서 새 AMI 기반 인스턴스 순차적으로 교체 (Rolling update)