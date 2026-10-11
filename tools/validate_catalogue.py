#!/usr/bin/env python3
"""Validate Alaa's offline catalogue using only the Python standard library.

This is a repository/build-time guard, not runtime signature verification.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import date
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
CATALOGUE = ROOT / "catalogue"
COUNTRIES = {"GH", "NG"}
STATUSES = {"draft", "verified", "stale", "disputed", "retired"}
SERVICE_TYPES = {"ussd", "sms_short_code", "phone_number", "web_link"}
REQUIRED = {"id", "name", "description", "countryCode", "provider", "category",
            "serviceType", "dialString", "instructions", "verificationStatus"}


class CatalogueError(ValueError):
    pass


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CatalogueError(f"{path.relative_to(ROOT)}: cannot read valid JSON ({exc})") from exc


def validate_entry(entry, expected_country, seen_ids):
    if not isinstance(entry, dict):
        raise CatalogueError(f"{expected_country}: every entry must be an object")
    missing = REQUIRED - entry.keys()
    if missing:
        raise CatalogueError(f"entry missing required fields: {', '.join(sorted(missing))}")
    for field in ("id", "name", "description", "provider", "category"):
        if not isinstance(entry[field], str) or not entry[field].strip():
            raise CatalogueError(f"{entry.get('id', '<unknown>')}: {field} must be a non-empty string")
    if entry["countryCode"] != expected_country:
        raise CatalogueError(f"{entry['id']}: countryCode does not match {expected_country} file")
    if entry["serviceType"] not in SERVICE_TYPES:
        raise CatalogueError(f"{entry['id']}: unsupported serviceType")
    if entry["verificationStatus"] not in STATUSES:
        raise CatalogueError(f"{entry['id']}: unsupported verificationStatus")
    if not isinstance(entry["dialString"], str):
        raise CatalogueError(f"{entry['id']}: dialString must be a string")
    if not isinstance(entry["instructions"], list) or not all(isinstance(x, str) for x in entry["instructions"]):
        raise CatalogueError(f"{entry['id']}: instructions must be a list of strings")
    if "version" in entry and (type(entry["version"]) is not int or entry["version"] < 1):
        raise CatalogueError(f"{entry['id']}: version must be a positive integer")
    if entry["id"] in seen_ids:
        raise CatalogueError(f"duplicate entry id: {entry['id']}")
    seen_ids.add(entry["id"])
    if entry["verificationStatus"] == "verified":
        source = entry.get("sourceUrl")
        verified_at = entry.get("verifiedAt")
        if not isinstance(source, str) or urlparse(source).scheme != "https" or not urlparse(source).netloc:
            raise CatalogueError(f"{entry['id']}: verified entries require an HTTPS sourceUrl")
        if not isinstance(verified_at, str):
            raise CatalogueError(f"{entry['id']}: verified entries require verifiedAt (YYYY-MM-DD)")
        try:
            date.fromisoformat(verified_at)
        except ValueError as exc:
            raise CatalogueError(f"{entry['id']}: verifiedAt must be YYYY-MM-DD") from exc
        if not entry["dialString"].strip():
            raise CatalogueError(f"{entry['id']}: verified entries require a dialString")


def validate_catalogue(release=False):
    manifest_path = CATALOGUE / "manifest.json"
    manifest = read_json(manifest_path)
    if not isinstance(manifest, dict) or not isinstance(manifest.get("files"), list):
        raise CatalogueError("manifest.json must contain a files array")
    schema_path = CATALOGUE / "schema.json"
    schema = read_json(schema_path)
    if schema.get("type") != "object" or not isinstance(schema.get("required"), list):
        raise CatalogueError("schema.json is missing basic object/required declarations")

    if release:
        if manifest.get("status") != "release":
            raise CatalogueError("release validation requires manifest status 'release'")
        if not manifest.get("signature") or not manifest.get("updatedAt"):
            raise CatalogueError("release manifest requires signature and updatedAt")
    elif manifest.get("status") == "development":
        print("NOTICE: development scaffold; no catalogue signature is verified.")

    seen_ids = set()
    listed_paths = set()
    for item in manifest["files"]:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str):
            raise CatalogueError("each manifest file needs a path")
        relative = Path(item["path"])
        if relative.is_absolute() or ".." in relative.parts or not relative.parts:
            raise CatalogueError(f"unsafe manifest path: {item['path']}")
        target = (CATALOGUE / relative).resolve()
        if not target.is_relative_to(CATALOGUE.resolve()):
            raise CatalogueError(f"manifest path escapes catalogue: {item['path']}")
        if target in listed_paths:
            raise CatalogueError(f"duplicate manifest path: {item['path']}")
        listed_paths.add(target)
        if not target.is_file():
            raise CatalogueError(f"manifest file missing: {item['path']}")
        expected_hash = item.get("sha256")
        if expected_hash is None:
            if release:
                raise CatalogueError(f"release manifest requires sha256 for {item['path']}")
        elif not isinstance(expected_hash, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_hash):
            raise CatalogueError(f"invalid sha256 for {item['path']}")
        elif hashlib.sha256(target.read_bytes()).hexdigest() != expected_hash:
            raise CatalogueError(f"sha256 mismatch for {item['path']}")

        payload = read_json(target)
        country_match = re.fullmatch(r"countries/(GH|NG)/services\.json", item["path"])
        if not country_match:
            raise CatalogueError(f"unexpected catalogue data path: {item['path']}")
        country = country_match.group(1)
        if payload.get("countryCode") != country or not isinstance(payload.get("entries"), list):
            raise CatalogueError(f"{item['path']}: expected countryCode and entries array")
        for entry in payload["entries"]:
            validate_entry(entry, country, seen_ids)

    expected = {CATALOGUE / "countries" / c / "services.json" for c in COUNTRIES}
    if listed_paths != expected:
        raise CatalogueError("manifest must list exactly the GH and NG services files")
    print(f"Catalogue validation passed: {len(seen_ids)} entries across {len(listed_paths)} files.")
    return len(seen_ids)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", action="store_true", help="require release metadata and file hashes")
    args = parser.parse_args()
    try:
        validate_catalogue(release=args.release)
    except CatalogueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
