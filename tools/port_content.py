# -*- coding: utf-8 -*-
"""
Ports the Android baby app's legacy content into structured JSON for iOS.

Sources (read-only, never modified):
  res/raw/months.xml       45 entries. Despite the name these are WEEKS (0..44).
                           <MonthInfo> = "how your baby grows" body
                           <ImageUrl>  = repurposed as the parent-focused body
  res/raw/skills.xml       12 entries, one per month (0..11). Each is a single
                           HTML blob holding 3 tiers of skills.
  PregnancyHelper.java     getWeekName(0..44) -> Arabic week titles.

Both XML bodies carry HTML-escaped inline markup (&lt;b&gt;, &lt;br&gt;). We
unescape it and convert to typed blocks so SwiftUI can style headings with the
design system instead of rendering HTML.

Outputs weeks.json and skills.json. Purely mechanical - no content is reworded.
"""

import html
import io
import json
import os
import re
import sys

ANDROID = r"D:\Mohammad\BitBucket\baby-tracker-ar-android(github)"
RAW = os.path.join(ANDROID, "app", "src", "main", "res", "raw")
JAVA = os.path.join(ANDROID, "app", "src", "main", "java", "com", "meshref", "baby")
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "BabyTracker", "Resources")

WEEK_COUNT = 45
MONTH_COUNT = 12
TIERS_PER_MONTH = 3

warnings = []


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read()


def balance_bold(text, label):
    """The source markup is hand-written and has two unbalanced spots that
    Android's lenient Html.fromHtml absorbs silently. Repair them to match the
    author's evident intent rather than dropping content:

      - orphan </b> (week 2 MonthInfo): the preceding line is a heading whose
        opening tag was lost - the same phrase is bolded in every other week -
        so re-open the tag at the start of that line.
      - unclosed <b> followed by only whitespace (week 2 ImageUrl): a dangling
        tag at end of content. Drop it.
    """
    depth = 0
    out = []
    pos = 0
    for m in re.finditer(r"<\s*(/?)\s*b\s*>", text, flags=re.I):
        closing = bool(m.group(1))
        chunk = text[pos:m.start()]
        pos = m.end()

        if closing and depth == 0:
            # Re-open around the last non-empty line so it becomes a heading.
            # The tag usually sits on its own line after the heading text, so
            # trailing newlines must be skipped before locating the line start.
            body = chunk.rstrip()
            trailing = chunk[len(body):]
            nl = body.rfind("\n")
            heading = body[nl + 1:]
            out.append(body[:nl + 1] + "<b>" + heading + "</b>" + trailing)
            warnings.append("%s: orphan </b> - re-opened heading %r"
                            % (label, heading.strip()[:40]))
            continue

        out.append(chunk)
        if closing:
            depth -= 1
            out.append("</b>")
        else:
            depth += 1
            out.append("<b>")

    tail = text[pos:]
    if depth > 0:
        if tail.strip():
            out.append(tail + "</b>" * depth)
            warnings.append("%s: unclosed <b> - auto-closed at end" % label)
        else:
            # Dangling tag before trailing whitespace: drop the tag, keep the space.
            for i in range(len(out) - 1, -1, -1):
                if out[i] == "<b>":
                    del out[i]
                    depth -= 1
                    if depth == 0:
                        break
            out.append(tail)
            warnings.append("%s: dangling <b> at end of content - dropped" % label)
    else:
        out.append(tail)

    return "".join(out)


def to_blocks(raw, label=""):
    """HTML-ish blob -> [{"kind": "heading"|"body"|"bullet", "text": ...}].

    <b>..</b> becomes a heading, everything else is body text. <br> is a line
    break. Blank runs collapse; each body block is one paragraph.
    """
    if not raw:
        return []

    text = html.unescape(raw)
    # Normalise line breaks first so <b> detection works on clean text.
    text = re.sub(r"<\s*br\s*/?\s*>", "\n", text, flags=re.I)
    text = balance_bold(text, label)

    blocks = []

    def push_body(chunk):
        for para in re.split(r"\n\s*\n", chunk):
            para = re.sub(r"[ \t]+", " ", para).strip()
            # Collapse single newlines inside a paragraph into spaces, but keep
            # bullet lines as their own blocks (the skills blobs rely on this).
            if not para:
                continue
            lines = [l.strip() for l in para.split("\n") if l.strip()]
            if any(l.startswith("•") for l in lines):
                for l in lines:
                    blocks.append({"kind": "bullet" if l.startswith("•") else "body",
                                   "text": l.lstrip("•").strip() if l.startswith("•") else l})
            else:
                blocks.append({"kind": "body", "text": " ".join(lines)})

    pos = 0
    for m in re.finditer(r"<\s*b\s*>(.*?)<\s*/\s*b\s*>", text, flags=re.I | re.S):
        push_body(text[pos:m.start()])
        heading = re.sub(r"\s+", " ", m.group(1)).strip()
        if heading:
            blocks.append({"kind": "heading", "text": heading})
        pos = m.end()
    push_body(text[pos:])

    # Anything still carrying a tag means the source had markup we don't model.
    for b in blocks:
        if re.search(r"<[^>]+>", b["text"]):
            warnings.append("unhandled markup remains: %r" % b["text"][:60])
    return blocks


def parse_week_titles():
    """Extract getWeekName's switch table verbatim from the Java source."""
    src = read(os.path.join(JAVA, "PregnancyHelper.java"))
    body = src[src.index("public static String getWeekName"):]
    body = body[:body.index("\n\t}")]
    titles = {}
    for m in re.finditer(r'case\s+(\d+)\s*:\s*weekName\s*=\s*"([^"]*)"', body):
        titles[int(m.group(1))] = m.group(2)
    missing = [i for i in range(WEEK_COUNT) if i not in titles]
    if missing:
        warnings.append("getWeekName has no case for week(s): %s" % missing)
    return titles


def parse_weeks():
    src = read(os.path.join(RAW, "months.xml"))
    entries = re.findall(r"<Month>(.*?)</Month>", src, flags=re.S)
    if len(entries) != WEEK_COUNT:
        warnings.append("months.xml has %d entries, expected %d" % (len(entries), WEEK_COUNT))

    titles = parse_week_titles()
    weeks = []
    for i, entry in enumerate(entries):
        def field(tag):
            m = re.search(r"<%s>(.*?)</%s>" % (tag, tag), entry, flags=re.S)
            return m.group(1) if m else ""

        no = field("MonthNo").strip()
        if no and int(no) != i:
            warnings.append("week %d has MonthNo=%s (out of order)" % (i, no))

        # Weeks 0..43 are month = i//4, week-in-month = i%4. Index 44 is the
        # trailing "12 months+" entry and stands alone (see updateWeekDots).
        is_final = (i >= 44)
        weeks.append({
            "index": i,
            "title": titles.get(i, ""),
            "month": 11 if is_final else i // 4,
            "weekOfMonth": 0 if is_final else i % 4,
            "weeksInMonth": 1 if is_final else 4,
            "babyGrowth": to_blocks(field("MonthInfo"), "week %d MonthInfo" % i),
            "parentBody": to_blocks(field("ImageUrl"), "week %d ImageUrl" % i),
        })

        if not weeks[-1]["babyGrowth"]:
            warnings.append("week %d has empty babyGrowth" % i)
    return weeks


def parse_skills():
    src = read(os.path.join(RAW, "skills.xml"))
    entries = re.findall(r"<Skill>(.*?)</Skill>", src, flags=re.S)
    if len(entries) != MONTH_COUNT:
        warnings.append("skills.xml has %d entries, expected %d" % (len(entries), MONTH_COUNT))

    months = []
    for month, entry in enumerate(entries):
        m = re.search(r"<SkillInfo>(.*?)</SkillInfo>", entry, flags=re.S)
        blocks = to_blocks(m.group(1) if m else "", "skills month %d" % month)

        tiers = []
        for b in blocks:
            # Android identifies a tier header purely by the line text (contains
            # "مهارات" and a paren) rather than by the bold tag - see
            # MainBabyActivity.parseSkillTiers. Mirror that so a lost <b> in the
            # source can't drop a whole tier, which is what happens on month 7.
            if b["kind"] != "bullet" and "مهارات" in b["text"] and "(" in b["text"]:
                # "مهارات تمّ إتقانها (يقوم بها معظم الأطفال الرضّع)"
                #  ^ title                ^ subtitle in parens
                text = b["text"]
                open_i = text.find("(")
                close_i = text.rfind(")")
                title = text[:open_i].strip() if open_i > 0 else text
                subtitle = text[open_i + 1:close_i].strip() if close_i > open_i > -1 else ""
                tiers.append({"title": title, "subtitle": subtitle, "items": []})
            elif b["kind"] == "bullet":
                if tiers:
                    tiers[-1]["items"].append(b["text"])
                else:
                    warnings.append("month %d: bullet before any tier header: %r"
                                    % (month, b["text"][:40]))

        if len(tiers) != TIERS_PER_MONTH:
            warnings.append("month %d parsed %d tiers, expected %d"
                            % (month, len(tiers), TIERS_PER_MONTH))
        for t_i, t in enumerate(tiers):
            if not t["items"]:
                warnings.append("month %d tier %d has no items" % (month, t_i))

        months.append({"month": month, "tiers": tiers})
    return months


def main():
    weeks = parse_weeks()
    skills = parse_skills()

    if not os.path.isdir(OUT):
        os.makedirs(OUT)

    for name, payload in (("weeks.json", weeks), ("skills.json", skills)):
        path = os.path.join(OUT, name)
        with io.open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write(json.dumps(payload, ensure_ascii=False, indent=2))
        print("wrote %s (%d entries)" % (path, len(payload)))

    total_items = sum(len(t["items"]) for m in skills for t in m["tiers"])
    print("\nskills: %d months, %d tiers, %d chips total"
          % (len(skills), sum(len(m["tiers"]) for m in skills), total_items))
    print("weeks:  %d entries, %d blocks total"
          % (len(weeks), sum(len(w["babyGrowth"]) + len(w["parentBody"]) for w in weeks)))

    if warnings:
        print("\n%d WARNING(S):" % len(warnings))
        for w in warnings:
            print("  - " + w)
    else:
        print("\nno warnings")


if __name__ == "__main__":
    sys.exit(main())
