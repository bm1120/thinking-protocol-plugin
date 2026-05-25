# managed-by: thinking-protocol-plugin
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime
import os
import re

FEEDS = [
    ("Behavioral Scientist", "https://behavioralscientist.org/feed/"),
    ("ScienceDaily (Psychology)", "https://www.sciencedaily.com/rss/mind_brain/psychology.xml")
]

# 행동경제학, 심리학, 의사결정, UX, 창의성 관련 키워드
KEYWORDS = ["behavior", "decision", "choice", "nudge", "consumer", "bias", "heuristic", "strategy", "psychology", "economics", "cognitive", "trust", "emotion", "creativity", "innovation", "ideation", "insight", "divergent"]

# Pre-filter: URL deny patterns (regex, all sources). See spec §3.1.
URL_DENY_PATTERNS = [
    r"behavioralscientist\.org/what-its-like-to-be",  # BS profile interview series, n=2 evidence
]

# Pre-filter: title keyword deny — research-type signals (NOT disease names). See spec §3.2.
# Keywords containing a space use substring match; single-word keywords use \b...\b regex.
TITLE_DENY_KEYWORDS = [
    "biomarker",
    "early detection",
    "blood test",
    "genetic test",
    "screening",
    "risk factor",
    "prevalence",
    "incidence rate",
    "epidemiolog",
]

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUTPUT_FILE = os.path.join(_REPO_ROOT, "00_Idea_Inbox", "Automated_Research_Feed.md")

def fetch_and_parse(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            xml_data = response.read()
            root = ET.fromstring(xml_data)
            items = []
            for item in root.findall(".//item"):
                title = item.findtext("title") or ""
                link = item.findtext("link") or ""
                desc = item.findtext("description") or ""
                items.append({"title": title, "link": link, "description": desc})
            return items
    except Exception as e:
        print(f"Error fetching {url}: {e}")
        return []

def is_relevant(text):
    text = text.lower()
    for kw in KEYWORDS:
        if kw in text:
            return True
    return False


def _match_keyword(text_lower, keyword):
    """Substring match for multi-word keywords; word-boundary match for single words.

    Multi-word keywords contain a space; single-word keywords don't. Word boundary
    prevents 'detect' false-matching 'detective' or 'detected'.
    """
    if " " in keyword:
        return keyword in text_lower
    return re.search(rf"\b{re.escape(keyword)}\b", text_lower) is not None


def should_skip(item, source_name):
    """Pre-filter: skip RSS items matching URL deny or title keyword deny rules.

    Returns (True, rule_name) if skip, else (False, "").
    Rule names: 'URL_DENY_profile' or 'TITLE_DENY:<keyword>'.
    """
    url = item.get("link") or ""
    title = item.get("title") or ""

    # URL deny match (priority 1)
    for pattern in URL_DENY_PATTERNS:
        if re.search(pattern, url):
            return (True, "URL_DENY_profile")

    # Title keyword deny match (priority 2)
    title_lower = title.lower()
    for keyword in TITLE_DENY_KEYWORDS:
        if _match_keyword(title_lower, keyword):
            return (True, f"TITLE_DENY:{keyword}")

    return (False, "")


def log_skip(source_name, url, title, rule_name):
    """Append a skip event to _logs/research-fetch-skipped.log.

    Format: ISO8601_UTC | source | url | title | rule_name
    Creates _logs/ directory if missing. Idempotent.
    """
    log_dir = os.path.join(_REPO_ROOT, "_logs")
    os.makedirs(log_dir, exist_ok=True)
    log_path = os.path.join(log_dir, "research-fetch-skipped.log")
    timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    title_safe = (title or "").replace("|", "/").replace("\n", " ")
    line = f"{timestamp} | {source_name} | {url} | {title_safe} | {rule_name}\n"
    with open(log_path, "a", encoding="utf-8") as f:
        f.write(line)


def main():
    today_str = datetime.now().strftime("%Y-%m-%d %H:%M")

    # Read existing feed once: used for dedupe (skip URLs already present —
    # including prior human-rejected entries, which remain in the feed marked
    # [x]) and for insertion below. Resolves Watch 25 resurfacing.
    existing_content = ""
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
            existing_content = f.read()

    new_entries = []
    for source_name, url in FEEDS:
        items = fetch_and_parse(url)
        # 각 소스별 최신 15개 기사를 검사하여 키워드가 일치하는 상위 3개만 추출
        accepted = 0
        for item in items[:15]:
            # Dedupe: skip if this URL already appears in the feed (already listed
            # or previously rejected). The URL/title pre-filter cannot otherwise
            # catch resurfaced prior human rejections (Watch 25).
            link = item.get("link", "")
            if link and link in existing_content:
                log_skip(source_name, link, item.get("title", ""), "DUPLICATE_in_feed")
                continue
            # Pre-filter: skip well-evidenced noise patterns before keyword relevance check
            skip, rule = should_skip(item, source_name)
            if skip:
                log_skip(source_name, item.get("link", ""), item.get("title", ""), rule)
                continue
            if is_relevant(item["title"]) or is_relevant(item["description"]):
                # 설명(Description)에서 불필요한 HTML 태그 제거 및 100자 요약
                clean_desc = re.sub('<[^<]+>', '', item["description"]).strip()
                clean_desc = clean_desc[:120] + "..." if len(clean_desc) > 120 else clean_desc
                new_entries.append(f"- [ ] **[{source_name}]** [{item['title']}]({item['link']})\n  > {clean_desc}")
                accepted += 1
                if accepted >= 3:
                    break
    
    if new_entries:
        os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

        header = f"## 📅 {today_str} 업데이트\n"
        body = "\n".join(new_entries) + "\n\n"
        title = "# 🤖 자동화된 연구 피드 (Automated Research Feed)\n\n매일 아침 9시에 행동경제학 및 의사결정 관련 최신 아티클이 이곳에 업데이트됩니다.\n\n---\n\n"

        # 새 entries 삽입: 첫 번째 `\n---\n\n` divider 직후에 넣기 (제목 영역 customization에 견고).
        # 파일 자체가 비어있거나 제목 헤더가 없으면 신규 생성.
        if not existing_content.startswith("# 🤖"):
            new_content = title + header + body + existing_content
        else:
            divider = "\n---\n\n"
            divider_pos = existing_content.find(divider)
            if divider_pos == -1:
                # divider 없음 — 안전하게 파일 맨 앞에 prepend
                new_content = title + header + body + existing_content
            else:
                insert_pos = divider_pos + len(divider)
                new_content = existing_content[:insert_pos] + header + body + existing_content[insert_pos:]
            
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Successfully added {len(new_entries)} relevant articles to the feed.")
    else:
        print("No relevant articles found today based on the keywords.")

if __name__ == "__main__":
    main()
