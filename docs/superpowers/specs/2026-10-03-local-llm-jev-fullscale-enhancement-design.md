# thinking-protocol-plugin v0.6.0–v0.7.0 풀스케일 고도화 설계

> 2026-10-03 · Cross-model review (Gemini + Codex) 기반 도출
> 양쪽 평결: **GO with cuts** → Claude 최종: **GO with cuts**

---

## 목차

1. [배경 및 동기](#1-배경-및-동기)
2. [설계 원칙](#2-설계-원칙)
3. [L1: Local LLM Router + 자동 티어링](#3-l1-local-llm-router--자동-티어링)
4. [L2: Jev 스킬 통합](#4-l2-jev-스킬-통합)
5. [L3: Converge 하이브리드 병렬화](#5-l3-converge-하이브리드-병렬화)
6. [L4: Dual-Track Incubate + Fresh Agent](#6-l4-dual-track-incubate--fresh-agent)
7. [L5: 의사결정 품질 메트릭 + 회고 루프](#7-l5-의사결정-품질-메트릭--회고-루프)
8. [L6: 멀티 프로바이더 Opt-in Tribunal](#8-l6-멀티-프로바이더-opt-in-tribunal)
9. [릴리스 계획](#9-릴리스-계획)
10. [Graceful Degradation 매트릭스](#10-graceful-degradation-매트릭스)

---

## 1. 배경 및 동기

### 현재 상태 (v0.5.1)

- 6단계 프로토콜 (Frame→Diverge→Incubate→Illuminate→Converge→Decide) 안정
- 6개 서브에이전트, 17개 스킬 운영 중
- Diverge 병렬 fan-out (3기법) 구현 완료
- 이중소스 recall (vault + claude-mem) 동작
- Claude Code API 토큰만 사용, 외부/로컬 LLM 연동 없음

### 해결할 문제

1. **Incubate가 비어있음** — "쉬고 오세요"만 출력, 자동화 없음
2. **Converge 순차 실행** — 앵커링 편향 위험, 복합 위험 미검출
3. **의사결정 품질 피드백 없음** — 결정 후 회고/개선 루프 부재
4. **단일 모델 의존** — Claude 외 관점 부재
5. **비용 비효율** — 간단한 분류/판정에도 프론티어 API 사용

### Cross-Model Review 결과

| 모델 | 평결 | 핵심 권고 |
|---|---|---|
| **Gemini** | GO with cuts | Diverge에 로컬 LLM 우선, Dual-Track Incubate, Converge 하이브리드 |
| **Codex** | GO with cuts | Incubate에 로컬 LLM 우선, 승격 금지 규칙, 프로토콜 모드 분리 유지 |
| **Claude (합성)** | GO with cuts | Incubate 우선 → Diverge 2순위, 하이브리드 Converge, opt-in Tribunal |

**주요 합의:**
- Converge 하이브리드 (병렬 critique + 단일 합성)
- Incubate Dual-Track (인간 휴식 강제 + 기계 보조)
- 멀티 프로바이더는 opt-in 격리
- 의사결정 메트릭/회고 루프는 High 우선순위

---

## 2. 설계 원칙

1. **레이어드 통합** — 각 레이어가 독립 동작, 이전 레이어 없이도 graceful degrade
2. **프로토콜 모드 분리 보존** — Diverge는 평가 금지, Incubate는 생성/평가 금지, Converge는 비판 루프 제한
3. **Jev는 second opinion** — 최종 결정권은 Claude 또는 사용자
4. **자율형 기본값** — 사용자 개입 최소화, 의견 있으면 반영
5. **영어 프롬프트 템플릿** — 로컬 LLM 한국어 한계 우회, 사용자 대면은 Claude가 한국어로

---

## 3. L1: Local LLM Router + 자동 티어링

### 개요

모든 로컬 LLM 호출을 중개하는 단일 진입점 `lib/local_llm_router.sh`.

### 런타임

- **기본: [Ollaya](https://github.com/ollaya-dev/ollaya)** — 의사결정 모델 전용 런타임, TypeSafe API 호환
- Kev/OpenJev 모델을 TypeSafe API 형태로 서빙

### 호출 흐름

```
플러그인 스킬/에이전트
    ↓ local_llm_query(type, state, question)
lib/local_llm_router.sh
    ↓ 1. Ollaya 실행 여부 확인 (curl localhost:11434/health)
    ↓ 2. 티어 결정 (캐시 or 재감지)
    ↓ 3. 영어 프롬프트 템플릿 조립
    ↓ 4. Ollaya TypeSafe API 호출
    ↓ 5. JSON 응답 파싱 (choice/score/noul + confidence)
호출자에게 구조화된 결과 반환
```

### 자동 티어링

하드웨어 감지 → 모델 자동 선택:

- macOS: `sysctl hw.memsize` → 총 RAM
- GPU: Apple Silicon 통합 메모리, NVIDIA는 `nvidia-smi`
- 캐시: `~/.cache/thinking-protocol/hw_tier.json` (24시간 TTL)

| 티어 | 조건 | 모델 | 용도 |
|---|---|---|---|
| 1 | ≤8GB | Kev-0.8B | Choice/Noul만 (stage transition, bias yes/no) |
| 2 | 16GB | Kev-4B | Choice + Score + Noul 전체 |
| 3 | 32GB | Kev-9B | 전체 + 높은 정확도 |
| 4 | 48GB+ | OpenJev-27B Q4 | 프론티어급 정확도 |

### settings.json 오버라이드

```json
{
  "local_llm": {
    "tier_override": 3,
    "model_override": "kev-9b",
    "ollaya_endpoint": "http://localhost:11434"
  }
}
```

### Graceful Degrade

Ollaya 미실행/미설치 시 → 로컬 LLM 기능 전체 비활성화, Claude 단독 모드 (v0.5.1과 동일). 에러 아닌 경고만 표시.

---

## 4. L2: Jev 스킬 통합

### 개요

각 프로토콜 단계에 Jev 판정을 **보조 판정**으로 삽입. 최종 결정권은 Claude 또는 사용자.

### 단계별 Jev 투입 맵

| 단계 | Jev 질문 타입 | 구체적 판정 | 기존 스킬 연동 |
|---|---|---|---|
| Frame | Noul | 문제 정의가 JTBD 형식을 충족하는가? | `stage-transition-check` |
| Frame | Choice | right-size 분류: `SMALL` / `NON_TRIVIAL` | `framer` 에이전트 |
| Diverge | Score | 각 아이디어의 novelty (1-5) | `diverge-compression` 클러스터링 입력 |
| Incubate | Choice | 지연 시간 분류: `TRIVIAL_30M` / `MEDIUM_OVERNIGHT` / `LARGE_3D` | `idea-incubation-log` |
| Converge | Noul | 각 bias 활성 여부 (yes/no + confidence) | `bias-check` |
| Converge | Score | premortem 실패 시나리오 plausibility (1-5) | `premortem-analysis` |
| Converge | Noul | 인과 주장에 confounders 존재 여부 | `causal-reasoning-check` |
| Decide | Choice | `ADVANCE` / `ROLLBACK` / `FAILURE_HANDLING` | `stage-transition-check` |

### 통합 패턴

```
기존 스킬 실행 (예: bias-check)
    ↓
Claude가 7개 bias 카테고리 분석 (기존 그대로)
    ↓
    ├─ Ollaya 가용? → Jev Noul로 각 bias 독립 판정
    │                  → confidence < 0.7이면 "low confidence" 플래그
    │                  → Claude 분석과 Jev 판정 비교 표시
    └─ Ollaya 불가? → Claude 분석만 사용 (v0.5.1 동작)
```

### 불일치 처리

Claude와 Jev가 불일치하면 둘 다 표시하고 사용자에게 판단 위임:
```
⚠️ 판정 불일치: sunk_cost_bias
  Claude: 활성 (근거: 이미 투자한 6개월을 언급)
  Jev:    비활성 (confidence: 0.62, low)
  → 사용자 판단 필요
```

### 새 스킬: `jev-judgment`

모든 Jev 호출을 감싸는 단일 스킬. 다른 스킬이 직접 Ollaya를 호출하지 않고 이 스킬을 경유.

```
입력: { type: "noul", state: "...", question: "..." }
출력: { answer: true, probability: 0.91, confidence: "high", model: "kev-4b", tier: 2 }
```

### 로깅

Jev 결과는 `_logs/jev_judgments.jsonl`에 누적 → 메트릭 피드백 루프의 데이터 소스.

### 프롬프트 템플릿

모두 영어, `lib/jev_templates/` 디렉토리에 관리. 한국어 사용자 입력은 Claude가 구조화된 영어 state로 변환 후 Jev에 전달.

---

## 5. L3: Converge 하이브리드 병렬화

### 개요

"비판 생성은 병렬, 판정은 순차/단일" — Gemini/Codex 합의안.

### 변경 전후

```
[현재 v0.5.1 — 순차]
validator → bias-check → premortem → causal-reasoning → 통합 판정

[v0.6.0 — 하이브리드]
validator (Merger 역할)
  ↓ Task tool 병렬 fan-out
  ┌──► Sub-A: bias-check + jev-judgment(noul)
  ├──► Sub-B: premortem-analysis + jev-judgment(score)
  └──► Sub-C: causal-reasoning-check + jev-judgment(noul)
  ↓ 3개 raw critique 수집
  ↓ validator 단일 통합:
    1. 중복 제거
    2. Compounded Risk 합성
    3. Jev confidence 교차 검증
    4. Counter-proposal 작성
    5. ≤3 survivors 결정
```

### ideator 패턴 재활용

`ideator.md`에 구현된 병렬 fan-out 패턴 차용:

- Task tool로 3개 서브에이전트 blind dispatch
- 각 서브에이전트는 텍스트만 반환 (vault 직접 쓰기 금지)
- validator가 merger로서 통합 → vault에 기록
- Task tool 불가 시 순차 fallback (기존 동작과 동일)

### validator.md 추가 사항

```markdown
## Parallel Critique Dispatch
- Task tool 가용 시: bias-check, premortem, causal-reasoning을 병렬 실행
- 각 서브에이전트에게 jev-judgment 스킬 호출 지시
- 결과 수집 후 Compounded Risk Synthesis 수행

## Jev Cross-Validation
- Claude critique와 Jev judgment 불일치 시:
  "⚠️ 불일치" 플래그 + 양쪽 근거 병기
```

### 성능 기대치

| 메트릭 | 현재 (순차) | 변경 (하이브리드) |
|---|---|---|
| Converge 소요 시간 | ~3x (직렬) | ~1.3x (병렬 + 합성) |
| 앵커링 편향 위험 | 있음 | 없음 (blind dispatch) |
| Compounded Risk 검출 | 없음 | 합성 단계에서 검출 |

---

## 6. L4: Dual-Track Incubate + Fresh Agent

### 개요

인간 휴식은 강제(Track A), LLM 보조는 백그라운드(Track B). 자율형 기본값.

### Track A: Human Incubation (코어, 변경 불가)

기존 incubator 본질 유지:

- `idea-incubation-log` 스킬로 아이디어 세트 + 지연 시간 기록
- `revisit-reminder` 스킬로 복귀 시점 설정
- `session-start.sh` hook에서 Incubation 상태 표시

### Track B: Machine Incubation Buffer (선택적)

#### B-1: Local LLM 변이 (Ollaya 필요)

incubator가 Diverge 결과를 로컬 생성 모델(Qwen3.5 등)에 넘겨 **평가 없는 변형**만 생성:

- 프롬프트 템플릿: `lib/incubation_templates/mutate.txt`
- 출력: `_incubation_buffer/{decision_id}_mutations.md`
- **금지:** 순위, 추천, feasibility, best/worst 판단
- 평가 표현이 출력에 포함되면 해당 항목 삭제

#### B-2: Fresh Agent Pool (Claude 사용)

컨텍스트 없는 신규 에이전트 = 인지적 incubation 시뮬레이션:

- 2~3개 Agent tool로 신규 에이전트 dispatch
- 각 에이전트에게 주는 것:
  - ✅ Frame 결과 (문제 정의만)
  - ✅ Diverge 아이디어 목록 (번호+제목만)
  - ❌ Diverge 논의 과정/이유 **미전달**
  - ❌ 이전 대화 컨텍스트 **미전달**
- 비용 통제: Agent tool의 `model: "haiku"` 파라미터로 경량 모델 지정

| 에이전트 | 렌즈 | 프롬프트 핵심 |
|---|---|---|
| **Outsider** | 외부인 시각 | "이 아이디어들을 처음 보는 외부인으로서, 빠진 관점은?" |
| **Inverter** | 반대 방향 | "이 아이디어들이 모두 틀렸다면, 정반대 접근은?" |
| **Connector** | 이종 영역 연결 | "완전히 다른 산업/학문에서 이 문제를 풀었던 사례는?" |

출력: `_incubation_buffer/{decision_id}_fresh_{lens}.md`

### Illuminate 게이트: 자율형

```
Incubate 종료 조건 도달 (session-start hook에서 감지)
    ↓
AskUserQuestion:
  "Incubation 완료: [결정 제목]
   백그라운드 결과: LLM 변이 N개, Fresh Agent 관점 M개 준비됨.

   쉬는 동안 떠오른 생각이 있으면 입력해주세요.
   없으면 엔터만 누르시면 자동 진행합니다."
    ↓
    ├─ 엔터/빈 입력 → buffer 자동 필터링 → validator 핸드오프
    └─ 텍스트 입력 → 사용자 의견 추가 → buffer 필터링 → validator 핸드오프
```

### 자동 합류 기준

| 조건 | 동작 |
|---|---|
| Jev novelty score ≥ 4/5 **AND** 기존 아이디어와 중복도 < 0.3 | 자동 합류 |
| novelty ≥ 3 **BUT** 중복도 ≥ 0.3 | 기각 (기존과 유사) |
| novelty < 3 | 기각 |
| 사용자가 명시 채택 | 무조건 합류 |

### 로깅

`_logs/illuminate_gate.jsonl`:

```json
{
  "decision_id": "DEC-042",
  "buffer_total": 13,
  "auto_promoted": 3,
  "auto_rejected": 10,
  "user_added": 0,
  "promoted_items": [
    {"source": "fresh_inverter", "novelty": 4.2, "overlap": 0.12},
    {"source": "llm_mutation_7", "novelty": 4.5, "overlap": 0.08},
    {"source": "fresh_connector", "novelty": 3.8, "overlap": 0.21}
  ]
}
```

### 프로토콜 보호 규칙

| 규칙 | 이유 |
|---|---|
| Fresh agent에게 Diverge 논의 과정 전달 금지 | 앵커링 방지 — 핵심 |
| Track B 결과는 `_incubation_buffer/`에만 저장 | `00_Idea_Inbox/`에 자동 추가 금지 |
| Illuminate 진입 전까지 사용자에게 내용 노출 안 함 | 무의식적 발효 방해 방지 |
| 평가/추천/순위 표현이 출력에 포함되면 삭제 | Incubate 모드 위반 방지 |
| Agent 수는 2~3개로 제한 | 토큰 비용 통제 |
| Track B 실패/미실행 시 아무 영향 없음 | Track A만으로 완전한 Incubate |

---

## 7. L5: 의사결정 품질 메트릭 + 회고 루프

### 핵심 메트릭 4개 (프로세스 기반)

| # | 메트릭 | 측정 시점 | 데이터 소스 | Jev 활용 |
|---|---|---|---|---|
| 1 | **Decision Drift** | Decide 완료 시 | Frame 초기 가설 vs 최종 결정 | Score(1-5): 얼마나 달라졌는가 |
| 2 | **Blindspot Count** | Converge 완료 시 | bias-check + premortem에서 발굴한 숨은 전제 수 | 자동 카운트 |
| 3 | **Premortem Recall** | 회고 시 (14/30일 후) | 실제 발생 문제 vs premortem 예측 | Noul: 이 항목이 실제 발생했는가 |
| 4 | **Process Adherence** | Decide 완료 시 | 각 단계 통과 여부 | Choice: FULL/PARTIAL/SKIPPED |

### 데이터 구조

`_decision_log/{decision_id}.jsonl`:

```json
{
  "decision_id": "DEC-042",
  "title": "마이크로서비스 전환",
  "created": "2026-10-03",
  "right_size": "NON_TRIVIAL",
  "stages_completed": ["frame","diverge","incubate","illuminate","converge","decide"],
  "metrics": {
    "decision_drift": 3.8,
    "blindspot_count": 4,
    "process_adherence": "FULL"
  },
  "premortem_predictions": [
    {"id": 1, "description": "네트워크 지연 증가", "plausibility": 4.2},
    {"id": 2, "description": "팀 학습곡선 6개월", "plausibility": 3.7}
  ],
  "retrospective": {
    "due_date": "2026-10-17",
    "status": "pending"
  }
}
```

### 회고 트리거: session-start hook

`session-start.sh`에 회고 체크 추가:

```bash
# 기존: 버전 스큐 체크, incubation 쿨다운 체크
# 추가: 회고 만기 체크
for log in _decision_log/*.jsonl; do
  due=$(jq -r '.retrospective.due_date' "$log")
  status=$(jq -r '.retrospective.status' "$log")
  if [[ "$status" == "pending" && "$due" <= "$(date +%Y-%m-%d)" ]]; then
    # 만기 도달 → 알림 출력
  fi
done
```

hook 출력:
```
📋 회고 대기 중:
  [DEC-042] 마이크로서비스 전환 (14일 경과)
  → /retrospective DEC-042 로 회고를 시작하세요
```

### 새 스킬: `decision-retrospective`

```
/retrospective DEC-042
    ↓
1. _decision_log/DEC-042.jsonl 로드
    ↓
2. AskUserQuestion:
   "결정 후 어떤 결과가 있었나요?
    예상치 못한 문제가 있었으면 알려주세요.
    없으면 엔터."
    ↓
3. Premortem 예측 항목별 Jev Noul 판정:
   "이 예측이 실제 발생했는가?"
    ↓
4. 메트릭 산출:
   - Premortem Recall Rate = 적중/전체
   - Surprise Count = premortem에 없던 실제 문제 수
    ↓
5. _decision_log/DEC-042.jsonl 업데이트:
   retrospective.status → "completed"
   retrospective.recall_rate → 0.75
   retrospective.surprises → [...]
    ↓
6. 누적 통계 갱신: _decision_log/_summary.json
```

### 누적 통계 (`_decision_log/_summary.json`)

```json
{
  "total_decisions": 12,
  "avg_decision_drift": 2.9,
  "avg_blindspot_count": 3.2,
  "avg_premortem_recall": 0.68,
  "process_adherence": {"FULL": 9, "PARTIAL": 2, "SKIPPED": 1},
  "trend": "recall_rate improving (+0.12 over last 5)"
}
```

session-start hook에서 주기적으로 요약 표시:
```
📊 의사결정 품질 (최근 12건):
   Premortem 적중률: 68% (↑12%)
   평균 Drift: 2.9/5
   프로세스 준수: 75% FULL
```

---

## 8. L6: 멀티 프로바이더 Opt-in Tribunal

### 개요

Converge 단계에서만 활성화. API Key 감지 시 AskUserQuestion으로 제안.

### 활성화 흐름

```
[기본 모드 — API Key 없음]
validator → 하이브리드 병렬 critique → Claude + Jev 판정 → 끝

[Tribunal 모드 — API Key 감지됨]
validator → 하이브리드 병렬 critique → Claude + Jev 판정 완료 후
  ↓
  AskUserQuestion:
    "외부 모델 API Key가 감지되었습니다 (Gemini ✅ / GPT ✅).
     Adversarial Tribunal을 실행할까요? (y/엔터=skip)"
  ↓
  ├─ skip → 기존 결과로 진행
  └─ y → Tribunal 실행
```

### Tribunal 실행

```
Claude 판정 결과 (survivors ≤3 + critique 요약)
    ↓ 동일 프롬프트를 외부 모델에 전달
    ┌──► Gemini (ask-gemini skill, background)
    └──► Codex/GPT (codex:rescue agent)
    ↓ 병렬 수집
    ↓
validator가 합성:
  각 survivor별 {Claude, Gemini, GPT} 판정 비교
    ↓
  ┌─ 3모델 합의 → 높은 확신으로 진행
  ├─ 2:1 분리 → 소수 의견 근거 병기, 다수 채택
  └─ 3자 분열 → 모든 근거 병기, 사용자 판단 위임
```

### Provider Adapter: `lib/provider_adapter.sh`

```bash
detect_providers() {
  local providers=""
  [[ -n "$GEMINI_API_KEY" ]] && providers+="gemini "
  [[ -n "$OPENAI_API_KEY" ]] && providers+="openai "
  echo "$providers"
}

# Gemini → ask-gemini skill
# GPT → codex:rescue agent
# 출력 형식 통일: { verdict, severity_tags, reasoning }
```

### settings.json 설정

```json
{
  "tribunal": {
    "enabled": true,
    "auto_prompt": true,
    "providers": ["gemini", "openai"],
    "trigger": "converge_only",
    "max_round": 1
  }
}
```

| 설정 | 기본값 | 설명 |
|---|---|---|
| `enabled` | `true` | API Key 있을 때 제안 허용 |
| `auto_prompt` | `true` | AskUserQuestion으로 매번 확인 |
| `trigger` | `converge_only` | Converge 단계에서만 |
| `max_round` | `1` | 의견 분열 시 재확인 최대 1회 |

### 로깅

`_logs/tribunal.jsonl`:

```json
{
  "decision_id": "DEC-042",
  "providers": ["claude", "gemini", "openai"],
  "consensus": "2:1",
  "dissent": {
    "provider": "gemini",
    "survivor": "Option B",
    "reasoning": "scalability risk underestimated"
  },
  "final_outcome": "adopted_majority"
}
```

---

## 9. 릴리스 계획

### v0.6.0 (Phase 1)

| 레이어 | 내용 | 의존성 |
|---|---|---|
| L1 | Local LLM Router + 자동 티어링 | Ollaya 설치 (선택) |
| L2 | Jev 스킬 통합 (단계별 판정) | L1 |
| L3 | Converge 하이브리드 병렬화 | L2 (Jev cross-validation) |

**신규 파일:**
- `lib/local_llm_router.sh`
- `lib/jev_templates/*.txt`
- `system_files/.claude/skills/jev-judgment/SKILL.md`
- `system_files/.claude/agents/validator.md` (수정)

**테스트:**
- Ollaya 가용/불가 양쪽 시나리오
- 티어 자동 감지 정확도
- Converge 병렬 vs 순차 결과 비교

### v0.7.0 (Phase 2)

| 레이어 | 내용 | 의존성 |
|---|---|---|
| L4 | Dual-Track Incubate + Fresh Agent | L1 (B-1), L2 (novelty score) |
| L5 | 메트릭 + 회고 루프 | L2 (Jev 판정 데이터) |
| L6 | 멀티 프로바이더 Tribunal | ask-gemini, codex:rescue |

**신규 파일:**
- `lib/incubation_templates/mutate.txt`
- `system_files/.claude/skills/decision-retrospective/SKILL.md`
- `system_files/.claude/agents/incubator.md` (수정)
- `system_files/.claude/hooks/session-start.sh` (수정)
- `lib/provider_adapter.sh`

**신규 디렉토리:**
- `_incubation_buffer/`
- `_decision_log/`

---

## 10. Graceful Degradation 매트릭스

| 조건 | L1 | L2 | L3 | L4 | L5 | L6 |
|---|---|---|---|---|---|---|
| Ollaya 미설치 | ❌ 비활성 | ❌ Claude만 | 정상 (Jev 없이) | B-1만 비활성 | 정상 (Jev 없이) | 정상 |
| Task tool 불가 | 정상 | 정상 | 순차 fallback | B-2만 순차 | 정상 | 정상 |
| API Key 없음 | 정상 | 정상 | 정상 | 정상 | 정상 | ❌ 비활성 |
| claude-mem 없음 | 정상 | 정상 | 정상 | 정상 | 정상 (로컬 로그만) | 정상 |
| 모든 외부 의존성 없음 | v0.5.1과 동일 동작 | | | | | |

**핵심 보장:** 외부 의존성이 하나도 없어도 플러그인은 v0.5.1과 동일하게 동작한다.
