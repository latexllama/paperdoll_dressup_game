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
BASE_PIVOTS = {
    "body": {"x": 1200.0, "y": 1620.0},
    "hip": {"x": 1200.0, "y": 1760.0},
    "torso": {"x": 1200.0, "y": 980.0},
    "neck": {"x": 1200.0, "y": 850.0},
    "head": {"x": 1200.0, "y": 555.0},
    "headNub": {"x": 1200.0, "y": 555.0},
    "leftArm": {"x": 1000.0, "y": 993.0},
    "leftForearm": {"x": 667.0, "y": 999.0},
    "leftHand": {"x": 349.0, "y": 1000.0},
    "rightArm": {"x": 1401.0, "y": 994.0},
    "rightForearm": {"x": 1733.0, "y": 999.0},
    "rightHand": {"x": 2051.0, "y": 1000.0},
    "leftThigh": {"x": 1096.0, "y": 1645.0},
    "leftShank": {"x": 1104.0, "y": 2115.0},
    "leftFoot": {"x": 1125.0, "y": 2645.0},
    "leftToe": {"x": 1127.0, "y": 2779.0},
    "rightThigh": {"x": 1301.0, "y": 1645.0},
    "rightShank": {"x": 1293.0, "y": 2115.0},
    "rightFoot": {"x": 1271.0, "y": 2645.0},
    "rightToe": {"x": 1271.0, "y": 2779.0},
    "backHair": {"x": 1200.0, "y": 500.0},
    "frontHair": {"x": 1200.0, "y": 500.0},
    "face": {"x": 1200.0, "y": 630.0},
    "leftEye": {"x": 1090.0, "y": 570.0},
    "rightEye": {"x": 1310.0, "y": 570.0},
    "leftBrow": {"x": 1090.0, "y": 485.0},
    "rightBrow": {"x": 1310.0, "y": 485.0},
    "mouth": {"x": 1200.0, "y": 725.0},
    "nose": {"x": 1200.0, "y": 645.0},
    "leftEar": {"x": 955.0, "y": 600.0},
    "rightEar": {"x": 1445.0, "y": 600.0},
    "horns": {"x": 1200.0, "y": 310.0},
    "tail": {"x": 1445.0, "y": 1810.0},
}
BASE_BODY_PART_DEFAULTS = {
    "body": {"parentId": "", "layer": "body"},
    "hip": {"parentId": "body", "layer": "body"},
    "torso": {"parentId": "hip", "layer": "body"},
    "neck": {"parentId": "torso", "layer": "body"},
    "head": {"parentId": "neck", "layer": "head"},
    "headNub": {"parentId": "head", "layer": "head"},
    "leftArm": {"parentId": "torso", "layer": "upperLimbs"},
    "leftForearm": {"parentId": "leftArm", "layer": "frontLimbs"},
    "leftHand": {"parentId": "leftForearm", "layer": "frontLimbs"},
    "rightArm": {"parentId": "torso", "layer": "upperLimbs"},
    "rightForearm": {"parentId": "rightArm", "layer": "frontLimbs"},
    "rightHand": {"parentId": "rightForearm", "layer": "frontLimbs"},
    "leftThigh": {"parentId": "hip", "layer": "legs"},
    "leftShank": {"parentId": "leftThigh", "layer": "legs"},
    "leftFoot": {"parentId": "leftShank", "layer": "frontLimbs"},
    "leftToe": {"parentId": "leftFoot", "layer": "frontLimbs"},
    "rightThigh": {"parentId": "hip", "layer": "legs"},
    "rightShank": {"parentId": "rightThigh", "layer": "legs"},
    "rightFoot": {"parentId": "rightShank", "layer": "frontLimbs"},
    "rightToe": {"parentId": "rightFoot", "layer": "frontLimbs"},
    "backHair": {"parentId": "head", "layer": "back"},
    "frontHair": {"parentId": "head", "layer": "front"},
    "face": {"parentId": "head", "layer": "head"},
    "leftEye": {"parentId": "face", "layer": "head"},
    "rightEye": {"parentId": "face", "layer": "head"},
    "leftBrow": {"parentId": "face", "layer": "head"},
    "rightBrow": {"parentId": "face", "layer": "head"},
    "mouth": {"parentId": "face", "layer": "head"},
    "nose": {"parentId": "face", "layer": "head"},
    "leftEar": {"parentId": "head", "layer": "head"},
    "rightEar": {"parentId": "head", "layer": "head"},
    "horns": {"parentId": "head", "layer": "front"},
    "tail": {"parentId": "hip", "layer": "back"},
}
BASE_RIG_TARGETS = set(BASE_BODY_PART_DEFAULTS.keys())


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


def normalize_body_rig_lateral_markup(body_rig: dict[str, Any]) -> None:
    for variant_data in body_rig.values():
        parts = {
            part.get("id"): part
            for part in variant_data.get("parts", [])
            if isinstance(part, dict)
        }
        for left_id, right_id in (("leftFoot", "rightFoot"),):
            left = parts.get(left_id)
            right = parts.get(right_id)
            if not left or not right:
                continue
            left_center = markup_center_x(left.get("svgMarkup", ""))
            right_center = markup_center_x(right.get("svgMarkup", ""))
            if left_center is not None and right_center is not None and left_center > right_center:
                left["svgMarkup"], right["svgMarkup"] = right.get("svgMarkup", ""), left.get("svgMarkup", "")
                left["variations"], right["variations"] = (
                    right.get("variations", {}),
                    left.get("variations", {}),
                )


def ensure_required_body_rig_nodes(body_rig: dict[str, Any]) -> None:
    for variant_data in body_rig.values():
        parts = variant_data.get("parts", [])
        if not isinstance(parts, list):
            continue
        ids: set[str] = set()
        for part in parts:
            if not isinstance(part, dict):
                continue
            part_id = str(part.get("id", ""))
            if part_id:
                ids.add(part_id)
            if not isinstance(part.get("variations"), dict):
                part["variations"] = {}
            if not isinstance(part.get("latticeVariations"), dict):
                part["latticeVariations"] = {}
        for part_id, defaults in BASE_BODY_PART_DEFAULTS.items():
            if part_id in ids:
                continue
            pivot = BASE_PIVOTS[part_id]
            parts.append(
                {
                    "id": part_id,
                    "layer": defaults["layer"],
                    "parentId": defaults["parentId"],
                    "pivot": {"x": pivot["x"], "y": pivot["y"]},
                    "svgMarkup": "<g/>",
                    "variations": {},
                    "latticeVariations": {},
                }
            )
            ids.add(part_id)


def markup_center_x(markup: str) -> float | None:
    cx_values = [
        float(match.group(1))
        for match in re.finditer(r"\bcx\s*=\s*['\"]\s*([-+]?(?:(?:\d*\.\d+)|(?:\d+\.?))(?:[eE][-+]?\d+)?)", markup)
    ]
    if cx_values:
        return sum(cx_values) / len(cx_values)
    numbers = [float(match.group(0)) for match in re.finditer(r"[-+]?(?:(?:\d*\.\d+)|(?:\d+\.?))(?:[eE][-+]?\d+)?", markup)]
    if len(numbers) < 4:
        return None
    xs = numbers[0::2]
    return (min(xs) + max(xs)) / 2


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
    for variant_id, variant_data in body_rig.items():
        parts = {
            part.get("id"): part
            for part in variant_data.get("parts", [])
            if isinstance(part, dict)
        }
        missing_required = sorted(BASE_RIG_TARGETS - set(parts.keys()))
        if missing_required:
            errors.append(f"body rig variant {variant_id} missing required rig nodes: {', '.join(missing_required)}")
        left_foot = parts.get("leftFoot")
        right_foot = parts.get("rightFoot")
        if left_foot and right_foot:
            left_center = markup_center_x(left_foot.get("svgMarkup", ""))
            right_center = markup_center_x(right_foot.get("svgMarkup", ""))
            if left_center is not None and right_center is not None and left_center > right_center:
                errors.append(f"body rig variant {variant_id} has swapped leftFoot/rightFoot SVG markup")
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
    normalize_body_rig_lateral_markup(body_rig)
    ensure_required_body_rig_nodes(body_rig)
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
