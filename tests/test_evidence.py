import json
from pathlib import Path
import tempfile
import unittest

from scripts import evidence


class EvidenceTests(unittest.TestCase):
    def test_hex_transport_is_parsed_without_executing_lua(self):
        payload = {"schema": 1, "records": [], "addonVersion": "fixture"}
        encoded = json.dumps(payload).encode().hex()
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.lua"
            path.write_text('error("must never run")\nJustAHintDiagnosticsDB = { ["evidenceHex"] = "' + encoded + '" }')
            self.assertEqual(evidence.read_capture(path), payload)

    def test_missing_or_bad_payload_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.lua"
            path.write_text('JustAHintDiagnosticsDB = { ["evidenceHex"] = "6666" }')
            with self.assertRaises(ValueError): evidence.read_capture(path)

    def test_successful_area_call_does_not_become_visual_verification(self):
        capture = {"records": [{"kind": "area", "id": 1, "data": {"status": "call-ok-unverified"}}]}
        result = evidence.summarize(capture)
        self.assertFalse(result["nativeAreaVisuallyVerified"])
        self.assertFalse(result["testerReportedVisibleArea"])

    def test_destination_and_tester_observation_stay_separate_from_verdict(self):
        capture = {"records": [
            {"kind": "scan", "id": 1, "data": {"results": [{"questID": 42, "destination": {"status": "ok"}}]}},
            {"kind": "area-observation", "id": 2, "data": {"visualResult": "visible", "areaRecordID": 1}},
        ]}
        result = evidence.summarize(capture)
        self.assertEqual(result["questProbes"][0]["destination"]["status"], "ok")
        self.assertTrue(result["testerReportedVisibleArea"])
        self.assertFalse(result["questDestinationUsefulnessVerified"])

    def test_area_comparison_retains_embedded_probe_and_clear_reason(self):
        capture = {"records": [
            {"kind": "area", "id": 3, "data": {"status": "call-ok-unverified",
                "questProbe": {"questID": 42, "mapPOIs": {"status": "ok", "value": []}}}},
            {"kind": "area-cleared", "id": 4, "data": {"areaRecordID": 3, "reason": "QUEST_LOG_UPDATE"}},
        ]}
        result = evidence.summarize(capture)
        self.assertEqual(result["questProbes"][0]["questID"], 42)
        self.assertEqual(result["questProbes"][0]["mapPOIs"]["value"], [])
        self.assertEqual(result["areaClears"][0]["areaRecordID"], 3)
        self.assertEqual(result["areaClears"][0]["reason"], "QUEST_LOG_UPDATE")
        self.assertFalse(result["nativeAreaVisuallyVerified"])

    def test_frame_isolation_remains_scoped_evidence_with_end_reason(self):
        result = evidence.summarize({"records": [
            {"id": 1, "kind": "isolation", "data": {"status": "frames-hidden-unverified",
                "scope": "world-map-quest-frames-only"}},
            {"id": 2, "kind": "isolation-ended", "data": {"isolationRecordID": 1,
                "reason": "default-quest-frame-reappeared", "status": "restore-called"}},
        ]})
        self.assertEqual(result["isolationTests"][0]["scope"], "world-map-quest-frames-only")
        self.assertEqual(result["isolationEnds"][0]["isolationRecordID"], 1)
        self.assertFalse(result["nativeAreaVisuallyVerified"])

    def test_region_queries_preserve_results_without_claiming_visibility_or_absence(self):
        statuses = ["draw-dependent-hit", "no-hit-unknown", "inconclusive-controls"]
        records = [{"id": index, "kind": "region-probe", "data": {
            "status": status, "questID": 42, "areaRecordID": 3,
            "absenceEstablished": False, "visualResult": "unverified",
            "phases": {"drawn": {"samples": 1089, "matches": 1 if index == 0 else 0}},
        }} for index, status in enumerate(statuses)]
        result = evidence.summarize({"records": records})
        self.assertEqual([item["status"] for item in result["regionProbes"]], statuses)
        self.assertEqual(result["regionProbes"][0]["phases"]["drawn"]["matches"], 1)
        self.assertTrue(all(item["areaRecordID"] == 3 for item in result["regionProbes"]))
        self.assertTrue(all(item["absenceEstablished"] is False for item in result["regionProbes"]))
        self.assertFalse(result["nativeAreaVisuallyVerified"])
        self.assertFalse(result["testerReportedVisibleArea"])

    def test_silent_queries_preserve_spatial_evidence_without_a_visual_verdict(self):
        data = {"status": "closed-map-transparent-hit", "questID": 837,
                "visibleDrawingRequested": False, "absenceEstablished": False,
                "phases": {"transparentDrawn": {"locations": [{"x": 0.4375, "y": 0.375}]}}}
        result = evidence.summarize({"records": [{"id": 18, "kind": "silent-region-probe", "data": data}]})
        self.assertEqual(result["silentRegionProbes"][0], {"recordID": 18, **data})
        self.assertFalse(result["nativeAreaVisuallyVerified"])
        self.assertFalse(result["testerReportedVisibleArea"])

    def test_native_button_placement_preserves_unverified_result_and_cleanup(self):
        data = {"status": "display-requested-unverified", "nativeIntegrationVerified": False,
                "visualResult": "unverified", "clickEnabled": False}
        clear = {"buttonRecordID": 14, "reason": "native-context-changed"}
        result = evidence.summarize({"records": [
            {"kind": "native-button", "id": 14, "data": data},
            {"kind": "native-button-cleared", "id": 15, "data": clear},
        ]})
        self.assertEqual(result["nativeButtonProbes"], [{"recordID": 14, **data}])
        self.assertEqual(result["nativeButtonClears"], [{"recordID": 15, **clear}])
        self.assertFalse(result["nativeAreaVisuallyVerified"])

    def test_native_ui_inspection_preserves_partial_reads_without_compatibility_verdict(self):
        data = {"status": "captured", "nativeIntegrationVerified": False,
                "frames": [{"source": "QuestMapFrame.DetailsFrame", "status": "present",
                            "visible": {"status": "ok", "value": False},
                            "rect": {"status": "error", "detail": "restricted geometry"}}]}
        result = evidence.summarize({"records": [{"kind": "native-ui", "id": 12, "data": data}]})
        self.assertEqual(result["nativeUIInspections"], [{"recordID": 12, **data}])
        self.assertFalse(result["nativeAreaVisuallyVerified"])
        self.assertFalse(result["testerReportedVisibleArea"])


if __name__ == "__main__": unittest.main()
