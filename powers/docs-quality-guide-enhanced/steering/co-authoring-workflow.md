# Doc Co-Authoring Workflow

This guide provides a structured workflow for collaborative document creation.
Use this when creating important documents that need to work well for multiple
readers.

## When to Use This Workflow

**Trigger conditions:**

- User mentions writing documentation: "write a doc", "draft a proposal",

  "create a spec"

- User mentions specific doc types: "PRD", "design doc", "decision doc", "RFC"
- User seems to be starting a substantial writing task

**Initial offer:** Offer the user a structured workflow for co-authoring the
document. Explain the three stages:

1. **Context Gathering**: User provides all relevant context while you ask

   clarifying questions

2. **Refinement & Structure**: Iteratively build each section through

   brainstorming and editing

3. **Reader Testing**: Test the doc with a fresh model (no context) to catch

   blind spots

Explain that this approach helps ensure the doc works well when others read
it. Ask if they want to try this workflow or prefer to work freeform.

## Stage 1: Context Gathering

**Goal:** Close the gap between what the user knows and what you know,
enabling smart guidance later.

### Initial Questions

Start by asking the user for meta-context about the document:

1. What type of document is this? (e.g., technical spec, decision doc,

   proposal)

2. Who's the primary audience?
3. What's the desired impact when someone reads this?
4. Is there a template or specific format to follow?
5. Any other constraints or context to know?
6. Does this doc require brAInwav brand styling or documentation signature?

Tell them they can answer in shorthand or dump information in any format that
works for them.

### Info Dumping

Once initial questions are answered, encourage the user to dump all the
context they have:

- Background on the project/problem
- Related team discussions or shared documents
- Why alternative solutions aren't being used
- Organizational context (team dynamics, past incidents, politics)
- Timeline pressures or constraints
- Technical architecture or dependencies
- Stakeholder concerns

Tell them not to worry about organizing it - just get it all out.

### Asking Clarifying Questions

When user signals they've done their initial dump, ask clarifying questions to
ensure understanding:

Generate 5-10 numbered questions based on gaps in the context.

Inform them they can use shorthand to answer (e.g., "1: yes, 2: see #channel,
3: no because backwards compat").

**Exit condition:** Enough context has been gathered when you can ask about
edge cases and trade-offs without needing basics explained.

## Stage 2: Refinement & Structure

**Goal:** Build the document section by section through brainstorming,
curation, and iterative refinement.

### Instructions to User

Explain that the document will be built section by section:

1. Clarifying questions will be asked about what to include
2. 5-20 options will be brainstormed
3. User says what to keep/remove/combine
4. The section will be drafted
5. It will be refined through surgical edits

Start with the section that has the most unknowns (the core
decision/proposal), then work through the rest.

### Section Ordering

**If the document structure is clear:** Ask which section they'd like to start
with.

**If user doesn't know what sections they need:** Based on the document type,
suggest 3-5 sections appropriate for the doc type:

| Doc type |
| --- |
| Technical spec |
| Decision doc |
| README |
| Runbook |
| API doc |
| Proposal/PRD |

### For Each Section

#### Step 1: Clarifying Questions

Ask 5-10 clarifying questions about what should be included in the section.

#### Step 2: Brainstorming

Brainstorm 5-20 things that might be included, looking for:

- Context shared that might have been forgotten
- Angles or considerations not yet mentioned

#### Step 3: Curation

Ask which points should be kept, removed, or combined. Request brief
justifications.

Examples:

- "Keep 1,4,7,9"
- "Remove 3 (duplicates 1)"
- "Remove 6 (audience already knows this)"
- "Combine 11 and 12"

#### Step 4: Gap Check

Ask if there's anything important missing for the section.

#### Step 5: Drafting

Draft the section based on what they've selected.

#### Step 6: Iterative Refinement

As user provides feedback:

- Use `str_replace` to make edits (never reprint the whole doc)
- Continue iterating until user is satisfied with the section

### Quality Checking

After 3 consecutive iterations with no major changes, ask if anything can be
removed without losing important information.

### Near Completion

As approaching completion (80%+ of sections done), re-read the entire document
and check for:

- Flow and consistency across sections
- Redundancy or contradictions
- Anything that feels like filler or generic content
- Whether every sentence carries weight

## Stage 3: Reader Testing

**Goal:** Test the document with a fresh model (no context bleed) to verify it
works for readers.

### Testing Rubric

**Question template (pick 5-10):**

1. What is this doc for, and who is it for?
2. What are the prerequisites or assumptions?
3. What is the primary workflow or decision?
4. What are the exact steps to achieve the outcome?
5. How do I verify success?
6. What are the failure modes and how do I recover?
7. What are the risks, constraints, or non-goals?
8. Who owns this, and how do I get help?

**Pass criteria:**

- At least 80% of answers are correct and complete
- No critical misunderstandings on safety, data loss, security, or rollback
- Ambiguities are localized to one section or less

### Testing Process

#### Step 1: Predict Reader Questions

Generate 5-10 questions that readers would realistically ask.

#### Step 2: Test with Sub-Agent (if available)

For each question, invoke a sub-agent with just the document content and the
question. Summarize what the reader got right/wrong for each question.

#### Step 3: Run Extra Checks

Invoke sub-agent to check for ambiguity, false assumptions, contradictions.

#### Step 4: Report and Fix

If issues found:

- Report that the reader struggled with specific issues
- List the specific issues
- Loop back to refinement for problematic sections

### Manual Testing (if no sub-agents)

If sub-agents aren't available, provide testing instructions:

1. Open a fresh conversation
2. Paste the document content
3. Ask the generated questions
4. Check if answers are correct and complete

## Final Review

When Reader Testing passes:

1. Recommend they do a final read-through themselves
2. Suggest double-checking any facts, links, or technical details
3. Ask them to verify it achieves the impact they wanted

## Tips for Effective Guidance

**Tone:**

- Be direct and procedural
- Explain rationale briefly when it affects user behavior
- Don't try to "sell" the approach - just execute it

**Handling Deviations:**

- If user wants to skip a stage: Ask if they want to skip this and write

  freeform

- If user seems frustrated: Acknowledge this is taking longer than expected
- Always give user agency to adjust the process

**Quality over Speed:**

- Don't rush through stages
- Each iteration should make meaningful improvements
- The goal is a document that actually works for readers
