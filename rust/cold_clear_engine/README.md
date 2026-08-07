# cold_clear_engine

This directory vendors the core decision-related crates from cold-clear into the tetris-tower project so they can be used as an internal planner engine.

## Structure

- `libtetris`: board and piece simulation logic
- `bot`: the actual decision engine
- `opening-book`: optional opening book support
- `c-api`: official cold-clear C ABI (`cold_clear.dll` / `coldclear.h`)
- `src/engine_adapter.rs`: wrapper interface for the decision engine

## Build C Library

Use PowerShell:

```powershell
Set-Location "<project>/rust/cold_clear_engine"
.\build_c_api.ps1
```

Expected outputs:

- `rust/cold_clear_engine/native/cold_clear.dll`
- `rust/cold_clear_engine/native/cold_clear.lib`
- `rust/cold_clear_engine/native/coldclear.h`

Godot bridge script checks `res://rust/cold_clear_engine/native/cold_clear.dll` first.
