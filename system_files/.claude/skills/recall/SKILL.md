---
name: recall
description: Retrieve relevant past work from this vault before starting new work or a decision. Runs a structure-aware search that prioritizes by document purpose (insights/decisions/KB/analyses/inbox) and degrades gracefully on vaults missing optional layers. Proposes pointers only — never writes memos.
system: true
---

# recall

Use when starting an analysis or non-trivial decision and you want to know what prior work in this vault relates ("have we done/decided/known this before?").

## Procedure

두 소스를 모두 조회한 뒤, **출처를 분리한 두 섹션**으로 제시한다.

### 소스 1 — 볼트 파일 (항상)
1. 볼트 루트에서 엔진 실행:
   ```
   python3 .claude/skills/recall/recall.py "<the user's question>"
   ```
   (Plugin install path: `${CLAUDE_PLUGIN_ROOT}/system_files/.claude/skills/recall/recall.py`.)
2. 반환된 랭크 포인터 줄을 수집한다.

### 소스 2 — 과거 세션 (claude-mem, 선택)
3. claude-mem 검색 도구가 가용하면 같은 질문으로 질의한다:
   `mcp__plugin_claude-mem_mcp-search__smart_search` 를 사용자 질문으로 호출.
   도구가 없으면(claude-mem 미설치/권한 없음) **조용히 건너뛴다 — 에러로 처리하지 않는다.**

### 제시 — 출처 분리 두 섹션
4. 결과를 두 헤더로 출력한다. 소스 2가 건너뛰어졌거나 결과가 없으면 두 번째 헤더는 **통째로 생략**한다:

   ```
   ## 과거 문서 (볼트 구조검색)
     [layer] path — why — confidence
   ## 과거 세션 (claude-mem)
     [session] date — 요약 — confidence
   ```
5. 상위 1-3개(볼트 파일) 히트는 Read로 열어 관련성을 확인한 뒤 인용한다.
6. recall.py 출력이 "Low connection density"이면 사용자에게 진짜 새 주제일 수 있다고 알린다 — 링크를 지어내지 않는다.

## Rules
- **Pointers only.** This skill surfaces past work; it never writes or edits memos. The human authors.
- **Confirm before citing.** A filename match is not proof; Read the file.
- **Honest empty result.** If nothing relevant, say so — do not pad.

## Anti-patterns
- ❌ Treating a weak keyword hit as an established connection.
- ❌ Writing the linking prose for the user.
- ❌ Failing on a vault without `insights/` — the engine skips absent layers by design.
