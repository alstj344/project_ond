# 기관 데이터 (2026-07 원본 스냅샷)

## 구성

- `generated/facilities-202607.sqlite3`: 전국 시설과 주변 대중교통을 담은 SQLite DB.
- `facilities`: 시설명, 주소, 종목/유형, 좌표, 대표 연락처, 운영상태, 지역, 원본 행 번호.
- `nearby_transit`: 버스/지하철 정류장, 좌표, 원본 거리/이동시간 수치, 연결 시설 ID.
- `generated/report.json`: 원본 행 수, 정제 후 건수, 지역별 건수, DB 무결성 검사 결과.

자료 출처는 사용자가 제공한 `KS_WNTY_PHSTRN_FCLTY_STTUS_202607.csv`와
`KS_ALSFC_NEARBY_PBTRNSP_INFO_202607.csv`입니다. 공개 서비스 적용 전 원 제공처의
이용조건과 갱신 주기를 확인해야 합니다. CSV에 포함된 지명은 임의로 교정하지 않았습니다.

## 정제 기준

- CSV 파서로 따옴표와 필드 안 줄바꿈을 처리합니다.
- 시설명/주소/상세주소/유형/좌표 조합을 해시 ID로 사용합니다. 원본의 공식 시설 ID는 없습니다.
- 동일 키는 수정일이 최신인 상태를 우선합니다. 시설명/주소 변경은 다른 ID가 될 수 있습니다.
- 삭제 표시 `Y`, 정상운영 이외 상태, 깨진 시설명은 로컬에 보관하되 Firebase 공개 목록에서는 제외합니다.
- Firebase 내보내기에서는 주소 누락/깨짐, 지역 누락/숫자 코드 오염도 제외합니다.
- 좌표 0 또는 한국 주변 범위를 벗어난 좌표는 null로 둡니다. 지도에 표시할 때 제외하세요.
- 교통정보는 이름+소수점 5자리 좌표 또는 이름+주소의 유일한 일치만 연결합니다.
  동명이거나 불확실한 자료는 `facility_id IS NULL`로 보관합니다.
- 담당자 이름/개인 연락처는 가져오지 않습니다. 시설 대표 전화번호만 포함합니다.
- 거리/이동시간의 단위 설명서가 제공되지 않아 원본 컬럼명과 수치를 유지합니다.
  단위를 확인하기 전 앱에서 분/미터로 단정해서 표시하지 마세요.

## Firebase용 기관 문서

`export_firestore.py --database generated/facilities-202607.sqlite3 --output generated/seoul.jsonl --province 서울특별시`

`facilities/ks_<해시>`에 저장할 문서를 생성합니다. 시설당 연결 교통정보 최대 5개를 포함합니다.
`bookingEnabled: false`로 설정하며, 2026-07 자료의 운영상태가 현재 영업 보장은 아닙니다.
기관 정보는 의료기관 연계 여부나 건강상 적합성을 의미하지 않습니다.

`publish_facilities.cjs --input generated/seoul.jsonl`은 쓰기 없이 건수만 검사합니다.
실제 등록에는 `--apply --confirm-count <정확한 건수> --config <기존 백엔드 config/firebase.js 절대경로>`가 필요합니다.
대상은 `project-ond/ond-db`로 제한하고, 기존 문서는 덮어쓰지 않습니다. 중간 실패 시 재실행할 수 있습니다.
전국 일괄 등록은 쓰기 할당량과 비용을 먼저 확인해야 합니다.

## 프로그램과 구분

원본에 수업 날짜, 시간, 강사, 모집 인원, 가격이 없으므로 `programs`를 가짜로 생성하지 않습니다.
실제 운영 프로그램을 별도로 입력하고 `facilityId`에 위 기관 문서 ID를 연결하세요.
이 DB 생성만으로 SwiftUI 탐색 화면/API가 자동 연결되는 것은 아닙니다.

검사: `python3 -m unittest discover -s . -p 'test_*.py'`
