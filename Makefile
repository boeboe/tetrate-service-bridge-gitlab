# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help


up: gitlab-start repo-config ## Bring up full demo scenario
clean: gitlab-remove ## Bring down full demo scenario


.PHONY: prereq-check
prereq-check: ## Check if prerequisites are installed
	@/bin/sh -c './prereq.sh check'

.PHONY: prereq-install
prereq-install: ## Install prerequisites
	@/bin/sh -c './prereq.sh install'

###

.PHONY: gitlab-start
gitlab-start: prereq-check ## Start gitlab server and runner
	@/bin/sh -c './gitlab.sh start'

.PHONY: gitlab-remove
gitlab-remove: ## Remove gitlab server and runner
	@/bin/sh -c './gitlab.sh remove'

###

.PHONY: repo-config
repo-config: ## Configure gitlab groups, projects and repos
	@/bin/sh -c './repo.sh config-repos'
