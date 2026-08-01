# Windows Shell and Search Tool Compatibility

## Problem

The local runtime executes every shell command through `sh`, even on native Windows. Windows command names installed only as batch launchers (for example `fvm.bat`) are therefore not resolved by their extensionless names, and Windows path syntax is interpreted as shell escaping. After command resolution, root-level FVM script invocations also have no project configuration because `.fvmrc` exists only in the child packages. The workspace grep handler applies file globs only to the full relative path and does not expand brace alternatives, so common filters such as `*.dart` and `*.{dart,ts}` incorrectly return no files below nested directories.

## Scope

- Select the native command interpreter on Windows while retaining `sh` on Unix-like hosts.
- Add root-level FVM configuration for Dart scripts launched from the repository root.
- Keep runtime environment guidance consistent with the interpreter actually used.
- Make grep file globs match both relative paths and basenames.
- Expand brace alternatives in grep file globs.
- Add focused regression tests for shell execution and grep filtering.
- Document the resulting runtime contracts.

## Definition of Done

- An extensionless Windows batch command can execute through `ShellExecuteTool`.
- Windows-style relative paths are accepted by the Windows command interpreter.
- Existing Unix shell behavior remains unchanged.
- `search_grep` finds nested files with `*.dart` and brace filters such as `*.{dart,ts}`.
- Focused tests and static analysis pass.
