# 설계: claude-mem 지속메모리/세션검색(②) + Diverge 병렬화(③) 역이식

- **날짜**: 2026-05-31
- **대상 저장소**: `thinking-protocol-plugin`
- **전파 메커니즘**: `system_files/` 수정 → `/migrate`로 볼트 전파
- **이번 라운드 전파 범위**: 플러그인 + 검증볼트 1개(`trading-vault`)
- **출처 참조**: hermes-agent(NousResearch)의 ② persistent memory/session search, ③ subagent parallelization 개념. 검증된 패턴 원본은 `assistant_project`(kr-cio 병렬 디스패치, claude-mem 활성화).

## 1. 목표와 비목표

### 목표
1. **②**: 볼트가 "과거 파일"뿐 아니라 "과거 세션"까지 회상하도록 `recall` 스킬을 claude-mem 연동 이중소스로 업그레이드한다.
2. **③**: `ideator`(Diverge 단계)의 3개 인지기법 직렬 체인을 병렬 fan-out으로 전환해 지연을 줄이고 상호 앵커링을 제거한다.
3. 두 변경 모두 플러그인 `system_files/`에 반영하고 `/migrate`로 전파 가능하게 만든다.

### 비목표 (이번 라운드 제외)
- ④ 멀티플랫폼 게이트웨이(Telegram/Discord/이메일) — 다음 라운드.
- ① 스킬 자동생성/패턴집계/메트릭 — 다음 라운드.
- 병렬 fan-out의 validator(Converge) 등 타 단계 확대 — 패턴만 문서화, 적용은 차기.
- 5개 볼트 일괄 전파 — 검증볼트 1개만.

## 2. 공통 제약

- **단일 변경 지점**: 모든 수정은 `thinking-protocol-plugin/system_files/`(+ settings 템플릿)에만. 볼트 직접 수정 금지(검증볼트의 `/migrate` 결과는 예외).
- **포크 보존**: 새/수정 파일은 `system: true` 프론트매터 유지 → 마이그레이션 시 사용자 포크(`system: false`)는 `_backup/` 스냅샷 후 보존, `_skipped_forks.txt`에 기록.
- **Graceful degradation**: claude-mem 미설치 환경 및 병렬 디스패치 불가 환경에서도 동작이 깨지지 않고 기존 동작으로 축소된다.
- **추적**: 플러그인 `VERSION` 범프(0.4.1 → 0.5.0), `CHANGELOG.md`에 `kind: skill` / `kind: rule` 항목 추가.

---

## 3. ② claude-mem 지속메모리 / 세션검색

### 3.1 현재 상태
- `system_files/.claude/skills/recall/recall.py` — 볼트 파일에 대한 구조인지 검색(레이어별 우선순위: insights/decisions/KB/analyses/inbox). 포인터만 반환, 작성 안 함.
- claude-mem은 **별도 플러그인**으로, transcript를 자동 관측하고 `mcp__plugin_claude-mem_mcp-search__{smart_search,search,get_observations}`로 세션 간 에피소드 회상을 제공. 현재 `assistant_project`에만 권한 활성.

### 3.2 변경 사항

**(a) `recall` 스킬을 이중소스로 업그레이드**
`recall/SKILL.md`의 Procedure를 2-소스 구조로 개정:

1. **소스 1 — 볼트 파일**: 기존 `recall.py "<질문>"` 실행 (변경 없음).
2. **소스 2 — 과거 세션**: claude-mem `smart_search`를 동일 질문으로 질의. 도구 미가용(미설치/권한없음) 시 이 소스를 **조용히 건너뛴다**.
3. **출력 병합 — 출처 분리 섹션**:
   ```
   ## 과거 문서 (볼트 구조검색)
     [layer] path — why — confidence
   ## 과거 세션 (claude-mem)
     [session] date — 요약 — confidence
   ```
   - claude-mem 결과가 없거나 도구 미가용이면 "## 과거 세션" 섹션 자체를 생략한다.
   - 기존 규칙 유지: 포인터만 제시, 인용 전 Read로 확인, 빈 결과는 정직하게 보고.

**(b) settings 템플릿에 권한 추가**
`system_files/`의 settings 템플릿(또는 `setup.sh`가 생성/머지하는 권한 목록)에 다음 allow 추가:
```
mcp__plugin_claude-mem_mcp-search__smart_search
mcp__plugin_claude-mem_mcp-search__search
mcp__plugin_claude-mem_mcp-search__get_observations
```
(assistant_project에서 검증된 항목 그대로.)

**(c) /migrate 후 활성화 안내**
`commands/migrate.sh` 마무리 단계(현재 research feed crontab 안내 위치)에 1-step 안내 출력 추가:
> "세션 간 회상을 쓰려면 claude-mem 플러그인을 활성화하세요. 미설치 시 recall은 볼트 파일 검색만 수행합니다(정상 동작)."

플러그인이 타 플러그인을 강제 설치하지 않는다. 권한만 미리 깔아두고 활성화는 사용자 몫.

**(d) CLAUDE.md.tmpl 문서화**
회상 워크플로우(이중소스, claude-mem 옵션) 1개 문단 추가.

### 3.3 ② 수용 기준
- claude-mem 활성 볼트: `/recall` 또는 recall 스킬 호출 시 두 섹션이 모두 채워진다.
- claude-mem 비활성 볼트: 에러 없이 "과거 문서" 섹션만 출력된다.
- `/migrate` 실행 시 settings에 claude-mem 권한 3종이 추가되고 안내가 출력된다.

---

## 4. ③ Diverge 단계 병렬화

### 4.1 현재 상태
`system_files/.claude/agents/ideator.md` — 단일 에이전트가 `scamper-ideation` → `remote-association-matrix` → `worst-possible-idea`를 **한 컨텍스트에서 순서대로** 실행(Mandatory chain). 결과를 연속번호로 묶어 `incubator`로 핸드오프.

**문제**: (1) 약 3배 직렬 지연. (2) 세 기법이 같은 컨텍스트를 공유해 앞 기법 산출이 뒤 기법을 앵커링 → 다양성 저하(hermes의 "multi-modal sweep" 원칙 위배).

### 4.2 변경 사항 — ideator 직접 병렬 디스패치
오케스트레이션 주체는 **ideator 에이전트 자신**(기존 진입점 유지). `ideator.md`의 `## Calls`를 직렬 체인에서 병렬 fan-out으로 개정:

1. ideator가 3개 **서브에이전트를 병렬 디스패치**한다. 각 서브에이전트는 정확히 하나의 기법만 수행하며 **서로의 출력을 보지 못한다**(블라인드 → 앵커링 제거):
   - subagent A: `scamper-ideation` (≥7 ideas, 7개 substep 전부)
   - subagent B: `remote-association-matrix` (≥5 distant pairings)
   - subagent C: `worst-possible-idea` (≥3 inversions)
2. ideator는 **병합 전용** 역할로 전환: 3개 결과를 받아 연속번호(1..N)로 재부여하고 기존 3-섹션 출력 포맷 유지, `incubator`로 핸드오프.
3. 기존 불변식 유지: 평가 금지, ≥15 floor, 사용자 N은 floor로 취급, 출처별 그룹핑, 마무리 핸드오프 문구.

**도구 전제**: 현재 `ideator.md` frontmatter의 `tools`는 `Read, Grep, Glob, WebSearch, WebFetch, Write`로 **서브에이전트 디스패치 도구가 없다**. 병렬 디스패치를 하려면 ideator의 `tools`에 디스패치 도구(Agent/Task)를 추가해야 한다. 추가 시 ideator가 의도치 않게 다른 에이전트까지 부르지 않도록, 시스템 프롬프트에서 "3개 Diverge 기법 서브에이전트만 병렬 호출"로 사용을 한정한다.

**폴백**: 병렬 서브에이전트 디스패치가 불가능한 환경에서는 ideator가 기존처럼 3개 기법을 **순차 실행**한다(동일 출력 포맷). `ideator.md`에 폴백 경로를 명시한다.

### 4.3 재사용 패턴 문서화
이 fan-out을 "parallel-fanout"(블라인드 병렬 → 병합) 패턴으로 플러그인 내 1개 문서/주석에 명문화. validator(bias-check+premortem+JTBD) 등 차기 확대의 기준으로만 남기고 이번엔 적용하지 않는다.

### 4.4 ③ 수용 기준
- Diverge 호출 시 3개 기법이 병렬로 실행되고(또는 폴백 시 순차), 출력 포맷·개수 불변식이 기존과 동일하다.
- 각 서브에이전트가 다른 기법의 산출을 참조하지 않는다(블라인드).
- 병렬 불가 환경에서 순차 폴백으로 동일 결과를 낸다.

---

## 5. 전파 & 검증

### 5.1 전파
1. 위 변경을 `system_files/`(+ settings 템플릿, CLAUDE.md.tmpl, migrate.sh)에 반영.
2. `VERSION` 0.4.1 → 0.5.0, `CHANGELOG.md` 항목 추가(② recall 이중소스 = `kind: skill`, ③ ideator 병렬화 = `kind: rule`).
3. **검증볼트 1개(`trading-vault`)에만** `/migrate` 실행 → `_backup/<timestamp>/` 스냅샷 생성, 포크 보존 확인. 나머지 4개 볼트는 사용자 요청 시 전파.

### 5.2 테스트 (`tests/`)
- **recall 이중소스 degrade**: claude-mem 도구 부재를 모의 → recall이 "과거 문서" 섹션만 출력하고 에러 없이 종료.
- **migrate idempotency**: 동일 볼트에 `/migrate` 2회 실행 → 두 번째가 무해(중복 권한/파일 미발생), `_skipped_forks.txt`에 포크 보존 기록.
- **ideator 폴백**: 병렬 불가 모의 → 순차 경로로 ≥15 ideas, 3섹션 포맷 유지.

### 5.3 롤백
검증볼트 문제 시: `cp -rp _backup/<latest>/. .` 후 `./setup.sh --verify`. 플러그인은 git revert.

---

## 6. 미해결/위험
- claude-mem `smart_search` 응답 스키마가 환경별로 다를 수 있음 → recall 병합부는 "줄 단위 포인터"로만 정규화하고 원본 스키마에 의존하지 않는다.
- settings 권한을 `setup.sh`가 생성하는지/사용자 settings에 머지하는지 구현 시 확인 필요(머지여야 사용자 기존 권한 보존).
- ideator 병렬 서브에이전트가 `00_Idea_Inbox/`에 동시 쓰기 시 충돌 가능 → 쓰기는 ideator(병합자)만 수행하고 서브에이전트는 결과를 반환만 하도록 강제.
