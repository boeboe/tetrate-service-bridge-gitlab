# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

.PHONY: prereq-check
prereq-check: ## Check if prerequisites are installed
	@/bin/sh -c './prereq.sh check'

.PHONY: prereq-install
prereq-install: ## Install prerequisites
	@/bin/sh -c './prereq.sh install'

.PHONY: gitlab-start
gitlab-start: ## Start gitlab cicd server
	@/bin/sh -c './gitlab.sh start'

.PHONY: gitlab-stop
gitlab-stop: ## Stop gitlab cicd server
	@/bin/sh -c './gitlab.sh stop'

.PHONY: gitlab-remove
gitlab-remove: ## Remove gitlab cicd server
	@/bin/sh -c './gitlab.sh remove'


.PHONY: gitlab-runner-start
gitlab-runner-start: ## Start gitlab-runner
	@/bin/sh -c './gitlab-runner.sh start'

.PHONY: gitlab-runner-stop
gitlab-runner-stop: ## Stop gitlab-runner
	@/bin/sh -c './gitlab-runner.sh stop'

.PHONY: gitlab-runner-remove
gitlab-runner-remove: ## Remove gitlab-runner
	@/bin/sh -c './gitlab-runner.sh remove'


.PHONY: repo-sync-images
repo-sync-images: ## Sync TSB images into gitlab docker repo
	@/bin/sh -c './repo.sh sync-images'

.PHONY: repo-config
repo-config: ## Configure gitlab groups, projects and repos
	@/bin/sh -c './repo.sh config-repos'
