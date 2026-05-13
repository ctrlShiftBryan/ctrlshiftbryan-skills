#!/usr/bin/env python3
"""Build an interactive PR-review HTML artifact from a findings JSON file.

Usage:
  python build_review.py --findings <path> --output <path>

The findings file is described in ../references/findings-schema.md. This
script does the minimum: validates the input lightly, fills in severity
counts when missing, and injects the data into template.html as a
``window.REVIEW_DATA`` assignment.

Python stdlib only — no third-party dependencies.
"""

import argparse
import json
import sys
from pathlib import Path

SEV_LEVELS = ("critical", "major", "minor", "nit", "praise")


def compute_severity_counts(data: dict) -> dict:
    counts = {sev: 0 for sev in SEV_LEVELS}
    for f in data.get("files", []):
        for a in f.get("annotations", []) or []:
            sev = a.get("sev")
            if sev in counts:
                counts[sev] += 1
    for a in data.get("general_annotations", []) or []:
        sev = a.get("sev")
        if sev in counts:
            counts[sev] += 1
    return counts


def validate(data: dict) -> list[str]:
    errs: list[str] = []
    for key in ("pr_number", "title", "files"):
        if key not in data:
            errs.append(f"missing required top-level key: {key}")
    if not isinstance(data.get("files"), list):
        errs.append("`files` must be a list")
        return errs

    keys_seen: set[str] = set()
    for i, f in enumerate(data["files"]):
        for k in ("path", "diff"):
            if k not in f:
                errs.append(f"files[{i}] missing required key: {k}")
        if "key" in f:
            if f["key"] in keys_seen:
                errs.append(f"files[{i}] duplicate key: {f['key']!r}")
            keys_seen.add(f["key"])
        for j, a in enumerate(f.get("annotations", []) or []):
            for k in ("sev", "title", "body"):
                if k not in a:
                    errs.append(
                        f"files[{i}].annotations[{j}] missing required key: {k}"
                    )
            if a.get("sev") not in SEV_LEVELS:
                errs.append(
                    f"files[{i}].annotations[{j}] invalid sev: {a.get('sev')!r}; "
                    f"expected one of {SEV_LEVELS}"
                )
    for j, a in enumerate(data.get("general_annotations", []) or []):
        for k in ("sev", "title", "body"):
            if k not in a:
                errs.append(f"general_annotations[{j}] missing required key: {k}")
        if a.get("sev") not in SEV_LEVELS:
            errs.append(
                f"general_annotations[{j}] invalid sev: {a.get('sev')!r}; "
                f"expected one of {SEV_LEVELS}"
            )
    return errs


def ensure_keys(data: dict) -> None:
    """Auto-assign `key` to any file that didn't get one."""
    used = {f["key"] for f in data["files"] if "key" in f}
    for i, f in enumerate(data["files"]):
        if "key" not in f:
            base = f"file-{i}"
            k = base
            n = 1
            while k in used:
                n += 1
                k = f"{base}-{n}"
            f["key"] = k
            used.add(k)


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Build PR-review HTML artifact from findings JSON."
    )
    ap.add_argument("--findings", required=True, help="Path to findings JSON")
    ap.add_argument("--output", required=True, help="Output HTML path")
    ap.add_argument(
        "--template",
        default=None,
        help="Override template path (default: sibling template.html)",
    )
    args = ap.parse_args()

    findings_path = Path(args.findings)
    output_path = Path(args.output)
    template_path = Path(args.template) if args.template else Path(__file__).parent / "template.html"

    if not findings_path.exists():
        print(f"ERROR: findings file not found: {findings_path}", file=sys.stderr)
        return 1
    if not template_path.exists():
        print(f"ERROR: template not found: {template_path}", file=sys.stderr)
        return 1

    try:
        data = json.loads(findings_path.read_text())
    except json.JSONDecodeError as e:
        print(f"ERROR: findings JSON is invalid: {e}", file=sys.stderr)
        return 1

    errors = validate(data)
    if errors:
        print("ERROR: findings JSON failed validation:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    ensure_keys(data)
    if "severity_counts" not in data:
        data["severity_counts"] = compute_severity_counts(data)

    template = template_path.read_text()
    placeholder = "/* __REVIEW_DATA__ */"
    if placeholder not in template:
        print(
            f"ERROR: template missing placeholder {placeholder!r}",
            file=sys.stderr,
        )
        return 1

    injected = "window.REVIEW_DATA = " + json.dumps(data, indent=2) + ";"
    rendered = template.replace(placeholder, injected)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered)
    print(f"Wrote {output_path}", file=sys.stderr)
    print(str(output_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
