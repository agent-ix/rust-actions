.PHONY: lint

# actionlint is required: YAML parsing alone passed a workflow that GitHub
# rejects (the `secrets` context in a step `if:`). Install it with
# `gh release download -R rhysd/actionlint -p '*linux_amd64.tar.gz'`.
lint:
	@command -v actionlint >/dev/null 2>&1 || { echo "actionlint is required: gh release download -R rhysd/actionlint -p '*linux_amd64.tar.gz'" >&2; exit 1; }
	actionlint
