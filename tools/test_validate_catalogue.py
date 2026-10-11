import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import validate_catalogue as validator


class CatalogueValidatorTests(unittest.TestCase):
    def test_current_development_scaffold_passes(self):
        self.assertEqual(validator.validate_catalogue(), 0)

    def test_verified_entry_requires_https_source_and_date(self):
        entry = {
            "id": "sample", "name": "Sample", "description": "Sample service",
            "countryCode": "GH", "provider": "Example", "category": "account",
            "serviceType": "ussd", "dialString": "*123#", "instructions": [],
            "verificationStatus": "verified",
        }
        with self.assertRaisesRegex(validator.CatalogueError, "HTTPS sourceUrl"):
            validator.validate_entry(entry, "GH", set())

    def test_duplicate_ids_are_rejected(self):
        entry = {
            "id": "same", "name": "Sample", "description": "Sample service",
            "countryCode": "GH", "provider": "Example", "category": "account",
            "serviceType": "ussd", "dialString": "*123#", "instructions": [],
            "verificationStatus": "draft",
        }
        seen = set()
        validator.validate_entry(entry, "GH", seen)
        with self.assertRaisesRegex(validator.CatalogueError, "duplicate"):
            validator.validate_entry(entry, "GH", seen)

    def test_release_mode_rejects_development_manifest(self):
        with self.assertRaisesRegex(validator.CatalogueError, "status 'release'"):
            validator.validate_catalogue(release=True)


if __name__ == "__main__":
    unittest.main()
