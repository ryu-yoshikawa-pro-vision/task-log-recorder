#!/usr/bin/env python3
import json
import math
import sys
from pathlib import Path

SUPPORTED_SCHEMA_KEYS = {
    "$schema",
    "title",
    "description",
    "type",
    "enum",
    "required",
    "properties",
    "items",
    "additionalProperties",
}


def load_json(path_str):
    path = Path(path_str)
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"Missing JSON file: {path}")
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}")


def check_type(expected, value):
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        if isinstance(value, bool):
            return False
        return isinstance(value, (int, float)) and not math.isnan(value)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "null":
        return value is None
    return True


def validate(schema, value, path, errors):
    expected = schema.get("type")
    if expected and not check_type(expected, value):
        errors.append(f"{path}: expected {expected}, got {type(value).__name__}")
        return

    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{path}: value {value!r} not in enum {schema['enum']!r}")

    if isinstance(value, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in value:
                errors.append(f"{path}: missing required property '{key}'")

        properties = schema.get("properties", {})
        for key, subschema in properties.items():
            if key in value:
                validate(subschema, value[key], f"{path}.{key}", errors)

        if schema.get("additionalProperties") is False:
            extra = sorted(set(value.keys()) - set(properties.keys()))
            for key in extra:
                errors.append(f"{path}: unexpected property '{key}'")

    if isinstance(value, list) and "items" in schema:
        for idx, item in enumerate(value):
            validate(schema["items"], item, f"{path}[{idx}]", errors)


def collect_unsupported_keywords(schema, path, errors):
    if isinstance(schema, dict):
        unsupported = sorted(set(schema.keys()) - SUPPORTED_SCHEMA_KEYS)
        for key in unsupported:
            errors.append(f"{path}: unsupported schema keyword '{key}'")

        if "properties" in schema and isinstance(schema["properties"], dict):
            for key, subschema in schema["properties"].items():
                collect_unsupported_keywords(subschema, f"{path}.properties.{key}", errors)

        if "items" in schema:
            collect_unsupported_keywords(schema["items"], f"{path}.items", errors)
    elif isinstance(schema, list):
        for idx, item in enumerate(schema):
            collect_unsupported_keywords(item, f"{path}[{idx}]", errors)


def main():
    if len(sys.argv) != 3:
        raise SystemExit("Usage: validate-output-schema.py <schema.json> <output.json>")

    schema = load_json(sys.argv[1])
    output = load_json(sys.argv[2])
    errors = []
    collect_unsupported_keywords(schema, "$", errors)
    validate(schema, output, "$", errors)
    if errors:
        raise SystemExit("\n".join(errors))


if __name__ == "__main__":
    main()
