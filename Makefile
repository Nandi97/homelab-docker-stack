SHELL := /bin/bash

.PHONY: lint-compose

lint-compose:
	bash scripts/lint-compose.sh
