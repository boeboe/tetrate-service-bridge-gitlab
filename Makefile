# HELP
# This will output the help for each task
# thanks to https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help

help: ## This help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z0-9_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

.PHONY: gitlab-start
gitlab-start: ## Start gitlab cicd server
	@/bin/sh -c './gitlab.sh start'

.PHONY: gitlab-config
gitlab-config: ## Configure gitlab cicd server
	@/bin/sh -c './gitlab.sh config'

.PHONY: gitlab-sync-images
gitlab-sync-images: ## Sync TSB images into gitlab docker repo
	@/bin/sh -c './gitlab.sh sync-images'

.PHONY: gitlab-stop
gitlab-stop: ## Stop gitlab cicd server
	@/bin/sh -c './gitlab.sh stop'

.PHONY: gitlab-remove
gitlab-remove: ## Remove gitlab cicd server
	@/bin/sh -c './gitlab.sh remove'

