---
name: context-engineering
description: Use when modifying vault context files (CLAUDE.md, *_Context.md, agent.md, SKILL.md, Stage_Transition_Rules.md, Core_Thinking_Protocol.md) — the markdown specs Claude reads as instructions. Distinct from harness-modification (executable runtime). Step 0 diagnosis verifies the change is genuinely a context concern (not harness, not data, not premature speculation).
system: true
---

# context-engineering

A **workflow skill** for vault evolution at the **context layer**. Vault context = files Claude reads as instructions. Distinct from harness (executable code: hooks, settings.json, scripts).

**Invoked by:** main orchestration agent (when a context-layer change is requested or symptom-detected). Direct human request, plan task, or Watch list trigger.
**Stage:** vault evolution — orthogonal to the 6-stage thinking protocol.

## When to invoke

**Direct request keywords:**
- "spec 바꿔야", "rule 추가/수정", "agent 동작 변경", "anti-pattern 추가", "skill 신규/편집"
- "라우팅 표 업데이트", "CLAUDE.md 항목 추가"

**Symptom-based (auto-detect):**
- "Claude가 [X] 안 함" / "[Y] 가이드라인 모호함"
- "spec 따랐는데 [Z]가 빠짐"
- "[A] vs [B] 일관성 없음" / "두 파일이 다른 말 함"
- "이 안내가 부족함"

**Plan-driven:** plan task explicitly names a context file to edit.

**Do NOT invoke for** (route to `harness-modification` instead):
- "이런 에러 자동으로 잡아야", "hook 추가", "settings.json 권한 변경"
- "사용자가 매번 챙겨야 하는 [X] 자동화"
- "런타임에 [Y] 강제"

If both context and harness changes are needed, see **Both case routing** in Step 0.

## Step 0: Trigger detection + diagnosis

Before any file edit, classify the request:

| 분류 | 조건 | 처리 |
|---|---|---|
| **A — Context only** | spec/rule 명확화, anti-pattern 추가, agent.md/SKILL.md 수정, routing 변경 | Step 1 진행 |
| **B — Harness only** | runtime enforcement 필요, executable 코드 변경 | `harness-modification`로 라우팅, 본 skill 종료 |
| **C — Both** | spec 변경 + runtime enforcement 동시 필요 | 의존성 체크 후 순차 호출 (보통 context 먼저) |
| **D — n=1 추측** | 단 1회 dogfood/관찰 + 일반화 추측 | Anti-Pattern #6 게이트: Watch list 등록, skill 종료 |
| **E — 콘텐츠/데이터 문제** | 사용자 노트 (`00_*` ~ `04_*`) 편집 필요 | skill 부적절: 사용자 직접 편집 안내, 종료 |

**A 판정에 필요한 evidence (Anti-Pattern #6 강제):**
- ≥ 2회 관찰된 spec 갭, OR plan에 명시된 context task, OR Watch list trigger fire 중 하나. n=1 추측은 D로 강등.

**진단 산출 (Output format 참조).**

## Complexity gate

A 판정 후 변경 규모 평가:

**Trivial (inline 처리, Step 1-6):**
- 단일 context 파일, ≤ 10줄 변경
- 기존 항목 수정·재정렬, 신규 섹션 없음
- Cross-file 영향 0–1개

**Non-trivial (brainstorming 라우팅):**
- ≥ 2개 context 파일 변경
- 신규 anti-pattern, 신규 stage, 신규 skill 추가
- Cross-file consistency 검증이 ≥ 3개 파일 필요
- 사용자 mental model 영향 (CLAUDE.md §1–§6 변경)

→ `superpowers:brainstorming` → spec → `superpowers:writing-plans` → `superpowers:executing-plans` (또는 `subagent-driven-development`). 본 skill은 contextual frame.

## Procedure (trivial 케이스)

**Step 1 — 영향 범위 매핑.** 변경 대상 파일 + 그 파일이 참조되는 곳을 grep으로 매핑. 누락 없는지 확인 (Phase 7-1 Stage_Transition_Rules.md 누락 사례 회피).

**Step 2 — 변경 설계.** 다른 context 파일이 같은 사실을 다르게 주장하지 않는지, 정량 표현이 측정 가능한지(`≥ 15` ✓, `충분히 많은` ✗), 강도 표현 일관(must/should/may) 검증.

**Step 3 — 편집.** 기존 패턴 보존(frontmatter, 헤딩, 표 형식, wikilinks `[[ ]]`, callouts `> [!tip]`). Korean prose, English code block (CLAUDE.md §5).

**Step 4 — Layer 1 정적 검증.** `grep -c "<old phrase>" <file>` → 0, `grep -c "<new phrase>" <file>` → 기대값. Cross-file 동기화 grep도 실행.

**Step 5 — 템플릿 동기화.** Source vault → `_template/` 동일 위치로 cp. `diff -q` empty 확인.

**Step 6 — CHANGELOG + Watch + commit + push.** Source `CHANGELOG.md` entry. `_template/CHANGELOG.md` v 항목 (MINOR for behavior change, PATCH for clarification). 추측성 요소 있으면 Watch trigger 명시. Commit + GitHub push (외부 영향 시).

## Output format

````
## Trigger 진단

증상: "[사용자 입력 인용]"
분류: [A / B / C / D / E]
근거: [1–2문장 + spec 위반 횟수 또는 evidence 출처]

[A] → context-engineering Step 1로 진행.
[B] → harness-modification 호출 (사용자 안내 또는 subagent dispatch).
[C] → 의존성 결정 후 순차 호출.
[D–E] → skill 종료, 대안 처리 안내.

## 변경 명세 (A로 진행 시)

- 파일: `<path>` 라인 `<line-range>`
- 옛 텍스트 → 새 텍스트 diff
- Cross-file 영향: [list]

## Layer 1 검증 결과

- `grep -c "<old>"`: 0 ✓
- `grep -c "<new>"`: 1 ✓
- `diff -q template/source`: empty ✓

## 커밋

- Source SHA: `<short>`
- Template sync SHA: `<short>` (해당 시)
- GitHub SHA: `<short>` (해당 시)

## Watch 등록 (해당 시)

Watch #N: `<trigger 조건>`
````

(Outer 4-backticks open the fenced block. Plain markdown inside.)

## Anti-patterns

- Cross-file consistency 검증 skip — Phase 7-1 Task 2 review에서 발견된 핵심 갭. Step 1 영향 범위 매핑 + Step 4 cross-file grep 둘 다 필수.
- "Spec edit인데 enforcement 없는 게 문제다"라며 `harness-modification`로 over-route. Spec 모호함 자체는 spec 명료화로 충분; enforcement는 ≥ 2회 spec 위반 관찰 후에만.
- n=1 dogfood 결과로 일반화. Anti-Pattern #6 위반. Watch list 등록 후 evidence 누적 대기.
- 강도 표현 혼용. `must` / `should` / `may`가 같은 spec 안에서 일관되지 않으면 enforcement가 깨짐.
- 사용자 데이터 디렉토리 (`00_*` ~ `04_*`) 편집. 콘텐츠는 사용자 영역, skill 적용 X.

## References

- `CLAUDE.md` §6 routing table — 본 skill 호출 trigger 등록 위치
- `CLAUDE.md` §Anti-Patterns #6 — speculative engineering 게이트
- `harness-modification/SKILL.md` — 자매 skill (Both 케이스 라우팅)
- `superpowers:brainstorming` / `writing-plans` / `executing-plans` — non-trivial 라우팅
- Phase 7-1 closure — context-engineering pattern의 첫 evidence base

## Calls

호출자:
- 사람: 직접 요청 또는 symptom-based 표현
- Plan task: "context 변경 적용"
- Watch list trigger: 명시적 fire 시
- 자매 skill `harness-modification`: Both 케이스에서 dependency 따라 본 skill 우선 호출 가능

금지 호출:
- 사용자가 명백히 harness 영역만 언급한 경우 (Step 0 분류 B → 라우팅)
- spec 표현이 명확한데 단순 확인 요청 (skill 작업 아님)

Output to user in Korean.
