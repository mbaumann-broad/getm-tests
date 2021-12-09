ifeq ($(shell which miniwdl),)
$(error Please install requirements using "pip install -r requirements.txt")
endif

# MiniWDL uses shellcheck for improved WDL linting. This check can be removed if folks dislike it.
ifeq ($(shell which shellcheck),)
$(error Please install shellcheck using "apt-get install shellcheck" or "brew install shellcheck")
endif

test: plugin
	miniwdl run --verbose drs_downloader_to_getm.wdl --input test/input/inputs.json

plugin:
	pip install --upgrade --no-cache-dir scripts/inject_gs_credentials

clean:
	git clean -dfX

.PHONY: test plugin
