#!/usr/bin/env python3
"""Call Bria's FIBO image model with a local reference image.

Exists because the reference image has to be base64-encoded, and doing that
through a chat tool call means pasting tens of thousands of characters by hand.
Here the encoding happens locally and never leaves the machine as text you have
to handle.

Reads the API key from the BRIA_API_KEY environment variable. The key is never
written to disk or echoed.

Examples
--------
Plain generation from a VGL spec::

    export BRIA_API_KEY=...
    scripts/bria-generate.py \
        --structured-prompt docs/icon-specs/pr-modicon-scrubber-v4.json \
        --out /tmp/out.png

Inspire workflow, using an existing family icon as visual reference::

    scripts/bria-generate.py \
        --image ../advanced-power-infrastructure/src/thumbnail.png \
        --prompt "Keep this exact style and chassis, but ..." \
        --out /tmp/out.png

The response's own structured_prompt is written alongside the image as
``<out>.vgl.json`` so it can be edited and fed back in via --structured-prompt.
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

MCP_URL = "https://mcp.prod.bria-api.com/mcp"
TOOL = "text_to_image"
MAX_REFERENCE_PIXELS = 512


def die(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def encode_reference(path: Path, max_side: int) -> str:
    """Return a data URI for path, downscaled so the payload stays sane."""
    raw = path.read_bytes()
    mime = mimetypes.guess_type(path.name)[0] or "image/png"

    try:
        from PIL import Image
    except ImportError:
        print("note: Pillow not installed, sending the image at full size", file=sys.stderr)
    else:
        import io

        with Image.open(io.BytesIO(raw)) as im:
            if max(im.size) > max_side:
                im = im.convert("RGB")
                im.thumbnail((max_side, max_side), Image.LANCZOS)
                buf = io.BytesIO()
                im.save(buf, "JPEG", quality=80, optimize=True)
                raw, mime = buf.getvalue(), "image/jpeg"

    encoded = base64.b64encode(raw).decode("ascii")
    print(f"reference: {path.name} -> {len(encoded):,} base64 chars ({mime})", file=sys.stderr)
    return f"data:{mime};base64,{encoded}"


def post(payload: dict, token: str) -> dict:
    request = urllib.request.Request(
        MCP_URL,
        data=json.dumps(payload).encode(),
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "api_token": token,
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=300) as response:
            body = response.read().decode()
    except urllib.error.HTTPError as error:
        die(f"HTTP {error.code} from Bria: {error.read().decode()[:400]}")

    # Streamable-HTTP transports may answer with server-sent events rather than
    # a bare JSON body; pull the payload out of the first data: frame if so.
    if body.lstrip().startswith("data:"):
        for line in body.splitlines():
            if line.startswith("data:"):
                body = line[len("data:"):].strip()
                break

    try:
        return json.loads(body)
    except json.JSONDecodeError:
        die(f"could not parse response: {body[:400]}")


def extract_result(envelope: dict) -> dict:
    """Pull the tool's own JSON payload out of the MCP response envelope."""
    if "error" in envelope:
        die(f"Bria returned an error: {json.dumps(envelope['error'])[:400]}")

    content = envelope.get("result", {}).get("content", [])
    for block in content:
        if block.get("type") == "text":
            try:
                return json.loads(block["text"])
            except json.JSONDecodeError:
                continue
    die(f"no JSON payload in response: {json.dumps(envelope)[:400]}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--prompt", default="", help="free-text prompt or modification instruction")
    parser.add_argument("--negative-prompt", default=None)
    parser.add_argument("--structured-prompt", type=Path, help="VGL JSON file; triggers the refine workflow")
    parser.add_argument("--image", type=Path, help="local reference image; triggers the inspire workflow")
    parser.add_argument("--aspect-ratio", default="1:1")
    parser.add_argument("--seed", type=int)
    parser.add_argument("--max-reference-pixels", type=int, default=MAX_REFERENCE_PIXELS)
    parser.add_argument("--out", type=Path, required=True, help="where to write the generated PNG")
    args = parser.parse_args()

    token = os.environ.get("BRIA_API_KEY")
    if not token:
        die("BRIA_API_KEY is not set. export it first; it is never read from a file here.")

    arguments: dict = {"prompt": args.prompt, "aspect_ratio": args.aspect_ratio}
    if args.negative_prompt:
        arguments["negative_prompt"] = args.negative_prompt
    if args.seed is not None:
        arguments["seed"] = args.seed

    if args.structured_prompt:
        if not args.structured_prompt.is_file():
            die(f"no such file: {args.structured_prompt}")
        spec = json.loads(args.structured_prompt.read_text())
        # Accept either a bare VGL object or one of our saved wrappers that
        # carries prompt/negative_prompt alongside it.
        if "structured_prompt" in spec:
            arguments.setdefault("prompt", spec.get("prompt", args.prompt))
            if not args.negative_prompt and spec.get("negative_prompt"):
                arguments["negative_prompt"] = spec["negative_prompt"]
            spec = spec["structured_prompt"]
        arguments["structured_prompt"] = json.dumps(spec)

    if args.image:
        if not args.image.is_file():
            die(f"no such file: {args.image}")
        if args.structured_prompt:
            print(
                "note: structured_prompt takes precedence, so this runs as refine, not inspire",
                file=sys.stderr,
            )
        arguments["image"] = encode_reference(args.image, args.max_reference_pixels)

    print("calling Bria ...", file=sys.stderr)
    envelope = post(
        {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
         "params": {"name": TOOL, "arguments": arguments}},
        token,
    )
    result = extract_result(envelope)

    url = result.get("image_url")
    if not url:
        die(f"no image_url in result: {json.dumps(result)[:400]}")

    args.out.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=120) as response:
        args.out.write_bytes(response.read())
    print(f"wrote {args.out}", file=sys.stderr)

    if result.get("structured_prompt"):
        spec_path = args.out.with_suffix(args.out.suffix + ".vgl.json")
        try:
            parsed = json.loads(result["structured_prompt"])
        except (json.JSONDecodeError, TypeError):
            parsed = result["structured_prompt"]
        spec_path.write_text(json.dumps(parsed, indent=2))
        print(f"wrote {spec_path}", file=sys.stderr)

    if result.get("seed") is not None:
        print(f"seed: {result['seed']}", file=sys.stderr)


if __name__ == "__main__":
    main()
