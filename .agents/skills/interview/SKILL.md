---
name: interview
description: Deep-dive interview skill for project plans and specs. Use when `/interview` is invoked or when the user wants to go deeper on a project plan, specification, or design document through structured questioning.
---

# Interview Skill

This skill conducts in-depth interviews about project plans, specs, and designs using the AskUserQuestion tool. It asks non-obvious, thought-provoking questions to surface hidden requirements, edge cases, and tradeoffs.

## When to Use

- User invokes `/interview` or `/interview <file>`
- User wants to "go deeper" on a plan or spec
- User has a rough spec and needs to flesh out details

## Workflow

### Step 1: Load the Spec

If a file path is provided as an argument, read that file. Otherwise, look for common spec files:
- `SPEC.md` in the current directory
- `spec.md` in the current directory
- Most recent `*.spec.md` file
- Most recent file in `plans/` directory

If no spec file is found, ask the user what they want to discuss.

### Step 2: Analyze and Identify Gaps

After reading the spec, analyze it for:
- Underspecified technical implementation details
- Missing error handling and edge cases
- UI/UX assumptions that need validation
- Security and privacy implications
- Performance and scalability concerns
- Integration points and dependencies
- Data model gaps
- State management complexity
- Testing strategy gaps
- Deployment and operational concerns

### Step 3: Conduct the Interview

Use the AskUserQuestion tool to ask probing questions. Follow these principles:

**Question Quality:**
- Ask non-obvious questions that reveal hidden complexity
- Avoid yes/no questions - prefer options or open-ended questions
- Ask about tradeoffs, not just preferences
- Surface implicit assumptions
- Probe edge cases and failure modes

**Question Categories to Cover:**

1. **Technical Architecture**
   - "How should X behave when Y fails?"
   - "What's the expected latency budget for this operation?"
   - "Should this be synchronous or async?"

2. **Data & State**
   - "What happens to this data after 30 days?"
   - "How do we handle conflicting updates?"
   - "What's the source of truth when X and Y disagree?"

3. **User Experience**
   - "What should the user see while this is loading?"
   - "How do we communicate this error without jargon?"
   - "What's the mobile experience for this?"

4. **Edge Cases**
   - "What if the user has 10,000 of these?"
   - "What happens during a network partition?"
   - "How do we handle partial failures?"

5. **Security & Privacy**
   - "Who should NOT be able to see this?"
   - "What happens when an employee leaves?"
   - "How long do we retain this data?"

6. **Operations**
   - "How do we know if this is working correctly?"
   - "What's the rollback strategy?"
   - "How do we debug this in production?"

**Interview Flow:**
- Ask 1-2 questions at a time using AskUserQuestion
- Provide thoughtful options based on the spec context
- After each answer, note the decision and identify follow-up questions
- Continue until all major areas are covered
- Aim for 8-15 total questions depending on spec complexity

### Step 4: Update the Spec

After the interview is complete:

1. Summarize the decisions made
2. Update the spec file with:
   - New requirements discovered
   - Clarified behaviors
   - Documented tradeoffs and rationale
   - Edge cases and error handling
3. Add a "Decisions Log" section if one doesn't exist
4. Preserve the original spec structure while adding detail

### Output Format

When updating the spec, add sections like:

```markdown
## Decisions Log

### [Date] Interview Session

**Technical Decisions:**
- Decision 1: [choice made] - Rationale: [why]
- Decision 2: [choice made] - Rationale: [why]

**Edge Cases Addressed:**
- [scenario]: [how we handle it]

**Open Questions:**
- [any remaining questions for later]
```

## Example Questions

Given a spec about "user authentication with SSO":

**Instead of:** "Should we support SSO?" (obvious, yes/no)
**Ask:** "When SSO login fails but local auth works, should we: (A) Fall back silently to local auth, (B) Show SSO error and offer local auth, (C) Block login entirely until SSO is fixed?"

**Instead of:** "What about session timeout?" (vague)
**Ask:** "For session timeout, what's the right tradeoff: (A) 15min - more secure but users re-auth often, (B) 8hrs - covers a workday, (C) 30 days with re-auth for sensitive actions?"

## Completion Criteria

The interview is complete when:
- All major areas (technical, UX, edge cases, security, ops) have been covered
- The user indicates they're satisfied
- No new questions are surfacing

At completion, write the updated spec and summarize what was decided.
