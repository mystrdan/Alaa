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
STATUSES = {"draft", "verified", "corroborated", "unverified", "historical",
            "stale", "disputed", "retired"}
SERVICE_TYPES = {"ussd", "sms_short_code", "phone_number", "web_link"}
SERVICE_STATUSES = {"active", "temporary", "seasonal", "historical",
                    "discontinued", "unknown"}
CATEGORIES = {"Telecom", "Government", "Education", "Finance and Payments",
              "Health", "Utilities", "Transport", "Agriculture",
              "Insurance and Pensions", "Commerce", "Other Services"}
ENTRY_KEYS = {"id", "name", "description", "countryCode", "provider", "category",
              "subcategory", "serviceType", "serviceStatus", "dialString",
              "instructions", "networkScope", "eligibility", "costNote",
              "securityWarning", "tags", "sourceUrl", "sourceTitle",
              "sourcePublisher", "verifiedAt", "lastCheckedAt",
              "verificationStatus", "version"}
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]{2,63}$")
REQUIRED = {"id", "name", "description", "countryCode", "provider", "category",
            "serviceType", "dialString", "instructions", "verificationStatus"}


class CatalogueError(ValueError):
    pass


def read_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise CatalogueError(f"{path.relative_to(ROOT)}: cannot read valid JSON ({exc})") from exc


def validate_entry(entry, expected_country, seen_ids, today=None):
    if not isinstance(entry, dict):
        raise CatalogueError(f"{expected_country}: every entry must be an object")
    missing = REQUIRED - entry.keys()
    if missing:
        raise CatalogueError(f"entry missing required fields: {', '.join(sorted(missing))}")
    unknown = entry.keys() - ENTRY_KEYS
    if unknown:
        raise CatalogueError(f"{entry.get('id', '<unknown>')}: unknown fields: {', '.join(sorted(unknown))}")
    for field in ("id", "name", "description", "provider", "category"):
        if not isinstance(entry[field], str) or not entry[field].strip():
            raise CatalogueError(f"{entry.get('id', '<unknown>')}: {field} must be a non-empty string")
    if not ID_PATTERN.fullmatch(entry["id"]):
        raise CatalogueError(f"{entry['id']}: id must match {ID_PATTERN.pattern}")
    if entry["countryCode"] != expected_country:
        raise CatalogueError(f"{entry['id']}: countryCode does not match {expected_country} file")
    if entry["category"] not in CATEGORIES:
        raise CatalogueError(f"{entry['id']}: unsupported category")
    if entry["serviceType"] not in SERVICE_TYPES:
        raise CatalogueError(f"{entry['id']}: unsupported serviceType")
    service_status = entry.get("serviceStatus", "unknown")
    if service_status not in SERVICE_STATUSES:
        raise CatalogueError(f"{entry['id']}: unsupported serviceStatus")
    if service_status in {"historical", "discontinued"} and entry["verificationStatus"] == "verified":
        raise CatalogueError(f"{entry['id']}: {service_status} services cannot be marked verified")
    for list_field in ("instructions", "tags"):
        if list_field in entry and (not isinstance(entry[list_field], list)
                                    or not all(isinstance(x, str) for x in entry[list_field])):
            raise CatalogueError(f"{entry['id']}: {list_field} must be a list of strings")
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

    source = entry.get("sourceUrl")
    if source is not None and (not isinstance(source, str) or urlparse(source).scheme != "https" or not urlparse(source).netloc):
        raise CatalogueError(f"{entry['id']}: sourceUrl must be an HTTPS URL when present")

    today = today or date.today()
    verified_at = entry.get("verifiedAt")
    if verified_at is not None:
        if not isinstance(verified_at, str):
            raise CatalogueError(f"{entry['id']}: verifiedAt must be YYYY-MM-DD")
        try:
            checked = date.fromisoformat(verified_at)
        except ValueError as exc:
            raise CatalogueError(f"{entry['id']}: verifiedAt must be YYYY-MM-DD") from exc
        if checked > today:
            raise CatalogueError(f"{entry['id']}: verifiedAt must not be in the future")

    if entry["verificationStatus"] == "verified":
        if source is None:
            raise CatalogueError(f"{entry['id']}: verified entries require an HTTPS sourceUrl")
        if verified_at is None:
            raise CatalogueError(f"{entry['id']}: verified entries require verifiedAt (YYYY-MM-DD)")
        if not entry["dialString"].strip():
            raise CatalogueError(f"{entry['id']}: verified entries require a dialString")
        if not entry["instructions"]:
            raise CatalogueError(f"{entry['id']}: verified entries require at least one instruction")


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
