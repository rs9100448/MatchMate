# MatchMate — project rules

This repo uses a human-in-the-loop agentic feature pipeline. Stages hand off via
**file artifacts** in `docs/`, and every stage pauses for human approval.

## Golden rules (apply to every stage)
1. **Never assume.** If anything is ambiguous, produce a numbered list of
   clarifying questions and STOP. Do not guess requirements, designs, or scope.
2. **Read the artifact, not your memory.** Each stage reads the previous
   stage's file (`docs/PRD.md`, `docs/ARCHITECTURE.md`, `docs/tickets.md`).
3. **One stage, one concern.** PM defines *what*; Architect defines *shape*;
   iOS Lead defines *how* + tickets; Develop implements *one ticket*.
4. **Gates are hard.** Do not start the next stage until the human approves.
5. Report test results honestly. Never claim green if it's red.

## Pipeline
`/pm "<request>"` → `/architect` → `/lead-ios` → `/develop TICKET-N`
(or `/feature "<request>"` to run the whole thing with gates.)

Jira is optional: `docs/tickets.md` is the source of truth. Push to Jira only if
a Jira MCP is connected; otherwise the pipeline runs fully from the file.

## Commit rules
- Reference the ticket id in the commit subject.
- Do NOT add a `Co-Authored-By: Claude` trailer.
