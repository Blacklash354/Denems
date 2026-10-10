#!/usr/bin/env python3
"""Turns Quaternius "Ultimate Modular Men / Women" figures (CC0) into rigid-part people for the NPC rig.

    python3 tools/people_convert.py <source dir with Male/ and Female/ *.glb> assets/people

The source figures are skinned meshes in a T-pose. Each look below mixes a head, body, legs and feet from
different outfits, recolours their materials (Soviet olive drab, bandit black, survivor browns) and cuts
the mesh into the rig's parts by each triangle's dominant bone: torso, head, upper arm / forearm (with the
hand) and thigh / shin (with the foot) per side. Every part is re-based on its joint, arms rotated so the
limb runs along +x like the procedural rig (src/rig.lua), and written as a small static .glb with baked
vertex colours, no skin and no animations. The joint layout (hip height, thigh length, shoulders, arm
segment lengths ...) goes into the file's top-level "extras" so the game can pose the parts exactly.
Source: https://github.com/LuanDucate/Ducz.CharacterCreator (public/models), Quaternius, CC0 1.0.
"""
import json
import os
import struct
import sys

import numpy as np

SCALE = 0.95          # the figures are ~1.86 m with hair/hats; this makes a 1.77 m man

# display-space colours
OLIVE_HELMET = (0.33, 0.37, 0.24)
GREATCOAT = (0.41, 0.4, 0.31)
WEBBING = (0.27, 0.21, 0.14)
TROUSERS = (0.35, 0.35, 0.26)
DARK = (0.17, 0.17, 0.15)
BOOTS = (0.11, 0.1, 0.09)
GLASS = (0.1, 0.12, 0.13)
WHITE_CAMO = (0.8, 0.82, 0.83)
WHITE_CAMO2 = (0.7, 0.72, 0.73)

M, F = "Male/", "Female/"
LOOKS = {
    # Soviet soldiers: a face under an olive helmet, greatcoat, belts and pouches
    "soldier": {
        "head": (M + "Worker.glb", "Worker_Head", {"Worker_Yellow": OLIVE_HELMET}),
        "body": (M + "Swat.glb", "Swat_Body", {"Swat": GREATCOAT, "Swat_Black": WEBBING}),
        "legs": (M + "Swat.glb", "Swat_Legs", {"Swat": TROUSERS, "Swat_Black": DARK}),
        "feet": (M + "Swat.glb", "Swat_Feet", {"Swat_Black": BOOTS}),
    },
    # ... in a gas mask
    "soldier_mask": {
        "head": (M + "Swat.glb", "Swat_Head", {"Swat": OLIVE_HELMET, "Swat_Black": (0.22, 0.23, 0.2), "Visor": GLASS}),
        "body": (M + "Swat.glb", "Swat_Body", {"Swat": GREATCOAT, "Swat_Black": WEBBING}),
        "legs": (M + "Swat.glb", "Swat_Legs", {"Swat": TROUSERS, "Swat_Black": DARK}),
        "feet": (M + "Swat.glb", "Swat_Feet", {"Swat_Black": BOOTS}),
    },
    # ... and in winter whites
    "soldier_winter": {
        "head": (M + "Worker.glb", "Worker_Head", {"Worker_Yellow": WHITE_CAMO}),
        "body": (M + "Swat.glb", "Swat_Body", {"Swat": WHITE_CAMO, "Swat_Black": WHITE_CAMO2}),
        "legs": (M + "Swat.glb", "Swat_Legs", {"Swat": WHITE_CAMO, "Swat_Black": WHITE_CAMO2}),
        "feet": (M + "Swat.glb", "Swat_Feet", {"Swat_Black": (0.3, 0.28, 0.26)}),
    },
    # an NCO: bareheaded, field jacket over the coat
    "sergeant": {
        "head": (M + "Adventurer.glb", "Adventurer_Head", {"Hair": (0.16, 0.13, 0.1)}),
        "body": (M + "Adventurer.glb", "Adventurer_Body", {"Green": GREATCOAT, "LightGreen": WEBBING}),
        "legs": (M + "Swat.glb", "Swat_Legs", {"Swat": TROUSERS, "Swat_Black": DARK}),
        "feet": (M + "Adventurer.glb", "Adventurer_Feet", {"Grey": BOOTS, "Black": BOOTS}),
    },
    # our own: German field grey, black leather webbing, the brimmed helmet greyed into a Stahlhelm
    "german": {
        "head": (M + "Worker.glb", "Worker_Head", {"Worker_Yellow": (0.36, 0.38, 0.35)}),
        "body": (M + "Swat.glb", "Swat_Body", {"Swat": (0.4, 0.42, 0.38), "Swat_Black": (0.12, 0.11, 0.1)}),
        "legs": (M + "Swat.glb", "Swat_Legs", {"Swat": (0.37, 0.39, 0.35), "Swat_Black": (0.2, 0.2, 0.19)}),
        "feet": (M + "Swat.glb", "Swat_Feet", {"Swat_Black": (0.08, 0.07, 0.07)}),
    },
    # bandits: black hoodies and leather, dark jeans
    "bandit": {
        "head": (M + "Casual_2.glb", "Casual2_Head", {"Hair": (0.08, 0.07, 0.06)}),
        "body": (M + "Casual_Hoodie.glb", "Casual_Body", {"Purple": (0.13, 0.13, 0.14)}),
        "legs": (M + "Punk.glb", "Punk_Legs", {"LightBlue": (0.2, 0.22, 0.3)}),
        "feet": (M + "Worker.glb", "Worker_Feet", {"Grey": (0.16, 0.15, 0.14), "Black": BOOTS}),
    },
    "bandit_leather": {
        "head": (M + "Adventurer.glb", "Adventurer_Head", {"Hair": (0.1, 0.08, 0.06)}),
        "body": (M + "Adventurer.glb", "Adventurer_Body", {"Green": (0.12, 0.11, 0.1), "LightGreen": (0.3, 0.24, 0.18)}),
        "legs": (M + "Punk.glb", "Punk_Legs", {"LightBlue": (0.18, 0.2, 0.27)}),
        "feet": (M + "Adventurer.glb", "Adventurer_Feet", {"Grey": (0.15, 0.14, 0.13), "Black": BOOTS}),
    },
    # survivors: worn field gear, a pack
    "loner": {
        "head": (M + "Adventurer.glb", "Adventurer_Head", {}),
        "body": (M + "Adventurer.glb", "Adventurer_Body", {"Green": (0.36, 0.37, 0.28), "LightGreen": (0.45, 0.42, 0.32)}),
        "legs": (M + "Adventurer.glb", "Adventurer_Legs", {}),
        "feet": (M + "Adventurer.glb", "Adventurer_Feet", {}),
        "extra": (M + "Adventurer.glb", "Backpack", {"LightGreen": (0.38, 0.36, 0.26), "Gold": (0.45, 0.4, 0.3)}),
    },
    "loner_farmer": {
        "head": (M + "Worker.glb", "Worker_Head", {"Worker_Yellow": (0.3, 0.23, 0.17)}),
        "body": (M + "Farmer.glb", "Farmer_Body", {"LightBlue": (0.33, 0.37, 0.44), "Brown": (0.4, 0.31, 0.23)}),
        "legs": (M + "Farmer.glb", "Farmer_Pants", {"LightBlue": (0.33, 0.37, 0.44)}),
        "feet": (M + "Farmer.glb", "Farmer_Feet", {}),
    },
    "loner_woman": {
        "head": (F + "Adventurer.glb", "Adventurer_Head", {}),
        "body": (F + "Adventurer.glb", "Adventurer_Body", {"LightGreen": (0.38, 0.4, 0.3), "Green": (0.3, 0.32, 0.24), "White": (0.6, 0.58, 0.52)}),
        "legs": (F + "Worker.glb", "Worker_Legs", {"Brown_02": (0.32, 0.3, 0.26), "Brown2": (0.25, 0.22, 0.18)}),
        "feet": (F + "Adventurer.glb", "Adventurer_Feet", {}),
    },
}

PARTS = ["torso", "head", "upperL", "foreL", "upperR", "foreR", "thighL", "shinL", "thighR", "shinR"]
FINGERS = ("Index", "Middle", "Ring", "Pinky", "Thumb")


def part_of(bone):
    if bone == "Head":
        return "head"
    for s in ("L", "R"):
        if bone == "UpperArm." + s:
            return "upper" + s
        if bone in ("LowerArm." + s, "Wrist." + s) or (bone.endswith("." + s) and bone[:-2].rstrip("0123456789") in FINGERS):
            return "fore" + s
        if bone == "UpperLeg." + s:
            return "thigh" + s
        if bone in ("LowerLeg." + s, "Foot." + s, "PT." + s):
            return "shin" + s
    return "torso"


def load(path):
    data = open(path, "rb").read()
    jl = struct.unpack("<I", data[12:16])[0]
    doc = json.loads(data[20:20 + jl])
    off = 20 + jl
    bl = struct.unpack("<I", data[off:off + 4])[0]
    return doc, data[off + 8:off + 8 + bl]


def accessor(doc, binc, i):
    a = doc["accessors"][i]
    v = doc["bufferViews"][a["bufferView"]]
    n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
    dt = np.dtype({5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}[a["componentType"]])
    start = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = v.get("byteStride", n * dt.itemsize)
    arr = np.ndarray((a["count"], n), dtype=dt, buffer=binc, offset=start, strides=(stride, dt.itemsize))
    if a.get("normalized"):
        return arr.astype(np.float64) / np.iinfo(dt).max
    return arr.astype(np.float64) if dt == np.float32 else arr.astype(np.int64)


def to_game(v):
    # glTF (+y up, figure faces +z, its left is +x) -> game (+x forward, +y up, +z right)
    return np.stack([v[:, 2], v[:, 1], -v[:, 0]], axis=1)


def to_gltf(v):
    return np.stack([-v[:, 2], v[:, 1], v[:, 0]], axis=1)


def linear(c):
    return [max(0.0, x) ** 2.2 for x in c]


class Source:
    cache = {}

    @classmethod
    def get(cls, path):
        if path not in cls.cache:
            cls.cache[path] = Source(path)
        return cls.cache[path]

    def __init__(self, path):
        self.doc, self.bin = load(path)
        doc = self.doc
        skin = doc["skins"][0]
        ibm = accessor(doc, self.bin, skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        self.joint_names = [doc["nodes"][j]["name"] for j in skin["joints"]]
        self.joint_pos = {}
        for name, m in zip(self.joint_names, ibm):
            p = np.linalg.inv(m)[:3, 3]
            self.joint_pos[name] = to_game(p[None, :])[0] * SCALE
        self.materials = [m.get("name") for m in doc.get("materials", [])]

    def mesh_nodes(self, name):
        out = []
        for n in self.doc["nodes"]:
            if "mesh" in n and "skin" in n and n.get("name") == name:
                out.append(n)
        assert out, "no mesh %s" % name
        return out

    def triangles(self, node, recolor):
        """yields (part, positions 3x3, normals 3x3, linear colour) per triangle, in game space"""
        doc, binc = self.doc, self.bin
        for pr in doc["meshes"][node["mesh"]]["primitives"]:
            at = pr["attributes"]
            pos = to_game(accessor(doc, binc, at["POSITION"])) * SCALE
            nor = to_game(accessor(doc, binc, at["NORMAL"]))
            joints = accessor(doc, binc, at["JOINTS_0"])
            weights = accessor(doc, binc, at["WEIGHTS_0"])
            idx = accessor(doc, binc, pr["indices"])[:, 0].reshape(-1, 3)
            mat = self.materials[pr["material"]] if "material" in pr else None
            base = doc["materials"][pr["material"]].get("pbrMetallicRoughness", {}).get("baseColorFactor", [0.8, 0.8, 0.8, 1]) if mat else [0.8] * 4
            col = linear(recolor[mat]) if mat in recolor else list(base[:3])
            dom = joints[np.arange(len(joints)), np.argmax(weights, axis=1)]
            vpart = [part_of(self.joint_names[j]) for j in dom]
            for a, b, c in idx:
                parts = [vpart[a], vpart[b], vpart[c]]
                p = max(set(parts), key=parts.count)
                yield p, pos[[a, b, c]], nor[[a, b, c]], col


def arm_basis(f):
    f = f / np.linalg.norm(f)
    r = np.cross(f, [0.0, 1.0, 0.0])
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    return np.stack([f, u, r])        # rows: local x, y, z


def build(name, look, src_dir, out_dir):
    parts = {p: [] for p in PARTS}
    joints = None
    for slot in ("head", "body", "legs", "feet", "extra"):
        if slot not in look:
            continue
        path, mesh, recolor = look[slot]
        src = Source.get(os.path.join(src_dir, path))
        if joints is None or slot == "body":
            joints = src.joint_pos
        for n in src.mesh_nodes(mesh):
            for p, pos, nor, col in src.triangles(n, recolor):
                parts[p].append((pos, nor, col))
    J = joints
    hipc = (J["UpperLeg.L"] + J["UpperLeg.R"]) / 2
    pivot_t = np.array([hipc[0], hipc[1], 0.0])
    palm = {}
    for s in ("L", "R"):
        d = J["Wrist." + s] - J["LowerArm." + s]
        palm[s] = J["Wrist." + s] + d / np.linalg.norm(d) * 0.07
    frames = {"torso": (pivot_t, None), "head": (J["Head"], None)}
    for s in ("L", "R"):
        frames["upper" + s] = (J["UpperArm." + s], arm_basis(J["LowerArm." + s] - J["UpperArm." + s]))
        frames["fore" + s] = (J["LowerArm." + s], arm_basis(palm[s] - J["LowerArm." + s]))
        frames["thigh" + s] = (J["UpperLeg." + s], None)
        frames["shin" + s] = (J["LowerLeg." + s], None)
    knee = J["LowerLeg.R"] - J["UpperLeg.R"]
    dims = {
        "hipY": round(float(hipc[1]), 4),
        "hip": round(float(abs(J["UpperLeg.R"][2] - hipc[2])), 4),
        "knee": [round(float(x), 4) for x in knee],
        "neck": [round(float(x), 4) for x in (J["Head"] - pivot_t)],
        "shoulder": [round(float(x), 4) for x in (J["UpperArm.R"] - pivot_t)],
        "upper": round(float(np.linalg.norm(J["LowerArm.R"] - J["UpperArm.R"])), 4),
        "fore": round(float(np.linalg.norm(palm["R"] - J["LowerArm.R"])), 4),
    }

    # glTF document: one node + mesh per part
    buf = bytearray()
    doc = {"asset": {"version": "2.0", "generator": "STEEL HEARTH tools/people_convert.py (Quaternius CC0 figures)"},
           "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "accessors": [], "bufferViews": [], "buffers": [],
           "extras": {"dims": dims, "source": "Quaternius Ultimate Modular Men/Women, CC0 1.0"}}

    def add_view(arr, target):
        nonlocal buf
        while len(buf) % 4:
            buf.append(0)
        off = len(buf)
        b = arr.tobytes()
        buf += b
        doc["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(b), "target": target})
        return len(doc["bufferViews"]) - 1

    def add_acc(arr, ctype, typ, target, minmax=False):
        view = add_view(arr, target)
        a = {"bufferView": view, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = [float(x) for x in arr.min(axis=0)]
            a["max"] = [float(x) for x in arr.max(axis=0)]
        doc["accessors"].append(a)
        return len(doc["accessors"]) - 1

    tris = 0
    for p in PARTS:
        tl = parts[p]
        if not tl:
            continue
        origin, basis = frames[p]
        pos = np.concatenate([t[0] for t in tl]) - origin
        nor = np.concatenate([t[1] for t in tl])
        if basis is not None:
            pos = pos @ basis.T
            nor = nor @ basis.T
        col = np.repeat(np.array([t[2] for t in tl]), 3, axis=0)
        # weld identical vertices so the part is indexed
        key = np.concatenate([np.round(pos, 5), np.round(nor, 3), np.round(col, 4)], axis=1)
        uniq, inv = np.unique(key, axis=0, return_inverse=True)
        inv = inv.reshape(-1)
        vp = to_gltf(uniq[:, 0:3]).astype(np.float32)
        vn = to_gltf(uniq[:, 3:6]).astype(np.float32)
        vc = uniq[:, 6:9].astype(np.float32)
        it = inv.astype(np.uint16 if len(uniq) < 65536 else np.uint32)
        acc_p = add_acc(vp, 5126, "VEC3", 34962, True)
        acc_n = add_acc(vn, 5126, "VEC3", 34962)
        acc_c = add_acc(vc, 5126, "VEC3", 34962)
        acc_i = add_acc(it, 5123 if it.dtype == np.uint16 else 5125, "SCALAR", 34963)
        doc["meshes"].append({"name": p, "primitives": [{"attributes": {"POSITION": acc_p, "NORMAL": acc_n, "COLOR_0": acc_c}, "indices": acc_i}]})
        doc["nodes"].append({"name": p, "mesh": len(doc["meshes"]) - 1})
        doc["scenes"][0]["nodes"].append(len(doc["nodes"]) - 1)
        tris += len(tl)
    while len(buf) % 4:
        buf.append(0)
    doc["buffers"].append({"byteLength": len(buf)})
    js = json.dumps(doc, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    out = os.path.join(out_dir, name + ".glb")
    with open(out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(buf), 0x004E4942) + bytes(buf))
    print("%-16s %5d tris  %7d bytes  hipY %.2f thigh %.2f upper %.2f fore %.2f" %
          (name, tris, os.path.getsize(out), dims["hipY"], -dims["knee"][1], dims["upper"], dims["fore"]))


# ---------------------------------------------------------------------------------------------------
# first-person arms: the soldier's sleeves and hands, fingers posed round a grip (right) and under a
# handguard (left), cut into upper arm / forearm / hand and exported white so the game can tint them
# with whatever coat and gloves the player wears.
# ---------------------------------------------------------------------------------------------------
FP_UPPER, FP_FORE, FP_PALM = 0.42, 0.40, 0.06       # src/viewmodel.lua's first-person arm rig
FP_HAND = 0.85                                      # the stylised hands are chunky this close to the eye
CURL = {   # radians per finger knuckle (joints 2, 3, 4); thumb joints (1, 2)
    "R": {"Index": (0.75, 0.9, 0.5), "Middle": (1.25, 1.2, 0.8), "Ring": (1.3, 1.25, 0.8), "Pinky": (1.35, 1.25, 0.8), "Thumb": (0.12, 0.25)},
    "L": {"Index": (0.6, 0.75, 0.45), "Middle": (0.75, 0.85, 0.5), "Ring": (0.8, 0.85, 0.5), "Pinky": (0.85, 0.9, 0.5), "Thumb": (0.1, 0.15)},
}


def rot_about(p, axis, a):
    axis = axis / np.linalg.norm(axis)
    x, y, z = axis
    c, s = np.cos(a), np.sin(a)
    t = 1 - c
    r = np.array([[c + x * x * t, x * y * t - z * s, x * z * t + y * s],
                  [y * x * t + z * s, c + y * y * t, y * z * t - x * s],
                  [z * x * t - y * s, z * y * t + x * s, c + z * z * t]])
    m = np.eye(4)
    m[:3, :3] = r
    m[:3, 3] = p - r @ p
    return m


def build_fp_arms(src_dir, out_dir):
    src = Source.get(os.path.join(src_dir, M + "Swat.glb"))
    doc, binc = src.doc, src.bin
    J = src.joint_pos
    names = src.joint_names
    # parents within the skin
    node_of = {doc["nodes"][j]["name"]: j for j in doc["skins"][0]["joints"]}
    parent = {}
    for i, n in enumerate(doc["nodes"]):
        for c in n.get("children", []):
            parent[doc["nodes"][c].get("name")] = n.get("name")
    # posed transform per joint (bind space): curl the fingers
    posed = {}

    def pose_of(name):
        if name in posed:
            return posed[name]
        m = pose_of(parent[name]) if parent.get(name) in node_of else np.eye(4)
        base, side = name[:-2].rstrip("0123456789"), name[-1]
        k = name[:-2][len(base):]
        if name.endswith((".L", ".R")) and base in FINGERS and k.isdigit():
            angles = CURL[side][base]
            # joint 1 of a finger is the metacarpal inside the palm: the knuckles are joints 2, 3 and 4
            i = int(k) - (1 if base == "Thumb" else 2)
            if 0 <= i < len(angles):
                nxt = name[:-2][:len(base)] + str(int(k) + 1) + "." + side
                d = (J[nxt] - J[name]) if nxt in J else (J[name] - J[parent[name]])
                d = d / np.linalg.norm(d)
                # palm faces down in the T-pose: curl towards it (the thumb also tucks forward over the grip)
                axis = np.cross(d, [0.0, -1.0, 0.0])
                if base == "Thumb":
                    axis = np.cross(d, [0.0, -0.6, 0.0] + (J["Middle1." + side] - J["Wrist." + side]) * 2)
                m = m @ rot_about(J[name], axis, angles[i])
        posed[name] = m
        return m

    parts = {k: [] for k in ("upperL", "foreL", "handL", "upperR", "foreR", "handR")}
    node = src.mesh_nodes("Swat_Body")[0]
    for pr in doc["meshes"][node["mesh"]]["primitives"]:
        at = pr["attributes"]
        pos = to_game(accessor(doc, binc, at["POSITION"])) * SCALE
        nor = to_game(accessor(doc, binc, at["NORMAL"]))
        joints = accessor(doc, binc, at["JOINTS_0"])
        weights = accessor(doc, binc, at["WEIGHTS_0"])
        idx = accessor(doc, binc, pr["indices"])[:, 0].reshape(-1, 3)
        # linear blend skinning with the posed fingers
        P = np.zeros_like(pos)
        N = np.zeros_like(nor)
        for k in range(4):
            for vi in range(len(pos)):
                w = weights[vi, k]
                if w <= 0:
                    continue
                m = pose_of(names[joints[vi, k]])
                P[vi] += w * (m[:3, :3] @ pos[vi] + m[:3, 3])
                N[vi] += w * (m[:3, :3] @ nor[vi])
        N /= np.maximum(1e-9, np.linalg.norm(N, axis=1))[:, None]
        dom = joints[np.arange(len(joints)), np.argmax(weights, axis=1)]
        for a, b, c in idx:
            bones = [names[dom[a]], names[dom[b]], names[dom[c]]]
            ps = []
            for bn in bones:
                pt = part_of(bn)
                if pt.startswith("fore") and bn[:-2] not in ("LowerArm",):
                    pt = "hand" + bn[-1]
                ps.append(pt)
            p = max(set(ps), key=ps.count)
            if p in parts:
                parts[p].append((P[[a, b, c]], N[[a, b, c]], [1.0, 1.0, 1.0]))
    frames = {}
    for s in ("L", "R"):
        sh, el, wr = J["UpperArm." + s], J["LowerArm." + s], J["Wrist." + s]
        frames["upper" + s] = (sh, arm_basis(el - sh), FP_UPPER / np.linalg.norm(el - sh))
        frames["fore" + s] = (el, arm_basis(wr - el), FP_FORE / np.linalg.norm(wr - el))
        along = J["Middle1." + s] - wr
        along /= np.linalg.norm(along)
        back = np.array([0.0, 1.0, 0.0]) - along * along[1]
        back /= np.linalg.norm(back)
        frames["hand" + s] = (wr + along * FP_PALM, np.stack([along, back, np.cross(along, back)]) * FP_HAND, None)
    write_parts("fp_arms", parts, frames, {"upper": FP_UPPER, "fore": FP_FORE, "palm": FP_PALM}, out_dir)


def write_parts(name, parts, frames, dims, out_dir):
    buf = bytearray()
    doc = {"asset": {"version": "2.0", "generator": "STEEL HEARTH tools/people_convert.py (Quaternius CC0 figures)"},
           "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "accessors": [], "bufferViews": [], "buffers": [],
           "extras": {"dims": dims, "source": "Quaternius Ultimate Modular Men/Women, CC0 1.0"}}

    def add_acc(arr, ctype, typ, target, minmax=False):
        while len(buf) % 4:
            buf.append(0)
        off = len(buf)
        b = arr.tobytes()
        buf.extend(b)
        doc["bufferViews"].append({"buffer": 0, "byteOffset": off, "byteLength": len(b), "target": target})
        a = {"bufferView": len(doc["bufferViews"]) - 1, "componentType": ctype, "count": int(arr.shape[0]), "type": typ}
        if minmax:
            a["min"] = [float(x) for x in arr.min(axis=0)]
            a["max"] = [float(x) for x in arr.max(axis=0)]
        doc["accessors"].append(a)
        return len(doc["accessors"]) - 1

    tris = 0
    for p, tl in parts.items():
        if not tl:
            continue
        origin, basis, stretch = frames[p]
        pos = np.concatenate([t[0] for t in tl]) - origin
        nor = np.concatenate([t[1] for t in tl])
        if basis is not None:
            pos = pos @ basis.T
            nor = nor @ basis.T
        if stretch:
            pos[:, 0] *= stretch
        col = np.repeat(np.array([t[2] for t in tl]), 3, axis=0)
        key = np.concatenate([np.round(pos, 5), np.round(nor, 3), np.round(col, 4)], axis=1)
        uniq, inv = np.unique(key, axis=0, return_inverse=True)
        inv = inv.reshape(-1)
        it = inv.astype(np.uint16 if len(uniq) < 65536 else np.uint32)
        acc_p = add_acc(to_gltf(uniq[:, 0:3]).astype(np.float32), 5126, "VEC3", 34962, True)
        acc_n = add_acc(to_gltf(uniq[:, 3:6]).astype(np.float32), 5126, "VEC3", 34962)
        acc_c = add_acc(uniq[:, 6:9].astype(np.float32), 5126, "VEC3", 34962)
        acc_i = add_acc(it, 5123 if it.dtype == np.uint16 else 5125, "SCALAR", 34963)
        doc["meshes"].append({"name": p, "primitives": [{"attributes": {"POSITION": acc_p, "NORMAL": acc_n, "COLOR_0": acc_c}, "indices": acc_i}]})
        doc["nodes"].append({"name": p, "mesh": len(doc["meshes"]) - 1})
        doc["scenes"][0]["nodes"].append(len(doc["nodes"]) - 1)
        tris += len(tl)
    while len(buf) % 4:
        buf.append(0)
    doc["buffers"].append({"byteLength": len(buf)})
    js = json.dumps(doc, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    out = os.path.join(out_dir, name + ".glb")
    with open(out, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(buf)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(buf), 0x004E4942) + bytes(buf))
    print("%-16s %5d tris  %7d bytes" % (name, tris, os.path.getsize(out)))


def main():
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    only = sys.argv[3:]
    for name, look in LOOKS.items():
        if only and name not in only:
            continue
        build(name, look, src_dir, out_dir)
    if not only or "fp_arms" in only:
        build_fp_arms(src_dir, out_dir)


if __name__ == "__main__":
    main()
