# Repository transition

Status on November 14, 2026: repository naming and documentation organization are ready; source transfer is deferred because the student confirmed that Claude/Fable is still writing in the legacy workspace.

## One project, one eventual working checkout

The ongoing remote is https://github.com/DemonRain7/before-the-cut, renamed from `before-the-cut-g1` without replacing its history. The new local checkout is the sibling `before-the-cut` directory. The active implementation remains in `fathom` until its current writer stops.

Do not move or rename the active directory, edit its game files, or tell a running agent to switch paths mid-operation. The preliminary local source snapshot is only a backup. It must not overwrite newer work.

## Transfer after the writer stops

1. Read the latest legacy `HANDOFF.md`, inspect the actual source and record the current status. Confirm there are no active writers before copying; do not infer that silence means completion.
2. Copy the latest `game/`, `agent_proxy/`, `tools/art/`, reusable verification tools and root launcher into the matching destinations here. Review asset provenance. Keep game/proxy directory relationships intact. Remove placeholder `.gitkeep` files if convenient.
3. Exclude `.git/`, `.claude/`, `.godot/`, `node_modules/`, `.wrangler/`, `__pycache__/`, credentials, generated imports, art previews, build exports, raw logs, private course screenshots and unrelated archives. Copy credential examples only after confirming that all keys are empty placeholders. Never copy the legacy `.git` over this checkout's history.
4. Reconcile G1 documents if the active writer changed them. Keep reviewed content and change references from root `g1/` to `docs/g1/`. Check the game/proxy READMEs, agent manifest, generator paths, screenshot-output path and launch commands. Put generated screenshots under ignored `artifacts/`, not the published course-docs folder.
5. Open or import `game/project.godot` from this checkout. Run the current game and proxy checks, including local mock integration where applicable; inspect the actual revised gameplay. Record failures honestly if they predate the move. Do not make paid model calls as part of relocation testing.
6. Review the staged file list and scan for secrets and private material. Commit without AI attribution and push normally to `main`; no force push is needed. Verify that both the code and required G1 documents can be accessed remotely.
7. Update root `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, README and the manifest with the verified source revision, launch commands and limitations. Mark the transfer complete and make `before-the-cut` the sole active checkout. Leave `fathom` as an archive until the student chooses to remove it.

## Ownership of each directory

| Destination | Contents |
|---|---|
| `game/` | Godot project, scenes, scripts, fixed cases, original game assets and game tests |
| `agent_proxy/` | Patient-agent API, provider adapters, validation and proxy tests |
| `agent_team/` | Production-agent skills and reviewer artifacts |
| `docs/g1/` | G1 design, configuration, plan, script and supporting records |
| `docs/development/` | Current implementation notes, art provenance and decisions |
| `tools/` | Reusable local utilities and asset generators |
| `artifacts/`, `validation/`, `exports/` | Local generated outputs, excluded from Git |

The older `fathom/exports/g1-repository` checkout and `prepare_g1_repository.py` served the original docs-only publication. Do not run that export pipeline against this repository: it would recreate obsolete paths and status text.

The former `g1/` paths in the remote repository contain forwarding documents so previously shared required-document links remain useful. New course posts should use the renamed repository and `docs/g1/` paths directly.
