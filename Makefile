AL_VERSION := latest
ML_VERSION := latest
PRETTIER_IMAGE := tmknom/prettier:latest

.PHONY: lint lint-ansible lint-markdown lint-role-docs lint-no-nested-include-role fix fix-yaml fix-markdown verify-hooks

lint: lint-ansible lint-markdown lint-no-nested-include-role lint-role-docs ## Run ansible-lint + markdownlint + role checks

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
