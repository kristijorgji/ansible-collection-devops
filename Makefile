AL_VERSION := 0.79.54
ML_VERSION := v0.24.1
PRETTIER_IMAGE := tmknom/prettier:3.6.2
SHELLCHECK_IMAGE := koalaman/shellcheck-alpine:stable

.PHONY: lint lint-ansible lint-markdown lint-role-docs lint-no-nested-include-role lint-shell \
	fix fix-yaml fix-markdown verify-hooks test-role test

lint: lint-ansible lint-markdown lint-no-nested-include-role lint-role-docs lint-shell ## Run ansible-lint + markdownlint + role + shell checks

lint-ansible: ## Ansible + YAML via ansible-lint (embeds yamllint)
	@echo "################################################################################"
	@echo "# ansible-lint"
	@echo "################################################################################"
	@docker run --rm -v "$(PWD):/code" -w /code \
		pipelinecomponents/ansible-lint:$(AL_VERSION) \
		ansible-lint -v .

lint-markdown: ## Check markdown via markdownlint-cli2
	@echo "################################################################################"
	@echo "# markdownlint-cli2"
	@echo "################################################################################"
	@docker run --rm -v "$(PWD):/data" -w /data \
		davidanson/markdownlint-cli2:$(ML_VERSION) "**/*.md"

lint-no-nested-include-role: ## Ban include_role inside roles/*/tasks
	@echo "################################################################################"
	@echo "# check-no-nested-include-role"
	@echo "################################################################################"
	@./scripts/check-no-nested-include-role.sh

lint-role-docs: ## Require role README coverage for every tasks_from file
	@echo "################################################################################"
	@echo "# check-role-docs"
	@echo "################################################################################"
	@./scripts/check-role-docs.sh

lint-shell: ## ShellCheck scripts, git hooks, and role files/*.sh
	@echo "################################################################################"
	@echo "# shellcheck"
	@echo "################################################################################"
	@docker run --rm -v "$(PWD):/mnt" -w /mnt $(SHELLCHECK_IMAGE) \
		sh -c 'shellcheck scripts/*.sh git_hooks/pre-commit git_hooks/pre-commit.d/* roles/*/files/*.sh'

fix: fix-yaml fix-markdown ## Auto-fix YAML + markdown

fix-yaml: ## Prettier write on YAML
	@echo "################################################################################"
	@echo "# Prettier (YAML)"
	@echo "################################################################################"
	@docker run --rm \
		-v "$(PWD):/work" \
		-w /work \
		--user $$(id -u):$$(id -g) \
		$(PRETTIER_IMAGE) \
		--write "**/*.{yml,yaml}" \
		--ignore-path .gitignore

fix-markdown: ## Prettier + markdownlint --fix on *.md
	@echo "################################################################################"
	@echo "# Prettier (Markdown)"
	@echo "################################################################################"
	@docker run --rm \
		-v "$(PWD):/work" \
		-w /work \
		--user $$(id -u):$$(id -g) \
		$(PRETTIER_IMAGE) \
		--write "**/*.md" \
		--parser markdown \
		--ignore-path .gitignore
	@echo "################################################################################"
	@echo "# markdownlint-cli2 --fix"
	@echo "################################################################################"
	@docker run --rm -v "$(PWD):/data" -w /data \
		davidanson/markdownlint-cli2:$(ML_VERSION) --fix "**/*.md"

verify-hooks: ## Confirm core.hooksPath=./git_hooks
	@./scripts/check-hooks.sh

test-role: ## Molecule one scenario: make test-role ROLE=docker
	@if [ -z "$(ROLE)" ]; then echo "ERROR: set ROLE= (example: make test-role ROLE=docker)" >&2; exit 1; fi
	@./scripts/molecule.sh $(ROLE)

test: ## Molecule for every scenario under molecule/*/
	@found=0; \
	for d in molecule/*/; do \
		[ -d "$$d" ] || continue; \
		found=1; \
		./scripts/molecule.sh "$$(basename "$$d")" || exit 1; \
	done; \
	if [ "$$found" -eq 0 ]; then echo "ERROR: no molecule/*/ scenarios" >&2; exit 1; fi
