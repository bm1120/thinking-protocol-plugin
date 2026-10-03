# v0.7.0 — Dual-Track Incubate + 메트릭 회고 + Tribunal 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Incubate 단계에 Fresh Agent + LLM 변이 트랙을 추가하고, 의사결정 품질 메트릭/회고 루프를 구축하며, Converge에 opt-in 멀티 프로바이더 Tribunal을 추가한다.

**Architecture:** incubator가 Track B(LLM 변이 + Fresh Agent)를 백그라운드 실행, Illuminate 게이트에서 자율 필터링. presenter가 메트릭을 `_decision_log/`에 기록, session-start hook이 회고 트리거. validator가 API Key 감지 시 Tribunal 제안.

**Tech Stack:** Bash (hooks/router), Python (메트릭), 기존 Claude Code 스킬/에이전트 마크다운

**Spec:** `docs/superpowers/specs/2026-10-03-local-llm-jev-fullscale-enhancement-design.md` §6-8

---

## File Map

### 신규 생성

| 파일 | 책임 |
|---|---|
| `lib/incubation_templates/mutate.txt` | LLM 변이 생성 프롬프트 (평가 금지) |
| `system_files/.claude/skills/decision-retrospective/SKILL.md` | 회고 스킬 (premortem 적중률 등) |
| `lib/provider_adapter.sh` | 멀티 프로바이더 감지 + 호출 어댑터 |
| `tests/test_v070_integration.sh` | v0.7.0 통합 테스트 |

### 수정

| 파일 | 변경 내용 |
|---|---|
| `system_files/.claude/agents/incubator.md` | Track B (LLM 변이 + Fresh Agent) 추가 |
| `system_files/.claude/agents/validator.md` | Tribunal opt-in 섹션 추가 |
| `system_files/.claude/agents/presenter.md` | 메트릭 수집 + `_decision_log/` 기록 추가 |
| `system_files/.claude/hooks/session-start.sh` | 회고 만기 체크 추가 |
| `lib/migrate.sh` | `_decision_log/`, `_incubation_buffer/` 디렉토리 생성 |
| `VERSION` | 0.6.0 → 0.7.0 |
| `CHANGELOG.md` | v0.7.0 항목 추가 |
| `.claude-plugin/plugin.json` | version 0.6.0 → 0.7.0 |

---

## Task 1: Incubation 템플릿 + 버퍼 디렉토리

**Files:**
- Create: `lib/incubation_templates/mutate.txt`
- Modify: `lib/migrate.sh`

- [ ] **Step 1: 변이 프롬프트 템플릿 생성**

```bash
mkdir -p lib/incubation_templates

cat > lib/incubation_templates/mutate.txt << 'EOF'
Below are ideas from a brainstorming session. Generate 10 mutations by:
- Combining 2+ ideas into one hybrid
- Inverting an assumption in one idea
- Transplanting an idea to a completely different domain

Rules:
- NO ranking, NO evaluation, NO feasibility judgment
- NO words like "best", "worst", "should", "recommend", "practical", "realistic"
- Output a numbered list only (1-10)
- Each mutation must reference which original idea(s) it derives from

IDEAS:
{{IDEAS}}
EOF
```

- [ ] **Step 2: migrate.sh에 신규 디렉토리 생성 추가**

`lib/migrate.sh`에서 기존 `mkdir -p "$VAULT/_logs"` 뒤에 추가:

```bash
# Ensure _decision_log/ and _incubation_buffer/ directories exist
mkdir -p "$VAULT/_decision_log"
mkdir -p "$VAULT/_incubation_buffer"
for d in "_decision_log/" "_incubation_buffer/"; do
  if ! grep -qxF "$d" "$VAULT/.gitignore" 2>/dev/null; then
    echo "$d" >> "$VAULT/.gitignore"
  fi
done
```

- [ ] **Step 3: 확인**

Run: `ls lib/incubation_templates/mutate.txt && grep "incubation_buffer" lib/migrate.sh`

- [ ] **Step 4: 커밋**

```bash
git add lib/incubation_templates/mutate.txt lib/migrate.sh
git commit -m "feat(L4): add incubation mutation template and buffer directories"
```

---

## Task 2: Incubator 에이전트 — Dual-Track + Fresh Agent

**Files:**
- Modify: `system_files/.claude/agents/incubator.md`

- [ ] **Step 1: incubator.md에 Track B 섹션 추가**

기존 `## Calls` 섹션 뒤, `## Anti-patterns` 앞에 새 섹션 삽입:

```markdown
## Machine Incubation — Track B (선택적)

인간 휴식(Track A)과 병행하여 백그라운드에서 보조 산출물을 생성한다. Track A(idea-incubation-log + 지연 시간)는 변경 불가 코어.

### B-1: Local LLM 변이 (Ollaya 필요)

Ollaya가 가용하면 Diverge 결과를 로컬 생성 모델에 넘겨 **평가 없는 변형**만 생성:

1. `lib/incubation_templates/mutate.txt` 템플릿에 아이디어 목록 삽입
2. `lib/local_llm_router.sh`의 Ollaya 엔드포인트로 전송
3. 출력: `_incubation_buffer/{decision_id}_mutations.md`
4. **금지:** 순위, 추천, feasibility, best/worst 판단. 평가 표현이 출력에 포함되면 해당 항목 삭제.
5. Ollaya 불가 시: 이 단계 전체 스킵 (에러 아님)

### B-2: Fresh Agent Pool (Claude 사용)

컨텍스트 없는 신규 에이전트로 인지적 incubation을 시뮬레이션:

1. Agent tool로 2~3개 에이전트를 `model: "haiku"`로 dispatch
2. 각 에이전트에게 주는 것:
   - ✅ Frame 결과 (문제 정의만)
   - ✅ Diverge 아이디어 목록 (번호+제목만)
   - ❌ Diverge 논의 과정/이유 **미전달** (앵커링 방지)
3. 에이전트별 렌즈:
   - **Outsider:** "이 아이디어들을 처음 보는 외부인으로서, 빠진 관점은?"
   - **Inverter:** "이 아이디어들이 모두 틀렸다면, 정반대 접근은?"
   - **Connector:** "완전히 다른 산업/학문에서 이 문제를 풀었던 사례는?"
4. 출력: `_incubation_buffer/{decision_id}_fresh_{lens}.md`
5. Agent 수는 2~3개로 제한 (토큰 비용 통제)

### Illuminate 게이트 (자율형)

Incubate 종료 조건 도달 시 (session-start hook에서 감지):

1. AskUserQuestion: "Incubation 완료: [결정 제목]. 백그라운드 결과: LLM 변이 N개, Fresh Agent 관점 M개 준비됨. 쉬는 동안 떠오른 생각이 있으면 입력해주세요. 없으면 엔터만 누르시면 자동 진행합니다."
2. 엔터/빈 입력 → buffer 자동 필터링 → validator 핸드오프
3. 텍스트 입력 → 사용자 의견 추가 → buffer 필터링 → validator 핸드오프

자동 합류 기준:
- `jev-judgment` Score(novelty) ≥ 4/5 **AND** 기존 아이디어와 중복도 < 0.3 → 자동 합류
- novelty < 4 또는 중복도 ≥ 0.3 → 기각
- 사용자가 명시 채택 → 무조건 합류

필터링 결과는 `_logs/illuminate_gate.jsonl`에 기록.
```

- [ ] **Step 2: 기존 Anti-patterns에 Track B 관련 항목 추가**

기존 Anti-patterns 목록 마지막에 추가:

```markdown
- Track B 결과를 `00_Idea_Inbox/`에 자동 추가. → `_incubation_buffer/`에만 저장.
- Illuminate 진입 전에 Track B 결과를 사용자에게 노출. → 무의식적 발효 방해.
- Fresh Agent에게 Diverge 논의 과정을 전달. → 앵커링 방지가 핵심.
```

- [ ] **Step 3: 확인**

Run: `grep -c "Track B\|Fresh Agent\|Illuminate" system_files/.claude/agents/incubator.md`
Expected: 10 이상

- [ ] **Step 4: 커밋**

```bash
git add system_files/.claude/agents/incubator.md
git commit -m "feat(L4): add Dual-Track Incubate with Fresh Agent pool to incubator"
```

---

## Task 3: Decision Retrospective 스킬

**Files:**
- Create: `system_files/.claude/skills/decision-retrospective/SKILL.md`

- [ ] **Step 1: 스킬 생성**

```bash
mkdir -p system_files/.claude/skills/decision-retrospective

cat > system_files/.claude/skills/decision-retrospective/SKILL.md << 'SKILLEOF'
---
name: decision-retrospective
description: Run a structured retrospective on a past decision. Measures premortem recall rate, surprise count, and updates cumulative quality metrics. Triggered by session-start hook when a decision's retrospective due date has passed.
system: true
---

# decision-retrospective

**Invoked by:** User via `/retrospective <decision_id>`, or prompted by session-start hook.
**Stage:** Post-Decide (feedback loop).

## When to invoke

- session-start hook detects a decision with `retrospective.status == "pending"` and `due_date <= today`
- User explicitly asks to review a past decision

## Procedure

1. **Load decision log:** Read `_decision_log/{decision_id}.jsonl`.
2. **Ask user for outcome:** Use AskUserQuestion:
   "결정 후 어떤 결과가 있었나요? 예상치 못한 문제가 있었으면 알려주세요. 없으면 엔터."
3. **Premortem recall check:** For each premortem prediction in the log:
   - Use `jev-judgment` Noul: "Did this predicted failure actually occur?"
   - Mark as `hit` or `miss`
4. **Compute metrics:**
   - Premortem Recall Rate = hits / total predictions
   - Surprise Count = actual problems not in premortem list
   - Decision Drift = already recorded at Decide time (read from log)
5. **Update decision log:**
   ```json
   {
     "retrospective": {
       "status": "completed",
       "completed_at": "<ISO date>",
       "recall_rate": 0.75,
       "surprises": ["unexpected issue 1", "unexpected issue 2"],
       "user_input": "<what user said>"
     }
   }
   ```
6. **Update cumulative summary:** Read/create `_decision_log/_summary.json`:
   ```json
   {
     "total_decisions": 12,
     "completed_retrospectives": 8,
     "avg_premortem_recall": 0.68,
     "avg_decision_drift": 2.9,
     "process_adherence": {"FULL": 9, "PARTIAL": 2, "SKIPPED": 1},
     "trend": "recall_rate improving (+0.12 over last 5)"
   }
   ```
7. **Display summary** to user in Korean.

## Output format

```
## 회고 완료: [결정 제목]

- Premortem 적중률: N/M (XX%)
- 예상 외 문제: N개
- Decision Drift: X.X/5 (결정 시 기록)
- 누적 평균 적중률: XX% (↑/↓ 변화)

[적중 항목 / 미적중 항목 / 예상 외 문제 상세]
```

## Anti-patterns

- 결과가 좋았다 = 좋은 결정이었다로 판단. → 프로세스 품질만 측정. 운을 걸러낸다.
- 회고를 건너뛰기. → session-start hook이 지속적으로 리마인드.
- Jev 판정만으로 적중 여부 확정. → 사용자 입력이 최종 판단.

Output to user in Korean.
SKILLEOF
```

- [ ] **Step 2: 확인**

Run: `grep -q "decision-retrospective" system_files/.claude/skills/decision-retrospective/SKILL.md && echo OK`

- [ ] **Step 3: 커밋**

```bash
git add system_files/.claude/skills/decision-retrospective/
git commit -m "feat(L5): add decision-retrospective skill with quality metrics"
```

---

## Task 4: Presenter 에이전트 — 메트릭 수집 통합

**Files:**
- Modify: `system_files/.claude/agents/presenter.md`

- [ ] **Step 1: presenter.md에 메트릭 수집 섹션 추가**

기존 `## Calls` 섹션에 추가:

```markdown
- `jev-judgment` — Decide 완료 시 Decision Drift를 Score(1-5)로 측정: "Frame 초기 가설과 최종 결정이 얼마나 달라졌는가?"

## Decision Metrics Logging

Decide 완료 후, 결정 메트릭을 `_decision_log/{decision_id}.jsonl`에 기록:

```json
{
  "decision_id": "DEC-{timestamp}",
  "title": "<결정 제목>",
  "created": "<YYYY-MM-DD>",
  "right_size": "NON_TRIVIAL",
  "stages_completed": ["frame","diverge","incubate","illuminate","converge","decide"],
  "metrics": {
    "decision_drift": 3.8,
    "blindspot_count": 4,
    "process_adherence": "FULL"
  },
  "premortem_predictions": [
    {"id": 1, "description": "...", "plausibility": 4.2}
  ],
  "retrospective": {
    "due_date": "<14일 후 날짜>",
    "status": "pending"
  }
}
```

- `decision_drift`: `jev-judgment` Score로 측정 (Ollaya 불가 시 사용자 자가 평가 요청)
- `blindspot_count`: Converge에서 발굴한 숨은 전제 수 (validator 출력에서 추출)
- `process_adherence`: 모든 6단계 통과 = FULL, 일부 스킵 = PARTIAL, 대폭 스킵 = SKIPPED
- `premortem_predictions`: Converge의 premortem-analysis 출력에서 추출
- `retrospective.due_date`: 결정일 + 14일
```

- [ ] **Step 2: 기존 Write destination 섹션 업데이트**

기존 `## Write destination` 뒤에 추가:

```markdown
- Log decision metrics to `_decision_log/DEC-{timestamp}.jsonl`.
```

- [ ] **Step 3: 확인**

Run: `grep -c "decision_log\|Decision Metrics\|retrospective" system_files/.claude/agents/presenter.md`
Expected: 5 이상

- [ ] **Step 4: 커밋**

```bash
git add system_files/.claude/agents/presenter.md
git commit -m "feat(L5): add decision metrics logging to presenter agent"
```

---

## Task 5: Session-Start Hook — 회고 트리거

**Files:**
- Modify: `system_files/.claude/hooks/session-start.sh`

- [ ] **Step 1: 회고 만기 체크 코드 추가**

`session-start.sh`에서 OLLAYA_STATUS 블록 뒤, `# Emit context` 줄 앞에 삽입:

```bash
# Retrospective due check
RETRO_REMINDER=""
if [[ -d "$VAULT/_decision_log" ]]; then
  TODAY_DATE="$(date +%Y-%m-%d)"
  PENDING_COUNT=0
  PENDING_LIST=""
  for log in "$VAULT"/_decision_log/DEC-*.jsonl; do
    [[ -f "$log" ]] || continue
    due=$(python3 -c "import json;d=json.load(open('$log'));print(d.get('retrospective',{}).get('due_date',''))" 2>/dev/null || echo "")
    status=$(python3 -c "import json;d=json.load(open('$log'));print(d.get('retrospective',{}).get('status',''))" 2>/dev/null || echo "")
    title=$(python3 -c "import json;d=json.load(open('$log'));print(d.get('title','unknown'))" 2>/dev/null || echo "unknown")
    if [[ "$status" == "pending" && -n "$due" && "$due" <= "$TODAY_DATE" ]]; then
      PENDING_COUNT=$((PENDING_COUNT+1))
      did=$(basename "$log" .jsonl)
      PENDING_LIST="${PENDING_LIST}\n  [${did}] ${title}"
    fi
  done
  if [[ "$PENDING_COUNT" -gt 0 ]]; then
    RETRO_REMINDER="📋 회고 대기 중 (${PENDING_COUNT}건):${PENDING_LIST}\n  → /retrospective <ID> 로 회고를 시작하세요"
  fi
fi
```

- [ ] **Step 2: additionalContext에 회고 리마인더 포함**

jq 호출에 `--arg retro "$RETRO_REMINDER"` 추가, additionalContext 문자열에:

```
+ (if $retro != "" then "\n- " + $retro else "" end)
```

- [ ] **Step 3: 확인**

Run: `grep -c "RETRO\|retrospective\|회고" system_files/.claude/hooks/session-start.sh`
Expected: 5 이상

- [ ] **Step 4: 커밋**

```bash
git add system_files/.claude/hooks/session-start.sh
git commit -m "feat(L5): add retrospective due check to session-start hook"
```

---

## Task 6: Provider Adapter + Tribunal

**Files:**
- Create: `lib/provider_adapter.sh`
- Modify: `system_files/.claude/agents/validator.md`

- [ ] **Step 1: provider_adapter.sh 생성**

```bash
cat > lib/provider_adapter.sh << 'ADAPTEREOF'
#!/usr/bin/env bash
# lib/provider_adapter.sh — Multi-provider detection and adapter for Tribunal mode.
# Sourced by validator agent. Never executed directly.
# managed-by: thinking-protocol-plugin

# --- Detect available external providers ---
detect_providers() {
  local providers=""
  [[ -n "${GEMINI_API_KEY:-}" ]] && providers+="gemini "
  [[ -n "${OPENAI_API_KEY:-}" ]] && providers+="openai "
  echo "$providers"
}

# --- Check if tribunal is enabled in settings ---
tribunal_enabled() {
  local vault="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local settings="$vault/.claude/settings.json"
  if [[ -f "$settings" ]]; then
    python3 -c "
import json
d=json.load(open('$settings'))
t=d.get('tribunal',{})
print('true' if t.get('enabled',True) else 'false')
" 2>/dev/null || echo "true"
  else
    echo "true"
  fi
}

# --- Format provider status for display ---
provider_status() {
  local providers
  providers=$(detect_providers)
  local status=""
  if echo "$providers" | grep -q "gemini"; then
    status+="Gemini ✅ "
  fi
  if echo "$providers" | grep -q "openai"; then
    status+="GPT ✅ "
  fi
  if [[ -z "$status" ]]; then
    status="(외부 API Key 없음)"
  fi
  echo "$status"
}
ADAPTEREOF
```

- [ ] **Step 2: validator.md에 Tribunal 섹션 추가**

기존 `## Anti-patterns` 바로 앞에 새 섹션 삽입:

```markdown
## Opt-in Adversarial Tribunal (외부 API Key 감지 시)

Converge 판정 완료 후, 외부 모델 API Key가 감지되면 Tribunal을 제안한다:

1. `lib/provider_adapter.sh`의 `detect_providers`로 가용 프로바이더 확인
2. API Key가 하나 이상 존재하면 AskUserQuestion:
   "외부 모델 API Key가 감지되었습니다 ({provider_status}). Adversarial Tribunal을 실행할까요? (y/엔터=skip)"
3. skip → 기존 결과로 진행
4. y → Tribunal 실행:
   - Claude 판정 결과를 동일 프롬프트로 외부 모델에 전달
   - Gemini: `ask-gemini` 스킬 (background)
   - GPT: `codex:rescue` 에이전트
   - 병렬 수집 후 합성:
     - 3모델 합의 → 높은 확신으로 진행
     - 2:1 분리 → 소수 의견 근거 병기, 다수 채택
     - 3자 분열 → 모든 근거 병기, 사용자 판단 위임
5. 결과는 `_logs/tribunal.jsonl`에 기록
6. `max_round: 1` — 의견 분열 시 재확인 최대 1회

**Tribunal은 Converge 단계에서만 실행된다.** 다른 단계에서 호출하지 않는다.
```

- [ ] **Step 3: settings.json 템플릿에 tribunal 설정 추가**

`system_files/.claude/settings.json.tmpl`에 tribunal 섹션 추가 (기존 local_llm 뒤):

기존 파일을 읽어서 `local_llm` 설정 뒤에 추가:

```json
  "tribunal": {
    "enabled": true,
    "auto_prompt": true,
    "providers": ["gemini", "openai"],
    "trigger": "converge_only",
    "max_round": 1
  }
```

- [ ] **Step 4: 확인**

Run: `grep -c "Tribunal\|tribunal\|detect_providers" lib/provider_adapter.sh system_files/.claude/agents/validator.md`

- [ ] **Step 5: 커밋**

```bash
git add lib/provider_adapter.sh system_files/.claude/agents/validator.md system_files/.claude/settings.json.tmpl
git commit -m "feat(L6): add provider adapter and opt-in Tribunal to validator"
```

---

## Task 7: 통합 테스트

**Files:**
- Create: `tests/test_v070_integration.sh`

- [ ] **Step 1: 테스트 파일 생성**

```bash
cat > tests/test_v070_integration.sh << 'TESTEOF'
#!/usr/bin/env bash
# tests/test_v070_integration.sh — v0.7.0 integration tests
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# --- L4: Incubation ---
check "mutate_template" '[[ -f "$PLUGIN_ROOT/lib/incubation_templates/mutate.txt" ]]'
check "mutate_no_eval" 'grep -q "NO ranking" "$PLUGIN_ROOT/lib/incubation_templates/mutate.txt"'
check "mutate_placeholder" 'grep -q "IDEAS" "$PLUGIN_ROOT/lib/incubation_templates/mutate.txt"'
check "incubator_track_b" 'grep -qi "Track B\|Machine Incubation" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'
check "incubator_fresh_agent" 'grep -qi "Fresh Agent\|Outsider\|Inverter\|Connector" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'
check "incubator_illuminate" 'grep -qi "Illuminate\|AskUserQuestion" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'
check "incubator_buffer_only" 'grep -q "_incubation_buffer" "$PLUGIN_ROOT/system_files/.claude/agents/incubator.md"'

# --- L5: Metrics & Retrospective ---
check "retro_skill_exists" '[[ -f "$PLUGIN_ROOT/system_files/.claude/skills/decision-retrospective/SKILL.md" ]]'
check "retro_skill_name" 'grep -q "name: decision-retrospective" "$PLUGIN_ROOT/system_files/.claude/skills/decision-retrospective/SKILL.md"'
check "retro_premortem" 'grep -q "premortem\|Premortem\|recall" "$PLUGIN_ROOT/system_files/.claude/skills/decision-retrospective/SKILL.md"'
check "presenter_metrics" 'grep -qi "decision_log\|Decision Metrics\|metrics" "$PLUGIN_ROOT/system_files/.claude/agents/presenter.md"'
check "hook_retro" 'grep -qi "RETRO\|retrospective\|회고" "$PLUGIN_ROOT/system_files/.claude/hooks/session-start.sh"'

# --- L6: Tribunal ---
check "provider_adapter" '[[ -f "$PLUGIN_ROOT/lib/provider_adapter.sh" ]]'
check "provider_detect" 'grep -q "detect_providers" "$PLUGIN_ROOT/lib/provider_adapter.sh"'
check "provider_sourceable" 'bash -c "source $PLUGIN_ROOT/lib/provider_adapter.sh && type detect_providers >/dev/null 2>&1"'
check "validator_tribunal" 'grep -qi "Tribunal\|tribunal" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'

# --- Migration ---
check "migrate_decision_log" 'grep -q "_decision_log\|decision_log" "$PLUGIN_ROOT/lib/migrate.sh"'
check "migrate_incubation_buffer" 'grep -q "_incubation_buffer\|incubation_buffer" "$PLUGIN_ROOT/lib/migrate.sh"'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
TESTEOF
chmod +x tests/test_v070_integration.sh
```

- [ ] **Step 2: 테스트 실행**

Run: `bash tests/test_v070_integration.sh`
Expected: All PASS

- [ ] **Step 3: 커밋**

```bash
git add tests/test_v070_integration.sh
git commit -m "test: add v0.7.0 integration tests (L4-L6)"
```

---

## Task 8: 버전 범프 + CHANGELOG

**Files:**
- Modify: `VERSION`, `CHANGELOG.md`, `.claude-plugin/plugin.json`

- [ ] **Step 1: VERSION 업데이트**

```bash
echo "0.7.0" > VERSION
```

- [ ] **Step 2: CHANGELOG.md 업데이트**

CHANGELOG.md의 `## v0.6.0` 앞에 추가:

```markdown
## v0.7.0 — 2026-10-XX — Dual-Track Incubate + Metrics + Tribunal

### Added
- **L4: Dual-Track Incubate**
  - Track B-1: 로컬 LLM 변이 생성 (`lib/incubation_templates/mutate.txt`)
  - Track B-2: Fresh Agent Pool (Outsider/Inverter/Connector 렌즈)
  - Illuminate 게이트: 자율형 (엔터=자동 진행, 입력=반영 후 진행)
  - 자동 합류 기준: Jev novelty ≥ 4 AND 중복도 < 0.3
  - `_incubation_buffer/` 디렉토리

- **L5: 의사결정 품질 메트릭 + 회고 루프**
  - `decision-retrospective` 스킬 신규
  - `presenter`: 결정 메트릭 `_decision_log/` 기록
  - `session-start.sh`: 회고 만기 자동 알림
  - 4대 메트릭: Decision Drift, Blindspot Count, Premortem Recall, Process Adherence

- **L6: 멀티 프로바이더 Opt-in Tribunal**
  - `lib/provider_adapter.sh`: API Key 감지 + 프로바이더 어댑터
  - `validator`: Converge 완료 후 Tribunal 제안 (opt-in)
  - 3모델 합의/분리/분열 합성 로직
  - `_logs/tribunal.jsonl` 결과 기록

### Changed
- `/migrate`: `_decision_log/`, `_incubation_buffer/` 디렉토리 생성
```

- [ ] **Step 3: plugin.json 버전 업데이트**

`"version": "0.6.0"` → `"version": "0.7.0"`

- [ ] **Step 4: 전체 테스트 실행**

Run:
```bash
bash tests/test_local_llm_router.sh && \
bash tests/test_jev_integration.sh && \
bash tests/test_v070_integration.sh && \
echo "=== ALL TEST SUITES PASS ==="
```

- [ ] **Step 5: 최종 커밋**

```bash
git add VERSION CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: bump version 0.6.0 -> 0.7.0 with changelog"
```

---

## 실행 순서 요약

| Task | 레이어 | 내용 | 의존성 |
|---|---|---|---|
| 1 | L4 | 변이 템플릿 + 버퍼 디렉토리 | 없음 |
| 2 | L4 | incubator Dual-Track + Fresh Agent | Task 1 |
| 3 | L5 | decision-retrospective 스킬 | 없음 |
| 4 | L5 | presenter 메트릭 수집 | Task 3 |
| 5 | L5 | session-start hook 회고 트리거 | Task 3 |
| 6 | L6 | provider_adapter + Tribunal | 없음 |
| 7 | — | 통합 테스트 | Task 1-6 |
| 8 | — | 버전 범프 + CHANGELOG | Task 7 |

**병렬 가능:** Task 1, Task 3, Task 6은 독립적 — 동시 실행 가능.
**병렬 가능:** Task 4와 Task 5는 독립적 — 동시 실행 가능.
