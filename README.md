# OND

정신건강 관리가 필요한 사용자가 자신의 상태와 운동 조건에 맞는 운동 프로그램을 탐색하고 예약할 수 있도록 지원하는 iOS 기반 운동 서비스입니다.

사용자는 운동 조건을 설정하고 프로그램과 기관을 탐색할 수 있으며, 예약부터 체크인·퇴실·후기 작성까지 하나의 앱에서 관리할 수 있습니다.

## 주요 기능

### 회원 및 사용자 정보
- Firebase Authentication 기반 회원가입 및 로그인
- 사용자 프로필 관리
- 운동 가능 시간, 선호 운동, 참여 방식 등 운동 조건 설정
- 의료정보 연결 여부 및 기관 권장 사항을 고려한 온보딩 흐름

### 프로그램 탐색
- 운동 프로그램 및 기관 탐색
- 지역·장소 검색
- 지도 기반 주변 프로그램 탐색
- 거리 범위 및 운동 조건에 따른 필터링
- 프로그램 상세 정보 및 리뷰 확인

### 예약 관리
- 운동 프로그램 예약
- 예약 내역 확인
- 예약 취소
- 홈 화면에서 예정된 일정 확인
- 예약 상태에 따른 체크인 및 퇴실

### 운동 기록 및 후기
- 참여 완료 프로그램 기록
- 프로그램 별점 및 후기 작성
- 운동 경험에 대한 설문 기록
- 마이페이지에서 지난 참여 및 작성 후기 확인

### 사용자 편의 기능
- 지도 기반 위치 확인
- 프로그램 및 기관 위치 정보 제공
- 운동 조건 수정
- 개인정보 및 계정정보 관리

## 기술 스택

### iOS
- Swift
- SwiftUI
- MapKit
- Firebase Authentication
- Firebase / Firestore

### Backend
- Node.js
- Express
- Firebase Admin SDK
- Firestore

### Design
- Figma

## 프로젝트 구조

```text
project_ond
├── CalmIOS/                 # iOS 애플리케이션
├── CalmIOS.xcodeproj/       # Xcode 프로젝트
├── backend/                 # Node.js / Express API 서버
├── Tests/                   # iOS 모델 및 기능 검사
├── security-tests/          # API 보안 관련 테스트
├── data-import/             # 체육시설 데이터 처리
├── firestore.rules          # Firestore 보안 규칙
├── firebase.json
└── README.md
```

## 실행 방법

### 1. 저장소 Clone

```bash
git clone https://github.com/alstj344/project_ond.git
cd project_ond
```

### 2. Backend 실행

```bash
cd backend
npm ci
npm start
```

기본 로컬 서버는 다음 주소에서 실행됩니다.

```text
http://localhost:3000
```

Firebase Admin SDK 사용을 위한 인증 정보는 로컬 환경에서 별도로 설정해야 하며, 서비스 계정 키와 환경변수 등의 비밀정보는 저장소에 포함하지 않습니다.

### 3. iOS 앱 실행

`CalmIOS.xcodeproj`를 Xcode에서 열고 iPhone Simulator를 선택한 뒤 실행합니다.

Debug Simulator에서는 로컬 백엔드 연결을 사용할 수 있습니다.

실제 기기 또는 Release 환경에서는 HTTPS 기반의 `ONDAPIBaseURL` 설정이 필요합니다.

## 데이터 및 Firebase

서비스 데이터는 Firestore를 기반으로 관리합니다.

주요 데이터는 다음과 같습니다.

- 사용자 프로필
- 운동 프로그램
- 체육시설
- 예약
- 리뷰

체육시설 데이터는 공공데이터를 가공하여 서비스에서 사용할 수 있는 형태로 구성했으며, 시설과 프로그램 정보를 연결해 탐색할 수 있도록 구현했습니다.

민감한 Firebase 인증 정보 및 서비스 계정 키는 Git 저장소에 포함하지 않습니다.

## 테스트

백엔드 API와 주요 앱 모델에 대한 자동 검사를 포함하고 있습니다.

검사 대상에는 다음 기능이 포함됩니다.

- 사용자 프로필 처리
- 프로그램 조회
- 시설 조회 및 검색
- 예약 생성 및 취소
- 리뷰 처리
- 입력값 검증
- API 오류 처리
- Firestore 읽기 및 요청 처리

iOS 모델 검사는 프로젝트 루트에서 실행할 수 있습니다.

```bash
bash Tests/run-model-checks.sh
bash Tests/run-profile-checks.sh
```

백엔드 테스트는 다음과 같이 실행합니다.

```bash
cd backend
npm test
```

## 보안

- Firebase Authentication을 통한 사용자 인증
- Firestore Security Rules 적용
- Firebase Admin SDK 기반 서버 데이터 처리
- 서버 입력값 검증
- 비밀 키 및 서비스 계정 정보 Git 제외
- 운영 환경에서 테스트용 데이터 생성 요청 제한
- 사용자 인증 정보와 서버 설정 분리

## 프로젝트 목표

OND는 단순히 운동 프로그램을 보여주는 것을 넘어, 운동 참여에 어려움을 느낄 수 있는 사용자가 자신의 상황에 맞는 프로그램을 보다 쉽게 탐색하고 참여할 수 있도록 지원하는 것을 목표로 합니다.

프로그램 탐색부터 예약, 참여, 기록까지의 과정을 하나의 서비스 흐름으로 연결하여 지속적인 운동 참여를 돕는 사용자 경험을 구현했습니다.
