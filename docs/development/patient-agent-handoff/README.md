# Patient agent: handoff package

November 21, 2026. Written by Claude (Fable) at the student's request: design how the patient AI
becomes an agent in the game, do not build it, and hand it to Codex.

**Status: a design and a work plan. Nothing in this folder is built. The student has not
reviewed it. No model was called and nothing was deployed to write it.**

## Files

| File | What it is | Who reads it |
| --- | --- | --- |
| `KICKOFF.md` | The prompt for Codex. Since the afternoon of November 21: everything that is left, in one run, with the defaults the student's message can change | Codex; the student starts it |
| `01-design.md` | What exists, what is missing, and the design: what the player gets, the agent's loop, the gates, protocol 4, evaluation, what stays out | Codex in full; the student, sections 1, 2 and 13 |
| `02-phases.md` | Ground rules, what needs the student's yes, decisions D1 to D9 with defaults, and phases P0 to P3 with what "done" means | Codex in full; the student, sections 2, 3 and 8 |

## The design in ten lines

1. The patient AI exists as a voice that answers: off by default, never deployed, last tried
   live on November 15, and when on it makes talk a cheaper ASK that the closing report cannot
   grade.
2. The model decides what the patient says, and whether the patient goes along with a first
   request for a tool. The game decides what is true, what counts as a reading, what it costs
   and what is scored.
3. The model never learns "drifting" or "steady". It is told tonight's SPEECH or TEMPER sign
   only from the moment the player has paid for an action that shows that line, so talk cannot
   leak a sign the model does not hold.
4. A typed or spoken line that asks one of the patient's questions is that question: the same
   lamps, the same proof. A small second model call reads what the line is about.
5. Anything else is small talk: free, and it leaves no note. After a question is paid for, the
   player can keep digging in their own words at no cost, and the patient holds tonight's
   manner. That is what the agent adds that the scripted patient cannot.
6. PRESS can carry the player's own words. Words alone are never pressure, and nothing costly
   is read into what the player types.
7. Where the case or the screen has promised something (a sealed tool, insisting, CALM, a
   question dodged once), the game keeps it and tells the model which way it goes.
8. Later the patient may speak first: after a reading, in a silence, on sitting down. It
   changes nothing in the rules.
9. Every call has a deadline and a scripted twin with the same effect on the rules, and the
   screen labels a fallback.
10. Whether the model may write the answers that are graded is decided by a measurement (E2),
    and whether the agent helps at all by a human comparison (E6). Until then the graded line
    stays authored.

## Phases

- **P0, reachable and proven** (for Monday November 23): a Worker that can be deployed, session
  isolation and the forced-timeout fallback shown, one command and one menu row to turn the
  patient AI on. No rule changes. Then stop and ask for the yes to deploy and to a small paid
  check.
- **P1, one set of rules:** gates, intent, the moves the game settles, PRESS with words, the
  closing report. Needs D1, D2 and D3.
- **P2, a turn of its own:** the beats.
- **P3, evaluation:** E1 to E5 with a live model, each with the student's yes; E6 with people.

## How this relates to the play-logic review

`docs/development/play-logic-review.md` asks whether every tool earns its place. Its section 8
finds the patient AI is decoration today and a loophole when on, and its fix 4 is this
package's P1. Its other proposals (the rule A, B or C, the second PRESS, four more fixes) are
separate work that waits for the student's pick. P0 collides with none of it.

## Where the facts come from

- Code and data: read on November 21 in the working tree (commit `361baa7` plus that day's
  uncommitted changes). Counts such as "51 of 60 combinations show the line" and "6 of 29 open
  tools are refused once" were computed from the case files that day.
- Cloudflare: its documentation as read on November 21. To be checked again by whoever deploys.
- Costs: one small live run on November 15. An estimate, not a quote.
- Nobody has played the current build, and no part of this design has met a model or a person.
