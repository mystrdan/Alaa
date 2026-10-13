import hashlib
import json
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest.mock import patch

import validate_catalogue as validator


def make_entry(**overrides):
    entry = {
        "id": "sample-entry",
        "name": "Sample",
        "description": "Sample service",
        "countryCode": "GH",
        "provider": "Example",
        "category": "Telecom",
        "serviceType": "ussd",
        "dialString": "*123#",
        "instructions": ["Dial *123#."],
        "verificationStatus": "draft",
    }
    entry.update(overrides)
    return entry


class CatalogueValidatorTests(unittest.TestCase):
    def test_current_development_scaffold_passes(self):
        self.assertEqual(validator.validate_catalogue(), 38)

    def test_verified_entry_requires_https_source_and_date(self):
        entry = make_entry(verificationStatus="verified")
        with self.assertRaisesRegex(validator.CatalogueError, "HTTPS sourceUrl"):
            validator.validate_entry(entry, "GH", set())

    def test_verified_entry_requires_nonempty_instructions(self):
        entry = make_entry(
            verificationStatus="verified",
            sourceUrl="https://example.com/help",
            verifiedAt=date.today().isoformat(),
            instructions=[],
        )
        with self.assertRaisesRegex(validator.CatalogueError, "instruction"):
            validator.validate_entry(entry, "GH", set())

    def test_duplicate_ids_are_rejected(self):
        entry = make_entry()
        seen = set()
        validator.validate_entry(entry, "GH", seen)
        with self.assertRaisesRegex(validator.CatalogueError, "duplicate"):
            validator.validate_entry(entry, "GH", seen)

    def test_missing_required_fields_are_rejected(self):
        entry = make_entry()
        del entry["provider"]
        with self.assertRaisesRegex(validator.CatalogueError, "missing required fields"):
            validator.validate_entry(entry, "GH", set())

    def test_unknown_enum_values_are_rejected(self):
        with self.assertRaisesRegex(validator.CatalogueError, "unsupported category"):
            validator.validate_entry(make_entry(category="Crypto"), "GH", set())
        with self.assertRaisesRegex(validator.CatalogueError, "unsupported serviceType"):
            validator.validate_entry(make_entry(serviceType="telepathy"), "GH", set())
        with self.assertRaisesRegex(validator.CatalogueError, "unsupported verificationStatus"):
            validator.validate_entry(make_entry(verificationStatus="trusted"), "GH", set())

    def test_unknown_fields_are_rejected(self):
        with self.assertRaisesRegex(validator.CatalogueError, "unknown fields"):
            validator.validate_entry(make_entry(releaseSigned=True), "GH", set())

    def test_country_mismatch_is_rejected(self):
        entry = make_entry(id="ng-sample", countryCode="NG")
        with self.assertRaisesRegex(validator.CatalogueError, "does not match GH"):
            validator.validate_entry(entry, "GH", set())

    def test_invalid_id_format_is_rejected(self):
        with self.assertRaisesRegex(validator.CatalogueError, "id must match"):
            validator.validate_entry(make_entry(id="Bad_ID"), "GH", set())

    def test_non_https_source_url_is_rejected_even_for_drafts(self):
        with self.assertRaisesRegex(validator.CatalogueError, "HTTPS URL"):
            validator.validate_entry(make_entry(sourceUrl="http://example.com"), "GH", set())

    def test_future_verified_at_is_rejected(self):
        future = date.today().replace(year=date.today().year + 1).isoformat()
        with self.assertRaisesRegex(validator.CatalogueError, "not be in the future"):
            validator.validate_entry(make_entry(verifiedAt=future), "GH", set())

    def test_malformed_verified_date_is_rejected(self):
        with self.assertRaisesRegex(validator.CatalogueError, "YYYY-MM-DD"):
            validator.validate_entry(make_entry(verifiedAt="yesterday"), "GH", set())

    def test_release_mode_rejects_development_manifest(self):
        with self.assertRaisesRegex(validator.CatalogueError, "status 'release'"):
            validator.validate_catalogue(release=True)


class ManifestPathSafetyTests(unittest.TestCase):
    def _write_fixture(self, root, manifest):
        cat = root / "catalogue"
        (cat / "countries" / "GH").mkdir(parents=True)
        (cat / "countries" / "NG").mkdir(parents=True)
        (cat / "countries" / "GH" / "services.json").write_text(
            json.dumps({"countryCode": "GH", "entries": []}), encoding="utf-8")
        (cat / "countries" / "NG" / "services.json").write_text(
            json.dumps({"countryCode": "NG", "entries": []}), encoding="utf-8")
        (cat / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
        (cat / "schema.json").write_text(
            json.dumps({"type": "object", "required": []}), encoding="utf-8")

    def test_unsafe_manifest_paths_are_rejected(self):
        for bad_path in ("../escape.json", "countries/../../evil.json",
                         "/etc/passwd", "countries/GH/../../manifest.json"):
            manifest = {"files": [{"path": bad_path, "sha256": None}]}
            with tempfile.TemporaryDirectory() as tmp:
                self._write_fixture(Path(tmp), manifest)
                with self.subTest(path=bad_path):
                    with patch.object(validator, "CATALOGUE", Path(tmp) / "catalogue"):
                        with self.assertRaisesRegex(validator.CatalogueError, "unsafe manifest path|escapes catalogue|unexpected catalogue data path"):
                            validator.validate_catalogue()

    def test_hash_mismatch_is_rejected(self):
        manifest = {
            "files": [
                {"path": "countries/GH/services.json", "sha256": "0" * 64},
                {"path": "countries/NG/services.json", "sha256": None},
            ],
        }
        with tempfile.TemporaryDirectory() as tmp:
            self._write_fixture(Path(tmp), manifest)
            with patch.object(validator, "CATALOGUE", Path(tmp) / "catalogue"):
                with self.assertRaisesRegex(validator.CatalogueError, "sha256 mismatch"):
                    validator.validate_catalogue()


if __name__ == "__main__":
    unittest.main()


if __name__ == "__main__":
    unittest.main()
