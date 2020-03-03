# meta
USERNAME     := kzmake
REPONAME     := nginx-forward-proxy
SEMVER_REGEX ?= ^([0-9]+\.[0-9]+\.[0-9]+)-?([0-9A-Za-z-]+[\.[0-9A-Za-z-]+]*)?\+?([0-9A-Za-z-]+)?
VERSION_CORE ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed -E -e 's/^v//' -e 's/$(SEMVER_REGEX)/\1/')
PRE_RELEASE  ?= $(shell git describe --tags --abbrev=0 2>/dev/null | sed -E -e 's/^v//' -e 's/$(SEMVER_REGEX)/\2/')
BUILD        ?=
VERSION      ?= $(if $(VERSION_CORE),$(VERSION_CORE),0.0.0)$(if $(PRE_RELEASE),-$(PRE_RELEASE),)$(if $(BUILD),+$(BUILD),)
IMAGETAG     := $(USERNAME)/$(REPONAME):$(VERSION)

# docker params
CNTNAME   := $(USERNAME)_$(REPONAME)
SHCOMMAND := /bin/sh

# flags
BUILDFLAGS := --rm --force-rm --compress \
	-f $(CURDIR)/Dockerfile \
	-t $(IMAGETAG) \
	--label org.label-schema.build-date=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ") \
	--label org.label-schema.name=$(REPONAME) \
	--label org.label-schema.schema-version="1.0" \
	--label org.label-schema.url="https://github.com/(USERNAME)/" \
	--label org.label-schema.usage="https://github.com/(USERNAME)/docker-$(REPONAME)" \
	--label org.label-schema.vcs-ref=$(shell git rev-parse --short HEAD) \
	--label org.label-schema.vcs-url="https://github.com/$(USERNAME)/docker-$(REPONAME)" \
	--label org.label-schema.vendor=$(USERNAME) \
	--label version="v$(VERSION)"
CACHEFLAGS ?= --no-cache=true --pull
MOUNTFLAGS ?= -v $(CURDIR)/nginx.conf:/etc/nginx/nginx.conf
NAMEFLAGS  ?= --name $(CNTNAME) --hostname $(CNTNAME)
OTHERFLAGS ?= -v /etc/hosts:/etc/hosts:ro -e TZ=Asia/Tokyo
PORTFLAGS  ?= -p 3128:3128
RUNFLAGS   ?=

# commands
all: help

build: ## Build image
	docker build $(BUILDFLAGS) $(CACHEFLAGS) .

clean: ## Clean images
	docker images | awk '(NR>1) && ($$2!~/none/) {print $$1":"$$2}' | grep "$(USERNAME)/$(REPONAME)" | xargs -n1 docker rmi

logs: ## Show container log
	docker logs -f $(CNTNAME)

pull: ## Pull image
	docker pull $(IMAGETAG)

push: ## Push image
	docker push $(IMAGETAG)
	docker tag $(IMAGETAG) $(USERNAME)/$(REPONAME):latest
	docker push $(USERNAME)/$(REPONAME):latest

restart: ## Restart container
	docker ps -a | grep '$(CNTNAME)' -q && docker restart $(CNTNAME) || echo "not running."

rm: ## Remove container
	docker rm -f $(CNTNAME)

run: ## Run app in container
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) $(IMAGETAG)

shell: ## Run shell in container
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) --entrypoint $(SHCOMMAND) $(IMAGETAG)

debug: ## Exec shell in container
	docker exec -it $(CNTNAME) $(SHCOMMAND)

stop: ## Stop container
	docker stop -t 2 $(CNTNAME)

test: ## Test container
	docker run --rm -it $(NAMEFLAGS) $(RUNFLAGS) $(PORTFLAGS) $(MOUNTFLAGS) $(OTHERFLAGS) --entrypoint sh $(IMAGETAG) -ec 'nginx -V;'

info: ## Show info
	@echo "image_tag:  $(IMAGETAG)"
	@echo "version:    $(VERSION)"
	@echo "maintainer: $(MAINTAINER)"

help: info ## Show help
	@cat $(MAKEFILE_LIST) \
	| grep -e "^[a-zA-Z_/\-]*: *.*## *" \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-24s\033[0m %s\n", $$1, $$2}' \
	| sed 's/\(.*\/.*\)/  \1/'
