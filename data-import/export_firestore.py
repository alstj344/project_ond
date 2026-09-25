"""Export active facility documents, not invented bookable programs."""
import argparse
import json
import sqlite3
from pathlib import Path


def export(database, output, province=None):
    db = sqlite3.connect(f"file:{database.resolve()}?mode=ro", uri=True)
    db.row_factory = sqlite3.Row
    query = """SELECT * FROM facilities WHERE is_active=1 AND address != ''
        AND instr(address, char(65533))=0 AND province != '' AND province NOT GLOB '*[0-9]*'"""
    params = []
    if province:
        query += " AND province=?"
        params.append(province)
    count = 0
    with output.open("x", encoding="utf-8") as target:
        for row in db.execute(query + " ORDER BY id", params):
            stops = []
            for stop in db.execute("""SELECT * FROM nearby_transit WHERE facility_id=?
                ORDER BY walking_distance_raw IS NULL, walking_distance_raw, id LIMIT 5""", (row["id"],)):
                stops.append({"name": stop["stop_name"], "mode": stop["mode"],
                              "latitude": stop["latitude"], "longitude": stop["longitude"],
                              "sourceMetrics": {"STRT_DSTNC_VALUE": stop["straight_distance_raw"],
                                                "WLKG_DSTNC_VALUE": stop["walking_distance_raw"],
                                                "WLKG_MVMN_TIME": stop["walking_time_raw"]}})
            doc = {"id": "ks_" + row["id"], "name": row["name"],
                   "category": row["category"], "facilityType": row["facility_type"],
                   "address": row["address"], "addressDetail": row["address_detail"],
                   "latitude": row["latitude"], "longitude": row["longitude"],
                   "phone": row["phone"], "website": row["website"],
                   "province": row["province"], "district": row["district"],
                   "sourceOperationStatus": row["operation_status"],
                   "bookingEnabled": False, "nearbyTransit": stops,
                   "source": {"dataset": "KS_WNTY_PHSTRN_FCLTY_STTUS", "snapshot": "202607",
                              "updatedAt": row["source_updated_at"], "row": row["source_row"]}}
            target.write(json.dumps(doc, ensure_ascii=False) + "\n")
            count += 1
    db.close()
    print(json.dumps({"exported": count, "province": province, "output": str(output)}, ensure_ascii=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--province")
    args = parser.parse_args()
    export(args.database, args.output, args.province)
