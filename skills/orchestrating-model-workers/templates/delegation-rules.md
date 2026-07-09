## Model Delegation Rules

- The smartest model available acts as the **manager**: it only does planning,
  judgment, and review. Implementation work with clear specs goes to cheaper
  models via subagents or configured workers (`~/.claude-workers/<name>/run`).
- **Token routing:** token-hungry work (reading large documents, log digging,
  browser automation and testing, research sweeps) always goes to the cheapest
  capable model, which must return a short summary with pointers (file paths,
  line numbers, links, IDs) — never a raw dump into the manager's context.
- **Revision gate:** every piece of work a cheaper model brings back gets an
  audit pass against the task's criteria before it is used. If it misses, send
  the SAME cheap model back out with specific revision notes. Only escalate to
  a smarter model after a second miss.
- **Escalation rule:** 'Judge the output, not the price tag. If a cheaper
  model's work misses the bar, escalate without asking.' These mappings are
  defaults, not limits — de-escalate freely when a task is simpler than its
  category suggests.
