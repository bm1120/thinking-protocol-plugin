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

def main():
    today_str = datetime.now().strftime("%Y-%m-%d %H:%M")
    
    new_entries = []
    for source_name, url in FEEDS:
        items = fetch_and_parse(url)
        # 각 소스별 최신 15개 기사를 검사하여 키워드가 일치하는 상위 3개만 추출
        accepted = 0
        for item in items[:15]:
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
        
        existing_content = ""
        if os.path.exists(OUTPUT_FILE):
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                existing_content = f.read()
        
        header = f"## 📅 {today_str} 업데이트\n"
        body = "\n".join(new_entries) + "\n\n"
        title = "# 🤖 자동화된 연구 피드 (Automated Research Feed)\n\n매일 아침 9시에 행동경제학 및 의사결정 관련 최신 아티클이 이곳에 업데이트됩니다.\n\n---\n\n"
        
        # 파일 최상단에 최신 내용을 삽입 (내림차순 정렬)
        if not existing_content.startswith("# 🤖"):
            new_content = title + header + body + existing_content
        else:
            new_content = existing_content.replace(title, title + header + body, 1)
            
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            f.write(new_content)
        print(f"Successfully added {len(new_entries)} relevant articles to the feed.")
    else:
        print("No relevant articles found today based on the keywords.")

if __name__ == "__main__":
    main()
