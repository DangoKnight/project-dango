#!/usr/bin/env python3
"""Rebuild battle SpriteFrames from the BDragon sheet catalog and preset rows."""

import hashlib
import json
from pathlib import Path


def main():
    root = Path(__file__).resolve().parents[1]
    source = json.loads((root / "textures/battle_fx/sources.json").read_text())
    catalog, presets = source["catalog"], source["presets"]
    sheets = sorted({preset["sheet"] for preset in presets.values()}, key=int)
    ids = {sheet: str(index + 1) for index, sheet in enumerate(sheets)}
    external, atlases, animations = [], [], []
    for sheet in sheets:
        entry = catalog[sheet]
        assert hashlib.sha256((root / entry["path"]).read_bytes()).hexdigest() == entry["sha256"], sheet
        external.append(f'[ext_resource type="Texture2D" path="res://{entry["path"]}" id="{ids[sheet]}"]')
    for name, preset in presets.items():
        sheet, row = preset["sheet"], preset["row"]
        count = catalog[sheet]["frame_count"]
        assert 0 <= row < 9 and count > 0
        frames = []
        for index in range(count):
            resource_id = f"Atlas_{name}_{index}"
            atlases.append(
                f'[sub_resource type="AtlasTexture" id="{resource_id}"]\n'
                f'atlas = ExtResource("{ids[sheet]}")\n'
                f'region = Rect2({index * 64}, {row * 64}, 64, 64)'
            )
            frames.append('{"duration": 1.0, "texture": SubResource("' + resource_id + '")}')
        animations.append(
            '{\n"frames": [' + ',\n'.join(frames) + '],\n"loop": false,\n'
            f'"name": &"{name}",\n"speed": {count / 0.7}\n' + '}'
        )
    output = (
        f'[gd_resource type="SpriteFrames" load_steps={1 + len(external) + len(atlases)} format=3]\n\n'
        + '\n'.join(external) + '\n\n' + '\n\n'.join(atlases)
        + '\n\n[resource]\nanimations = [' + ',\n'.join(animations) + ']\n'
    )
    (root / "resources/battle/effects.tres").write_text(output)
    print(f"Imported {len(animations)} BDragon battle presets from {len(sheets)} sheets")


if __name__ == "__main__":
    main()
