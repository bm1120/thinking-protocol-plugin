# v0.6.0 — Local LLM Router + Jev 통합 + Converge 병렬화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ollaya 기반 로컬 의사결정 모델(Jev/Kev)을 플러그인에 통합하고, Converge 단계를 하이브리드 병렬화하여 앵커링 편향을 제거한다.

**Architecture:** `lib/local_llm_router.sh`가 모든 로컬 LLM 호출을 중개. `jev-judgment` 스킬이 각 단계별 스킬에서 Jev를 호출하는 단일 진입점. `validator.md`는 ideator의 병렬 fan-out 패턴을 차용하여 3개 critique를 병렬 실행 후 단일 합성.

**Tech Stack:** Bash (router/hooks), Ollaya TypeSafe API (HTTP/JSON), 기존 Claude Code 스킬/에이전트 마크다운

**Spec:** `docs/superpowers/specs/2026-10-03-local-llm-jev-fullscale-enhancement-design.md`

---

## File Map

### 신규 생성

| 파일 | 책임 |
|---|---|
| `lib/local_llm_router.sh` | Ollaya 헬스체크, 티어 감지, API 호출, JSON 파싱 |
| `lib/jev_templates/noul.txt` | Noul (yes/no) 질문 프롬프트 템플릿 |
| `lib/jev_templates/choice.txt` | Choice (분류) 질문 프롬프트 템플릿 |
| `lib/jev_templates/score.txt` | Score (1-5) 질문 프롬프트 템플릿 |
| `system_files/.claude/skills/jev-judgment/SKILL.md` | Jev 호출 래퍼 스킬 |
| `tests/test_local_llm_router.sh` | router 단위 테스트 (mock Ollaya) |
| `tests/test_jev_integration.sh` | Jev 통합 테스트 (mock 응답) |

### 수정

| 파일 | 변경 내용 |
|---|---|
| `system_files/.claude/agents/validator.md` | 병렬 fan-out + Jev cross-validation 추가 |
| `system_files/.claude/skills/bias-check/SKILL.md` | Jev Noul 보조 판정 섹션 추가 |
| `system_files/.claude/skills/stage-transition-check/SKILL.md` | Jev Choice 보조 판정 섹션 추가 |
| `system_files/.claude/hooks/session-start.sh` | Ollaya 상태 표시 추가 |
| `lib/migrate.sh` | `_logs/` 디렉토리 생성 + jev 설정 머지 |
| `VERSION` | 0.5.1 → 0.6.0 |
| `CHANGELOG.md` | v0.6.0 항목 추가 |
| `.claude-plugin/plugin.json` | version 0.4.1 → 0.6.0 |

---

## Task 1: Local LLM Router 코어

**Files:**
- Create: `lib/local_llm_router.sh`
- Test: `tests/test_local_llm_router.sh`

- [ ] **Step 1: 테스트 파일 생성 — 헬스체크 테스트**

```bash
cat > tests/test_local_llm_router.sh << 'TESTEOF'
#!/usr/bin/env bash
# tests/test_local_llm_router.sh — local_llm_router unit tests with mock Ollaya
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$PLUGIN_ROOT/lib/local_llm_router.sh"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# --- Test 1: ollaya_available returns 1 when no server ---
OLLAYA_ENDPOINT="http://localhost:59999"
check "ollaya_unavailable" '! ollaya_available'

# --- Test 2: detect_hw_tier returns valid tier ---
tier=$(detect_hw_tier)
check "tier_is_number" '[[ "$tier" =~ ^[1-4]$ ]]'

# --- Test 3: model_for_tier returns correct model ---
check "tier1_model" '[[ "$(model_for_tier 1)" == "kev-0.8b" ]]'
check "tier2_model" '[[ "$(model_for_tier 2)" == "kev-4b" ]]'
check "tier3_model" '[[ "$(model_for_tier 3)" == "kev-9b" ]]'
check "tier4_model" '[[ "$(model_for_tier 4)" == "openjev-27b-q4" ]]'

# --- Test 4: build_request outputs valid JSON ---
req=$(build_request "noul" "test state" "is this true?")
check "request_valid_json" 'echo "$req" | python3 -c "import sys,json;json.load(sys.stdin)"'
check "request_has_type" 'echo "$req" | python3 -c "import sys,json;d=json.load(sys.stdin);assert d[\"type\"]==\"noul\""'

# --- Test 5: parse_response handles Jev output ---
MOCK_RESPONSE='{"answer":true,"probability":0.91,"confidence":"high"}'
parsed=$(parse_response "$MOCK_RESPONSE" "noul")
check "parsed_answer" 'echo "$parsed" | python3 -c "import sys,json;d=json.load(sys.stdin);assert d[\"answer\"]==True"'
check "parsed_confidence" 'echo "$parsed" | python3 -c "import sys,json;d=json.load(sys.stdin);assert d[\"confidence\"]==\"high\""'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
TESTEOF
chmod +x tests/test_local_llm_router.sh
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run: `bash tests/test_local_llm_router.sh`
Expected: FAIL — `lib/local_llm_router.sh` 존재하지 않음

- [ ] **Step 3: local_llm_router.sh 구현**

```bash
cat > lib/local_llm_router.sh << 'ROUTEREOF'
#!/usr/bin/env bash
# lib/local_llm_router.sh — Single entry point for all local LLM (Jev/Kev) calls.
# Sourced by skills/hooks. Never executed directly.
# managed-by: thinking-protocol-plugin

# --- Config ---
OLLAYA_ENDPOINT="${OLLAYA_ENDPOINT:-http://localhost:11434}"
TIER_CACHE="${HOME}/.cache/thinking-protocol/hw_tier.json"
TIER_CACHE_TTL=86400  # 24 hours

# --- Ollaya health check ---
ollaya_available() {
  curl -sf --max-time 2 "${OLLAYA_ENDPOINT}/health" >/dev/null 2>&1
}

# --- Hardware tier detection ---
detect_hw_tier() {
  # Check cache first
  if [[ -f "$TIER_CACHE" ]]; then
    local cached_at
    cached_at=$(python3 -c "import json;print(json.load(open('$TIER_CACHE'))['cached_at'])" 2>/dev/null || echo 0)
    local now
    now=$(date +%s)
    if (( now - cached_at < TIER_CACHE_TTL )); then
      python3 -c "import json;print(json.load(open('$TIER_CACHE'))['tier'])" 2>/dev/null
      return
    fi
  fi

  local total_mb=0

  # macOS
  if [[ "$(uname)" == "Darwin" ]]; then
    local bytes
    bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
    total_mb=$(( bytes / 1024 / 1024 ))
  else
    # Linux
    total_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  fi

  local tier=1
  if (( total_mb >= 49152 )); then
    tier=4
  elif (( total_mb >= 32768 )); then
    tier=3
  elif (( total_mb >= 16384 )); then
    tier=2
  else
    tier=1
  fi

  # Cache result
  mkdir -p "$(dirname "$TIER_CACHE")"
  python3 -c "
import json
with open('$TIER_CACHE','w') as f:
    json.dump({'tier':$tier,'total_mb':$total_mb,'cached_at':$(date +%s)},f)
" 2>/dev/null || true

  echo "$tier"
}

# --- Tier → model mapping ---
model_for_tier() {
  local tier="${1:-1}"
  case "$tier" in
    1) echo "kev-0.8b" ;;
    2) echo "kev-4b" ;;
    3) echo "kev-9b" ;;
    4) echo "openjev-27b-q4" ;;
    *) echo "kev-0.8b" ;;
  esac
}

# --- Build request JSON ---
build_request() {
  local type="$1" state="$2" question="$3"
  python3 -c "
import json,sys
print(json.dumps({
    'type': '$type',
    'state': $(python3 -c "import json;print(json.dumps('$state'))"),
    'question': $(python3 -c "import json;print(json.dumps('$question'))")
},ensure_ascii=False))
"
}

# --- Parse Jev response ---
parse_response() {
  local response="$1" type="$2"
  # Normalize and add metadata
  python3 -c "
import json,sys
raw = json.loads('''$response''')
result = {
    'answer': raw.get('answer'),
    'probability': raw.get('probability', 0.0),
    'confidence': raw.get('confidence', 'unknown'),
    'type': '$type'
}
print(json.dumps(result))
"
}

# --- Main query function (called by skills) ---
# Usage: local_llm_query <type> <state> <question>
# Returns: JSON with answer/probability/confidence or empty string if unavailable
local_llm_query() {
  local type="$1" state="$2" question="$3"

  if ! ollaya_available; then
    echo ""
    return 0
  fi

  # Read settings override
  local vault="${CLAUDE_PROJECT_DIR:-$(pwd)}"
  local model_override=""
  local tier_override=""
  if [[ -f "$vault/.claude/settings.json" ]]; then
    model_override=$(python3 -c "import json;d=json.load(open('$vault/.claude/settings.json'));print(d.get('local_llm',{}).get('model_override',''))" 2>/dev/null || echo "")
    tier_override=$(python3 -c "import json;d=json.load(open('$vault/.claude/settings.json'));print(d.get('local_llm',{}).get('tier_override',''))" 2>/dev/null || echo "")
  fi

  local model=""
  if [[ -n "$model_override" ]]; then
    model="$model_override"
  elif [[ -n "$tier_override" ]]; then
    model=$(model_for_tier "$tier_override")
  else
    model=$(model_for_tier "$(detect_hw_tier)")
  fi

  local request_body
  request_body=$(build_request "$type" "$state" "$question")

  local response
  response=$(curl -sf --max-time 30 \
    -H "Content-Type: application/json" \
    -d "$request_body" \
    "${OLLAYA_ENDPOINT}/v1/decisions" 2>/dev/null) || {
    echo ""
    return 0
  }

  local parsed
  parsed=$(parse_response "$response" "$type")

  # Log to _logs/jev_judgments.jsonl
  local log_dir="$vault/_logs"
  if [[ -d "$log_dir" ]] || mkdir -p "$log_dir" 2>/dev/null; then
    python3 -c "
import json, datetime
entry = {
    'timestamp': datetime.datetime.now().isoformat(),
    'type': '$type',
    'model': '$model',
    'result': json.loads('''$parsed''')
}
with open('$log_dir/jev_judgments.jsonl','a') as f:
    f.write(json.dumps(entry,ensure_ascii=False)+'\n')
" 2>/dev/null || true
  fi

  echo "$parsed"
}
ROUTEREOF
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run: `bash tests/test_local_llm_router.sh`
Expected: All PASS (ollaya_unavailable, tier_is_number, tier[1-4]_model, request_valid_json, request_has_type, parsed_answer, parsed_confidence)

- [ ] **Step 5: 커밋**

```bash
git add lib/local_llm_router.sh tests/test_local_llm_router.sh
git commit -m "feat(L1): add local_llm_router with hw tier detection and Ollaya adapter"
```

---

## Task 2: Jev 프롬프트 템플릿

**Files:**
- Create: `lib/jev_templates/noul.txt`
- Create: `lib/jev_templates/choice.txt`
- Create: `lib/jev_templates/score.txt`

- [ ] **Step 1: 템플릿 디렉토리 및 파일 생성**

```bash
mkdir -p lib/jev_templates

cat > lib/jev_templates/noul.txt << 'EOF'
You are a decision judge. Given the state below, answer the yes/no question.
Return ONLY a JSON object: {"answer": true|false, "probability": 0.0-1.0, "confidence": "high"|"medium"|"low"}

STATE:
{{STATE}}

QUESTION:
{{QUESTION}}
EOF

cat > lib/jev_templates/choice.txt << 'EOF'
You are a decision judge. Given the state below, choose exactly one option from the provided list.
Return ONLY a JSON object: {"answer": "<chosen option>", "probability": 0.0-1.0, "confidence": "high"|"medium"|"low"}

STATE:
{{STATE}}

OPTIONS:
{{OPTIONS}}

QUESTION:
{{QUESTION}}
EOF

cat > lib/jev_templates/score.txt << 'EOF'
You are a decision judge. Given the state below, score the item on a 1-5 scale.
Return ONLY a JSON object: {"answer": <number 1-5>, "probability": 0.0-1.0, "confidence": "high"|"medium"|"low"}

STATE:
{{STATE}}

QUESTION:
{{QUESTION}}

SCALE:
1 = very low
2 = low
3 = medium
4 = high
5 = very high
EOF
```

- [ ] **Step 2: 템플릿 존재 확인**

Run: `ls -la lib/jev_templates/`
Expected: noul.txt, choice.txt, score.txt 3개 파일

- [ ] **Step 3: 커밋**

```bash
git add lib/jev_templates/
git commit -m "feat(L2): add Jev prompt templates (noul/choice/score)"
```

---

## Task 3: jev-judgment 스킬

**Files:**
- Create: `system_files/.claude/skills/jev-judgment/SKILL.md`

- [ ] **Step 1: 스킬 파일 생성**

```bash
mkdir -p system_files/.claude/skills/jev-judgment

cat > system_files/.claude/skills/jev-judgment/SKILL.md << 'SKILLEOF'
---
name: jev-judgment
description: Wrapper skill for all Jev/Kev local decision model calls. Other skills call this instead of Ollaya directly. Returns typed judgment (Choice/Score/Noul) with confidence. Graceful degrade when Ollaya unavailable.
system: true
---

# jev-judgment

**Invoked by:** Any skill needing a local LLM judgment (bias-check, stage-transition-check, premortem-analysis, etc.)
**Stage:** Any (wrapper, not stage-specific).

## When to invoke

Call this skill whenever you need a **structured local judgment** to supplement Claude's analysis:
- **Noul** (yes/no): "Is sunk cost bias active?", "Does this meet JTBD format?"
- **Choice** (classify): "ADVANCE / ROLLBACK / FAILURE_HANDLING", "SMALL / NON_TRIVIAL"
- **Score** (1-5): novelty, plausibility, urgency

## Procedure

1. **Check Ollaya availability** by running:
   ```bash
   source lib/local_llm_router.sh && ollaya_available && echo "UP" || echo "DOWN"
   ```

2. **If DOWN:** Skip Jev judgment entirely. Output:
   ```
   Jev: (Ollaya 미실행 — Claude 단독 판정)
   ```
   Continue with Claude-only analysis. This is not an error.

3. **If UP:** Execute the query:
   ```bash
   source lib/local_llm_router.sh
   result=$(local_llm_query "<type>" "<state>" "<question>")
   echo "$result"
   ```

4. **Interpret result:**
   - `confidence: "high"` (probability ≥ 0.8) → 신뢰 가능
   - `confidence: "medium"` (0.6-0.8) → 참고용
   - `confidence: "low"` (< 0.6) → 낮은 신뢰도 플래그 표시

5. **Compare with Claude analysis:**
   - 일치 → "✅ Claude + Jev 일치" 표시
   - 불일치 → "⚠️ 판정 불일치" + 양쪽 근거 병기, 사용자 판단 위임

## Output format

```
### Jev 보조 판정
- 타입: <noul|choice|score>
- 모델: <kev-0.8b|kev-4b|kev-9b|openjev-27b-q4>
- 판정: <answer>
- 확률: <probability>
- 신뢰도: <confidence>
- Claude 비교: <✅ 일치 | ⚠️ 불일치>
```

## Logging

Every call is automatically logged to `_logs/jev_judgments.jsonl` by `lib/local_llm_router.sh`. No additional logging needed in this skill.

## Anti-patterns

- Calling Ollaya directly without going through `lib/local_llm_router.sh`. → Always source the router.
- Treating Jev as the final authority. → Jev is second opinion only.
- Blocking on Ollaya timeout. → Router has 30s max-time; if it returns empty, proceed without Jev.
- Running Jev in Diverge for evaluation purposes. → Score(novelty) is permitted only for post-Diverge compression, not during idea generation.
SKILLEOF
```

- [ ] **Step 2: 스킬 존재 확인**

Run: `cat system_files/.claude/skills/jev-judgment/SKILL.md | head -5`
Expected: YAML frontmatter with `name: jev-judgment`

- [ ] **Step 3: 커밋**

```bash
git add system_files/.claude/skills/jev-judgment/
git commit -m "feat(L2): add jev-judgment wrapper skill"
```

---

## Task 4: bias-check에 Jev 보조 판정 통합

**Files:**
- Modify: `system_files/.claude/skills/bias-check/SKILL.md`

- [ ] **Step 1: bias-check에 Jev 섹션 추가**

`SKILL.md`의 `## Anti-patterns` 바로 위에 새 섹션을 삽입:

```markdown
## Jev 보조 판정 (선택적)

각 bias 카테고리에 대해 Claude 분석을 완료한 뒤, `jev-judgment` 스킬을 호출하여 독립적인 보조 판정을 받는다.

**호출 방법:**

각 bias마다 Noul 질문을 실행한다:
```bash
source lib/local_llm_router.sh
# 예: sunk cost
local_llm_query "noul" "<candidate description and evaluation context>" "Is sunk cost fallacy active in this evaluation?"
```

**결과 처리:**
- Ollaya 미실행 → 이 섹션 전체 스킵 (Claude 분석만 사용)
- Ollaya 가용 → 7개 bias 각각에 대해 Noul 판정 실행
- Claude와 Jev 불일치 시 → 테이블에 `⚠️` 열 추가:

```
| Bias | Claude | Jev | 일치 | Evidence | Counter-measure |
|---|---|---|---|---|---|
| Sunk cost | active | active(0.89) | ✅ | ... | ... |
| Confirmation | active | not active(0.62) | ⚠️ | ... | ... |
```

**Jev confidence < 0.7인 판정은 "(low confidence)" 표시하고 Claude 판정을 우선한다.**
```

- [ ] **Step 2: 변경 확인**

Run: `grep -c "Jev" system_files/.claude/skills/bias-check/SKILL.md`
Expected: 7 이상 (Jev 관련 라인 수)

- [ ] **Step 3: 커밋**

```bash
git add system_files/.claude/skills/bias-check/SKILL.md
git commit -m "feat(L2): integrate Jev noul judgment into bias-check skill"
```

---

## Task 5: stage-transition-check에 Jev Choice 통합

**Files:**
- Modify: `system_files/.claude/skills/stage-transition-check/SKILL.md`

- [ ] **Step 1: stage-transition-check에 Jev Choice 섹션 추가**

`SKILL.md`의 기존 절차 마지막에 새 섹션 추가:

```markdown
## Jev 보조 판정 (선택적)

Pre-check를 모두 완료한 뒤, `jev-judgment` 스킬로 독립적인 Choice 판정을 받는다.

**호출 방법:**

```bash
source lib/local_llm_router.sh
local_llm_query "choice" "<pre-check results summary>" "Based on these pre-check results, should the protocol: ADVANCE to next stage, ROLLBACK to previous stage, or enter FAILURE_HANDLING?"
```

**결과 처리:**
- Ollaya 미실행 → 스킵, Claude 판정만 사용
- Claude와 Jev 일치 → "✅ 교차 검증 통과" 표시
- Claude와 Jev 불일치 → "⚠️ 교차 검증 불일치" + 양쪽 근거를 Audit trail에 병기

**이 보조 판정은 Claude의 판정을 뒤집지 않는다.** 불일치는 사용자에게 정보를 제공할 뿐이다.
```

- [ ] **Step 2: 변경 확인**

Run: `grep -c "Jev" system_files/.claude/skills/stage-transition-check/SKILL.md`
Expected: 5 이상

- [ ] **Step 3: 커밋**

```bash
git add system_files/.claude/skills/stage-transition-check/SKILL.md
git commit -m "feat(L2): integrate Jev choice judgment into stage-transition-check"
```

---

## Task 6: Converge 하이브리드 병렬화 — validator.md 수정

**Files:**
- Modify: `system_files/.claude/agents/validator.md`

- [ ] **Step 1: validator.md를 하이브리드 병렬로 변경**

기존 `validator.md`의 `## Calls` 섹션을 아래로 교체:

```markdown
## Calls

**Hybrid Fan-Out & Synthesize** (비판 생성은 병렬, 판정은 단일 통합):

### Stage 1: Parallel Critique Dispatch

validator는 `Task`로 세 서브에이전트를 **병렬** 디스패치한다. 각 서브에이전트는 정확히 한 critique만 수행하며 **서로의 출력을 보지 못한다** (블라인드 → 앵커링 제거):

1. subagent A → `bias-check` + `jev-judgment`(noul) — 7개 bias 카테고리별 활성/잠재/비해당 판정.
2. subagent B → `premortem-analysis` + `jev-judgment`(score) — "12개월 후 실패했다면 왜?" ≥ 5 시나리오, plausibility 스코어.
3. subagent C → `causal-reasoning-check` + `jev-judgment`(noul) — 인과 주장별 confounders/counterfactual 검증.

**중요(쓰기 충돌 방지):** 서브에이전트는 critique 텍스트를 반환만 한다. vault에 쓰지 않는다.

**Fallback (순차):** `Task` tool이 불가능하면, validator가 세 critique를 직접 순서대로 실행한다 (v0.5.1과 동일 동작). 어떤 critique도 건너뛰지 않는다.

### Stage 2: Validator Master Synthesis

병렬 결과를 모아 validator가 단일 통합자로:

1. **중복 제거** — 동일 위험이 다른 이름으로 나온 것을 통합.
2. **Compounded Risk 합성** — 개별 critique가 복합 작용할 때 발생하는 2차/3차 위험을 식별.
3. **Jev Cross-Validation** — Claude critique와 Jev judgment 불일치 시 "⚠️ 불일치" 플래그 + 양쪽 근거 병기.
4. **Counter-proposal 작성** — 각 survivor에 대해 critique를 반영한 개선 버전 생성.
5. **≤3 survivors 결정** — Keep / Refine / Drop 판정.
```

- [ ] **Step 2: Cold-start hygiene 섹션 유지 확인**

기존 `## Cold-start hygiene`, `## Output`, `## Hand-off`, `## Anti-patterns` 섹션은 그대로 유지한다. 변경하지 않는다.

Run: `grep "Cold-start" system_files/.claude/agents/validator.md`
Expected: `## Cold-start hygiene` 라인 존재

- [ ] **Step 3: Jev Cross-Validation 출력 안내를 Output 섹션에 추가**

`## Output` 섹션의 기존 내용 뒤에 추가:

```markdown
- Jev cross-validation 결과: 각 candidate별 Claude/Jev 일치율 + 불일치 항목 목록.
```

- [ ] **Step 4: 커밋**

```bash
git add system_files/.claude/agents/validator.md
git commit -m "feat(L3): convert validator to hybrid fan-out with Jev cross-validation"
```

---

## Task 7: session-start.sh에 Ollaya 상태 표시 추가

**Files:**
- Modify: `system_files/.claude/hooks/session-start.sh`

- [ ] **Step 1: Ollaya 상태 체크 코드 추가**

`session-start.sh`에서 `FEED_REMINDER` 변수 설정 블록 뒤, `# Emit context` 줄 앞에 삽입:

```bash
# Ollaya (local decision model) status check
OLLAYA_STATUS=""
if curl -sf --max-time 2 "http://localhost:11434/health" >/dev/null 2>&1; then
  OLLAYA_STATUS="✅ Ollaya running — Jev local judgments enabled"
else
  OLLAYA_STATUS="ℹ️ Ollaya not running — Claude-only mode (install: https://github.com/ollaya-dev/ollaya)"
fi
```

- [ ] **Step 2: additionalContext에 Ollaya 상태 포함**

jq 호출의 `additionalContext` 문자열에 Ollaya 상태를 추가. 기존 jq 블록에서 `--arg reminder` 뒤에 추가:

```bash
    --arg ollaya "$OLLAYA_STATUS" \
```

그리고 additionalContext 문자열에:

```
+ "\n- " + $ollaya
```

를 `$reminder` 조건 뒤에 삽입.

- [ ] **Step 3: 변경 확인**

Run: `grep "OLLAYA" system_files/.claude/hooks/session-start.sh`
Expected: OLLAYA_STATUS 관련 라인 3개 이상

- [ ] **Step 4: 커밋**

```bash
git add system_files/.claude/hooks/session-start.sh
git commit -m "feat(L1): show Ollaya status in session-start hook"
```

---

## Task 8: 마이그레이션 업데이트

**Files:**
- Modify: `lib/migrate.sh`

- [ ] **Step 1: `_logs/` 디렉토리 생성 로직 추가**

`lib/migrate.sh`의 기존 greenfield 로직에서 시스템 파일 복사 직후에 추가:

```bash
# Ensure _logs/ directory exists for Jev judgment logging
mkdir -p "$VAULT/_logs"
if ! grep -qxF "_logs/" "$VAULT/.gitignore" 2>/dev/null; then
  echo "_logs/" >> "$VAULT/.gitignore"
fi
```

- [ ] **Step 2: settings.json 템플릿에 local_llm 기본 설정 추가**

settings.json 템플릿 (setup.sh 또는 migrate에서 생성하는 부분)에 `local_llm` 섹션 추가:

```json
{
  "local_llm": {
    "tier_override": "",
    "model_override": "",
    "ollaya_endpoint": "http://localhost:11434"
  }
}
```

이를 `merge_claude_mem_permissions`와 동일한 패턴으로 멱등 머지하는 `merge_local_llm_config` 함수를 추가:

```bash
merge_local_llm_config() {
  local settings="$VAULT/.claude/settings.json"
  [[ -f "$settings" ]] || return 0
  python3 - "$settings" << 'PYEOF' || { echo "WARN: local_llm config merge skipped"; return 0; }
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except (json.JSONDecodeError, ValueError):
    sys.exit(0)
if "local_llm" not in d:
    d["local_llm"] = {
        "tier_override": "",
        "model_override": "",
        "ollaya_endpoint": "http://localhost:11434"
    }
    json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
    print("local_llm config added to settings.json")
PYEOF
}
```

- [ ] **Step 3: 커밋**

```bash
git add lib/migrate.sh
git commit -m "feat(L1): add _logs/ dir creation and local_llm config merge to migration"
```

---

## Task 9: 통합 테스트

**Files:**
- Create: `tests/test_jev_integration.sh`
- Modify: `tests/test_migration.sh`

- [ ] **Step 1: Jev 통합 테스트 생성**

```bash
cat > tests/test_jev_integration.sh << 'TESTEOF'
#!/usr/bin/env bash
# tests/test_jev_integration.sh — Jev skill and template integration tests
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0; FAIL=0
check() { local label="$1" cond="$2"; if eval "$cond"; then PASS=$((PASS+1)); echo "PASS: $label"; else FAIL=$((FAIL+1)); echo "FAIL: $label"; fi; }

# --- Test 1: jev-judgment skill exists with correct frontmatter ---
check "jev_skill_exists" '[[ -f "$PLUGIN_ROOT/system_files/.claude/skills/jev-judgment/SKILL.md" ]]'
check "jev_skill_name" 'grep -q "^name: jev-judgment$" "$PLUGIN_ROOT/system_files/.claude/skills/jev-judgment/SKILL.md"'
check "jev_skill_system" 'grep -q "^system: true$" "$PLUGIN_ROOT/system_files/.claude/skills/jev-judgment/SKILL.md"'

# --- Test 2: All 3 templates exist and contain required placeholders ---
for tmpl in noul choice score; do
  check "${tmpl}_template_exists" '[[ -f "$PLUGIN_ROOT/lib/jev_templates/${tmpl}.txt" ]]'
  check "${tmpl}_has_state" 'grep -q "{{STATE}}" "$PLUGIN_ROOT/lib/jev_templates/${tmpl}.txt"'
  check "${tmpl}_has_question" 'grep -q "{{QUESTION}}" "$PLUGIN_ROOT/lib/jev_templates/${tmpl}.txt"'
done
check "choice_has_options" 'grep -q "{{OPTIONS}}" "$PLUGIN_ROOT/lib/jev_templates/choice.txt"'

# --- Test 3: bias-check references jev-judgment ---
check "bias_check_jev" 'grep -q "jev-judgment" "$PLUGIN_ROOT/system_files/.claude/skills/bias-check/SKILL.md"'
check "bias_check_noul" 'grep -q "noul" "$PLUGIN_ROOT/system_files/.claude/skills/bias-check/SKILL.md"'

# --- Test 4: stage-transition-check references jev-judgment ---
check "stage_check_jev" 'grep -q "jev-judgment" "$PLUGIN_ROOT/system_files/.claude/skills/stage-transition-check/SKILL.md"'
check "stage_check_choice" 'grep -q "choice" "$PLUGIN_ROOT/system_files/.claude/skills/stage-transition-check/SKILL.md"'

# --- Test 5: validator.md has parallel fan-out ---
check "validator_parallel" 'grep -q "Parallel Critique Dispatch" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'
check "validator_synthesis" 'grep -q "Validator Master Synthesis" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'
check "validator_compounded" 'grep -q "Compounded Risk" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'
check "validator_fallback" 'grep -q "Fallback" "$PLUGIN_ROOT/system_files/.claude/agents/validator.md"'

# --- Test 6: session-start.sh has Ollaya check ---
check "hook_ollaya" 'grep -q "OLLAYA" "$PLUGIN_ROOT/system_files/.claude/hooks/session-start.sh"'

# --- Test 7: router is sourceable without error ---
check "router_sourceable" 'bash -c "source $PLUGIN_ROOT/lib/local_llm_router.sh && type ollaya_available >/dev/null 2>&1"'
check "router_has_query" 'bash -c "source $PLUGIN_ROOT/lib/local_llm_router.sh && type local_llm_query >/dev/null 2>&1"'

echo ""
echo "=== Result: PASS=$PASS, FAIL=$FAIL ==="
[[ $FAIL -eq 0 ]] || exit 1
TESTEOF
chmod +x tests/test_jev_integration.sh
```

- [ ] **Step 2: 테스트 실행**

Run: `bash tests/test_jev_integration.sh`
Expected: All PASS

- [ ] **Step 3: 기존 마이그레이션 테스트에 jev-judgment 스킬 카운트 확인 추가**

`tests/test_migration.sh`의 `check "greenfield_skills"` 라인에서 스킬 수를 16에서 17로 올린다:

기존:
```bash
check "greenfield_skills" '[[ -d .claude/skills ]] && [[ $(ls .claude/skills | wc -l) -ge 16 ]]'
```

변경:
```bash
check "greenfield_skills" '[[ -d .claude/skills ]] && [[ $(ls .claude/skills | wc -l) -ge 17 ]]'
```

- [ ] **Step 4: 마이그레이션 테스트에 _logs 디렉토리 + local_llm 설정 테스트 추가**

`tests/test_migration.sh`의 `check "gitignore_backup"` 뒤에 추가:

```bash
check "logs_dir_exists" '[[ -d _logs ]]'
check "gitignore_logs" 'grep -qxF "_logs/" .gitignore'
check "local_llm_config" 'python3 -c "import json;d=json.load(open(\".claude/settings.json\"));assert \"local_llm\" in d"'
```

- [ ] **Step 5: 커밋**

```bash
git add tests/test_jev_integration.sh tests/test_migration.sh
git commit -m "test: add Jev integration tests and update migration assertions"
```

---

## Task 10: 버전 범프 + CHANGELOG

**Files:**
- Modify: `VERSION`
- Modify: `CHANGELOG.md`
- Modify: `.claude-plugin/plugin.json`

- [ ] **Step 1: VERSION 파일 업데이트**

```bash
echo "0.6.0" > VERSION
```

- [ ] **Step 2: CHANGELOG.md 업데이트**

CHANGELOG.md의 맨 위에 새 항목 추가 (기존 내용 앞에):

```markdown
## 0.6.0 — 2026-10-XX — Local LLM + Jev Integration + Converge Parallelization

### Added
- **L1: Local LLM Router** (`lib/local_llm_router.sh`)
  - Ollaya 기반 Jev/Kev 의사결정 모델 통합
  - 자동 하드웨어 티어 감지 (Kev-0.8B ~ OpenJev-27B)
  - settings.json `local_llm` 오버라이드 지원
  - Graceful degrade: Ollaya 미실행 시 Claude 단독 모드

- **L2: Jev 스킬 통합**
  - `jev-judgment` 래퍼 스킬 신규
  - `bias-check`: 7개 bias별 Jev Noul 보조 판정
  - `stage-transition-check`: Jev Choice 교차 검증
  - 프롬프트 템플릿: `lib/jev_templates/` (noul/choice/score)
  - 판정 로그: `_logs/jev_judgments.jsonl`

- **L3: Converge 하이브리드 병렬화**
  - `validator`: 3개 critique (bias-check, premortem, causal-reasoning)를 Task tool로 병렬 fan-out
  - Validator Master Synthesis: 중복 제거, Compounded Risk 합성, Jev Cross-Validation
  - 순차 fallback 유지 (Task tool 불가 시)

### Changed
- `session-start.sh`: Ollaya 상태 표시 추가
- `/migrate`: `_logs/` 디렉토리 생성 + `local_llm` 설정 멱등 머지
```

- [ ] **Step 3: plugin.json 버전 업데이트**

`.claude-plugin/plugin.json`의 `"version"` 필드를 `"0.4.1"`에서 `"0.6.0"`으로 변경.

- [ ] **Step 4: 전체 테스트 실행**

Run:
```bash
bash tests/test_local_llm_router.sh && \
bash tests/test_jev_integration.sh && \
echo "=== ALL TEST SUITES PASS ==="
```
Expected: 모든 테스트 통과

- [ ] **Step 5: 최종 커밋**

```bash
git add VERSION CHANGELOG.md .claude-plugin/plugin.json
git commit -m "chore: bump version 0.5.1 -> 0.6.0 with changelog"
```

---

## 실행 순서 요약

| Task | 레이어 | 내용 | 의존성 |
|---|---|---|---|
| 1 | L1 | local_llm_router.sh + 테스트 | 없음 |
| 2 | L2 | Jev 프롬프트 템플릿 | 없음 |
| 3 | L2 | jev-judgment 스킬 | Task 1 |
| 4 | L2 | bias-check Jev 통합 | Task 3 |
| 5 | L2 | stage-transition-check Jev 통합 | Task 3 |
| 6 | L3 | validator.md 병렬화 | Task 3, 4, 5 |
| 7 | L1 | session-start.sh Ollaya 표시 | Task 1 |
| 8 | L1 | 마이그레이션 업데이트 | Task 1 |
| 9 | — | 통합 테스트 | Task 1-8 |
| 10 | — | 버전 범프 + CHANGELOG | Task 9 |

**병렬 가능:** Task 1과 Task 2는 독립적 — 동시 실행 가능.
**병렬 가능:** Task 4와 Task 5는 독립적 — 동시 실행 가능.
**병렬 가능:** Task 7과 Task 8은 독립적 — 동시 실행 가능.
