# Interview before a change

Run this before any edit to code or to a requirement on the delegated-access branches. It specializes the
generic `/interview` skill (`.claude/skills/interview/SKILL.md`) to this feature: the question areas below
replace its generic categories; its mechanics (one or two questions at a time, options rather than yes/no,
record the decisions) stay. The developer decides every question; the skill supplies the context and the
recorded rationale so the decision is informed.

## Proportion

- A fix inside one branch that changes no documented behavior: areas 1, 4, 9 only, often answered in one
  exchange.
- A behavior change or a new row: every area, 6 to 12 questions.
- A new feature or a stack reorder: every area, plus an open-items line in the owning section's How to review for anything open.

## Preparation (load before asking)

`references/requirements-index.md` for the rows named; the owning section of the document; `references/decisions.md`
for the decisions those rows cite; `references/branch-context/<branch>.md`; the RFC digest under
`references/rfcs/` for the protocol touched. State the informed opinion (`update-protocol.md` section 4)
after the first area is clear, not at the end.

## Question areas

1. **Requirement intent.** What outcome changes for the person, the service provider or the agency? Which
   FR row states the current intent, and does the change amend it, narrow it or add a row? Is this a
   product-owner decision or an implementation detail the documents leave open?
2. **Affected FR and protocol rows.** From the index: every `FR-…` row and every protocol row (`ONB-`, `CON-`,
   `ACC-`, `EXC-`, `INT-`, `REF-`, `ATT-`, `BIL-`, `DISC-`, `SAML-`, `UINF-`) the change touches, and the
   section that owns each. Which earlier decision (`Dnn`) does it reverse or refine, and what did that decision reject?
3. **RFC conformance.** Which specification governs the behavior (RFC 6749, 8693, 8707, 7662, 7009, 9449,
   7523, 8414, SAML Core/Profiles, NIST IR 8587)? Is the change inside the latitude the RFC leaves (record it in
   the decision entry) or a departure from its letter (record it as such, with the reason)? What does the
   reference application or harness need to change in step (`CLAUDE.md` section 5)?
4. **Existing-client behavior unchanged.** Is the new path keyed off the new records only (service provider
   approved for delegation, delegation scopes, bound tokens, grants)? Could an existing OIDC or SAML
   integration observe any difference, including on an error path? What spec proves it does not?
5. **Security posture.** Token binding, replay windows, single-use identifiers, rate limits, what an
   intercepted artifact can do, what the agency can verify; who must not be able to see or do the thing.
   Does the change alter a risk-based decision already recorded (for example the deferred DPoP nonce)?
6. **Data growth and performance.** New rows per sign-in, per exchange, per refresh; retention and
   cleanup; indexes; Redis keys and their TTLs; preloads in list pages (Bullet is on); cost at the
   token endpoint.
7. **Billing and fraud-signal effects.** Does it add, remove or re-attribute a billable event or an
   `sp_return_logs` row (follow the `login-billing` skill); does it change what the Attempts API delivers
   to the agency, to the service provider, and under which enrollment gate?
8. **Documentation impact.** Which sections, FR rows, protocol rows and Appendix C rows change; is a
   `(note: …)` line resolved; what does the owning section's As built need to say; does the README or
   `SKILL.md` diagram change.
9. **Owning branch and rebase cascade.** Which branch owns the behavior (Appendix A and B, `references/branches.md`);
   which branches sit above it and must rebase; does the change move code between branches; does the
   integration pointer still name the top; which worktrees must rerun specs.

## Closing the interview

1. Summarize the decisions in the developer's words.
2. Record them per `references/update-protocol.md` (section 16 entry, the owning section's rows amended in
   place, its Decisions list, As built when code lands); regenerate the indexes; sync the twins.
3. State explicitly which requirements changed and which skill context changed.
4. Leave genuinely open items in the owning section's How to review or in Appendix D.2, never as silent
   omissions.

## Data-change review

When the change adds or alters a table, column, durable log row, token storage, billing or reporting
evidence, an analytics event or an Attempts API schema, run the data team's decision procedure from
`.claude/skills/login-billing/references/data-change-review-guidelines.md` (requirement, durability,
table ownership, grain, sensitivity, event shape) and record that the data team was notified.
