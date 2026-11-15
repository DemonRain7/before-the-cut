# Repository transition

**Status on November 15, 2026: the transfer is complete.** This checkout is the only active one; `fathom` is an archive until the student chooses to remove it. The student gave the transfer to the next agent to schedule; Claude did it after its own work in `fathom` stopped, with no other writer running.

What was done, step by step against the list below:

1. Read the legacy `HANDOFF.md` and the source. Claude was the only writer.
2. Copied `game/` (without `.godot/`), `agent_proxy/` (without `node_modules/`, `.dev.vars`, `.wrangler/`), `tools/art/` (without `out/` and `__pycache__/`), `tools/gd_static_check.py`, `tools/run_hidden.py`, `tools/run_proxy_integration.mjs`, `run-game.ps1`, and `DIRECTION.md` as `docs/development/direction.md`. Not copied: the one-off G1 and migration scripts (`prepare_g1_repository.py`, `revise_g1_*.py`, `build_g1_script_docx.py`, `migrate_autonomous_runtime.py`), the legacy handoff files, `g1/` media and deck sources, `exports/`, `history/`. Removed the three `.gitkeep` files.
3. `*.import` is no longer ignored: Godot's import settings and resource ids belong in the repository, only the `.godot/` cache does not. `agent_proxy/.dev.vars.example` holds empty placeholders only. `validation/` was copied locally for the evidence links and stays ignored.
4. `docs/g1/05` and `docs/g1/README.md` now record the submitted post. `docs/g1/01`-`04`, `06` and `07` are the submitted G1 versions and were not changed. Paths that named the `fathom` folder now name the repository root; `agent_proxy/README.md` links `docs/g1/`.
5. Imported `game/project.godot` fresh and ran every check here (results in `HANDOFF.md`; logs in the local `validation/2026-11-15/transfer-checks/`). A capture run on a hidden desktop drew 122 frames; the first 38, which include every text screen of the first patient, are pixel-identical to the frames drawn in `fathom`. No paid call was made.
6. Scanned the staged files for keys, tokens and personal details: none found.
7. Updated the root `HANDOFF.md`, `NEXT_AGENT_PROMPT.md`, `README.md`, `AGENTS.md` and `agent-config.json`.

The checklist below is kept as the record of the plan.

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
