#!/usr/bin/env python3
"""Minimal fake `oc` for testing toolkit-ops checks without a cluster.

Serves resources from the JSON fixture at $MOCK_OC_FIXTURE:
  {"resources": [<k8s objects>], "exec": {"<ns>/<pod>": {"env": "...", "missing_modules": [...],
   "missing_files": [...], "git": "abc1234 2026-11-01", "url_code": "401", "exec_rc": 0}},
   "whoami": "admin", "can_i": "yes"}
Supports: whoami, auth can-i, get (kind[/name] [name] -n/-A, -o json|jsonpath=...|name), get --raw, exec.
"""
import json
import os
import re
import sys

FIX = json.load(open(os.environ["MOCK_OC_FIXTURE"]))
RES = FIX["resources"]
ALIAS = {"deploy": "deployment", "csv": "clusterserviceversion", "dsc": "datasciencecluster",
         "dsci": "dscinitialization", "co": "clusteroperator", "sc": "storageclass", "ns": "namespace",
         "svc": "service", "cm": "configmap", "sa": "serviceaccount", "isvc": "inferenceservice",
         "machinesets": "machineset", "crd": "customresourcedefinition", "is": "imagestream"}


def norm_kind(k):
    k = k.lower().split(".")[0]
    k = ALIAS.get(k, k)
    kinds = {o["kind"].lower() for o in RES}
    if k not in kinds and k.endswith("es") and k[:-2] in kinds:
        k = k[:-2]
    elif k not in kinds and k.endswith("s") and k[:-1] in kinds:
        k = k[:-1]
    return ALIAS.get(k, k)


def split_path(p):
    toks, cur, i = [], "", 0
    while i < len(p):
        c = p[i]
        if c == "\\" and i + 1 < len(p):
            cur += p[i + 1]; i += 2; continue
        if c == ".":
            if cur: toks.append(cur)
            cur = ""; i += 1; continue
        if c == "[":
            if cur: toks.append(cur)
            cur = ""
            j = p.index("]", i)
            toks.append(p[i:j + 1]); i = j + 1; continue
        cur += c; i += 1
    if cur: toks.append(cur)
    return toks


def walk(vals, toks):
    for t in toks:
        nxt = []
        for v in vals:
            if t.startswith("[?("):
                m = re.match(r'\[\?\(@\.([\w.]+)=="([^"]*)"\)\]', t)
                if isinstance(v, list) and m:
                    key, want = m.group(1).split("."), m.group(2)
                    for it in v:
                        x = it
                        for kk in key:
                            x = x.get(kk) if isinstance(x, dict) else None
                        if x is not None and str(x) == want:
                            nxt.append(it)
            elif t == "[*]":
                if isinstance(v, list): nxt.extend(v)
                elif isinstance(v, dict): nxt.extend(v.values())
            elif t.startswith("["):
                n = int(t[1:-1])
                if isinstance(v, list) and len(v) > n: nxt.append(v[n])
            else:
                if isinstance(v, dict) and t in v: nxt.append(v[t])
                elif isinstance(v, list):
                    nxt.extend(x[t] for x in v if isinstance(x, dict) and t in x)
        vals = nxt
    return vals


def fmt(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, (dict, list)): return json.dumps(v)
    return str(v)


def jsonpath(obj, expr):
    out = ""
    for lit, path in re.findall(r"([^{]*)\{([^}]*)\}", expr):
        out += lit
        if path.startswith("range") or path == "end": continue
        vals = walk([obj], split_path(path.lstrip(".")) if path not in (".", "") else [])
        out += " ".join(fmt(v) for v in vals)
    tail = re.sub(r".*\}", "", expr) if "}" in expr else ""
    return out + tail


def cmd_get(args):
    ns, alln, out, raw, sel = None, False, None, None, None
    pos = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("-n", "--namespace"): ns = args[i + 1]; i += 2; continue
        if a in ("-A", "--all-namespaces"): alln = True; i += 1; continue
        if a == "-o": out = args[i + 1]; i += 2; continue
        if a.startswith("-o"): out = a[2:].lstrip("="); i += 1; continue
        if a == "--raw": raw = args[i + 1]; i += 2; continue
        if a in ("-l", "--selector"): sel = args[i + 1]; i += 2; continue
        if a.startswith("--"): i += 1; continue
        pos.append(a); i += 1
    if raw is not None:
        print(json.dumps({"data": [{"id": "mock-model"}]})); return 0
    if not pos: return 1
    kind, name = pos[0], (pos[1] if len(pos) > 1 else None)
    if "/" in kind: kind, name = kind.split("/", 1)
    kind = norm_kind(kind)
    objs = [o for o in RES if o["kind"].lower() == kind]
    if sel:
        k_, _, v_ = sel.partition("=")
        objs = [o for o in objs if o["metadata"].get("labels", {}).get(k_) == v_]
    if ns and not alln:
        objs = [o for o in objs if o["metadata"].get("namespace") in (ns, None)]
    if name:
        objs = [o for o in objs if o["metadata"]["name"] == name]
        if not objs: return 1
        obj = objs[0]
    else:
        obj = {"kind": "List", "items": objs}
    if out == "json": print(json.dumps(obj))
    elif out and out.startswith("jsonpath"):
        expr = out.split("=", 1)[1].strip("'\"")
        print(jsonpath(obj, expr), end="")
    elif out == "name": print("\n".join(f"{kind}/{o['metadata']['name']}" for o in (objs if not name else [obj])))
    else:
        if not name and not objs: return 0
        print("\n".join(o["metadata"]["name"] for o in (objs if not name else [obj])))
    return 0


def cmd_exec(args):
    pod, ns = args[0], None
    if "-n" in args: ns = args[args.index("-n") + 1]
    cmd = args[args.index("--") + 1:]
    ex = FIX.get("exec", {}).get(f"{ns}/{pod}")
    if ex is None: return 1
    prog = cmd[0]
    if prog == "env": print(ex.get("env", "")); return 0
    if prog == "git": print(ex.get("git", "")); return 0 if ex.get("git") else 128
    if prog == "test": return 1 if any(cmd[-1].endswith(f) for f in ex.get("missing_files", [])) else 0
    if prog == "python3":
        code = cmd[2] if len(cmd) > 2 else ""
        m = re.match(r"import (\S+)$", code)
        if m: return 1 if m.group(1) in ex.get("missing_modules", []) else 0
        if "urllib" in code: print(ex.get("url_code", "401")); return 0
        return 0
    if prog == "bash": print(f"EXIT={ex.get('exec_rc', 0)}"); return 0
    return 0


def main():
    a = sys.argv[1:]
    if os.environ.get('MOCK_OC_LOG'):
        with open(os.environ['MOCK_OC_LOG'], 'a') as f:
            f.write(' '.join(a) + '\n')
    if not a: return 1
    if os.environ.get('MOCK_OC_UNREACHABLE'): return 1
    if a[0] == "whoami":
        if "-t" in a: print("sha256~mock"); return 0
        print(FIX.get("whoami", "admin")); return 0
    if a[0] == "auth": print(FIX.get("can_i", "yes")); return 0
    if a[0] == "get": return cmd_get(a[1:])
    if a[0] == "exec": return cmd_exec(a[1:])
    if a[0] in ("project",): print("default"); return 0
    sys.stderr.write(f"mock-oc: refusing non-read-only command: {' '.join(a)}\n")
    return 99


sys.exit(main())
