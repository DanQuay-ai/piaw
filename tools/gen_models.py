#!/usr/bin/env python3
"""Concept PNG -> Meshy image-to-3D -> auto-rig -> animations. Resumable (state in assets/characters/state.json)."""
import json, time, base64, urllib.request, configparser, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
cfg = configparser.ConfigParser(); cfg.read(ROOT / "keys.cfg")
KEY = cfg["keys"]["meshy"].strip('"'); B = "https://api.meshy.ai/openapi/v1"
OUT = ROOT / "assets/characters"; OUT.mkdir(parents=True, exist_ok=True)
SF = OUT / "state.json"; st = json.loads(SF.read_text()) if SF.exists() else {}
def save(): SF.write_text(json.dumps(st, indent=1))
def req(path, data=None):
    r = urllib.request.Request(B + path, data=json.dumps(data).encode() if data else None,
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=120) as f: return json.load(f)
def wait(path):
    while True:
        t = req(path)
        if t["status"] in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"): return t
        time.sleep(8)
def dl(url, p): urllib.request.urlretrieve(url, p)
names = sys.argv[1:] or [p.stem for p in sorted((ROOT/"assets/concepts").glob("*.png"))]
# 1) submit all image-to-3d
for n in names:
    s = st.setdefault(n, {})
    if "i3d" not in s:
        uri = "data:image/png;base64," + base64.b64encode((ROOT/f"assets/concepts/{n}.png").read_bytes()).decode()
        s["i3d"] = req("/image-to-3d", {"image_url": uri, "ai_model": "latest", "should_texture": True,
            "enable_pbr": False, "target_polycount": 8000, "should_remesh": True, "topology": "triangle", "pose_mode": "a-pose"})["result"]
        save(); print("submitted", n)
for n in names:
    s = st[n]
    if "glb" not in s:
        t = wait(f"/image-to-3d/{s['i3d']}")
        if t["status"] != "SUCCEEDED": print("3D FAILED", n, t.get("task_error")); continue
        s["glb"] = True; save(); print("3d ok", n)
    if "rig" not in s:
        s["rig"] = req("/rigging", {"input_task_id": s["i3d"], "height_meters": 1.75})["result"]; save()
for n in names:
    s = st[n]
    if "rig" not in s or s.get("rigged"): continue
    t = wait(f"/rigging/{s['rig']}")
    if t["status"] != "SUCCEEDED": print("RIG FAILED", n, t.get("task_error")); continue
    r = t["result"]; dl(r["rigged_character_glb_url"], OUT / f"{n}.glb")
    for k, v in (r.get("basic_animations") or {}).items():
        if k.endswith("glb_url") and v: dl(v, OUT / f"{n}__{k.replace('_glb_url','')}.glb")
    s["rigged"] = True; save(); print("rigged", n)
print("done")
