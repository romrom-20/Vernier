#!/usr/bin/env python3
"""Score invented contribution probe reports, including every declared batch target.

Usage: summarize-contribution-probe.py --run LABEL REPORT FIXTURES [--run ...]
Reads saved reports only; never opens an archive, changes settings or calls a model.
"""
import argparse
import json
import math
from pathlib import Path

ACTS = ("continued", "directed", "checked", "reported")


def summarize(report, fixtures):
    if report.get("syntheticOnly") is not True:
        raise ValueError("Expected an explicitly synthetic probe report")
    cases = {case["id"]: case for case in fixtures}
    rows = {row["id"]: row for row in report["cases"]}
    if not cases or len(cases) != len(fixtures) or len(rows) != len(report["cases"]) or rows.keys() != cases.keys():
        raise ValueError("Report must contain every unique fixture exactly once; partial runs cannot be scored")
    counts = dict(targets=0, completeMatches=0, primaryMatches=0, wordingPrimaryMatches=0,
                  accepted=0, acceptedIncorrect=0, acceptedClear=0, withheld=0, missing=0,
                  falsePositiveActs=0, missedActs=0, packetMatches=0, packets=len(rows), errors=0)
    acts = {act: dict(tp=0, fp=0, fn=0) for act in ACTS}
    misses = []
    for case_id, case in cases.items():
        row = rows[case_id]
        counts["errors"] += "error" in row
        labels = row.get("readings", [])
        expected_targets = case.get("targets", [dict(messageIndex=len(case["messages"]) - 1,
                                                    primary=case["primary"], additional=case["additional"])])
        packet_match = True
        for target in expected_targets:
            message_id = f"invented-{case_id}-{target['messageIndex']}"
            matching = [label for label in labels if label["messageID"] == message_id]
            if len(matching) > 1:
                raise ValueError(f"Duplicate target reading: {message_id}")
            label = matching[0] if matching else None
            expected = set() if target["primary"] == "other" else {target["primary"], *target["additional"]}
            actual = {claim["action"] for claim in label["claims"]} if label else set()
            primary = label["primary"] if label else None
            accepted = label is not None and label["accepted"]
            primary_match = primary == target["primary"]
            complete = primary_match and actual == expected and (accepted or target["primary"] == "other")
            counts["targets"] += 1
            counts["completeMatches"] += complete
            counts["primaryMatches"] += primary_match
            counts["accepted"] += accepted
            counts["acceptedClear"] += accepted and primary != "other"
            counts["acceptedIncorrect"] += accepted and not complete
            counts["withheld"] += label is not None and not accepted
            counts["missing"] += label is None
            counts["falsePositiveActs"] += len(actual - expected)
            counts["missedActs"] += len(expected - actual)
            if "targets" in row:
                scores = [score for score in row["targets"] if score["messageID"] == message_id]
                if len(scores) != 1 or scores[0]["pass"] != complete:
                    raise ValueError(f"Probe target score disagrees with saved labels: {message_id}")
                counts["wordingPrimaryMatches"] += scores[0]["wordingPrimaryMatch"]
            elif len(expected_targets) == 1:
                counts["wordingPrimaryMatches"] += row["wordingPrimaryMatch"]
            else:
                raise ValueError("Old batch reports lack per-target wording comparisons; rerun with reportVersion 2")
            for act in ACTS:
                acts[act]["tp"] += act in actual and act in expected
                acts[act]["fp"] += act in actual and act not in expected
                acts[act]["fn"] += act not in actual and act in expected
            if not complete:
                misses.append(dict(case=case_id, messageIndex=target["messageIndex"],
                                   expected=sorted(expected), actual=sorted(actual), primary=primary, accepted=accepted))
            packet_match &= complete
        counts["packetMatches"] += packet_match
        if row["pass"] != packet_match:
            raise ValueError(f"Probe packet score disagrees with all target outcomes: {case_id}")
    for values in acts.values():
        values["precision"] = values["tp"] / (values["tp"] + values["fp"]) if values["tp"] + values["fp"] else None
        values["recall"] = values["tp"] / (values["tp"] + values["fn"]) if values["tp"] + values["fn"] else None
    latency = sorted(row["seconds"] for row in rows.values())
    # Nearest-rank quantiles. Includes cold/warm calls and failed packets; not per-target latency.
    return dict(engine=report["engine"], version=report["version"], **counts, acts=acts,
                packetLatencySeconds={"p50": latency[math.ceil(len(latency) * .5) - 1],
                                      "p95": latency[math.ceil(len(latency) * .95) - 1]}, misses=misses)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run", nargs=3, action="append", required=True, metavar=("LABEL", "REPORT", "FIXTURES"))
    args = parser.parse_args()
    output = {}
    for name, report_path, fixture_path in args.run:
        if name in output:
            parser.error(f"Duplicate run label: {name}")
        output[name] = summarize(json.loads(Path(report_path).read_text()), json.loads(Path(fixture_path).read_text()))
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
