# Reading order

The delegated-access work is described by three documents under `docs/` and one README. They are
written for different readers and answer different questions; none repeats another.

## The four files

| File | Answers | Written for | Structure |
|---|---|---|---|
| `docs/delegated-access-README.md` | How the three documents relate, in what order to read them, which branch carries what | Anyone arriving cold | Short: document map, branch diagram, matrix cross-references, skill paragraph |
| `docs/delegated-access-functional-requirements.md` (the FR document) | *What* the capability must do | Product owner, privacy and security reviewers, agency partners | One section per area (onboarding, consent UX, consent enforcement, tokens, verification, fraud signals, billing, operations, Department of State case, per-site keys); `FR-<area>-<n>` rows with MUST/SHOULD/MAY; "Questions to resolve"; Appendix A open decisions; Appendix B map to the companion; Appendix C the alternative pattern; Appendix D decisions log; Appendix E generated traceability matrix |
| `docs/delegated-access-requirements.md` (the companion) | *How* it is built, protocol by protocol | Maintainers of identity-idp and of the reference applications | Sections per protocol concern (§3 onboarding data model, §4 consent, §5 exchange, §6 introspection, §7 refresh, §8 fraud signals, §9 billing, §10 configuration, §11 security, §12 testing, §13 rollout, §14 reference apps and harness, §15 SAML, §16 third-party-initiated login, §17 per-site keys); rows `ONB-`, `CON-`, `ACC-`, `EXC-`, `INT-`, `REF-`, `ATT-`, `BIL-`, `DISC-`, `SAML-`, `TPL-` with Why/Where/How and code sketches; dated "Amendments" subsections; Appendix C DPoP; Appendix D repository mapping; Appendix E protocol decisions `Ennn`; Appendix F generated traceability matrix |
| `docs/delegated-access-implementation-plan.md` (the plan) | What the foundation branch had, what each feature adds, removes and why; what was decided and when | Implementers and reviewers of the branch stack | §1–§4 context and approach; §5 one subsection per feature (5.1–5.17) with Requirements line, additions, removals, findings, as-built blocks; §6 cross-cutting; §7 infrastructure and environment-specific pieces (7.5); §8 branch stack and review order with the generated 8.1 matrix; §9 decisions log `Dnn` |

The plan's 5.x "Requirements" lines are the join: each names the FR rows and companion rows the feature
serves, and the §8 table names the branch. The generated indexes in this skill are derived from those lines.

## Where to start

**A reader who wants the shape of the thing** (an hour): README; FR document §1–§2 and the Objective
paragraphs of §3–§10; companion §0–§2 (terms, actors, happy path, design decisions); plan §1, §3 and §4.
Then the branch diagram in plan §8.

**A reviewer of one branch**: plan §8 "Where to start", then the feature's 5.x section (Requirements line,
Add, Remove, Findings, As built), then each FR row the line names (FR document) and each companion row
(companion), then the diff against the branch below. `references/branch-context/<branch>.md` collects
this for each branch; `references/traceability.md` lists the rows per branch.

**An implementer changing or adding behavior**: `CLAUDE.md` first (conventions and the recording rules),
then the owning feature's 5.x section and its decisions in plan §9 (`references/decisions.md` indexes them),
then the companion rows for the protocol detail and the RFC digests under `references/rfcs/`. Before
editing, `references/update-protocol.md` and `references/interview.md`.

**A question about a single identifier**: `references/requirements-index.md` gives the document, section
and line; read that section, not the whole document.

## How the documents cite each other

- FR rows cite companion sections in Appendix B (section level) and companion rows in their text.
- Companion rows cite FR rows in amendment subsections and Appendix E rows cite plan decisions (`Dnn`).
- Plan 5.x sections cite FR rows, companion sections and rows, and decisions; plan §9 entries cite the
  FR and companion rows they change and the Appendix E rows that record them.
- The three generated matrices (plan 8.1, FR Appendix E, companion Appendix F) show the same join
  from each document's side; they are regenerated, never edited.
