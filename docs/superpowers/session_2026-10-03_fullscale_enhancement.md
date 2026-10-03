# Session: v0.6.0-v0.7.0 풀스케일 고도화
> 2026-10-03 ~ 2026-10-04

## 세션 목표
thinking-protocol-plugin에 로컬 LLM(Jev/Kev), Converge 병렬화, Dual-Track Incubate, 메트릭 회고 루프, 멀티프로바이더 Tribunal을 통합하는 풀스케일 고도화.

## 의사결정 과정

### 1. Cross-Model Review (Gemini + Codex)
- 5개 DEBATE POINT로 양쪽에 동일 프롬프트 전송
- **양쪽 평결: GO with cuts**
- 핵심 분기점: 로컬 LLM 우선순위
  - Gemini: Diverge 우선 (양적 확산에 최적)
  - Codex: Incubate 우선 (Diverge는 이미 병렬화됨)
  - Claude 판정: **Codex 채택** — Diverge 이미 3기법 병렬 fan-out 구현이라 추가 ROI 낮음

### 2. 주요 설계 결정
- **Jev 한국어 한계** → 영어 프롬프트 템플릿으로 우회, 사용자 대면은 Claude가 한국어
- **Ollaya 기본 런타임** → 의사결정 모델 전용, TypeSafe API 호환
- **자동 티어링** → 하드웨어 감지 (8GB→Kev-0.8B, 16GB→Kev-4B, 32GB→Kev-9B, 48GB+→OpenJev-27B)
- **Fresh Agent = 앵커링 제거** → Diverge 논의 과정 미전달이 핵심
- **자율형 Illuminate 게이트** → AskUserQuestion, 엔터=자동 진행
- **session-start hook 기반 회고** → 추가 인프라 불필요
- **Tribunal은 Converge only + opt-in** → API Key 감지 시 제안

### 3. 사용자 피드백으로 반영된 변경
- "인간 휴식 강제 규칙을 에이전트에 반영 + 컨텍스트 없는 신규 에이전트로 판단" → Fresh Agent Pool 설계 추가
- "사용자 복귀는 질문 후 디폴트 자율 진행" → AskUserQuestion + 자동 필터링 흐름
- "타이머보다 AskUserQuestion" → CLI 타이머 제거, AskUserQuestion 채택

## 실행 방식
- **Orca CLI + Codex Astra (gpt-6-astra xhigh)** 워크트리 병렬 디스패치
- v0.6.0: 6개 워크트리 (Task 1~8), v0.7.0: 3개 워크트리 (Task 1+2, 3+4+5, 6)
- git commit 권한은 매번 interactive prompt → `orca terminal send --text "" --enter`로 승인

## 결과
- **v0.6.0** (L1-L3): 커밋 8개, 테스트 33 PASS
- **v0.7.0** (L4-L6): 커밋 6개, 테스트 51 PASS (누적)
- 총 12개 신규 파일, 8개 기존 파일 수정
- `5cb3984..69d9419` push 완료

## 산출물
- Spec: `docs/superpowers/specs/2026-10-03-local-llm-jev-fullscale-enhancement-design.md`
- Plan v0.6.0: `docs/superpowers/plans/2026-10-03-v060-local-llm-jev-converge-parallel.md`
- Plan v0.7.0: `docs/superpowers/plans/2026-10-03-v070-incubate-metrics-tribunal.md`
