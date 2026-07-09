---
description: Delegate a task to a configured model worker, then audit the result before accepting it
argument-hint: "[worker-name] <task description>"
---

Delegate a task to a model worker per the orchestrating-model-workers skill
(read its SKILL.md in this plugin if you haven't this session).

Arguments given: "$ARGUMENTS"

1. Pick the worker: if the first argument names one (check
   `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-worker.sh" list`), use it; otherwise
   use the only configured worker, or ask which.
2. Write a complete, self-contained spec for the task: relevant file paths,
   acceptance criteria, constraints, and the instruction to return a short
   summary with pointers (never full file dumps).
3. Dispatch headlessly: `~/.claude-workers/<name>/run -p "<spec>" --permission-mode acceptEdits`
   (drop `--permission-mode` for read-only research tasks).
4. Revision gate — audit the result against the acceptance criteria yourself:
   read the diff, run the tests or the code. Do not present unverified worker
   output as done.
5. If it misses: send the SAME worker back out with specific revision notes.
   After a second miss, do the task yourself or via a smarter subagent —
   judge the output, not the price tag.
6. Report to the user: what was delegated, audit verdict, and the final result.
