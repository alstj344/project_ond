# 기관 검색 운영 기록 (2026-09-26)

실행 백엔드: `/Users/iminseo/Desktop/backend`.

## 수정사항

- `controllers/facilityController.js`: 기존 공개 응답 필드 유지. 교통정보의 원본 `mode`를 `type`으로 호환하며 Swift Int 필드를 정수로 변환.
- `controllers/facilitySearch.js`: 로컬 서울 검색 목록 전체에서 필터/거리/정렬을 먼저 적용하고 해당 페이지 최대 30개 ID만 Firestore `getAll`로 조회.
- 기존 `facilityController.backup.js`는 수정하지 않음.
- 페이지 상세는 5분 캐시, 동일 진행 중 요청 공유, 캐시 최대 200페이지.
- 할당량 오류 시 60초 동안 새로운 Firestore 요청 중지. 이미 소진된 할당량을 복구하는 기능은 아님.
- `programController.js`, `reservationController.js`: 예약 응답을 Swift의 `RemoteProgram` 형식과 통일. 기존 날짜 별칭도 유지.

## 데이터 기준

`data/facilities-seoul-202607.jsonl`이 검색 인덱스. 원본은 이 폴더의 `generated/seoul.jsonl`.
검색/총 건수/정렬은 해당 스냅샷 기준. 상세와 교통정보는 Firestore 최신 문서 기준(캐시 최대 5분).
Firestore에서 기관명, 좌표, 종목을 변경하거나 기관을 추가/삭제하면 검색 파일도 갱신하고 서버를 재시작해야 함.
삭제/비공개 기관은 상세 반환에서 제외되므로 갱신 전 총 건수와 반환 건수 차이가 있을 수 있음.
검색 파일이 없을 때 Firestore 전체 조회로 자동 대체하지 않고 503 반환.

## 확인

`node --test tests/facilityQuota.test.js tests/profileUpdate.test.js tests/programController.test.js`

14개 테스트 통과. 실제 DB 검증: 강남 + 체력단련장 611건, 반환 30건, Firestore 요청 문서 30개, 종목 48개.
이는 컨트롤러 직접 실행 검증이며, 기존 3000 포트 서버의 자동 재시작이나 iOS 화면 검증은 수행하지 않음.

기존 서버 터미널에서 Ctrl+C 후 `node server.js`로 재시작.
새로운 전체 기능 개발/보안 감사가 완료됐다는 의미는 아니며, 이번 수정 범위는 기관 검색과 예약 응답 형식.
