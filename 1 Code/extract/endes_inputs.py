"""Verify the frozen ENDES inventory and prepare small Stata-readable evidence tables."""

import argparse
import csv
import hashlib
from pathlib import Path
import re


MANIFEST = "ENDES-all-project-datasets-2026-11-20-v1.csv"
MANIFEST_SHA = "d7d32b986b1f9468d588675d52e98d3447b242f7c4d98ee419f719c2d5b1b816"
DISTRICT_REVIEW_SHA = "f2c0cdeadb70bf1002f807ffdbb011c06c0ab4fc47d606ebb740e7b9fdb699b7"
EVIDENCE = {
    "locality_adjudication_ledger.csv": "bc705fccc5cecc834df4d3387574f12f0be4658714d2561b54223d7a697afd13",
    "additional_geographic_review_inputs.csv": "8d7c744c7ffd6cfb1e51d12554ceaec23e7e0e04e679933582d63cc0aecdc54e",
    "settlement_reference_index.csv": "b28b36a6ce121356052f1f5632fdec5d0b5599840faebff975fab91b9cb9a948",
    "2015_linkage_evidence_flags.csv": "8cef30d96da73c933e24b4a4c61384790b697e7882e22840e6efd6fd73a959ac",
}
SENSITIVITY = {
    "CSALUD01": (34583, 270, "7e97efaaa34fe4aab6f8a3f5cb11f462e7848b5fec1b2549dfc94a54cf1d1f94"),
    "RECH0": (36692, 45, "eacd48ec89f360b0c197f56430c3a27fdbba8a44460cf2f7e6421b8e3486bc55"),
    "RECH23": (36692, 132, "53646dcda6332890b069ec901476d2a66a241dc961772056a292bfb67f4b4bab"),
}


def read_csv(path):
    with path.open(newline="", encoding="utf-8-sig") as file:
        yield from csv.DictReader(file)


def write_csv(path, rows):
    with path.open("x", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def verify(path, expected):
    with path.open("rb") as file:
        actual = hashlib.file_digest(file, "sha256").hexdigest()
    if actual != expected:
        raise ValueError(f"{path.name}: expected SHA-256 {expected}, observed {actual}")
    return actual


def stage(project, geographic_audit, earlier, crosswalk, output, district_review=None):
    manifest = project / "3 Data" / "0 Support docs" / MANIFEST
    verify(manifest, MANIFEST_SHA)
    modules = []
    provenance = [dict(role="source catalogue", path=manifest.as_posix(), sha256=MANIFEST_SHA)]
    for row in read_csv(manifest):
        path = (project / row["project_relative_path"]).resolve()
        sha = verify(path, row["sha256"])
        core = row["workflow_role"] in ("core preparation", "respondent roster candidate")
        modules.append(dict(wave=row["wave"], table=row["table_id"], role="core" if core else "context",
                            path=path.as_posix(), format=row["format"], rows=row["observations"],
                            variables=row["variable_count"], encoding=row.get("csv_encoding", ""),
                            separator=row.get("csv_separator", ""), sha256=sha, unit=row["unit"],
                            keys=row["key_fields_to_validate"], publisher_url=row["source_publisher_url"],
                            publisher_member=row["source_publisher_member"], dictionary_url=row["dictionary_url"]))
    if len(modules) != 86 or len({(r["wave"], r["table"]) for r in modules}) != 86:
        raise ValueError("Expected the pinned inventory of 86 distinct project inputs.")

    if earlier is not None:
        source_register = {r["local_derivative"]:r for r in read_csv(earlier / "source_manifest.csv")
                           if r["year"]=="2015" and r["local_derivative"]}
        definitions = {"CSALUD01": "Selected person aged 15 or more", "RECH0": "Sampled household",
                       "RECH23": "Sampled household or dwelling characteristics"}
        for table, (rows, variables, sha) in SENSITIVITY.items():
            name = f"2015_{table.lower()}.sav"
            path = earlier / "extracted" / name
            verify(path, sha)
            source = source_register[name]
            if source["derivative_sha256"] != sha:
                raise ValueError(f"2015 source register differs for {name}.")
            dictionary = ("salud" if table == "CSALUD01" else "hogar")
            modules.append(dict(wave=2015, table=table, role="core", path=path.as_posix(), format="sav",
                                rows=rows, variables=variables, encoding="", separator="", sha256=sha,
                                unit=definitions[table], keys="hhid", publisher_url=source["source_url"],
                                publisher_member=source["selected_member"],
                                dictionary_url=f"https://encuestas.inei.gob.pe/endes/recursos/endes_2015_diccionario.rar#{dictionary}"))

    paths = {
        "locality_adjudication_ledger.csv": geographic_audit / "results/locality_adjudication_ledger.csv",
        "additional_geographic_review_inputs.csv": geographic_audit / "results/additional_geographic_review_inputs.csv",
        "settlement_reference_index.csv": geographic_audit / "sources/settlement_reference_index.csv",
    }
    if crosswalk is not None:
        paths["2015_linkage_evidence_flags.csv"] = crosswalk / "sources/2015_linkage_evidence_flags.csv"
    for name, path in paths.items():
        provenance.append(dict(role=name, path=path.as_posix(), sha256=verify(path, EVIDENCE[name])))

    decisions = [dict(wave=r["wave"], native_locality10=r["locality10"], nomccpp=r["endes_name"],
                      case_id=r["case_id"], disposition=r["status"])
                 for r in read_csv(paths["locality_adjudication_ledger.csv"])]
    keys = {(r["wave"], r["native_locality10"], r["nomccpp"]) for r in decisions}
    if len(decisions) != 138 or len(keys) != 138:
        raise ValueError("Expected exactly 138 distinct reviewed name cases.")
    valid_dispositions = {"verified", "point_review", "identity_unresolved"}
    if {r["disposition"] for r in decisions} != valid_dispositions:
        raise ValueError("Unexpected locality review disposition.")
    review = {(r["wave"], r["published_code"], r["endes_name"])
              for r in read_csv(paths["additional_geographic_review_inputs.csv"])
              if r["could_change_regional_roster_side"] == "True" and r["part_of_name_audit"] == "False"}
    if len(review) != 6 or keys & review:
        raise ValueError("Expected six wave-key instances of the four additional possible roster-code switches.")
    exceptions = [dict(wave=w, native_locality10=c, nomccpp=n, code_switch_review=1)
                  for w,c,n in sorted(review)]
    if district_review is not None:
        sha = verify(district_review, DISTRICT_REVIEW_SHA)
        provenance.append(dict(role="district-code adjudication 2026-11-21",
                               path=district_review.as_posix(), sha256=sha))
        statuses = {"confirmed_native": 1, "supported_crosswalk": 2, "hold_code_conflict": 3,
                    "hold_point_conflict": 3, "hold_alias_conflict": 3}
        # Carry the exact published key strings and the approved decision, without audit notes.
        district_rows = [
            dict(wave=r["wave"], source_locality10=r["observed_code"],
                 housing_locality10=r["housing_code"], nomccpp=r["name"],
                 lon_key=r["x"], lat_key=r["y"], district_review_id=r["case"],
                 district_link_status=statuses[r["disposition"]], reviewed_interviews=r["n"],
                 approved_locality10=r["supported_code"])
            for r in read_csv(district_review)
        ]

    # Select independent INEI reference points used by the prior axis audit.
    cartography = {"INEI Census via IDEP", "INEI precensus via OSINFOR", "INEI SDMR"}
    points = set()
    for r in read_csv(paths["settlement_reference_index.csv"]):
        code = r["locality10"]
        if (r["source"] not in cartography or code[:6] != r["district6"] or
                not re.fullmatch(r"[0-9]{10}", code) or not r["lon"] or not r["lat"]):
            continue
        lon, lat = float(r["lon"]), float(r["lat"])
        if -82 < lon < -68 and -19 < lat < 0:
            points.add((code, lon, lat))
    point_rows = [dict(native_locality10=code, reference_lon=lon, reference_lat=lat)
                  for code,lon,lat in sorted(points)]

    output.mkdir()
    write_csv(output / "modules.csv", sorted(modules, key=lambda r: (int(r["wave"]), r["table"])))
    write_csv(output / "locality_reviews.csv", decisions)
    write_csv(output / "geography_exceptions.csv", exceptions)
    if district_review is not None:
        write_csv(output / "district_reviews.csv", district_rows)
    write_csv(output / "inei_reference_points.csv", point_rows)
    if crosswalk is not None:
        linkage = list(read_csv(paths["2015_linkage_evidence_flags.csv"]))
        write_csv(output / "2015_locality_lookup.csv", linkage)
    write_csv(output / "input_provenance.csv", provenance)
    print(f"Verified {len(modules)} ENDES tables, {len(keys)} name review cases and {len(points)} reference points.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project_dropbox", type=Path)
    parser.add_argument("locality_audit", type=Path)
    parser.add_argument("output", type=Path, help="New directory for the staged input tables")
    parser.add_argument("--earlier", type=Path, help="2015 native module and receipt directory")
    parser.add_argument("--crosswalk", type=Path, help="2015 locality evidence directory")
    parser.add_argument("--district-review", type=Path,
                        help="Approved district case ledger required for the 2016–2025 build")
    args = parser.parse_args()
    if bool(args.earlier) != bool(args.crosswalk):
        parser.error("--earlier and --crosswalk are both required for the 2015 sensitivity inputs")
    stage(args.project_dropbox.resolve(), args.locality_audit.resolve(),
          args.earlier.resolve() if args.earlier else None,
          args.crosswalk.resolve() if args.crosswalk else None, args.output.resolve(),
          args.district_review.resolve() if args.district_review else None)
