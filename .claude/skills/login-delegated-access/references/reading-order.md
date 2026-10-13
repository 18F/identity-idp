# Reading order

The delegated-access work is described by one document, `docs/delegated-access-functional-requirements.md`,
with `docs/delegated-access-README.md` as its short front door. The implementation plan that preceded it is
kept as a historical file and is not part of the reading order.

## The document

| Part | Answers | Structure |
|---|---|---|
| Front matter | What exists today, how to read the document, the branch stack, the conventions (identifiers, current state only, fictitious names, vocabulary, requirement language, standards) | Status paragraph, "How to read this document", "The branch stack", "Conventions" |
| Sections 1 to 14 | For one branch: what it delivers and why, what it must do, how it is built on the wire, what was built, what was decided, how to review it | One section per feature branch in stack order, heading `# N. \`delegated-access-<name>\`: <title>`, each with Objective, Functional requirements (`FR-<area>-<n>` rows), Protocol rows (`ONB-`, `CON-`, `ACC-`, `EXC-`, `REF-`, `INT-`, `SAML-`, `DISC-`, `BIL-`, `ATT-`, `UINF-`), As built, Decisions (one line per `Dnn`), How to review |
| Section 15 | The base branch and the work outside this repository | 15.1 document-image sharing for a direct service provider (kept on the base), 15.2 third-party-initiated login (reference applications), 15.3 the reference applications and the end-to-end harness, 15.4 the configuration repository, 15.5 and 15.6 the two designs recorded and not built, 15.7 encrypted user-information enhancements documented for later, 15.8 the FR rows no branch owns |
| Section 16 | Why each decision was taken and what was rejected | Dated `##` subsections with numbered `**Dnn — Title.**` entries, D1 upward |
| Appendix A | Where any identifier lives | Generated traceability matrix: FR row → section and branch → protocol rows → decisions; protocol rows by prefix; rows owned by section 15; foundation items |
| Appendix B | How the stack is reviewed and merged | The stack, how it is used, where to start a review, the pull request procedure |
| Appendix C | What is local-only or sandbox-only | One table, plus what is not environment-specific although it looks so |
| Appendix D | The performance review and the open items with their owners | D.1 to D.4 |
| Appendix E | What the foundation branch was and what the stack kept, replaced and removed | E.1 to E.5 |
| Appendix F | Terms | One table |

Every row states the requirement as it stands today and cites the decision that last changed it as `(Dnn)`;
there are no amendment trails. The generated indexes in this skill are derived from the section headings,
the row tables and the Decisions lists.

## Where to start

**A reader who wants the shape of the thing** (an hour): the README; the front matter; the Objective of each
of sections 1 to 14; Appendix E.1 and E.2 for where the code came from; the branch diagram in Appendix B.

**A reviewer of one branch**: Appendix A to find the rows, then the branch's section in full (Objective, the
two row tables, As built, Decisions, How to review), then the diff against the branch below.
`references/branch-context/<branch>.md` collects the same for each branch; `references/traceability.md`
lists the rows per section.

**An implementer changing or adding behavior**: `CLAUDE.md` first (conventions and the recording rules),
then the owning section and its decisions in section 16 (`references/decisions.md` indexes them), then the
RFC digests under `references/rfcs/`. Before editing, `references/update-protocol.md` and
`references/interview.md`.

**A question about a single identifier**: `references/requirements-index.md` gives the section, the branch
and the line; read that section, not the whole document.

## The historical plan

`docs/delegated-access-implementation-plan.md` records how each feature was planned against the foundation
branch, its findings and its dated amendment trails, through 2026-10-13. It is not maintained; its old
section numbers (5.x features, section 8 stack, section 9 decisions, 7.5 environment pieces) appear in
older commit messages and in the "Historical plan section" line at the top of each branch section. When it
disagrees with the document, the document is right. Nothing in it is regenerated.
