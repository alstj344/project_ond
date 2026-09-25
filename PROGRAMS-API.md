# 프로그램 조회 연결

- 앱: 이 폴더의 CalmIOS.xcodeproj
- 실행 서버: /Users/iminseo/Desktop/backend (이 폴더의 backend와 다름)
- DB: project-ond / ond-db
- GET /api/programs: 공개 목록, 인증 토큰 전송 없음
- OPEN 상태 문서만 조회. 내부 메모와 사용자 정보는 반환하지 않음.
- 최대 20건, nextCursor가 있으면 ?after=<cursor>로 다음 페이지 조회.

## programs 문서

필수: title(String), status("OPEN"), startAt(Timestamp), endAt(Timestamp),
price(0 이상의 정수, 원), capacity(1 이상의 정수), reservedCount(0~capacity 정수).
종료 시간은 시작 시간 이후여야 함. 유효하지 않은 문서는 노출하지 않음.

표시용: description, exerciseType, difficulty, participationType,
facilityId, instructorId (String), imageURL(HTTPS String).
이미지 이용 권한과 시설·강사 정보를 확인한 실제 데이터만 공개해야 함.
예약 인원은 이후 예약 서버 로직이 관리하며 앱에서 직접 수정하지 않음.

## 현재 범위

프로그램 탭은 서버 목록/상세를 사용함. 데이터가 없으면 빈 상태를 표시함.
홈/탐색의 기존 예시 데이터와 예약/후기는 아직 서버 미연결.
실제 프로그램 상세의 예약은 서버 예약 기능이 연결될 때까지 비활성 상태.
샘플 프로그램 자동 업로드와 운영 데이터 변경은 하지 않음.
현재 API 연결은 Debug iOS Simulator 전용임.

서버 변경 후 기존 터미널에서 Control+C, node server.js로 재시작하고
Xcode에서 다시 실행해야 함. Firestore 복합 색인이 필요하다는 서버 오류가
발생하면 status + 문서 ID 조회 색인을 추가해야 함. 규칙을 공개로 풀지 말 것.
