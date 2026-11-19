"""Stage exact INEI module members for Stata and record their byte-level provenance."""
import argparse
import csv
import hashlib
import io
import pathlib
import sys
import zipfile


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def stage(vintage, plan, split):
    destination = vintage / split
    destination.mkdir()
    with plan.open(encoding="utf-8-sig", newline="") as stream:
        sources = list(csv.DictReader(stream))
    if not sources or len({(r["wave"], r["module"]) for r in sources}) != len(sources):
        raise ValueError("The input plan must contain exactly one row per wave and module.")
    verified = {}
    registry = []
    for row in sources:
        wave, module = row["wave"], row["module"]
        if not wave.isdecimal() or module not in {"csalud01", "rech0", "rech23"}:
            raise ValueError(f"Unexpected wave/module: {wave}/{module}")
        if pathlib.Path(row["source"]).name != row["source"]:
            raise ValueError("Source names must be basenames in the vintage sources folder.")
        source = vintage / "sources" / row["source"]
        if source not in verified:
            verified[source] = sha256(source)
        if verified[source] != row["source_sha256"].lower():
            raise ValueError(f"Source checksum changed: {source.name}")
        member = row["member"]
        extension = pathlib.PurePosixPath(member or source.name).suffix.lower()
        if extension not in {".sav", ".dta", ".csv"}:
            raise ValueError(f"Unexpected module format: {extension}")
        if member:
            with zipfile.ZipFile(source) as archive:
                if archive.namelist().count(member) != 1:
                    raise ValueError(f"A unique exact member is required: {member}")
                content = archive.read(member)
            staged = destination / f"{wave}_{module}{extension}"
            with staged.open("xb") as stream:
                stream.write(content)
        else:
            staged = source
        encoding = ""
        separator = ""
        expected_rows = ""
        if extension == ".csv":
            content = staged.read_bytes()
            try:
                decoded = content.decode("utf-8-sig")
                encoding = "UTF-8"
            except UnicodeDecodeError:
                decoded = content.decode("latin-1")
                encoding = "ISO-8859-1"
            header_line = decoded.splitlines()[0]
            delimiter = max((";", ",", "|"), key=header_line.count)
            separator = {";": "semicolon", ",": "comma", "|": "pipe"}[delimiter]
            reader = csv.reader(io.StringIO(decoded, newline=""), delimiter=delimiter, strict=True)
            header = [name.strip().lower() for name in next(reader)]
            if "hhid" not in header or len(set(header)) != len(header):
                raise ValueError(f"Invalid module header: {source.name} / {member}")
            expected_rows = 0
            for fields in reader:
                if len(fields) != len(header):
                    raise ValueError(f"Nonrectangular CSV: {source.name} / {member}, line {reader.line_num}")
                expected_rows += 1
        registry.append(dict(
            row, file=staged.relative_to(vintage).as_posix(), format=extension[1:],
            encoding=encoding, separator=separator, expected_rows=expected_rows,
            input_sha256=sha256(staged), input_bytes=staged.stat().st_size,
        ))
        print(wave, module, staged.name, expected_rows, sha256(staged), flush=True)
    with (destination / "modules.csv").open("x", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(registry[0]))
        writer.writeheader()
        writer.writerows(registry)
    print(f"Staged {len(registry)} modules with Python {sys.version.split()[0]}.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vintage", type=pathlib.Path)
    parser.add_argument("plan", type=pathlib.Path)
    parser.add_argument("split", choices=("core", "extension"))
    args = parser.parse_args()
    stage(args.vintage.resolve(strict=True), args.plan, args.split)

