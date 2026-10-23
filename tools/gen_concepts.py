#!/usr/bin/env python3
"""Generate character concept images with Meshy text-to-image.
Run from Terminal:  python3 tools/gen_concepts.py   (inside the 'akan game' folder)"""
import json, time, urllib.request, configparser, pathlib, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
cfg = configparser.ConfigParser(); cfg.read(ROOT / "keys.cfg")
KEY = cfg["keys"]["meshy"].strip('"')
API = "https://api.meshy.ai/openapi/v1/text-to-image"
SUFFIX = ", full body, A-pose, front view, plain grey background, low-poly PS2 game character concept, empty hands"
CHARS = {
 "asante_scout": "West African warrior 1820s, bare chest, white clay body markings, leaf and raffia camouflage, cloth loincloth",
 "asante_batakari": "Asante warrior in a fitted brown war smock covered with small leather amulets, horned leather cap",
 "asante_ankobia": "Asante royal guard, leopard-skin cap, dark red cloth wrap, gold armlets",
 "asante_musketeer": "Asante musketeer, dark brown cloth wrap, leather bandolier with small powder gourds",
 "fante_asafo": "Fante asafo company soldier 1700s, cloth wrap, brass horn on belt, cowrie necklace",
 "british_redcoat": "1820s British infantry redcoat, white crossbelts, shako hat",
 "west_india_regt": "Black soldier, 1870s West India Regiment zouave uniform, red fez with white turban, red trimmed vest",
 "dutch_soldier": "1700s Dutch colonial soldier on the Gold Coast, blue coat, tricorne hat",
}
def req(url, data=None):
    r = urllib.request.Request(url, data=json.dumps(data).encode() if data else None,
        headers={"Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    with urllib.request.urlopen(r, timeout=60) as f: return json.load(f)
out = ROOT / "assets/concepts"; out.mkdir(parents=True, exist_ok=True)
TJ = out / "tasks.json"
tasks = json.loads(TJ.read_text()) if TJ.exists() else {}
only = sys.argv[1:]
for name, desc in CHARS.items():
    if only and name not in only: continue
    if (out / f"{name}.png").exists(): print("skip", name); continue
    try:
        tid = tasks.get(name) or req(API, {"ai_model": "nano-banana", "prompt": desc + SUFFIX, "aspect_ratio": "3:4"})["result"]
        tasks[name] = tid; TJ.write_text(json.dumps(tasks, indent=1))
        while True:
            t = req(f"{API}/{tid}")
            if t["status"] in ("SUCCEEDED", "FAILED", "CANCELED"): break
            time.sleep(4)
        if t["status"] != "SUCCEEDED": print("FAILED", name, t.get("task_error")); continue
        urllib.request.urlretrieve(t["image_urls"][0], out / f"{name}.png"); print("ok", name)
    except Exception as e:
        print("ERROR", name, e)
print("Done. Images in assets/concepts")
