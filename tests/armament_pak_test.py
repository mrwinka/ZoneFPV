"""Verify armament data boundaries, inherited behavior and isolation."""
import importlib.util
import copy
from pathlib import Path
import re
import unittest

root = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("armament_pak", root / "build" / "build-armament-pak.py")
pak = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pak)


def parse_cfg(text):
    """Small independent parser for balanced cfg nodes, refs and indexed maps."""
    root = {"fields": {}}
    stack = [root]
    for raw in text.splitlines():
        line = raw.split('//', 1)[0].strip()
        if not line:
            continue
        if line == 'struct.end':
            if len(stack) == 1:
                raise ValueError('unbalanced end')
            stack.pop()
            continue
        header = re.fullmatch(r'(\S+)\s*:\s*struct\.begin\s*(?:\{([^}]+)\})?', line)
        if header:
            name, attrs = header.groups()
            node = {"fields": {}, "attrs": dict(re.findall(r'(\w+)=([^; }]+)', attrs or ''))}
            if name in stack[-1]['fields']:
                raise ValueError('duplicate node '+name)
            stack[-1]['fields'][name] = node
            stack.append(node)
            continue
        prop = re.fullmatch(r'(\S+)\s*=\s*(.*)', line)
        if not prop or len(stack) == 1:
            raise ValueError('unsupported cfg: '+line)
        key, value = prop.groups()
        if key in stack[-1]['fields']:
            raise ValueError('duplicate property '+key)
        stack[-1]['fields'][key] = value
    if len(stack) != 1:
        raise ValueError('unterminated struct')
    return root['fields']


def resolve_cfg(nodes, name):
    def merge(base, override):
        out = copy.deepcopy(base)
        for key, value in override.items():
            out[key] = merge(out[key], value) if isinstance(value, dict) and isinstance(out.get(key), dict) else copy.deepcopy(value)
        return out
    def resolve(node, seen):
        reference = node.get('attrs', {}).get('refkey')
        if reference in seen:
            raise ValueError('reference cycle')
        base = resolve(nodes[reference], seen | {reference}) if reference else {}
        own = {key: resolve(value, seen) if isinstance(value, dict) else value for key, value in node['fields'].items()}
        return merge(base, own)
    return resolve(nodes[name], {name})


class ArmamentPakTests(unittest.TestCase):
    def test_only_namespaced_definitions(self):
        text = pak.source_bytes().decode()
        pak.validate_source(text.encode())
        self.assertEqual(len(parse_cfg(text)), 21)
        self.assertEqual(text.count("struct.begin"), text.count("struct.end"))
        self.assertNotRegex(text, r"(?m)^Explosion(?:RGD5|F1)\s*:")
        self.assertNotIn("bpatch", text)
        self.assertNotIn("NiagaraSystem", text)
        self.assertNotIn("AkAudio", text)
        self.assertEqual(text.count("refkey=ExplosionF1"), 1)
        self.assertEqual(text.count("refkey="+pak.PRIVATE_BASE), 20)

    def test_resolved_feedback_cannot_inherit_surface_timeline(self):
        # An independent reference fixture carries the same nested-map shape
        # and an unrelated future field. Resolve the actual serialized config,
        # rather than asserting only that generator strings contain a no-op.
        fixture = '''Empty : struct.begin
   SID = Empty
   ConcussionEffects : struct.begin
      [0] = ConcussionComposite
   struct.end
   NPCConcussionEffects : struct.begin
      [0] = KnockDownAIOnly
   struct.end
   DefaultEffectSIDs : struct.begin
      [0] = ExplosionRockPostProcess
   struct.end
   UnrelatedGameplayFlag = PreserveMe
   PhysicalMaterialEffects : struct.begin
'''
        for index, physical in enumerate(pak.PHYSICAL_MATERIALS):
            fixture += f'''      [{index}] : struct.begin
         PhysicalMaterialType = EPhysicalMaterialType::{physical}
         EffectSIDs : struct.begin
            [0] = ExplosionDirtPostProcess
         struct.end
      struct.end
'''
        fixture += '''   struct.end
struct.end
ExplosionRGD5 : struct.begin {refkey=Empty}
   SID = ExplosionRGD5
   NativeWeaponFlag = PreserveGrenade
struct.end
ExplosionF1 : struct.begin {refkey=ExplosionRGD5}
   SID = ExplosionF1
struct.end
'''
        baseline = parse_cfg(fixture)
        before = copy.deepcopy(baseline)
        native_before = {key: resolve_cfg(baseline, key) for key in ('Empty', 'ExplosionRGD5', 'ExplosionF1')}
        combined = {**baseline, **parse_cfg(pak.source_bytes().decode())}
        for index in range(1, 21):
            resolved = resolve_cfg(combined, f'ZoneFPV_Kamikaze_{index:02d}')
            self.assertEqual(resolved['ConcussionEffects'], {'[0]': pak.NOOP_SID})
            self.assertEqual(resolved['DefaultEffectSIDs'], {'[0]': pak.NOOP_SID})
            self.assertEqual(resolved['NPCConcussionEffects'], {'[0]': 'KnockDownAIOnly'})
            self.assertEqual(len(resolved['PhysicalMaterialEffects']), 14)
            for row in resolved['PhysicalMaterialEffects'].values():
                self.assertEqual(row['EffectSIDs'], {'[0]': pak.NOOP_SID})
            self.assertEqual(resolved['UnrelatedGameplayFlag'], 'PreserveMe')
            self.assertEqual(resolved['NativeWeaponFlag'], 'PreserveGrenade')
        self.assertEqual(baseline, before, 'resolution must not mutate native definitions')
        for name, resolved in native_before.items():
            self.assertEqual(resolve_cfg(combined, name), resolved, 'native grenade behavior cannot be patched')

        effect_base = parse_cfg('''[0] : struct.begin
   SID = Empty
   Type = EEffectType::None
   Duration = 0.f
   NativeFlag = PreserveTemplate
struct.end
''')
        effect_before = copy.deepcopy(effect_base)
        no_op_nodes = parse_cfg(pak.effect_source_bytes().decode())
        self.assertEqual(list(no_op_nodes), [pak.NOOP_SID])
        no_op = resolve_cfg({**effect_base, **no_op_nodes}, pak.NOOP_SID)
        self.assertEqual(no_op['SID'], pak.NOOP_SID)
        self.assertEqual(no_op['Type'], 'EEffectType::None')
        self.assertEqual(no_op['Duration'], '0.')
        self.assertEqual(no_op['bIsPermanent'], 'false')
        self.assertEqual(effect_base, effect_before)
        # Independent timeline reproduction: a native surface effect starts a
        # Lerp timeline which survives effect-list retirement; our only selected
        # player effect is Type::None and never starts that timeline at all.
        effects = {pak.NOOP_SID: no_op, 'ExplosionDirtPostProcess': {'Type': 'EEffectType::PostProcessing'}}
        def start_player_feedback(explosion):
            return [sid for sid in explosion['DefaultEffectSIDs'].values() if effects.get(sid, {}).get('Type')=='EEffectType::PostProcessing']
        native = copy.deepcopy(native_before['ExplosionF1'])
        native['DefaultEffectSIDs'] = {'[0]': 'ExplosionDirtPostProcess'}
        self.assertTrue(start_player_feedback(native))
        for index in range(1, 21):
            self.assertEqual(start_player_feedback(resolve_cfg(combined, f'ZoneFPV_Kamikaze_{index:02d}')), [])

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
            valid.replace(b"[0] = "+pak.NOOP_SID.encode(), b"[0] = ExplosionRockPostProcess", 1),
            valid.replace(b"PhysicalMaterialType = EPhysicalMaterialType::Sand", b"PhysicalMaterialType = EPhysicalMaterialType::WoodThin"),
            valid.replace(b"refkey="+pak.PRIVATE_BASE.encode(), b"refkey=ExplosionF1", 1),
        ]:
            with self.subTest(invalid=invalid[:100]):
                with self.assertRaises(ValueError):
                    pak.validate_source(invalid)
        for invalid in [pak.effect_source_bytes().replace(b'EEffectType::None', b'EEffectType::PostProcessing'),
                        pak.effect_source_bytes().replace(b'refkey=[0]', b'refkey=Missing'),
                        pak.effect_source_bytes().replace(pak.NOOP_SID.encode(), b'Empty')]:
            with self.assertRaises(ValueError):
                pak.validate_effect_source(invalid)


if __name__ == "__main__":
    unittest.main()
