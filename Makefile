.PHONY: lint

# Parses every workflow with Python's yaml.safe_load (catches malformed
# YAML), then runs actionlint over them if it's installed on PATH (catches
# workflow-schema and shellcheck-level issues). actionlint is optional so
# `make lint` still works on a machine that hasn't installed it.
lint:
	@echo "==> YAML-parsing workflows"
	@python3 -c "\
import pathlib, sys, yaml; \
paths = sorted(pathlib.Path('.github/workflows').glob('*.yml')); \
assert paths, 'no workflow files found under .github/workflows'; \
[ (print(f'    {p}'), yaml.safe_load(p.read_text())) for p in paths ]"
	@if command -v actionlint >/dev/null 2>&1; then \
		echo "==> actionlint"; \
		actionlint; \
	else \
		echo "==> actionlint not installed; skipping"; \
	fi
