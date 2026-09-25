"""Build a local facility catalogue from the supplied July 2026 CSV snapshot."""
import argparse
import csv
import hashlib
import json
import math
import sqlite3
from collections import Counter, defaultdict
from pathlib import Path


def clean(value):
    return " ".join((value or "").split())


def number(value):
    try:
        result = float(value)
        return result if math.isfinite(result) and result >= 0 else None
    except (TypeError, ValueError):
        return None


def coordinates(lat, lon):
    lat, lon = number(lat), number(lon)
    if lat is not None and lon is not None and 33 <= lat <= 39 and 124 <= lon <= 132:
        return lat, lon
    return None, None


def identifier(*values):
    return hashlib.sha256(json.dumps(values, ensure_ascii=False).encode()).hexdigest()[:32]


def read_rows(path, required=()):
    with path.open(encoding="utf-8-sig", newline="") as source:
        reader = csv.DictReader(source)
        missing = set(required) - set(reader.fieldnames or [])
        if missing:
            raise ValueError(f"Missing CSV columns: {sorted(missing)}")
        yield from reader


def build(facility_path, transit_path, output):
    output.mkdir(parents=True, exist_ok=True)
    db_path = output / "facilities-202607.sqlite3"
    if db_path.exists():
        raise SystemExit("Output already exists; choose a new --output directory.")
    db = sqlite3.connect(db_path)
    db.execute("PRAGMA foreign_keys=ON")
    db.executescript("""
        CREATE TABLE facilities (
          id TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT, facility_type TEXT,
          address TEXT, address_detail TEXT, latitude REAL, longitude REAL,
          phone TEXT, website TEXT, province TEXT, district TEXT,
          operation_status TEXT, deleted INTEGER, is_active INTEGER, quality_issue TEXT,
          source_updated_at TEXT, source_row INTEGER, source_snapshot TEXT DEFAULT '202607');
        CREATE TABLE nearby_transit (
          id TEXT PRIMARY KEY, facility_id TEXT REFERENCES facilities(id),
          source_facility_name TEXT, source_address TEXT, mode TEXT, stop_name TEXT,
          latitude REAL, longitude REAL, straight_distance_raw REAL,
          walking_distance_raw REAL, walking_time_raw REAL, source_row INTEGER,
          source_snapshot TEXT DEFAULT '202607');
        CREATE INDEX facilities_region ON facilities(province, district, is_active);
        CREATE INDEX nearby_facility ON nearby_transit(facility_id, walking_distance_raw);
    """)
    counts = Counter()
    for row_index, row in enumerate(read_rows(facility_path, ("FCLTY_NM", "FCLTY_STATE_VALUE", "DEL_AT")), 2):
        counts["facility_rows"] += 1
        name = clean(row.get("FCLTY_NM"))
        address = clean(row.get("RDNMADR_ONE_NM")) or clean(row.get("FCLTY_ADDR_ONE_NM"))
        detail = clean(row.get("RDNMADR_TWO_NM")) or clean(row.get("FCLTY_ADDR_TWO_NM"))
        lat, lon = coordinates(row.get("FCLTY_LA"), row.get("FCLTY_LO"))
        deleted = clean(row.get("DEL_AT")) == "Y"
        status = clean(row.get("FCLTY_STATE_VALUE"))
        issue = "invalid_name" if not name or "\ufffd" in name else ""
        active = not deleted and status == "정상운영" and not issue
        key = identifier(name, address, detail, row.get("FCLTY_TY_CD"), lat, lon)
        values = (key, name, clean(row.get("INDUTY_NM")), clean(row.get("FCLTY_TY_NM")),
                  address, detail, lat, lon, clean(row.get("FCLTY_TEL_NO")),
                  clean(row.get("FCLTY_HMPG_URL")), clean(row.get("CTPRVN_NM")),
                  clean(row.get("SIGNGU_NM")), status, int(deleted), int(active), issue,
                  clean(row.get("UPDT_DT")), row_index)
        db.execute("""INSERT INTO facilities VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,'202607')
          ON CONFLICT(id) DO UPDATE SET operation_status=excluded.operation_status,
          deleted=excluded.deleted, is_active=excluded.is_active,
          source_updated_at=excluded.source_updated_at, source_row=excluded.source_row
          WHERE excluded.source_updated_at > facilities.source_updated_at""", values)
    db.commit()
    # Only unambiguous name + coordinate/address matches may link the two sources.
    by_point, by_address = defaultdict(set), defaultdict(set)
    for key, name, address, lat, lon in db.execute("SELECT id,name,address,latitude,longitude FROM facilities"):
        if lat is not None:
            by_point[(name, round(lat, 5), round(lon, 5))].add(key)
        if address:
            by_address[(name, address)].add(key)
    for row_index, row in enumerate(read_rows(transit_path, ("ALSFC_NM", "ALSFC_ADDR", "BSTP_SUBWAYST_NM")), 2):
        counts["transit_rows"] += 1
        name, address = clean(row.get("ALSFC_NM")), clean(row.get("ALSFC_ADDR"))
        lat, lon = coordinates(row.get("ALSFC_LA"), row.get("ALSFC_LO"))
        candidates = by_point.get((name, round(lat, 5), round(lon, 5)), set()) if lat is not None else set()
        if not candidates:
            candidates = by_address.get((name, address), set())
        linked = next(iter(candidates)) if len(candidates) == 1 else None
        counts["transit_matched_rows" if linked else "transit_unmatched_rows"] += 1
        stop_lat, stop_lon = coordinates(row.get("PBTRNSP_FCLTY_LA"), row.get("PBTRNSP_FCLTY_LO"))
        mode, stop = clean(row.get("PBTRNSP_FCLTY_SDIV_NM")), clean(row.get("BSTP_SUBWAYST_NM"))
        key = identifier(name, address, lat, lon, mode, stop, stop_lat, stop_lon)
        db.execute("INSERT OR IGNORE INTO nearby_transit VALUES (?,?,?,?,?,?,?,?,?,?,?,?,'202607')",
                   (key, linked, name, address, mode, stop, stop_lat, stop_lon,
                    number(row.get("STRT_DSTNC_VALUE")), number(row.get("WLKG_DSTNC_VALUE")),
                    number(row.get("WLKG_MVMN_TIME")), row_index))
        if row_index % 25000 == 0:
            db.commit()
            print(f"Processed {counts['transit_rows']} transit rows", flush=True)
    db.commit()
    counts["facilities"] = db.execute("SELECT count(*) FROM facilities").fetchone()[0]
    counts["active_facilities"] = db.execute("SELECT count(*) FROM facilities WHERE is_active=1").fetchone()[0]
    counts["transit_stops"] = db.execute("SELECT count(*) FROM nearby_transit").fetchone()[0]
    counts["active_seoul_facilities"] = db.execute("SELECT count(*) FROM facilities WHERE is_active=1 AND province='서울특별시'").fetchone()[0]
    report = dict(counts)
    report["regions"] = dict(db.execute("SELECT province,count(*) FROM facilities WHERE is_active=1 GROUP BY province"))
    report["integrity"] = db.execute("PRAGMA integrity_check").fetchone()[0]
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    db.close()
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--facilities", required=True, type=Path)
    parser.add_argument("--transit", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    build(args.facilities, args.transit, args.output)
