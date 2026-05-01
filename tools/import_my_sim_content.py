"""Import focused dress-up content from the source web project.

This tool keeps the Godot v1 content data derived from the existing
TypeScript/JSON source instead of hand-copying SVG-heavy payloads.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
from pathlib import Path
from typing import Any


CONTENT_TYPES = ("wardrobe", "equipmentVisuals", "equipmentAssets", "poses", "startingState")
WARDROBE_ITEM_KEYS = (
    "id",
    "name",
    "slot",
    "description",
    "visualId",
    "color",
    "accentColor",
    "pieces",
)
HAIR_COLOR_FILLS = {
    "#183f7b": "var(--doll-hair-shadow)",
    "#1f4a8c": "var(--doll-hair)",
    "#30518a": "var(--doll-hair-shadow)",
    "#3861a6": "var(--doll-hair)",
    "#49454e": "var(--doll-hair)",
    "#9a633f": "var(--doll-hair-shadow)",
    "#b6754a": "var(--doll-hair)",
    "#d08a5b": "var(--doll-hair-shadow)",
    "#e09a6b": "var(--doll-hair)",
}
IRIS_COLOR_FILLS = {
    "#3a5bd7": "var(--doll-eye)",
    "#828180": "var(--doll-eye)",
}
BASE_RIG_TARGETS = {
    "body",
    "hip",
    "torso",
    "neck",
    "head",
    "headNub",
    "leftArm",
    "leftForearm",
    "leftHand",
    "rightArm",
    "rightForearm",
    "rightHand",
    "leftThigh",
    "leftShank",
    "leftFoot",
    "leftToe",
    "rightThigh",
    "rightShank",
    "rightFoot",
    "rightToe",
    "backHair",
    "frontHair",
    "face",
    "leftEye",
    "rightEye",
    "leftBrow",
    "rightBrow",
    "mouth",
    "nose",
    "leftEar",
    "rightEar",
    "horns",
    "tail",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def extract_json_const(source: str, start_token: str, end_token: str) -> Any:
    start = source.find(start_token)
    if start < 0:
        raise ValueError(f"Could not find {start_token!r}")
    start += len(start_token)
    end = source.find(end_token, start)
    if end < 0:
        raise ValueError(f"Could not find end token {end_token!r}")
    raw = source[start:end].strip()
    raw = re.sub(r"\s+as const;\s*$", "", raw)
    return json.loads(raw)


def extract_original_equipment_assets(source: str) -> list[dict[str, Any]]:
    assets: list[dict[str, Any]] = []
    pattern = re.compile(
        r"(?P<id>[A-Za-z][A-Za-z0-9_]*)\s*:\s*\{\s*"
        r"actorSpace\s*:\s*(?P<actor>true|false)\s*,\s*"
        r"markup\s*:\s*(?P<string>'(?:\\.|[^'])*')\s*,?\s*\}",
        re.S,
    )
    for match in pattern.finditer(source):
        assets.append(
            {
                "id": match.group("id"),
                "name": match.group("id"),
                "source": "original",
                "actorSpace": match.group("actor") == "true",
                "svgMarkup": ast.literal_eval(match.group("string")),
            }
        )
    if not assets:
        raise ValueError("No original equipment assets were parsed.")
    return assets


def cta_assets_to_records(payload: dict[str, Any]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    piece_ids = sorted(
        set(payload["female"]["pieces"].keys()) | set(payload["male"]["pieces"].keys())
    )
    for asset_id in piece_ids:
        variants: dict[str, Any] = {}
        for variant in ("female", "male"):
            markup = payload[variant]["pieces"].get(asset_id)
            if markup:
                variants[variant] = {
                    "viewBox": payload[variant]["viewBox"],
                    "svgMarkup": markup,
                }
        records.append(
            {
                "id": asset_id,
                "name": asset_id,
                "source": "cta",
                "actorSpace": False,
                "variants": variants,
            }
        )
    return records


def custom_assets_to_records(payload: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for asset in payload:
        records.append(
            {
                "id": asset["id"],
                "name": asset.get("name", asset["id"]),
                "source": "custom",
                "actorSpace": bool(asset.get("actorSpace", False)),
                "svgMarkup": asset.get("svgMarkup", ""),
            }
        )
    return records


def source_content_path(source_root: Path, name: str) -> Path:
    return source_root / "src" / "game" / "content" / "data" / f"{name}.json"


def wardrobe_to_dressup_records(payload: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {key: item[key] for key in WARDROBE_ITEM_KEYS if key in item}
        for item in payload
    ]


def replace_known_fills(markup: str, fill_map: dict[str, str]) -> str:
    result = markup
    for fill, token in fill_map.items():
        result = result.replace(f'fill="{fill}"', f'fill="{token}"')
        result = result.replace(f'fill="{fill.upper()}"', f'fill="{token}"')
    return result


def tokenize_body_rig_colors(body_rig: dict[str, Any]) -> None:
    for variant_data in body_rig.values():
        for part in variant_data.get("parts", []):
            part_id = part.get("id", "")
            if part_id in {"backHair", "frontHair", "leftBrow", "rightBrow"}:
                fill_map = HAIR_COLOR_FILLS
            elif part_id in {"leftEye", "rightEye"}:
                fill_map = IRIS_COLOR_FILLS
            else:
                continue
            part["svgMarkup"] = replace_known_fills(part.get("svgMarkup", ""), fill_map)
            for variation_id, markup in list(part.get("variations", {}).items()):
                part["variations"][variation_id] = replace_known_fills(markup, fill_map)


def validate_outputs(outputs: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    wardrobe = outputs["wardrobe.json"]
    visuals = outputs["equipment_visuals.json"]
    assets = outputs["equipment_assets.json"]
    poses = outputs["poses.json"]
    body_rig = outputs["body_rig.json"]
    asset_ids = {asset.get("id") for asset in assets}
    visual_ids = {visual.get("id") for visual in visuals}
    wardrobe_ids = {item.get("id") for item in wardrobe}
    pose_ids = {pose.get("id") for pose in poses}
    rig_targets = set(BASE_RIG_TARGETS) | {
        part.get("id")
        for variant_data in body_rig.values()
        for part in variant_data.get("parts", [])
    }

    for collection_name, records in {
        "wardrobe": wardrobe,
        "equipment_visuals": visuals,
        "equipment_assets": assets,
        "poses": poses,
    }.items():
        ids = [record.get("id") for record in records]
        if len(ids) != len(set(ids)):
            errors.append(f"{collection_name} contains duplicate ids")

    for item in wardrobe:
        unknown = sorted(set(item.keys()) - set(WARDROBE_ITEM_KEYS))
        if unknown:
            errors.append(f"wardrobe item {item.get('id')} has unknown fields: {', '.join(unknown)}")
        if item.get("visualId") not in visual_ids:
            errors.append(f"wardrobe item {item.get('id')} references missing visual {item.get('visualId')}")
    for visual in visuals:
        for index, piece in enumerate(visual.get("pieces", [])):
            if piece.get("assetId") not in asset_ids:
                errors.append(f"visual {visual.get('id')} piece {index} references missing asset {piece.get('assetId')}")
            if piece.get("target") not in rig_targets:
                errors.append(f"visual {visual.get('id')} piece {index} references missing rig target {piece.get('target')}")
    starting = outputs["starting_outfit.json"]
    if starting.get("poseId") not in pose_ids:
        errors.append(f"starting outfit references missing pose {starting.get('poseId')}")
    for item_id in starting.get("equippedItemIds", []):
        if item_id not in wardrobe_ids:
            errors.append(f"starting outfit references missing wardrobe item {item_id}")
    return errors


def import_content(source_root: Path, project_root: Path, dry_run: bool = False) -> dict[str, Any]:
    if not (source_root / "package.json").exists():
        raise FileNotFoundError(f"Source project not found: {source_root}")
    if not (project_root / "project.godot").exists():
        raise FileNotFoundError(f"Godot project not found: {project_root}")

    cta_sample_source = read_text(source_root / "src" / "doll" / "assets" / "ctaSampleAssets.ts")
    cta_equipment_source = read_text(source_root / "src" / "doll" / "assets" / "ctaEquipmentAssets.ts")
    original_equipment_source = read_text(source_root / "src" / "doll" / "assets" / "originalEquipmentAssets.ts")

    body_rig = extract_json_const(
        cta_sample_source,
        "export const ctaBodyRigAssets = ",
        "\n\nexport type CtaSampleVariant",
    )
    tokenize_body_rig_colors(body_rig)
    cta_sample_assets = extract_json_const(
        cta_sample_source,
        "export const ctaSampleAssets = ",
        "\n\nexport const ctaBodyRigAssets",
    )
    cta_equipment = extract_json_const(
        cta_equipment_source,
        "export const ctaEquipmentAssets = ",
        "\n\nexport const ctaEquipmentAssetIds",
    )

    custom_equipment = json.loads(read_text(source_content_path(source_root, "equipmentAssets")))
    equipment_assets = (
        cta_assets_to_records(cta_equipment)
        + extract_original_equipment_assets(original_equipment_source)
        + custom_assets_to_records(custom_equipment)
    )

    sample_meta = {
        "actorViewBox": {"width": 2400, "height": 3100},
        "variants": {
            "female": {"viewBox": cta_sample_assets["female"]["viewBox"], "baseScale": 1.58},
            "male": {"viewBox": cta_sample_assets["male"]["viewBox"], "baseScale": 1.55},
        },
    }

    starting_state = json.loads(read_text(source_content_path(source_root, "startingState")))
    starting_outfit = {
        "id": "starter",
        "name": "Starter Outfit",
        "variant": "female",
        "poseId": "idle",
        "skinTone": "#d28062",
        "skinLine": "#8f4b38",
        "hairColor": "#221a16",
        "eyeColor": "#222222",
        "equippedItemIds": [
            value
            for value in starting_state.get("equippedWardrobe", {}).values()
            if isinstance(value, str) and value
        ],
    }

    outputs: dict[str, Any] = {
        "body_rig.json": body_rig,
        "equipment_assets.json": equipment_assets,
        "equipment_visuals.json": json.loads(read_text(source_content_path(source_root, "equipmentVisuals"))),
        "wardrobe.json": wardrobe_to_dressup_records(
            json.loads(read_text(source_content_path(source_root, "wardrobe")))
        ),
        "poses.json": json.loads(read_text(source_content_path(source_root, "poses"))),
        "sample_meta.json": sample_meta,
        "starting_outfit.json": starting_outfit,
    }

    manifest = {
        "sourceProject": str(source_root),
        "bodyRigParts": {
            "female": len(body_rig["female"]["parts"]),
            "male": len(body_rig["male"]["parts"]),
        },
        "wardrobeItems": len(outputs["wardrobe.json"]),
        "equipmentAssets": len(equipment_assets),
        "equipmentVisuals": len(outputs["equipment_visuals.json"]),
        "poses": len(outputs["poses.json"]),
    }
    validation_errors = validate_outputs(outputs)
    manifest["validationErrors"] = validation_errors
    if validation_errors:
        raise ValueError("Generated content is invalid:\n- " + "\n- ".join(validation_errors))
    outputs["import_manifest.json"] = manifest

    if not dry_run:
        content_dir = project_root / "content"
        for file_name, payload in outputs.items():
            write_json(content_dir / file_name, payload)

    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", default=r"D:\DEV\GAME\web_projects\my_sim")
    parser.add_argument("--project", default=".")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    manifest = import_content(Path(args.source).resolve(), Path(args.project).resolve(), args.dry_run)
    print(json.dumps(manifest, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
