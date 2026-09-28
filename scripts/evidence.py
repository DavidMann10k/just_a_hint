"""Read diagnostic JSON transported as hex; never execute SavedVariables Lua."""

import json
from pathlib import Path
import re

from . import package


def read_capture(path: Path) -> dict:
    if path.stat().st_size > 20_000_000: raise ValueError("diagnostic SavedVariables exceed the import size limit")
    text = path.read_text(encoding="utf-8-sig")
    matches = re.findall(r'\["evidenceHex"\]\s*=\s*"([0-9a-f]+)"', text)
    if len(matches) != 1: raise ValueError("no unique evidenceHex payload; run the current /jahdiag scan and /reload")
    value = json.loads(bytes.fromhex(matches[0]).decode("utf-8"))
    if not isinstance(value, dict) or value.get("schema") != 1 or not isinstance(value.get("records"), list):
        raise ValueError("unexpected diagnostic evidence schema")
    return value


def summarize(capture: dict) -> dict:
    result = {"builds": [], "capabilities": [], "scans": [], "questProbes": [], "areaCalls": [], "areaObservations": [], "areaClears": [],
              "isolationTests": [], "isolationEnds": [], "regionProbes": [], "silentRegionProbes": [], "nativeUIInspections": [],
              "nativeButtonProbes": [], "nativeButtonClears": [],
              "nativeAreaVisuallyVerified": False, "questDestinationUsefulnessVerified": False}
    builds = set()
    for record in capture["records"]:
        build = record.get("build", {})
        if build.get("status") == "ok":
            signature = json.dumps(build["value"], sort_keys=True)
            if signature not in builds: result["builds"].append(build["value"]); builds.add(signature)
        kind, data = record.get("kind"), record.get("data", {})
        if "capabilities" in data:
            result["capabilities"].append({"recordID": record.get("id"), "build": build,
                                            "functions": data["capabilities"]})
        if kind == "scan":
            result["scans"].append({"recordID": record.get("id"), "questListStatus": data.get("questListStatus"),
                                   "capturedQuests": len(data.get("results", [])), "context": data.get("context")})
        probes = data.get("results", []) if kind == "scan" else [data] if kind == "probe" else []
        if kind == "area" and isinstance(data.get("questProbe"), dict): probes = [data["questProbe"]]
        for probe in probes:
            result["questProbes"].append({"recordID": record.get("id"), "questID": probe.get("questID"), "status": probe.get("status"),
                "title": probe.get("title"), "guidance": probe.get("context", {}),
                "accepted": probe.get("accepted"), "objectives": probe.get("objectives"),
                "destination": probe.get("destination"), "distance": probe.get("distance"),
                "mapPOIs": probe.get("mapPOIs"), "mapWaypoint": probe.get("mapWaypoint")})
        if kind == "area": result["areaCalls"].append({"recordID": record.get("id"), **data})
        if kind == "area-observation": result["areaObservations"].append(data)
        if kind == "area-cleared": result["areaClears"].append({"recordID": record.get("id"), **data})
        if kind == "silent-region-probe": result["silentRegionProbes"].append({"recordID": record.get("id"), **data})
        if kind == "region-probe": result["regionProbes"].append({"recordID": record.get("id"), **data})
        if kind == "native-ui": result["nativeUIInspections"].append({"recordID": record.get("id"), **data})
        if kind == "native-button": result["nativeButtonProbes"].append({"recordID": record.get("id"), **data})
        if kind == "native-button-cleared": result["nativeButtonClears"].append({"recordID": record.get("id"), **data})
        if kind == "isolation": result["isolationTests"].append({"recordID": record.get("id"), **data})
        if kind == "isolation-ended": result["isolationEnds"].append({"recordID": record.get("id"), **data})
    # Preserve observations as tester evidence, not as a machine-generated verdict.
    result["testerReportedVisibleArea"] = any(item.get("visualResult") == "visible" for item in result["areaObservations"])
    return result


def import_evidence(root: Path, client: dict) -> dict:
    wtf = Path(client["clientDirectory"]) / "WTF"
    paths = sorted(wtf.rglob(package.ADDON + ".lua"), key=lambda path: path.stat().st_mtime, reverse=True)
    if not paths: raise ValueError("no diagnostic captures yet; in the beta run /jahdiag scan normal, then /reload")
    # Choose the most recently flushed character capture; keep its personal path
    # in ignored local evidence rather than public project documentation.
    capture = read_capture(paths[0])
    result = summarize(capture)
    package.write_json(root / ".jah/evidence.json", capture)
    package.write_json(root / ".jah/feasibility.json", result)
    return result
