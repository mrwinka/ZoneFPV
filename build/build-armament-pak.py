"""Build and verify the additive, namespaced ZoneFPV explosion config PAK."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
ENTRY = "Stalker2/Content/GameLite/GameData/ExplosionPrototypes/ExplosionPrototypes_patch_ZoneFPVWeapons.cfg"
EFFECT_ENTRY = "Stalker2/Content/GameLite/GameData/EffectPrototypes/EffectPrototypes_patch_ZoneFPVWeapons.cfg"
SOURCE_ROOT = ROOT / "pak_sources" / "ZoneFPV_Armament_P"
SOURCE = SOURCE_ROOT / ENTRY
EFFECT_SOURCE = SOURCE_ROOT / EFFECT_ENTRY
PAK = ROOT / "packages" / "ZoneFPV_Armament_P.pak"
MANIFEST = PAK.with_suffix(".manifest.json")
MOUNT = "../../../"
BASE_REFERENCE_SHA256 = "76622aa6afc4a72d73b064cf21c5d26752ca8cc8a628c14c983d11ff8eaee2cc"
EFFECT_REFERENCE_SHA256 = "5f8e2596899a4e73f56753bdbfbeacb1227459e5b1e521c6e86d5595fd20c0d4"
PRIVATE_BASE = "ZoneFPV_Kamikaze_PlayerFeedbackNone"
NOOP_SID = "ZoneFPV_PlayerBlastFeedbackNone"
# The installed EffectPrototypes[0] declares Type=EEffectType::None. Give our
# no-op a nonempty namespaced SID instead of relying on reserved Empty lookup.
# Keep every native physical-material key, replacing only its player feedback
# effect, so recursive reference merging cannot leak inherited blast timelines.
PHYSICAL_MATERIALS = ("Puddle", "Water", "Dirt", "Ground", "ForestGrass", "Default",
                      "Rock", "Brick", "Asphalt", "Gravel", "WoodThin", "WoodSolid", "Tree", "Sand")
# Resolved ExplosionF1 values from the decoded shipping config. Curves,
# audio, Niagara VFX, NPC concussion and armor penetration remain inherited.
LINEAR = {
    "DamagePlayer": 100,
    "DamageNPC": 260,
    "DamageArmorPlayer": 30,
    "DamageArmorNPC": 0,
    "DamageDestructible": 2000,
    "ImpulsePower": 30000,
}
RADII = {
    "Radius": 1000,
    "ImpulseRadius": 750,
    "ForceFeedbackRadius": 1000,
    "ConcussionRadius": 800,
}


def cfg_number(value: float) -> str:
    number = f"{value:.6f}".rstrip("0").rstrip(".")
    return number if "." in number else number + "."


def feedback_base_lines() -> list[str]:
    lines = [f"{PRIVATE_BASE} : struct.begin {{refurl=../ExplosionPrototypes.cfg; refkey=ExplosionF1}}",
             f"   SID = {PRIVATE_BASE}",
             "   // A namespaced EEffectType::None prototype prevents player-only feedback at its source.",
             "   // These lists affect player feedback only; NPCConcussionEffects stays inherited.",
             "   ConcussionEffects : struct.begin", f"      [0] = {NOOP_SID}", "   struct.end",
             "   PhysicalMaterialEffects : struct.begin"]
    for index, physical in enumerate(PHYSICAL_MATERIALS):
        lines.extend([f"      [{index}] : struct.begin",
                      f"         PhysicalMaterialType = EPhysicalMaterialType::{physical}",
                      "         EffectSIDs : struct.begin", f"            [0] = {NOOP_SID}",
                      "         struct.end", "      struct.end"])
    lines.extend(["   struct.end", "   DefaultEffectSIDs : struct.begin", f"      [0] = {NOOP_SID}",
                  "   struct.end", "struct.end", ""])
    return lines


def effect_source_bytes() -> bytes:
    return (f"// Additive player-feedback no-op used only by ZoneFPV kamikaze.\n"
            f"{NOOP_SID} : struct.begin {{refurl=../EffectPrototypes.cfg; refkey=[0]}}\n"
            f"   SID = {NOOP_SID}\n"
            "   Type = EEffectType::None\n   Duration = 0.\n   bIsPermanent = false\nstruct.end\n").encode('utf-8')


def validate_effect_source(data: bytes) -> None:
    if data != effect_source_bytes():
        raise ValueError('Effect config must contain exactly the namespaced Type::None prototype')


def source_bytes() -> bytes:
    lines = [
        "// ZoneFPV armament: additive explosion definitions only.",
        "// Power: 0.25 .. 5 in 0.25 steps; native grenades remain unchanged.",
        "// Damage and impulse scale linearly; radii scale by sqrt(power).",
        "// Own kamikaze never starts player concussion/surface-dirt timelines.",
        "",
    ]
    lines.extend(feedback_base_lines())
    for index in range(1, 21):
        sid = f"ZoneFPV_Kamikaze_{index:02d}"
        power = index / 4
        lines.append(f"{sid} : struct.begin {{refkey={PRIVATE_BASE}}}")
        lines.append(f"   SID = {sid}")
        for field, base in LINEAR.items():
            lines.append(f"   {field} = {cfg_number(base * power)}")
        for field, base in RADII.items():
            lines.append(f"   {field} = {cfg_number(base * math.sqrt(power))}")
        lines.extend(["struct.end", ""])
    return ("\n".join(lines) + "\n").encode("utf-8")


def validate_source(data: bytes) -> None:
    text = data.decode("utf-8")
    definitions = re.findall(
        r"^(ZoneFPV_Kamikaze_\d{2}) : struct\.begin \{refkey="+PRIVATE_BASE+r"\}\n(.*?)^struct\.end$",
        text,
        re.M | re.S,
    )
    expected_names = [f"ZoneFPV_Kamikaze_{index:02d}" for index in range(1, 21)]
    if [name for name, _ in definitions] != expected_names:
        raise ValueError("Expected exactly the 20 unique ZoneFPV power definitions")
    # No original-node replacement, broad config replacement, removal or patch.
    headers = re.findall(r"^(\S+)\s*:\s*struct\.begin", text, re.M)
    if headers != [PRIVATE_BASE]+expected_names or "bpatch" in text or "removenode" in text:
        raise ValueError("Armament config must add only namespaced definitions")
    expected_base="\n".join(feedback_base_lines())
    if text.count(expected_base)!=1:
        raise ValueError("Missing or changed private player-feedback-free base")
    for index, (name, body) in enumerate(definitions, 1):
        properties = dict(re.findall(r"^\s*(\w+)\s*=\s*(\S+)\s*$", body, re.M))
        if properties.pop("SID", None) != name:
            raise ValueError(f"SID/header mismatch for {name}")
        if set(properties) != set(LINEAR) | set(RADII):
            raise ValueError(f"Unexpected or missing prototype properties for {name}")
        power = index / 4
        for field, base in LINEAR.items():
            if not math.isclose(float(properties[field]), base * power, abs_tol=1e-6):
                raise ValueError(f"Wrong linear scaling: {name}.{field}")
        for field, base in RADII.items():
            if not math.isclose(float(properties[field]), base * math.sqrt(power), abs_tol=1e-6):
                raise ValueError(f"Wrong radius scaling: {name}.{field}")


def run(repak: Path, *args: str) -> bytes:
    result = subprocess.run([str(repak), *args], check=True, capture_output=True)
    return result.stdout


def verify_pak(repak: Path, expected: bytes) -> dict:
    entries = run(repak, "list", str(PAK)).decode("utf-8").splitlines()
    if len(entries)!=2 or set(entries)!={ENTRY,EFFECT_ENTRY}:
        raise ValueError(f"PAK should contain exactly its two additive configs, got {entries!r}")
    info = run(repak, "info", str(PAK)).decode("utf-8")
    if not re.search(r"Mount point:\s*\.\./\.\./\.\./\s*$", info, re.M | re.I):
        raise ValueError(f"Unexpected PAK mount point: {info}")
    unpacked = run(repak, "get", str(PAK), ENTRY)
    if unpacked != expected:
        raise ValueError("PAK round-trip bytes differ from the validated source")
    unpacked_effect=run(repak, "get", str(PAK), EFFECT_ENTRY)
    validate_effect_source(unpacked_effect)
    return {
        "schema": 1,
        "mount_point": MOUNT,
        "entry": ENTRY,
        "entries": [ENTRY,EFFECT_ENTRY],
        "prototype_sids": [f"ZoneFPV_Kamikaze_{index:02d}" for index in range(1, 21)],
        "base_prototype": "ExplosionF1",
        "private_base_prototype": PRIVATE_BASE,
        "player_feedback_effect_sid": NOOP_SID,
        "player_feedback_effect_type": "EEffectType::None",
        "decoded_effect_reference_sha256": EFFECT_REFERENCE_SHA256,
        "inherited_npc_concussion_effect": "KnockDownAIOnly",
        "decoded_base_reference_sha256": BASE_REFERENCE_SHA256,
        "native_grenade_prototypes_unchanged": ["ExplosionRGD5", "ExplosionF1"],
        "power_min": .25,
        "power_max": 5,
        "power_step": .25,
        "damage_and_impulse_scaling": "power",
        "radius_scaling": "sqrt(power)",
        "cfg_sha256": hashlib.sha256(expected).hexdigest(),
        "effect_cfg_sha256": hashlib.sha256(unpacked_effect).hexdigest(),
        "pak_sha256": hashlib.sha256(PAK.read_bytes()).hexdigest(),
        "repak_sha256": hashlib.sha256(repak.read_bytes()).hexdigest(),
        "repak_version": run(repak, "--version").decode("utf-8").strip(),
        "pak_info": info.strip(),
        "verified": ["source structure", "private player-feedback-free base with all14 physical-material entries and default fallback", "namespaced no-op with proven Type::None and valid default-template reference", "20 scalar power steps", "two additive entries only", "mount point", "binary round trip"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repak", type=Path, default=ROOT.parent / "research" / "repak" / "repak.exe")
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    expected = source_bytes()
    validate_source(expected)
    expected_effect=effect_source_bytes()
    validate_effect_source(expected_effect)
    if args.verify_only:
        if SOURCE.read_bytes() != expected:
            raise ValueError("Checked source differs from reproducible generated config")
        if EFFECT_SOURCE.read_bytes()!=expected_effect:
            raise ValueError('Checked effect source differs from generated no-op')
    else:
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        SOURCE.write_bytes(expected)
        EFFECT_SOURCE.parent.mkdir(parents=True, exist_ok=True)
        EFFECT_SOURCE.write_bytes(expected_effect)
        PAK.parent.mkdir(parents=True, exist_ok=True)
        run(args.repak, "pack", "--version", "V11", "--mount-point", MOUNT, str(SOURCE_ROOT), str(PAK))
    manifest = verify_pak(args.repak, expected)
    if not args.verify_only:
        MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    else:
        stored = json.loads(MANIFEST.read_text(encoding="utf-8"))
        if stored != manifest:
            raise ValueError("Saved verification manifest differs from the current PAK/source")
    print(f"PASS additive armament PAK: 20 power steps, exact source round trip, {PAK.stat().st_size} bytes")
    print(f"SHA256 {manifest['pak_sha256']}")


if __name__ == "__main__":
    main()
