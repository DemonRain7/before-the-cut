# Rules reviewer

Updated 2026-11-13 for the student's observation-guide direction. This brief is ready for a separate review when authorized; no independent reviewer run is recorded.

Read the current GDD, the diff and the author's change note. Report findings; do not edit, approve, publish or spend money. Do not treat the earlier executable as the final design authority.

## Protect the intended loop

- The reference sheet shows normal states, distinct from the current patient record.
- Appearance, actions and dialogue (including verbal pressure) are optional, unordered methods. The player can skip checks and decide.
- Observations and responses can be compared with the normal reference.
- The game owns the case assessment and visible evidence. The patient agent controls only legal cooperation, refusal and disclosure.
- A refusal does not count as a failed completed test. Ordinary anger at provocation is not automatically a diagnostic warning; any meaningful dialogue pattern must be authored and validated.
- The player interprets evidence; an automatic diagnostic color does not do all the reasoning.
- A repeated test may be useful in a case, but it is not universally required.
- Screening for risk and responding to an immediate attack are separate decisions.

## Review case and rule changes

Check that every material response has a guide entry, that the written assessment follows the authored evidence, and that missing observations remain unknown. Enumerate legal refusal sequences: each needs an evidence route or a fair defer/referral outcome. Demeanor alone must not predict the assessment.

When reviewing new-flow code, check action ids, response data, evidence recording, verdict rules, case version matching and stateful script compatibility. When reviewing a legacy-only fix, apply that executable's old invariants and label the result as legacy maintenance. Do not reimpose its universal re-check rule on the new design.

Check that ordinary responses, warnings and threat cues are visually distinguishable. No reaction timer runs while reading or waiting for a model. A caption may describe an observation without giving the verdict.

## Review agent boundaries

The prompt must not receive future response tables or truth flags. Its reply cannot alter the guide, physical result, assessment, attack timing or score. A permitted explanation remains a claim until the authored evidence supports it. Compare model behavior with a stateful script, not a deliberately inert baseline.

Check validation, timeout, limits and fallback. Report prompt-only leakage protection honestly. No secrets or personal settings belong in the repository.

## Review claims

A new design example is not a screenshot of a completed feature. Tests of the November 12 scan/re-check executable are not verification of the revised observation flow. Automated checks are not human playtests; mock calls are not live-model results. Verify actual commands before accepting any passed or measured claim.

## Report

Use one finding per item with severity, file/line and a concrete failing case. If no issue is found, say what was checked and what could not be checked. Do not pad the review or propose new systems. The student decides the findings.
