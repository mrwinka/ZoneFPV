"""Verify armament data boundaries, inherited behavior and isolation."""
import importlib.util
from pathlib import Path
import re
import unittest

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("armament_pak", root / "build" / "build-armament-pak.py")
pak = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pak)


class ArmamentPakTests(unittest.TestCase):
    def test_only_namespaced_definitions(self):
        text = pak.source_bytes().decode()
        pak.validate_source(text.encode())
        self.assertEqual(text.count("struct.begin"), 20)
        self.assertEqual(text.count("struct.end"), 20)
        self.assertNotRegex(text, r"(?m)^Explosion(?:RGD5|F1)\s*:")
        self.assertNotIn("bpatch", text)
        self.assertNotIn("NiagaraSystem", text)
        self.assertNotIn("AkAudio", text)
        self.assertEqual(text.count("refkey=ExplosionF1"), 20)

    def test_effective_values(self):
        blocks = dict(re.findall(r"(ZoneFPV_Kamikaze_\d+) : .*?\n(.*?)struct.end", pak.source_bytes().decode(), re.S))
        weak = blocks["ZoneFPV_Kamikaze_01"]
        normal = blocks["ZoneFPV_Kamikaze_04"]
        strong = blocks["ZoneFPV_Kamikaze_20"]
        def number(block, name):
            return float(re.search(rf"(?m)^\s*{name}\s*=\s*([\d.]+)$", block).group(1))
        self.assertEqual(number(weak, "DamagePlayer"), 25)
        self.assertEqual(number(weak, "DamageNPC"), 65)
        self.assertEqual(number(weak, "Radius"), 500)
        self.assertEqual(number(weak, "ImpulseRadius"), 375)
        self.assertEqual(number(normal, "DamageNPC"), 260)
        self.assertEqual(number(normal, "DamagePlayer"), 100)
        self.assertEqual(number(normal, "Radius"), 1000)
        self.assertEqual(number(normal, "ImpulsePower"), 30000)
        self.assertEqual(number(strong, "DamageNPC"), 1300)
        self.assertEqual(number(strong, "DamageDestructible"), 10000)
        self.assertEqual(number(strong, "ImpulsePower"), 150000)
        self.assertAlmostEqual(number(strong, "Radius"), 2236.067977, places=5)
        self.assertEqual(number(strong, "DamageArmorNPC"), 0)

    def test_validator_rejects_bad_or_conflicting_data(self):
        valid = pak.source_bytes()
        for invalid in [
            valid.replace(b"ZoneFPV_Kamikaze_01", b"ExplosionF1"),
            valid.replace(b"DamageNPC = 65.", b"DamageNPC = 999."),
            valid.replace(b"Radius = 500.", b"Radius = 0."),
            valid.replace(b"SID = ZoneFPV_Kamikaze_20", b"SID = ZoneFPV_Kamikaze_19"),
            valid + b"ExplosionF1 : struct.begin {bpatch}\nstruct.end\n",
        ]:
            with self.subTest(invalid=invalid[:100]):
                with self.assertRaises(ValueError):
                    pak.validate_source(invalid)


if __name__ == "__main__":
    unittest.main()
