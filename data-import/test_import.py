import csv
import json
import sqlite3
import tempfile
import unittest
from pathlib import Path
from import_facilities import build, coordinates, number
from export_firestore import export


class ImportTests(unittest.TestCase):
    def test_invalid_coordinates_and_metrics(self):
        self.assertEqual(coordinates("0", "0"), (None, None))
        self.assertEqual(coordinates("37.5", "127"), (37.5, 127.0))
        self.assertIsNone(number("NaN"))
        self.assertIsNone(number("-1"))

    def test_multiline_dedup_deletion_and_matching(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            facility = {"FCLTY_NM": "테스트\n시설", "RDNMADR_ONE_NM": "서울 주소",
                        "FCLTY_LA": "37.5", "FCLTY_LO": "127", "DEL_AT": "N",
                        "FCLTY_STATE_VALUE": "정상운영", "CTPRVN_NM": "서울특별시", "UPDT_DT": "2026-07-01"}
            removed = {**facility, "FCLTY_NM": "삭제 시설", "DEL_AT": "Y"}
            invalid = {**facility, "FCLTY_NM": "\ufffd시설"}
            rows = [facility, facility, removed, invalid]
            with (root / "facilities.csv").open("w", encoding="utf-8-sig", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=facility.keys()); writer.writeheader(); writer.writerows(rows)
            stop = {"ALSFC_NM": "테스트\n시설", "ALSFC_ADDR": "서울 주소", "ALSFC_LA": "37.5",
                    "ALSFC_LO": "127", "BSTP_SUBWAYST_NM": "정류장", "WLKG_MVMN_TIME": "120"}
            with (root / "transit.csv").open("w", encoding="utf-8-sig", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=stop.keys()); writer.writeheader()
                writer.writerows([stop, {**stop, "ALSFC_NM": "알 수 없는 시설"}])
            build(root / "facilities.csv", root / "transit.csv", root / "out")
            db_path = root / "out/facilities-202607.sqlite3"
            with sqlite3.connect(db_path) as db:
                self.assertEqual(db.execute("SELECT count(*) FROM facilities").fetchone()[0], 3)
                self.assertEqual(db.execute("SELECT count(*) FROM facilities WHERE is_active=1").fetchone()[0], 1)
                self.assertEqual(db.execute("SELECT count(*) FROM nearby_transit WHERE facility_id IS NULL").fetchone()[0], 1)
            export(db_path, root / "export.jsonl", "서울특별시")
            docs = [json.loads(line) for line in (root / "export.jsonl").read_text().splitlines()]
            self.assertEqual(len(docs), 1)
            self.assertFalse(docs[0]["bookingEnabled"])
            self.assertEqual(docs[0]["nearbyTransit"][0]["sourceMetrics"]["WLKG_MVMN_TIME"], 120)
            self.assertNotIn("price", docs[0])


if __name__ == "__main__":
    unittest.main()
