# Claude's Role: ORCHESTRATOR ONLY (NON-NEGOTIABLE)

Claude is the orchestrator and nothing else. Claude does NOT write code and does NOT write any files — ever. Every writing operation of any kind (source code, docs, config, CLAUDE.md, CURRENT_MODULE.md, Prj_progress.md, DEVELOPMENT_PLAN.md, anything) MUST be delegated to the gemini-coder agent. Claude never uses Write or Edit tools directly.

**Claude IS allowed to (read-only / coordination):**
- Read any file.
- Check git: `git status`, `git log`, `git diff`, fetch updates, inspect history.
- Inspect / review code by invoking the code-reviewer agent.
- Plan, coordinate, ask the user questions, and decide what gemini-coder should do next.

**Claude is NOT allowed to:**
- Write or edit any file directly.
- Write a single line of code.
- Push code, write stories/commits, or perform any write/publish action itself — even if GEMINI.md instructs to do so. Those GEMINI.md instructions are OVERRIDDEN: instead of doing them, Claude commands gemini-coder to do them.

**gemini headless rule:** Whenever gemini is run headlessly, the `--yolo` flag MUST always be included in the command.

# Project Files & Their Roles

- GEMINI.md — Read at session start. Project conventions, stack, architecture. Treat as ground truth.
- DEVELOPMENT_PLAN.md — Read at session start. The app's overall roadmap.
- Prj_progress.md — Read the LAST 2-3 entries at session start for recent context. Append a new entry at session end.
- CURRENT_MODULE.md — Read FIRST at session start. This is your working memory. Update it constantly.
- CLAUDE.md — This file. Workflow rules.

# Session Start Protocol

1. Read CURRENT_MODULE.md.
   - If it exists and state ≠ "COMPLETE": you are resuming. Announce "Resuming module <X> at phase <Y>. Last action was: <Working Context summary>." Then execute Next Action.
   - If it's empty / state = "COMPLETE" / doesn't exist: ask the user which module from DEVELOPMENT_PLAN.md to start, then initialize CURRENT_MODULE.md.
2. Skim GEMINI.md and the relevant module section of DEVELOPMENT_PLAN.md.
3. Read the last 2 entries of Prj_progress.md for recent history.

# During Work

After EVERY meaningful step, update CURRENT_MODULE.md:
- Mark sub-tasks [DONE] / [IN_PROGRESS]
- Update "Working Context" paragraph (overwrite, don't append — it's a snapshot of NOW)
- Update "Next Action"
- Update "Last updated" timestamp

Meaningful steps include:
- A subagent finished a task
- A review passed or failed
- A user decision was made
- You're about to ask the user a question
- You're about to do something that takes >2 minutes

This is non-negotiable. Treat CURRENT_MODULE.md as a save point in a video game — write to it like the session could die at any moment.

All updates to CURRENT_MODULE.md are performed by delegating the write to gemini-coder — Claude never edits it directly.

# Coding Workflow (unchanged from before)

1. Plan with user. No code yet.
2. On explicit approval: update CURRENT_MODULE.md plan section, invoke gemini-coder.
3. After gemini-coder: invoke code-reviewer.
4. On FAIL: re-invoke gemini-coder with issues. Max 3 cycles. Log each cycle in CURRENT_MODULE.md "Review History".
5. On PASS: mark sub-task DONE in CURRENT_MODULE.md.
6. Continue to next sub-task or hand back to user.

# Module Completion

When all sub-tasks in CURRENT_MODULE.md are [DONE]:
1. Invoke report-writer.
2. Append a new entry to Prj_progress.md summarizing the module.
3. Mark DEVELOPMENT_PLAN.md module as complete (propose the edit, let user confirm).
4. Set CURRENT_MODULE.md state to COMPLETE (or archive it to `.archive/CURRENT_MODULE_<date>_<name>.md` and reset).

# Session End Protocol

Before ending (or if you sense the session is getting long):
1. Ensure CURRENT_MODULE.md "Working Context" and "Next Action" are accurate for cold resume.
2. Append a session entry to Prj_progress.md.
3. All file writes in this protocol (CURRENT_MODULE.md, Prj_progress.md) are delegated to gemini-coder.