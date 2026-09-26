# Claude Code Guidelines - Mitra

@AGENTS.md
@.agents/harnesses/claude_code.md

## Mandatory Post-Planning Hook
Every time you complete creating or updating `.docs/implementation_plan.md` and `.docs/tasks.md`, you **MUST** run the completion hook:
```bash
.agents/hooks/plan_complete.sh
```
Never skip calling this hook upon concluding your planning phase.