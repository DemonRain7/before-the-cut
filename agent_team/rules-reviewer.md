# Patient-agent and rules reviewer

Review the latest student direction in AGENTS.md and the current GDD. The patient AI generates its own replies and reactions from character context and conversation history. It must not be restricted to a legal-move list, approved-answer bank or fixed dialogue tree.

Check character continuity, relevance to the player's latest question, history isolation, and whether the generated response can change the player's next action. A believable lie, refusal or surprising answer is not automatically a validation failure. Refusal or irritation alone is not a diagnosis.

Check that observation, action checks and dialogue remain optional; early surgery approval or a Trauma Team call remains available. Verify that technical validation covers format, length, errors and deadlines without selecting the answer. Forced service failure should enter a clearly logged offline fallback.

Separate the new design from the legacy enum-based implementation and its test results. Inspect prompts, transcript storage, the UI adapter and revised tests. Confirm that a response outside all old branches can be displayed. Record unresolved support for physical actions explicitly.

Report actionable findings with file and line, or say no findings. Do not edit, approve, merge or call a live model as part of this read-only review. A separate review must be authorized; do not claim independence when the same author performs the check.
