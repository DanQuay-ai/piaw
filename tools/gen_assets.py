#!/usr/bin/env python3
"""Resumable Meshy pipeline: concept images -> 3D (weapons, gorilla) -> rig -> animation clips.
State in assets/state_assets.json. Raw animation GLBs land in assets/raw_anims (converted by tools/extract_anims.gd)."""
import json, time, base64, urllib.request, configparser, pathlib, sys, concurrent.futures as cf
ROOT = pathlib.Path(__file__).resolve().parent.parent
cfg = configparser.ConfigParser(); cfg.read(ROOT / "keys.cfg")
KEY = cfg["keys"]["meshy"].strip('"'); B = "https://api.meshy.ai/openapi/v1"
SF = ROOT / "assets/state_assets.json"; st = json.loads(SF.read_text()) if SF.exists() else {}
def save(): SF.write_text(json.dumps(st, indent=1))
def req(path, data=None):
    r = urllib.request.Request(B + path, data=json.dumps(data).encode() if data else None,
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    for i in range(4):
        try:
            with urllib.request.urlopen(r, timeout=120) as f: return json.load(f)
        except Exception as e:
            if i == 3: raise
            time.sleep(5)
def wait(path):
    while True:
        t = req(path)
        if t["status"] in ("SUCCEEDED", "FAILED", "CANCELED", "EXPIRED"): return t
        time.sleep(6)

W = ", isolated object, side view, centered, plain light grey background, realistic game asset, 19th century West Africa"
OBJECTS = {  # name: (prompt, kind)
 "dane_gun": ("Long flintlock trade musket 'Dane gun', dark wood stock with brass tacks and brass bands, iron barrel, leather sling" + W, "weapon"),
 "long_dane": ("Very long slender flintlock hunting musket, decorated wooden stock wrapped with leather strips and red cloth, iron barrel" + W, "weapon"),
 "blunderbuss": ("Short flintlock blunderbuss with flared brass muzzle, dark wooden stock" + W, "weapon"),
 "afena_royal": ("Asante afena ceremonial sword, curved leaf-shaped iron blade with openwork holes, gold dumbbell-shaped hilt with two spheres" + W, "weapon"),
 "afena_war": ("Asante war afena, broad curved iron machete blade, wooden dumbbell hilt wrapped in leather" + W, "weapon"),
 "gorilla": ("Huge muscular western lowland gorilla standing upright on two legs like a man, arms slightly away from body, full body, front view, A-pose, plain grey background, realistic game character", "creature"),
}
ANIMS = {
 "euro": {"idle": 0, "shoot": 234, "reload": 170, "die": 183, "hit": 177, "charge": 511},
 "asante": {"idle": 0, "slash": 97, "cheer": 59, "die": 184, "sneak": 559, "charge": 510},
 "gorilla": {"idle": 0, "maul": 198, "run": 16, "roar": 101, "die": 189},
}
CHARS = {"british_redcoat": "euro", "west_india_regt": "euro", "dutch_soldier": "euro",
 "asante_scout": "asante", "asante_batakari": "asante", "asante_ankobia": "asante", "asante_musketeer": "asante", "fante_asafo": "asante"}

def obj_pipeline(name):
    s = st.setdefault(name, {}); prompt, kind = OBJECTS[name]
    img = ROOT / f"assets/concepts/{name}.png"
    if not img.exists():
        tid = s.get("img") or req("/text-to-image", {"ai_model": "nano-banana", "prompt": prompt, "aspect_ratio": "1:1" if kind == "weapon" else "3:4"})["result"]
        s["img"] = tid; save()
        t = wait(f"/text-to-image/{tid}"); urllib.request.urlretrieve(t["image_urls"][0], img)
    if "i3d" not in s:
        uri = "data:image/png;base64," + base64.b64encode(img.read_bytes()).decode()
        body = {"image_url": uri, "ai_model": "latest", "should_texture": True, "enable_pbr": False,
                "target_polycount": 3000 if kind == "weapon" else 8000, "should_remesh": True, "topology": "triangle"}
        if kind == "creature": body["pose_mode"] = "a-pose"
        s["i3d"] = req("/image-to-3d", body)["result"]; save()
    out = ROOT / ("assets/weapons" if kind == "weapon" else "assets/characters"); out.mkdir(parents=True, exist_ok=True)
    if not (out / f"{name}.glb").exists() and kind == "weapon":
        t = wait(f"/image-to-3d/{s['i3d']}"); urllib.request.urlretrieve(t["model_urls"]["glb"], out / f"{name}.glb")
    if kind == "creature":
        wait(f"/image-to-3d/{s['i3d']}")
        if "rig" not in s: s["rig"] = req("/rigging", {"input_task_id": s["i3d"], "height_meters": 1.9})["result"]; save()
        t = wait(f"/rigging/{s['rig']}")
        if not (out / f"{name}.glb").exists(): urllib.request.urlretrieve(t["result"]["rigged_character_glb_url"], out / f"{name}.glb")
        anim_set(name, s["rig"], "gorilla")
    print("done", name, flush=True)

def anim_set(char, rig, group):
    raw = ROOT / "assets/raw_anims"; raw.mkdir(parents=True, exist_ok=True)
    s = st.setdefault(char, {}); a = s.setdefault("anims", {})
    for k, aid in ANIMS[group].items():
        if k not in a: a[k] = req("/animations", {"rig_task_id": rig, "action_id": aid})["result"]; save()
    for k, tid in a.items():
        p = raw / f"{char}__{k}.glb"
        if p.exists(): continue
        t = wait(f"/animations/{tid}")
        if t["status"] == "SUCCEEDED": urllib.request.urlretrieve(t["result"]["animation_glb_url"], p)
        else: print("ANIM FAIL", char, k, t.get("task_error"), flush=True)
    print("anims", char, flush=True)

chst = json.loads((ROOT / "assets/characters/state.json").read_text())
with cf.ThreadPoolExecutor(8) as ex:
    futs = [ex.submit(obj_pipeline, n) for n in OBJECTS]
    futs += [ex.submit(anim_set, c, chst[c]["rig"], g) for c, g in CHARS.items()]
    for f in futs:
        try: f.result()
        except Exception as e: print("ERROR", e, flush=True)
print("ALL DONE", flush=True)
