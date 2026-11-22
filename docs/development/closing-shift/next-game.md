# What would make someone run another night?

Design notes, November 22, 2026. The owner has deferred the two-player version. The current implementation assignment is the [closing animation remake](claude-prompt.md). The experiments below are available for a later prototype.

## The owner's direction for a future two-player shift

One player screens arrivals and decides who enters. The other operates on the admitted patient, working close to the affected implant. The doctor handles and replaces that specific component. A short QTE can give weight to a moment such as a wrist coupling seating in its socket. Between patients, preparing a part or testing a return could give intake information for its current decision.

The doctor chooses where to look. During hand or port work they can look up from the part to check the patient's face, then return to the component. During work on the face, that frightening possibility is already within arm's reach. The expression or implant can suddenly change while the tool is engaged, including between timed inputs. For a future test, try one wrist case and one face case and watch when the doctor voluntarily looks up.

## Single player

Today a player reads a file, looks for discrepancies and admits or removes a visitor. That is close to the doorman's decision in *That's Not My Neighbor*. The most distinctive thing we already have happens after admission. The person has somewhere to go, a machine they need and someone who will bear the consequences if we get the repair wrong. Give the player a hand in that repair. [Nacho Sama's description of the doorman's job](https://nachogames.itch.io/thats-not-my-neighbor)

| Possible direction | What the player actually does | Reason to replay | First risk to test |
| --- | --- | --- | --- |
| **One workbench shared by the queue** | Choose where a scarce stabilizer goes. Fit it, run the repaired implant under load, then stop or release it. | A different order of arrivals changes whom the same part can help. A returning patient shows whether yesterday's repair held. | A routine waveform puzzle could overwhelm the human decision. Give each test a visible consequence. |
| **Trace a bad shipment** | Keep a removed part from an appointment, compare its serial fragment with the next failure, decide which pallet to recall. | Two patients with opposite behavior can share a supplier. A recall may protect the district and cancel innocent patients' repairs. | A mystery that resolves from reading alone. Have the player move a real suspect part onto a bench and replay its fault. |
| **Run an underground clinic with witnesses** | Take a courier's deal, redirect a part to a neighbor or testify. See who comes back as a witness or refuses to speak for you. | Different promises create different witnesses, routes and obligations on the next night. | A menu of allegiances. Make the commitment with an object already on the desk. |

For a later solo workbench experiment, one counterfeit shipment could make two appointments interact and one courier could put a price on the choice. Give the player one object to act on at a time. The normal object here is an implant cartridge. The stamp screen and clinic radio already provide places to introduce it.

### Ninety seconds without generated dialogue

| Time | What happens |
| --- | --- |
| 0–20 s | Rook puts his LOADER hand on the bar. It relaxes late. His tow slip accounts for the apparent discrepancy on his form. The service tray contains one certified limiter and one Lantern part with a filed serial. The radio says the next patient needs the same coupling. |
| 20–45 s | The player routes the certified limiter to Rook and runs one load pulse. The opening and closing traces now line up. The player can see exactly what that part bought. Rook goes back to work. |
| 45–70 s | The next patient's trace shows the same delayed release. The courier offers an unlicensed spare in exchange for leaving the lot off the recall list. Accepting gets the next patient a working hand today and leaves the suspect batch in circulation. Quarantining the lot keeps it out of the market and postpones a person's repair. |
| 70–90 s | On the closing camera Rook lowers a crate or is still waiting at the docks, according to the first decision. The next shift opens with the recipient of the spare or the person who lost a shift waiting for parts. They bring evidence the player can use. |

A correct reading of the patient's condition and a responsible allocation of the part can pull in different directions. The contact becomes a person with access to stock, a witness and someone owed a favor. The immediate reward is a specific treatment the player otherwise could not offer. For a fair first version, make the hidden truth, batch fault and available inventory independent. Show a consequence of each choice by the following shift. Keep the existing two-row diagnosis reliable wherever the old desk rules apply.

## Two players working at once

Use a shared clinic with two stations and one tray in transit. The intake doctor sees the patient's unprompted gesture, the registration slip and what the patient is trying to return to. The theatre doctor can bench-test the removed part, read the lot record and decide whether the one remaining certified part is a good fit. Either sends a short ping with a patient name and a marked finding. Voice chat is optional. The film lets both players see what happened to their decisions.

| Time in a two-case shift | Intake station | Theatre station | Decision the other player can change |
| --- | --- | --- | --- |
| 0–20 s | Examine Rook's delayed release. | Start with yesterday's returned LOADER part already on the bench. Reproduce a sticking return and read its lot. | Theatre can request the sleeve serial before intake spends its last lamp. |
| 20–45 s | Read a courier's slip while Rook's tray crosses the hatch. | Fit Rook's cartridge and vary the load. The borrowed part locks at the top of its range. | Intake can disclose the filed serial. Theatre can reserve the certified part or ask intake to hold the next case. |
| 45–75 s | The courier needs a decision. Hold a slot, accept the spare or call the crew. | Choose whether to release Rook, fit the spare at reduced range or return the part through the hatch. | One shared part and one waiting berth make both choices consequential. |
| 75–90 s | Route the final case or report the lot. | Finish the repair or seal the batch so the next shift cannot draw it. | The closing cameras show who got home and which lot stayed in circulation. |

The overlapping tasks borrow the shared work of preparation and service from *Overcooked*. The two different views borrow the need to describe an observation from *Keep Talking and Nobody Explodes*. Test whether one factual exchange changes a treatment someone was about to choose. [Team17 on Overcooked](https://www.team17.com/games/overcooked) · [Steel Crate Games on asymmetric information](https://keeptalkinggame.com/)

**Quiet and overloaded stretches.** Start the theatre with one consequential returned part. If intake sends everyone away, theatre can trace that lot, send a recall or return a tested spare. Each creates a new option at intake. When the theatre queue fills, display the remaining berth to both players. Intake can hold the chair or redirect the next delivery. When intake clears its last visitor, let that player help test the last part. A task that would have no downstream effect ends immediately. Both players can agree to close early when neither station has work.

**One player, two seats or a dropped connection.** The solo prototype pauses the unattended station when the player swaps screens. Two local players can each operate one station. Test that pairing before investing in networking. In an online prototype the host owns case IDs, the tray, the pressure roll and settlement. A reconnecting player receives the current tray and work state. A repeated button packet acknowledges the original action once. A remaining player can take the other station and finish the shift. Pass only the observed finding to the other station and give the case a single accountable owner for each decision.

**Other multiplayer directions.** Two doctors working the same patient could play a one-screen rhythm test where one adjusts the load and the other judges release. It is cheaper to prototype and may feel repetitive across a whole night. A player secretly acting as a courier could bluff about the lot and trade favors across nights. That requires a group willing to accuse one another, plus a complete job for that player after discovery. Try the two-doctor pair first because it serves the investigation and surgery in both solo and co-op.

## An inexpensive decision test

Build one room, one tray, two patients, a certified limiter and a suspect spare. Stage one night with no admissions and one with both admitted. Use fixed lines, identical case seeds and a persistent next-morning shot. Ask six new solo players and three pairs to try two short shifts. Use the following targets for that first outside test.

- Count voluntary second shifts and ask what they wanted to try differently. Keep developing the workbench if at least four of six solo players replay and can point to a repair or allocation decision that changed a person's outcome.
- Time a period of forced waiting from the moment a station has no meaningful action, excluding a player's deliberate pause to watch or speak. Aim for under ten consecutive seconds even in the all-refused branch. Rework the handoff if the theatre player repeatedly waits for intake to admit someone.
- Observe a decision changed by a message in all three pairs and ask each partner to explain the other's contribution. If the winning habit is to read one code aloud, move the useful information into the moving mechanism and retest.
- Ask who the courier helped and what it cost. A response that mentions only credits sends the contact design back for another pass.
