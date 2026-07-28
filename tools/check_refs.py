# -*- coding: utf-8 -*-
"""
Cheap static reference check.

Not a compiler - it only catches the single mistake that has cost the most
CI time on this project: referencing a symbol that was never written, because
the code calling it and the code defining it were authored minutes apart with
no build in between. Run before pushing.
"""

import glob
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def load():
    files = (glob.glob(os.path.join(ROOT, "BabyTracker", "**", "*.swift"), recursive=True)
             + glob.glob(os.path.join(ROOT, "ForumKit", "**", "*.swift"), recursive=True))
    return {os.path.basename(f): io.open(f, encoding="utf-8").read() for f in files}


def members_of(source, *patterns):
    found = set()
    for pattern in patterns:
        found |= set(re.findall(pattern, source))
    return found


def main():
    src = load()
    combined = "\n".join(src.values())
    problems = []

    def report(label, missing):
        if missing:
            problems.append("%s: %s" % (label, ", ".join(sorted(missing))))
            print("  FAIL %-22s %s" % (label, ", ".join(sorted(missing))))
        else:
            print("  ok   %s" % label)

    # Localised strings
    declared = members_of(src["Strings.swift"], r"static (?:var|func|let) (\w+)")
    report("L.*", set(re.findall(r"\bL\.(\w+)", combined)) - declared)

    # ForumStore surface
    store = members_of(src["ForumStore.swift"], r"public func (\w+)",
                       r"public (?:private\(set\) )?var (\w+)")
    calls = (set(re.findall(r"\bstore\.(\w+)", combined))
             | set(re.findall(r"ForumStore\.shared\.(\w+)", combined)))
    report("ForumStore", calls - store)

    # ForumAuth surface
    auth = members_of(src["ForumAuth.swift"], r"public func (\w+)",
                      r"public (?:private\(set\) )?var (\w+)",
                      r"public static let (\w+)")
    report("ForumAuth", set(re.findall(r"\bauth\.(\w+)", combined)) - auth)

    # `model` is bound to ForumFeedModel in the feed and PostDetailModel in the
    # detail screen, so the union is the correct surface to check against.
    model = (members_of(src["ForumFeedModel.swift"], r"(?:func|var|let) (\w+)")
             | members_of(src["PostDetailView.swift"], r"(?:func|var|let) (\w+)"))
    report("model.*", set(re.findall(r"\bmodel\.(\w+)", combined)) - model)

    # Design tokens
    warm = members_of(src["WarmPalette.swift"], r"static (?:let|var|func) (\w+)")
    report("Warm.*", set(re.findall(r"\bWarm\.(\w+)", combined)) - warm - {"Tier"})

    metrics = members_of(src["WarmPalette.swift"], r"static (?:let|var) (\w+)")
    report("WarmMetrics.*", set(re.findall(r"\bWarmMetrics\.(\w+)", combined)) - metrics)

    fonts = members_of(src["WarmType.swift"], r"static let (\w+)")
    report("WarmFont.*", set(re.findall(r"\bWarmFont\.(\w+)", combined)) - fonts)

    # Every referenced view type must be declared somewhere
    declared_types = members_of(combined, r"(?:struct|class|enum|actor)\s+(\w+)")
    view_refs = set(re.findall(r"\b([A-Z][A-Za-z0-9]*View)\s*\(", combined))
    system_views = {
        "NavigationView", "ScrollView", "AnyView", "TabView", "EmptyView",
        "ContentView", "ProgressView", "UnicodeScalarView", "ImageView",
    }
    report("View types", view_refs - declared_types - system_views)

    print()
    if problems:
        print("%d problem(s)" % len(problems))
        return 1
    print("no unresolved references")
    return 0


if __name__ == "__main__":
    sys.exit(main())
