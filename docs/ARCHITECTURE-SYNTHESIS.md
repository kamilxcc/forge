# Forge Plugin Architecture Synthesis
## Integrating Superpowers & Gstack Best Practices

**Date**: 2026-04-23  
**Context**: Analysis of `obra/superpowers` and `garrytan/gstack` repositories, applied to current `forge-plugin` implementation

---

## Executive Summary

This document synthesizes architectural patterns from two mature Claude Code plugin projects:

- **Superpowers** (`obra/superpowers`): Workflow-centric, strict linear progression, TDD enforcement, verification gates
- **Gstack** (`garrytan/gstack`): Configuration-centric, multi-host support, persistent infrastructure, rich telemetry

**Forge-plugin's current state**: Implements basic workflow orchestration (`/plan` → `/implement` → `/review`), per-project knowledge base loading, and work document tracking. **Gap analysis** shows opportunities in:

1. Verification-before-completion gates (missing)
2. Hard gates preventing workflow skipping (partially present via status checks)
3. Rich context propagation between skill execution
4. Observability and decision trails
5. Escalation protocol for blocked tasks

This document provides a **6-layer synthesis architecture** that forge-plugin can adopt incrementally without breaking changes to existing skills.

---

## Pattern 1: Verification-Before-Completion Gates

### Current Forge State
- `forge-implement` executes steps but provides summaries without structured verification
- `forge-review` outputs pass/warn/block verdicts but no independent verification requirements
- No explicit "red-green-refactor" cycle enforcement

### Superpowers Pattern
**"NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"**

Gate function:
1. **IDENTIFY**: What command proves this claim?
2. **RUN**: Execute the FULL command (fresh, complete)
3. **READ**: Full output, check exit code, count failures  
4. **VERIFY**: Does output confirm the claim?
5. **CLAIM**: Make the claim WITH evidence

### Recommended Implementation for Forge

**In `forge-test/SKILL.md`**: Add explicit verification pattern

```yaml
# Verification Protocol for forge-test

Before claiming "tests pass":
1. Identify the test suite command from project.yaml
2. Run the full suite fresh (no cached results)
3. Parse output: count pass/fail, check exit code
4. If any failure: report actual count with evidence
5. Only then claim "Tests pass: X/Y"
```

**In `forge-review/SKILL.md`**: Require verification evidence in verdict

```
PASS verdict requires:
- [ ] Re-read plan.md requirement-by-requirement
- [ ] Verify each requirement met (show evidence)
- [ ] Run project's verification commands
- [ ] No compiler warnings/errors
```

### Impact
- Reduces false-positive "completion" claims
- Creates audit trail (evidence in review.md)
- Integrates naturally into existing review workflow

---

## Pattern 2: Hard Gates with Explicit Blocking

### Current Forge State
Status-based checks exist (`task.md` must have `status: confirmed`) but are advisory, not enforcing.

### Superpowers Pattern
Hard-gate: `/plan` must NOT transition into coding until user explicitly confirms the plan. Any change that lets `/implement` auto-chain breaks the workflow.

Guard syntax:
```
SUBAGENT-GUARD: If Claude spawned as sub-agent, skip orchestrator logic
HARD-GATE: If workflow state not confirmed, block progression
```

### Recommended Implementation for Forge

**In `forge/SKILL.md`** (orchestrator): Add explicit blocking

```markdown
## Workflow State Machine

Allowed transitions:
- requirement.md (any status) → clarify (output) → requirement.md (status: confirmed)
- requirement.md (status: confirmed) → plan (output) → plan.md (status: confirmed)
- plan.md (status: confirmed) → implement (output) → review → test

**Hard blocks** (prevent progression):
- If task.md missing → /implement fails with error message
- If task.md status ≠ confirmed → /implement asks user to confirm or replan
- If review.md status = BLOCK → /test refuses to run (requires escalation review)
```

**In `/implement`**: Escalate BLOCK reviews

```markdown
If previous review.md contains `status: BLOCK`:
  🛑 Code review blocked this feature. Escalation required:
  - Review blocking reason in review.md
  - Run /clarify to address concerns (outputs new requirement.md)
  - User confirms new requirement
  - Run /plan again to generate revised plan
  - Then /implement (replaces previous implementation)
```

### Impact
- Prevents "skip the plan and just code" anti-pattern
- Creates audit trail of approvals
- Enables rollback via status resets

---

## Pattern 3: Context Propagation & Staleness Tracking

### Current Forge State
- Work documents (requirement/plan/task/review) stored separately
- Knowledge base loaded fresh per skill
- No explicit staleness tracking or context versioning

### Gstack Pattern
Rich metadata in skill frontmatter:
```yaml
preamble-tier: 2
triggers: 
  - "user types /plan with slug containing 'security'"
  - "review.md exists and status = NEEDS_CONTEXT"
allowed-tools: [Read, Write, Edit, Bash, Grep]
```

Review dashboard tracks:
- Staleness (commits elapsed since review)
- Verdict logic with context (commit SHA reference)
- Escalation chain

### Recommended Implementation for Forge

**Step 1: Add metadata to work documents**

```yaml
# task.md preamble
---
feature: add-aiapp-collect-card
dated_slug: 2026-04-23-add-aiapp-collect-card
plan_doc: plan.md
created_at: 2026-04-23
created_by: claude-implement-v2
git_commit_at_plan: abc1234def5678  # capture plan commit context
task_started_at: 2026-04-23T16:30:00Z
task_started_by: subagent-xyz
---
```

**Step 2: Track staleness in reviews**

Add to `forge-review/SKILL.md`:
```markdown
## Staleness Check

1. Read review.md created_at
2. Run: git log --oneline plan.md | head -1
3. If commits > 5 or days > 3: 
   Warning: "Plan is stale (last updated 7 days ago). 
   Consider running /plan again."
```

**Step 3: Link decisions to contexts**

```markdown
# In review.md verdict section

PASS (evidence-based):
- Requirement: "AIAPP 多应用收合卡片在「全部」Tab 展示"
  ✅ Verified: GuildFeedSquareDelegatesManager registers new TYPE
  ✅ Verified: GuildFeedSquareFeedItemData routes cardType=13 correctly
  
Risk: "GProRecommendCardType has no named constant 13"
- Mitigation: Added TODO comments in 2 locations
- Follow-up: Update when SDK adds GProRecommendCardType.AI_APP_COLLECT_CARD
```

### Impact
- Review verdicts become auditable (why, not just what)
- Staleness surfaces automatically  
- Easier to re-run stale plans without losing context

---

## Pattern 4: Escalation Protocol with State Tracking

### Current Forge State
- `forge-review` outputs PASS/WARN/BLOCK
- No structured escalation pathway for BLOCK/WARN cases
- No tracking of escalation history

### Superpowers Pattern
Four-state status system:
```
DONE: Task complete, ready to merge
DONE_WITH_CONCERNS: Complete but has known issues (documented)
NEEDS_CONTEXT: Blocked waiting on input
BLOCKED: Cannot proceed (security/architecture violation)
```

### Recommended Implementation for Forge

**In `forge-review/SKILL.md`**: Structured escalation

```markdown
## Verdict States

- **PASS**: All requirements verified, no concerns → proceed to /test
- **WARN**: Complete but concerns exist → proceed to /test with notes  
- **NEEDS_CONTEXT**: Blocked, requires user decision → escalate to /clarify
- **BLOCK**: Violates rules → requires escalation review

## Escalation Flow

If NEEDS_CONTEXT:
  Reason: "<specific concern>"
  Blocking factor: "<what prevents approval>"
  Recommend action: "/clarify to address concern"
  
If BLOCK:
  Reason: "<rule violation>"
  Rule source: "<from KB rules.yaml>"
  Require: Manual escalation (user decision)
```

**In work document structure**: Track escalation history

```
work/qqguild-feed/2026-04-23-add-aiapp-collect-card/
├── requirement.md (status: confirmed)
├── plan.md (status: confirmed)
├── task.md (status: confirmed)
├── review.md (status: BLOCK)
├── escalation/
│   ├── 2026-04-23-review-block-security.md (user input)
│   ├── requirement-v2.md (revised requirement after escalation)
│   ├── plan-v2.md (replanned after escalation)
│   └── task-v2.md (retasked)
```

### Impact
- Clear pathway for blocked work
- Escalation history preserved
- Prevents "stuck" features from accumulating

---

## Pattern 5: No-Placeholders Enforcement in Plans

### Current Forge State
Task steps in `task.md` are well-scoped, but some refer to earlier tasks indirectly ("参照 GuildFeedSquareAIAppRankSection").

### Superpowers Pattern
Strict no-placeholder rule. Detected patterns:
- "TBD", "TODO", "implement later"
- "Add appropriate error handling" (without code)
- "Similar to Task N" (repeat code, not reference)
- Steps that describe without showing (no code blocks)

Scanner implementation:
```regex
/TBD|TODO|implement later|fill in details|add.*validation|handle.*edge cases|Similar to|without showing/
```

### Recommended Implementation for Forge

**In `forge-plan/SKILL.md`**: Add placeholder checker

```markdown
## Self-Review: No Placeholders

After writing plan.md, run this checklist:

- [ ] Search for these patterns: "TBD", "待办", "待确认", "例如", "类似"
- [ ] Each task step shows actual code, not descriptions
- [ ] Each step has exact file paths, not "in the appropriate module"
- [ ] If step says "参照 X", also include full code snippet (DRY: repeat code verbatim)
- [ ] No "and other necessary changes"

If any found:
  Fix inline, then output:
  ✅ No-placeholder check: PASS
```

**Automated checker script** (optional, add to `scripts/`):

```bash
#!/bin/bash
# scripts/check-no-placeholders.sh
FILE=$1
PATTERNS="TBD|TODO|待办|例如|类似|以及其他|并补充|其中|此外"

if grep -iE "$PATTERNS" "$FILE"; then
  echo "❌ Found placeholders in $FILE"
  exit 1
else
  echo "✅ No placeholders found"
  exit 0
fi
```

### Impact
- Plans become executable without guessing
- Reduces back-and-forth during implementation
- Documents constraints explicitly

---

## Pattern 6: Multi-Host Configuration Pattern

### Current Forge State
Forge-plugin targets Claude Code only. No consideration for:
- Different host capabilities (Cursor, Claude Code, Copilot)
- Different file paths per host
- Different tool budgets per host

### Gstack Pattern
Host configuration abstraction:

```typescript
// hosts/claude.ts
const claude: HostConfig = {
  name: 'claude',
  displayName: 'Claude Code',
  globalRoot: '.claude/skills/gstack',
  pathRewrites: [],
  toolRewrites: {},
  coAuthorTrailer: 'Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>',
};

// hosts/cursor.ts
const cursor: HostConfig = {
  name: 'cursor',
  displayName: 'Cursor AI',
  globalRoot: '.cursor/commands',  // different location
  pathRewrites: [
    { pattern: '.claude', replacement: '.cursor' },
  ],
  toolRewrites: {
    'Bash': { disabled: true },  // cursor has different bash support
  },
};
```

Frontmatter with tiers:

```yaml
name: forge-plan
preamble-tier: 1  # always shown
description: 生成技术方案

preamble:
  - tier: 1
    content: |
      # 前置条件（所有主机）
      - .forge-kb/ 存在
      - requirement.md status=confirmed
  
  - tier: 2  
    content: |
      # Cursor 专用注意
      仅在 Cursor 中运行本 skill
      
  - tier: 3
    content: |
      # 高级选项（可选）
```

### Recommended Implementation for Forge

**Phase 1: Store host metadata** (no behavior change)

```yaml
# In settings.json for target projects
forge:
  host: claude-code  # or "cursor", "copilot"
  features:
    enable_escalation: true
    enable_telemetry: false
    knowledge_base_auto_refresh: true
```

**Phase 2: Conditional tool declarations** (in skill frontmatter)

```yaml
name: forge-implement
description: Forge 编码执行能力

tool_budget:
  base: [Read, Write, Edit, Bash, Glob, Grep]
  if_host_is_cursor:
    - use: [Read, Write, Edit, Glob, Grep]
    - skip: [Bash]  # Cursor has limited bash
    - recommend: "Run verification commands after exiting skill"
```

**Phase 3: Host-aware skill selection** (future)

```
/go <需求> in Cursor 
→ routes to /plan (no implementation today, use /implement in Claude Code)

/go <需求> in Claude Code
→ full pipeline /plan → /implement → /review → /test
```

### Impact (Future)
- Forge-plugin becomes portable across hosts
- Graceful degradation (fewer tools in Cursor, full power in Claude Code)
- Users not frustrated by "command not available"

---

## Implementation Roadmap

### Phase 1 (Immediate): No Breaking Changes
**Goal**: Add verification patterns without changing skill APIs

- [ ] Add verification examples to `forge-test/SKILL.md` preamble
- [ ] Add staleness check to `forge-review/SKILL.md` Step 2
- [ ] Document escalation flow in `forge/SKILL.md`
- [ ] Test with current qqguild-feed feature

**Effort**: 2-3 hours, 1 skill update round

**Files to modify**:
- `skills/forge-test/SKILL.md` (add verification section)
- `skills/forge-review/SKILL.md` (add staleness + escalation)  
- `skills/forge/SKILL.md` (add escalation flow)
- `references/structured-step-output.md` (add verification evidence template)

---

### Phase 2 (Week 2): Context Propagation
**Goal**: Track staleness and decision context

- [ ] Add metadata fields to `work/` document preambles (git_commit, created_by)
- [ ] Update `forge-implement` to capture git context
- [ ] Update `forge-review` to check staleness and link decisions
- [ ] Create `ESCALATION_HISTORY.md` template in work directory

**Effort**: 4-6 hours, all skills touched

**Files**:
- `skills/forge-implement/SKILL.md` (capture git context)
- `skills/forge-review/SKILL.md` (staleness check + evidence linking)
- `skills/forge/SKILL.md` (escalation directory management)
- `scripts/` (new: `archive-escalation.sh`)

---

### Phase 3 (Month 2): Escalation Automation
**Goal**: Auto-route blocked work, track escalation chains

- [ ] Implement `NEEDS_CONTEXT` auto-routing to `/clarify`
- [ ] Store escalation metadata in `.forge-kb/meta/escalations.jsonl`
- [ ] Add escalation dashboard (`scripts/show-escalation-status.sh`)
- [ ] Integrate with project-wide blockers view

**Effort**: 8-10 hours, new scripts + skill updates

**Files**:
- `skills/forge-review/SKILL.md` (NEEDS_CONTEXT → /clarify routing)
- `scripts/show-escalation-status.sh` (new)
- `.forge-kb/meta/escalations.jsonl` (new template)

---

### Phase 4 (Month 3): Multi-Host Support
**Goal**: Forge-plugin works across Cursor, Claude Code, Copilot

- [ ] Create host config abstraction (`hosts/`)
- [ ] Update skill frontmatter with conditional tool declarations
- [ ] Implement host detection in `forge/SKILL.md`
- [ ] Test in Cursor environment

**Effort**: 12-15 hours, significant refactor

**Files**:
- `hosts/claude.ts` (new host config)
- `hosts/cursor.ts` (new host config)  
- `scripts/detect-host.sh` (new)
- All skills: add host-awareness to frontmatter

---

## Architecture Diagram: Proposed 6-Layer Stack

```
┌─────────────────────────────────────────────────────────┐
│ Layer 6: Multi-Host Abstraction (Phase 4)               │
│ - Host detection (Claude Code / Cursor / Copilot)       │
│ - Tool budget per host                                   │
│ - Graceful degradation                                  │
└─────────────────────────────────────────────────────────┘
             ↑
┌─────────────────────────────────────────────────────────┐
│ Layer 5: Escalation Protocol (Phase 3)                  │
│ - PASS / WARN / NEEDS_CONTEXT / BLOCK states            │
│ - Auto-routing to /clarify                               │
│ - Escalation history tracking                            │
└─────────────────────────────────────────────────────────┘
             ↑
┌─────────────────────────────────────────────────────────┐
│ Layer 4: Context Propagation (Phase 2)                  │
│ - Staleness tracking (git commits, days elapsed)         │
│ - Decision trails (evidence-based verdicts)              │
│ - Metadata versioning (created_by, created_at, git SHA) │
└─────────────────────────────────────────────────────────┘
             ↑
┌─────────────────────────────────────────────────────────┐
│ Layer 3: Verification Gates (Phase 1)                   │
│ - IDENTIFY-RUN-READ-VERIFY-CLAIM protocol               │
│ - Red-green-refactor enforcement                         │
│ - Evidence-based completion claims                       │
└─────────────────────────────────────────────────────────┘
             ↑
┌─────────────────────────────────────────────────────────┐
│ Layer 2: Hard Blocking (Current)                         │
│ - Status-based workflow gates                            │
│ - Prevent skip-plan anti-pattern                         │
│ - Structured error on precondition failure               │
└─────────────────────────────────────────────────────────┘
             ↑
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Core Workflow (Current)                         │
│ - /plan → /implement → /review → /test                  │
│ - Per-project knowledge base (.forge-kb/)                │
│ - Work directory tracking (work/<project>/<dated-slug>/) │
└─────────────────────────────────────────────────────────┘
```

---

## Key Decisions to Lock In

### 1. **Verification Evidence Retention**
Decision: Keep full evidence in review.md (not in separate audit log)

Rationale: 
- Easier to review: everything in one markdown file
- No new infrastructure needed
- Matches existing work document model

Alternative considered: Separate `audit/` directory with structured JSON
- Pro: Structured for querying
- Con: Adds complexity, requires new tooling

### 2. **Staleness Thresholds**
Decision: Warn if plan > 5 commits old OR > 3 days old

Rationale:
- Balances drift risk with unnecessary re-planning
- Matches gstack's review dashboard logic

Tuning: Configurable in `.forge-kb/meta/config.yaml` (Phase 2)

### 3. **Escalation vs. Replan**
Decision: BLOCK → requires manual escalation (user decides replan or archive)
Decision: NEEDS_CONTEXT → auto-route to /clarify

Rationale:
- BLOCK = architecture/security, needs human judgment
- NEEDS_CONTEXT = missing info, skill can help gather it

### 4. **Co-Author Trailer**
Decision: Keep current (no change to git workflow)

Note: gstack uses host-specific co-authors. Forge-plugin could add:
```yaml
coAuthorTrailer: 'Co-Authored-By: Claude Forge Plugin <forge@anthropic.com>'
```

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Verification gates slow down execution | Phase 1 adoption friction | Make gates optional initially (flag: `enable_verification_gates: false` in project.yaml) |
| Staleness checking false-positives | False urgency to replan | User overrides threshold in config.yaml |
| Escalation state explosion | Complex state machine | Start with 3 states (PASS/WARN/BLOCK), add NEEDS_CONTEXT in Phase 3 |
| Multi-host abstraction over-engineers current needs | Delayed value | Phase 4 only after Phase 1-3 proven in production |

---

## Success Metrics

After Phase 1 implementation:
- ✅ Every review.md includes structured evidence (100% of reviews)
- ✅ Zero "undefined variable" bugs from /implement → /test (due to no-placeholder enforcement)
- ✅ Staleness check catches stale plans (< 2 days old average between replan)

After Phase 2-3:
- ✅ BLOCKED features tracked in escalation dashboard
- ✅ Average time-to-resolve for NEEDS_CONTEXT < 2 hours (auto-routing to /clarify)
- ✅ Zero "lost context" failures between sessions

After Phase 4:
- ✅ Forge-plugin works in Cursor (graceful degradation: no /implement, only plan)
- ✅ Documented host matrix (what works where)

---

## References

- **Superpowers Pattern Source**: https://github.com/obra/superpowers
  - Key files: `skills/verification-before-completion/`, `skills/subagent-driven-development/`
  
- **Gstack Pattern Source**: https://github.com/garrytan/gstack  
  - Key files: `hosts/claude.ts`, `scripts/resolvers/review.ts`, `autoplan/SKILL.md` preamble

- **Current Forge-plugin**:
  - `/Users/kamilxiao/code/forge-plugin/skills/`
  - Work in progress: `work/qqguild-feed/2026-04-23-add-aiapp-collect-card/`

---

## Appendix: Skill Modification Checklist (Phase 1)

### `forge-test/SKILL.md`

- [ ] Add "Verification Protocol" section (after execution flow)
- [ ] Example: "Before claiming 'tests pass', run full suite fresh"
- [ ] Reference: `<plugin-root>/references/verification-protocol.md` (new file)

### `forge-review/SKILL.md`

- [ ] Add "Staleness Check" sub-step in Step 2 (after reading review.md)
- [ ] Add "Evidence Linking" template in verdict section
- [ ] Example: "PASS (evidence-based): Requirement X verified by..."

### `forge/SKILL.md`

- [ ] Add "Escalation Flow" section in orchestrator
- [ ] Clarify: BLOCK vs. NEEDS_CONTEXT routing
- [ ] Add example: "If status=BLOCK in review.md, /test refuses"

### `references/`

- [ ] Create `verification-protocol.md` (template from superpowers)
- [ ] Update `structured-step-output.md` to include evidence section

---

**Document Status**: DRAFT — Ready for Phase 1 implementation planning  
**Next Step**: User confirms Phase 1 scope, then create task list for skill modifications
