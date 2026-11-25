These are Stratix's original CI workflows, parked here so they don't run. Anyroom runs its own
`build.yml` (compile check on every push) and `release.yml` (manual sign and upload) instead, so
the repo doesn't spend macOS runner time on upstream's UI, visual-regression and hardware suites.
Move a file back into `.github/workflows/` to turn it on again.
