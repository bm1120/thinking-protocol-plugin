# claude-mem 이중소스 recall(②) + Diverge 병렬화(③) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** thinking-protocol-plugin의 `recall` 스킬을 볼트파일+claude-mem 이중소스로, `ideator`(Diverge)를 3기법 블라인드 병렬 fan-out으로 업그레이드하고 검증볼트 1개(trading-vault)에 전파한다.

**Architecture:** 모든 소스 변경은 `system_files/`(+ settings 템플릿, migrate.sh, CLAUDE.md.tmpl)에만 가하고 `/migrate`로 전파한다. claude-mem 미설치·병렬 디스패치 불가 환경에서 기존 동작으로 graceful degrade한다. 새/수정 파일은 `system: true`를 유지해 사용자 포크를 보존한다.

**Tech Stack:** Bash(migrate.sh, 테스트), Markdown(스킬/에이전트/CLAUDE 템플릿), JSON(settings 템플릿), Python3 stdlib(recall.py — 이번엔 미변경), claude-mem MCP(`mcp__plugin_claude-mem_mcp-search__*`).

작업 루트: `/Users/choeingyu/Documents/docker/thinking-protocol-plugin` (브랜치 `feature/claude-mem-recall-and-diverge-parallel`).

---

### Task 1: settings 템플릿에 claude-mem 권한 추가 (②-b)

**Files:**
- Modify: `system_files/.claude/settings.json.tmpl` (permissions.allow 배열)
- Test: `tests/test_migration.sh` (그린필드 후 settings.json 검증 케이스 추가)

- [ ] **Step 1: 실패 테스트 추가**

`tests/test_migration.sh`에서 "1. Greenfield install" 블록(`check "gitignore_backup" ...` 직후)에 추가:

```bash
# 1b. Greenfield settings.json carries claude-mem search permissions
check "claudemem_smart_search" 'grep -q "mcp__plugin_claude-mem_mcp-search__smart_search" .claude/settings.json'
check "claudemem_search"       'grep -q "mcp__plugin_claude-mem_mcp-search__search" .claude/settings.json'
check "claudemem_get_obs"      'grep -q "mcp__plugin_claude-mem_mcp-search__get_observations" .claude/settings.json'
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash tests/test_migration.sh`
Expected: `FAIL: claudemem_smart_search` (및 나머지 2개 FAIL), 마지막 요약에 FAIL>0

- [ ] **Step 3: settings 템플릿에 권한 추가**

`system_files/.claude/settings.json.tmpl`의 `"permissions".allow` 배열에서 `"WebSearch"` 줄 바로 위에 3줄 삽입:

```json
      "mcp__plugin_claude-mem_mcp-search__smart_search",
      "mcp__plugin_claude-mem_mcp-search__search",
      "mcp__plugin_claude-mem_mcp-search__get_observations",
      "WebFetch",
      "WebSearch"
```

(기존 `"WebFetch",` `"WebSearch"` 줄은 그대로 두고 그 앞에 3줄을 넣는다. JSON 쉼표 유지 확인.)

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash tests/test_migration.sh`
Expected: `PASS: claudemem_smart_search`, `PASS: claudemem_search`, `PASS: claudemem_get_obs`, 기존 케이스 전부 유지 PASS

- [ ] **Step 5: 커밋**

```bash
git add system_files/.claude/settings.json.tmpl tests/test_migration.sh
git commit -m "feat(settings): add claude-mem search permissions to vault template"
```

---

### Task 2: /migrate에 claude-mem 활성화 안내 추가 (②-c)

**Files:**
- Modify: `commands/migrate.sh` (마이그레이션 완료부 + 그린필드 완료부)
- Test: `tests/test_migration.sh` (그린필드 출력에 안내 문구 검증)

- [ ] **Step 1: 실패 테스트 추가**

`tests/test_migration.sh` 상단 그린필드 호출을 출력 캡처로 바꾸고 검증 추가. 기존:

```bash
# 1. Greenfield install via /migrate (decline cron with "n")
echo "n" | bash "$MIGRATE_CMD"
```

를 다음으로 교체:

```bash
# 1. Greenfield install via /migrate (decline cron with "n")
GREENFIELD_OUT="$(echo "n" | bash "$MIGRATE_CMD")"
check "claudemem_notice" 'echo "$GREENFIELD_OUT" | grep -q "claude-mem"'
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash tests/test_migration.sh`
Expected: `FAIL: claudemem_notice`

- [ ] **Step 3: migrate.sh에 안내 함수 + 호출 추가**

`commands/migrate.sh`에서 `register_cron_if_consented` 정의 부근(또는 파일 상단 함수 영역)에 함수 추가:

```bash
print_claude_mem_notice() {
  echo ""
  echo "[memory] 세션 간 회상을 쓰려면 claude-mem 플러그인을 활성화하세요."
  echo "         미설치 시 recall은 볼트 파일 검색만 수행합니다(정상 동작)."
}
```

그리고 마이그레이션 완료부(`echo "Run ./setup.sh --verify to confirm 8/8."` 직전)와 그린필드 완료부(`echo "Greenfield install complete. VERSION=$PLUGIN_VERSION"` 직전)에 각각 한 줄 호출 추가:

```bash
print_claude_mem_notice
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash tests/test_migration.sh`
Expected: `PASS: claudemem_notice`, 기존 케이스 전부 PASS

- [ ] **Step 5: 커밋**

```bash
git add commands/migrate.sh tests/test_migration.sh
git commit -m "feat(migrate): print claude-mem activation guidance after migrate"
```

---

### Task 3: recall 스킬을 이중소스로 업그레이드 (②-a)

**Files:**
- Modify: `system_files/.claude/skills/recall/SKILL.md` (Procedure 섹션 전면 개정, frontmatter `system: true` 유지)
- Test: 내용 검증(grep)

> recall.py(엔진)는 변경하지 않는다. 이중소스 동작은 스킬 지시문 수준에서 정의된다(엔진 실행 → claude-mem 질의 → 출처분리 출력).

- [ ] **Step 1: SKILL.md의 `## Procedure` 블록 교체**

기존 `## Procedure` ~ `## Rules` 직전까지를 다음으로 교체:

````markdown
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
````

- [ ] **Step 2: 내용 검증**

Run:
```bash
grep -q "과거 문서" system_files/.claude/skills/recall/SKILL.md && \
grep -q "과거 세션" system_files/.claude/skills/recall/SKILL.md && \
grep -q "smart_search" system_files/.claude/skills/recall/SKILL.md && \
grep -q "조용히 건너뛴다" system_files/.claude/skills/recall/SKILL.md && \
grep -q "^system: true" system_files/.claude/skills/recall/SKILL.md && \
echo "RECALL_OK"
```
Expected: `RECALL_OK`

- [ ] **Step 3: 기존 규칙 보존 확인**

Run: `grep -q "Pointers only" system_files/.claude/skills/recall/SKILL.md || grep -q "포인터만" system_files/.claude/skills/recall/SKILL.md && echo "RULES_PRESENT"`
Expected: `RULES_PRESENT` (Rules/Anti-patterns 섹션이 그대로 남아 있어야 함 — 교체는 Procedure 블록만)

- [ ] **Step 4: 커밋**

```bash
git add system_files/.claude/skills/recall/SKILL.md
git commit -m "feat(recall): dual-source recall (vault files + claude-mem sessions)"
```

---

### Task 4: CLAUDE.md.tmpl에 회상 워크플로우 문서화 (②-d)

**Files:**
- Modify: `system_files/CLAUDE.md.tmpl`
- Test: 내용 검증(grep)

- [ ] **Step 1: 회상 워크플로우 문단 추가**

`system_files/CLAUDE.md.tmpl` 끝부분(마지막 섹션 뒤)에 추가:

```markdown
## Recall (과거 작업 회상)

새 분석/비자명 결정을 시작하기 전 `recall` 스킬을 사용한다. recall은 두 소스를 조회한다:
- **과거 문서**: 이 볼트의 insights/decisions/KB/analyses/inbox 구조검색 (항상).
- **과거 세션**: claude-mem이 활성화돼 있으면 세션 간 에피소드까지 회상. 미설치 시 자동 생략(정상).

결과는 출처를 분리해 제시되며, recall은 포인터만 제안하고 메모를 직접 쓰지 않는다.
```

- [ ] **Step 2: 내용 검증**

Run: `grep -q "Recall (과거 작업 회상)" system_files/CLAUDE.md.tmpl && grep -q "claude-mem이 활성화" system_files/CLAUDE.md.tmpl && echo "CLAUDE_OK"`
Expected: `CLAUDE_OK`

- [ ] **Step 3: 커밋**

```bash
git add system_files/CLAUDE.md.tmpl
git commit -m "docs(claude-md): document dual-source recall workflow"
```

---

### Task 5: ideator를 블라인드 병렬 fan-out으로 전환 (③)

**Files:**
- Modify: `system_files/.claude/agents/ideator.md` (frontmatter `tools` + `## Calls` 섹션)
- Test: 내용 검증(grep)

- [ ] **Step 1: frontmatter `tools`에 디스패치 도구 추가**

기존:
```
tools: Read, Grep, Glob, WebSearch, WebFetch, Write
```
교체:
```
tools: Task, Read, Grep, Glob, WebSearch, WebFetch, Write
```

- [ ] **Step 2: `## Calls` 섹션 전체 교체**

기존 `## Calls` ~ `## Write-permission scope` 직전까지를 다음으로 교체:

````markdown
## Calls

**Parallel fan-out** (세 기법을 서로 블라인드로 병렬 디스패치한 뒤 병합):

ideator는 `Task`로 세 서브에이전트를 **병렬** 디스패치한다. 각 서브에이전트는 정확히 한 기법만 수행하며 **서로의 출력을 보지 못한다**(블라인드 → 상호 앵커링 제거):

1. subagent A → `scamper-ideation` — 7개 SCAMPER substep 전부 (Substitute / Combine / Adapt / Modify / Put-to-other-use / Eliminate / Reverse). ≥ 7 ideas.
2. subagent B → `remote-association-matrix` — ≥ 5 distant concept pairings.
3. subagent C → `worst-possible-idea` — ≥ 3 worst-case inversions.

그 다음 ideator는 **병합자(MERGER)** 역할만 한다: 세 결과를 모아 연속번호 1..N으로 재부여하고, 아래 3-섹션 출력 포맷을 유지하며, `incubator`로 핸드오프한다.

**중요(쓰기 충돌 방지):** `00_Idea_Inbox/`에 대한 쓰기는 **병합자 ideator만** 수행한다. 서브에이전트는 아이디어를 텍스트로 반환만 하고 파일을 쓰지 않는다.

**Fallback (순차):** 이 환경에서 병렬 서브에이전트 디스패치가 불가능하면, ideator가 세 기법을 직접 순서대로 실행한다(동일 출력 포맷). 어떤 기법도 건너뛰지 않는다.

**Total: ≥ 15 ideas, grouped by source skill in output.**

**User-specified N handling**: any user N (e.g., "5개 brainstorm해줘") is treated as a **floor, not a ceiling**. The chain always runs in full. Open the response with one transparency line:

> 다양성 확보를 위해 SCAMPER + Remote-Association + Worst-Possible chain을 사용해 [N]개 산출 (요청 [N_user]개 이상 충족).

If the user specifies no N, omit "(요청 ... 충족)".
````

- [ ] **Step 3: 내용 검증**

Run:
```bash
grep -q "^tools: Task," system_files/.claude/agents/ideator.md && \
grep -q "Parallel fan-out" system_files/.claude/agents/ideator.md && \
grep -q "블라인드" system_files/.claude/agents/ideator.md && \
grep -q "Fallback (순차)" system_files/.claude/agents/ideator.md && \
grep -q "병합자 ideator만" system_files/.claude/agents/ideator.md && \
grep -q "^system: true" system_files/.claude/agents/ideator.md && \
echo "IDEATOR_OK"
```
Expected: `IDEATOR_OK`

- [ ] **Step 4: 불변식 보존 확인**

Run:
```bash
grep -q "≥ 15 ideas" system_files/.claude/agents/ideator.md && \
grep -q "floor, not a ceiling" system_files/.claude/agents/ideator.md && \
grep -q "Hand off to" system_files/.claude/agents/ideator.md && \
echo "INVARIANTS_OK"
```
Expected: `INVARIANTS_OK` (Output/Anti-patterns 섹션은 손대지 않음 — Calls 블록만 교체)

- [ ] **Step 5: 커밋**

```bash
git add system_files/.claude/agents/ideator.md
git commit -m "feat(ideator): blind parallel fan-out for Diverge stage with sequential fallback"
```

---

### Task 6: VERSION 범프 + CHANGELOG 기록

**Files:**
- Modify: `VERSION` (0.4.1 → 0.5.0)
- Modify: `CHANGELOG.md` (최상단 항목 추가)

- [ ] **Step 1: VERSION 갱신**

Run:
```bash
echo "0.5.0" > VERSION
```

- [ ] **Step 2: CHANGELOG 항목 추가**

`CHANGELOG.md` 최상단(가장 최근 항목 위)에 추가:

```markdown
## 0.5.0 — 2026-06-01

- kind: skill — recall을 이중소스로 업그레이드(볼트 파일 + claude-mem 세션 회상). claude-mem 미설치 시 볼트 파일 검색만 수행하며 graceful degrade. 출처 분리 2-섹션 출력.
- kind: rule — ideator(Diverge)를 3기법 블라인드 병렬 fan-out으로 전환. 병렬 불가 시 순차 폴백. 쓰기는 병합자 ideator만.
- settings 템플릿에 claude-mem 검색 권한 3종 추가. /migrate가 claude-mem 활성화 안내 출력.
- Source: docs/superpowers/specs/2026-05-31-claude-mem-memory-and-diverge-parallelization-design.md
```

- [ ] **Step 3: 전체 테스트 재실행 (회귀 확인)**

Run: `bash tests/test_migration.sh && bash tests/test_layer_marking.sh`
Expected: 두 스크립트 모두 FAIL=0

- [ ] **Step 4: 커밋**

```bash
git add VERSION CHANGELOG.md
git commit -m "chore: bump version 0.4.1 -> 0.5.0 with changelog"
```

---

### Task 7: 검증볼트(trading-vault)에 전파 + 검증 (전파 범위)

**Files:**
- Modify(via /migrate): `/Users/choeingyu/Documents/docker/trading-vault/` 볼트 시스템 파일
- 백업 자동 생성: `trading-vault/_backup/<timestamp>/`

> 이 태스크는 플러그인이 아니라 별도 볼트에서 수행한다. 볼트는 별도 git 저장소이므로 커밋은 볼트 쪽에서 발생한다.

- [ ] **Step 1: 마이그레이션 전 스냅샷 확인**

Run:
```bash
cd /Users/choeingyu/Documents/docker/trading-vault && git status --short && cat VERSION
```
Expected: 현재 VERSION이 0.5.0 미만(예: 0.4.x)임을 확인. 워킹트리 dirty 여부 기록.

- [ ] **Step 2: /migrate 실행 (cron 안내는 상황에 맞게 응답)**

Run (플러그인 경로 명시):
```bash
cd /Users/choeingyu/Documents/docker/trading-vault && \
echo "n" | bash /Users/choeingyu/Documents/docker/thinking-protocol-plugin/commands/migrate.sh
```
Expected 출력에 포함: `Migration complete: <old> → 0.5.0`, `Backup: _backup/<ts>/`, `[memory] ... claude-mem`, 그리고 `_skipped_forks.txt` 안내.

- [ ] **Step 3: 전파 결과 검증**

Run:
```bash
cd /Users/choeingyu/Documents/docker/trading-vault && \
cat VERSION && \
grep -q "Parallel fan-out" .claude/agents/ideator.md && \
grep -q "과거 세션" .claude/skills/recall/SKILL.md && \
grep -q "mcp__plugin_claude-mem_mcp-search__smart_search" .claude/settings.json && \
ls -d _backup/*/ | tail -1 && \
echo "PROPAGATION_OK"
```
Expected: `0.5.0` + `PROPAGATION_OK`. 단, ideator/recall/settings가 사용자 포크(`system: false`)였다면 보존되어 변경이 안 보일 수 있음 — 그 경우 `_backup/<ts>/_skipped_forks.txt`에 해당 파일이 나열되는지 확인하고 사용자에게 포크 병합 필요를 보고.

- [ ] **Step 4: 볼트 변경 커밋(볼트 저장소)**

Run:
```bash
cd /Users/choeingyu/Documents/docker/trading-vault && \
git add -A && \
git commit -m "chore: migrate to thinking-protocol-plugin 0.5.0 (dual-source recall + parallel diverge)"
```
Expected: 커밋 생성. (사용자가 볼트 커밋을 원치 않으면 이 스텝은 보고 후 보류.)

- [ ] **Step 5: 검증 요약 보고**

trading-vault에서 (1) recall 이중소스 출력 형태, (2) Diverge 병렬 동작(또는 폴백), (3) 포크 보존 결과를 사용자에게 요약 보고.

---

## Self-Review

**Spec coverage (스펙 §별 대응 태스크):**
- §3.2(a) recall 이중소스 → Task 3 ✓
- §3.2(b) settings 권한 → Task 1 ✓
- §3.2(c) /migrate 안내 → Task 2 ✓
- §3.2(d) CLAUDE.md.tmpl 문서화 → Task 4 ✓
- §4.2 ideator 병렬 + 도구 전제 + 폴백 + 쓰기충돌 → Task 5 ✓
- §5.1 VERSION/CHANGELOG/전파 → Task 6, 7 ✓
- §5.2 테스트(migration idempotency는 기존 test_migration.sh가 커버; recall degrade는 claude-mem 미설치 시 settings 권한만 추가될 뿐 recall.py 동작 불변 → 회귀로 Task 6 Step 3에서 확인; ideator 폴백은 에이전트 행동이라 Task 7 Step 5 수동 검증) → 부분 ✓ (아래 한계 명시)
- §5.3 롤백 → Task 7의 _backup 경로로 가능, 별도 태스크 불필요

**한계(명시):** recall의 claude-mem 분기와 ideator 병렬/폴백은 LLM 에이전트 행동이라 단위 테스트가 아닌 수동 검증(Task 7 Step 5)으로 확인한다. 자동 테스트는 bash/json/migrate 계층(Task 1·2·6)에 한정된다.

**Placeholder scan:** TBD/TODO/"적절히 처리" 류 없음. 모든 코드/문구 스텝에 실제 내용 포함.

**Type/이름 일관성:** 권한 문자열 3종, 함수명 `print_claude_mem_notice`, 헤더 "과거 문서"/"과거 세션", `tools: Task,` 접두 — 태스크 간 표기 일치 확인 완료.
