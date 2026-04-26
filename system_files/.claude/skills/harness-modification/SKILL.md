---
name: harness-modification
description: Use when modifying vault harness files (.claude/hooks/*.sh, .claude/settings.json, scripts/*.py, scripts/*.sh) — the executable runtime that enforces specs at execution time. Distinct from context-engineering (markdown specs Claude reads). Step 0 diagnosis + complexity gate + TDD-style implementation.
system: true
---

# harness-modification

A **workflow skill** for vault evolution at the **harness layer**. Vault harness = code that EXECUTES at runtime (hooks, system scripts, settings.json registrations). Distinct from context (markdown specs Claude reads).

**Invoked by:** main orchestration agent (when a harness-layer change is requested or symptom-detected). Direct human request, plan task, or Watch list trigger.
**Stage:** vault evolution — orthogonal to the 6-stage thinking protocol.

## When to invoke

**Direct request keywords:**
- "hook 추가/수정", "harness 변경", "settings.json 바꿔", "script 추가"

**Symptom-based (auto-detect):**
- "이런 에러가 자꾸 발생", "사용자가 매번 챙겨야 함"
- "spec 따랐는데 [X]가 빠짐 (반복 ≥ 2회)"
- "시스템적으로 처리해야", "자동화 필요", "런타임에 [Y] 강제"
- "검증이 사후에만 됨"

**Plan-driven:** plan task explicitly names a harness file to edit.

**Do NOT invoke for** (route to `context-engineering` instead):
- "spec 명확화", "rule 추가", "anti-pattern 추가", "agent.md / SKILL.md 수정"
- spec이 모호한데 enforcement 추가하려는 경우 — 먼저 spec 명료화

If both context and harness changes are needed, see **Both case routing** in Step 0.

## Step 0: Trigger detection + diagnosis

Before any file edit, classify the request:

| 분류 | 조건 | 처리 |
|---|---|---|
| **A — Harness only** | runtime enforcement, hook/script/settings 변경 | Step 1 진행 |
| **B — Context only** | spec/rule 변경, markdown 편집 | `context-engineering`로 라우팅, 본 skill 종료 |
| **C — Both** | runtime enforcement + spec 동시 변경 | 의존성 체크 후 순차 호출 (보통 context 먼저) |
| **D — n=1 추측** | 단 1회 spec 위반 관찰 + 일반화 추측 | Anti-Pattern #6 게이트: Watch list 등록, skill 종료 |
| **E — 외부 도구/MCP/네트워크** | vault 외부 인프라 문제 | skill 부적절: 별도 진단 안내, 종료 |

**A 판정에 필요한 evidence (Anti-Pattern #6 강제):**
- ≥ 2회 spec 위반 관찰, OR plan에 명시된 harness task, OR Watch list trigger fire 중 하나. n=1 추측은 즉시 D로 강등.

**진단 산출 (Output format 참조).**

## Complexity gate

A 판정 후:

**Trivial (inline 처리, Step 1-6):**
- 1개 hook 파일 + ≤ 50줄 변경
- 기존 settings.json 항목 수정 (신규 등록 X)
- Regex 1개 변경, command path 정정

**Non-trivial (brainstorming 라우팅):**
- 신규 hook 종류 (event matcher 신규 등록)
- 다중 hook 사이 실행 순서 재설계
- 신규 system script (`scripts/*.py`)
- 보안 권한 모델 변경 (`.claude/settings.json` permissions)
- 사용자 데이터 권한 영향 (`00_*` ~ `04_*` 디렉토리)

→ `superpowers:brainstorming` → spec → `superpowers:writing-plans` → `superpowers:executing-plans` (또는 `subagent-driven-development`).

## Procedure (trivial 케이스)

**Step 1 — 파일 매핑.** 기존 hook + settings + 패턴 확인. `ls .claude/hooks/`, `grep -n "hooks" .claude/settings.json`, 기존 `.sh` 파일 비교.

**Step 2 — 변경 설계.** Event matcher 결정 (`SessionStart` / `UserPromptSubmit` / `PostToolUse` / 기타). Command path는 `$CLAUDE_PROJECT_DIR/.claude/hooks/<name>.sh` (절대경로 하드코딩 금지). 실행 순서가 기존 hook과 충돌 없는지 확인.

**Step 3 — TDD-style 구현.** 기대 동작 정의 (mock 입력 → 기대 출력 + 종료코드). Hook script 작성: `bash`, English comments per CLAUDE.md §5, `set -euo pipefail`. 단독 실행으로 검증.

**Step 4 — settings.json 등록 + 템플릿 sync.** `.claude/settings.json`의 `hooks.<event>` 배열에 추가. `_template/.claude/settings.json.tmpl`에도 동일 등록 (placeholder 유지). `_template/.claude/hooks/<name>.sh`로 hook script 복사.

**Step 5 — Layer 1 정적 검증.** Hook 등록 grep, 실행 권한 (`-rwxr-xr-x`), source ↔ template `diff -q`, `_template/tests/test_setup.sh` 8/8 회귀.

**Step 6 — CHANGELOG + Watch + commit + push.** Source `CHANGELOG.md` entry. `_template/CHANGELOG.md` v 항목 (MINOR for new hook, PATCH for fix). Watch list trigger 정의 (revert/escalate). Commit + sync commit + GitHub push.

## Output format

````
## Trigger 진단

증상: "[사용자 입력 인용]"
분류: [A / B / C / D / E]
근거: [1–2문장 + spec 위반 횟수 또는 evidence 출처]

[A] → harness-modification Step 1로 진행.
[B] → context-engineering 호출.
[C] → 의존성 결정. 보통 context 먼저, harness 후.
[D–E] → skill 종료, 대안 처리 안내.

## 변경 명세 (A로 진행 시)

- 신규/수정 hook: `<path>`
- Event matcher: `<event>`
- Command path: `$CLAUDE_PROJECT_DIR/...`
- 기존 hook과 실행 순서 관계: <설명>

## TDD 결과

- 기대 입력 → 기대 출력: [mock example]
- 단독 실행 결과: [pass / fail + exit code]

## Layer 1 검증

- settings.json 등록 (source + template): ✓
- 실행 권한: -rwxr-xr-x ✓
- 템플릿 sync `diff -q`: empty ✓
- Setup tests: 8/8 PASS ✓

## 커밋

- Source: `<short SHA>`
- Template sync: `<short SHA>` (해당 시)
- GitHub: `<short SHA>` (해당 시)

## Watch 등록 (해당 시)

Watch #N: `<trigger 조건>`
````

(Outer 4-backticks open the fenced block. Plain markdown inside.)

## Anti-patterns

- 테스트 없이 hook commit. Step 3 단독 실행 검증 skip은 가장 위험한 anti-pattern (런타임 에러 시 전체 세션 중단 가능).
- `$CLAUDE_PROJECT_DIR` 안 쓰고 절대경로 하드코딩. 포팅된 vault에서 작동 안 함.
- 기존 hook 순서·이름 무시하고 추가. 같은 event matcher가 여러 hook 호출 시 순서 의존성 발생 가능.
- 사용자 데이터 디렉토리 (`00_*` ~ `04_*`) 권한 변경. 콘텐츠 보호 위반.
- 템플릿 동기화 skip. 외부 사용자에게 enforcement 누락.
- "사용자가 시스템적이라고 말했으니 곧바로 hook 만들기" — Step 0 진단 skip → A 판정 안 거치고 Step 1 진입은 Anti-Pattern #6 직접 위반.

## References

- `.claude/hooks/*.sh` — existing hook patterns (file naming, `$CLAUDE_PROJECT_DIR` usage, exit codes)
- `.claude/settings.json` — hook registration schema (event matchers, command paths)
- `_template/.claude/settings.json.tmpl` — template form with `{{VAULT_ABS_PATH}}` placeholder
- `_template/tests/test_setup.sh` — setup regression tests
- `superpowers:test-driven-development` — Step 3 TDD-style hook test
- `superpowers:requesting-code-review` — optional, for non-trivial hook review
- `superpowers:brainstorming` / `writing-plans` / `executing-plans` — non-trivial 라우팅
- `context-engineering/SKILL.md` — 자매 skill (Both 케이스 라우팅)
- CLAUDE.md §5 — language convention (English code comments)
- CLAUDE.md §Anti-Patterns #6 — speculative engineering 게이트

## Calls

호출자:
- 사람: 직접 요청 또는 symptom-based 표현 ("자꾸 [X]가 안 됨", "시스템적으로...")
- Plan task: "harness 변경 적용"
- Watch list trigger: 명시적 enforcement 갭 fire 시
- 자매 skill `context-engineering`: Both 케이스에서 spec 명료화 후 본 skill 호출

금지 호출:
- spec 모호한 상태에서 enforcement만 추가 (Step 0 분류 B로 라우팅)
- n=1 spec 위반 관찰만으로 hook 만들기 (Anti-Pattern #6)

Output to user in Korean.
