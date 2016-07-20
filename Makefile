# podium
# https://github.com/topfreegames/podium
# Licensed under the MIT license:
# http://www.opensource.org/licenses/mit-license
# Copyright © 2016 Top Free Games <backend@tfgco.com>
# Forked from
# https://github.com/dayvson/go-leaderboard
# Copyright © 2013 Maxwell Dayvson da Silva

PACKAGES = $(shell glide novendor)
GODIRS = $(shell go list ./... | grep -v /vendor/ | sed s@github.com/topfreegames/podium@.@g | egrep -v "^[.]$$")
MYIP = $(shell ifconfig | egrep inet | egrep -v inet6 | egrep -v 127.0.0.1 | awk ' { print $$2 } ')
OS = "$(shell uname | awk '{ print tolower($$0) }')"
LOCAL_REDIS_PORT=1212
LOCAL_TEST_REDIS_PORT=1234

setup-hooks:
	@cd .git/hooks && ln -sf ../../hooks/pre-commit.sh pre-commit

setup: setup-hooks
	@go get -u github.com/Masterminds/glide/...
	@go get -u github.com/onsi/ginkgo/ginkgo
	@go get github.com/gordonklaus/ineffassign
	@glide install

# get a redis instance up (localhost:1234)
redis:
	@redis-server --port ${LOCAL_REDIS_PORT} --daemonize yes; sleep 1
	@redis-cli -p ${LOCAL_REDIS_PORT} info > /dev/null

# kill this redis instance (localhost:1234)
redis-kill:
	@-redis-cli -p ${LOCAL_REDIS_PORT} shutdown

test: test-redis
	@ginkgo --cover $(GODIRS)
	@make test-redis-kill

test-coverage: test
	@rm -rf _build
	@mkdir -p _build
	@echo "mode: count" > _build/test-coverage-all.out
	@bash -c 'for f in $$(find . -name "*.coverprofile"); do tail -n +2 $$f >> _build/test-coverage-all.out; done'

test-coverage-html: test-coverage
	@go tool cover -html=_build/test-coverage-all.out

# get a redis instance up (localhost:1234)
test-redis:
	@redis-server --port ${LOCAL_TEST_REDIS_PORT} --daemonize yes; sleep 1
	@redis-cli -p ${LOCAL_TEST_REDIS_PORT} info > /dev/null

# kill this redis instance (localhost:1234)
test-redis-kill:
	@-redis-cli -p ${LOCAL_TEST_REDIS_PORT} shutdown

cross: cross-linux cross-darwin

cross-linux:
	@mkdir -p ./bin
	@echo "Building for linux-i386..."
	@env GOOS=linux GOARCH=386 go build -o ./bin/podium-linux-i386 ./main.go
	@echo "Building for linux-x86_64..."
	@env GOOS=linux GOARCH=amd64 go build -o ./bin/podium-linux-x86_64 ./main.go
	@$(MAKE) cross-exec

cross-darwin:
	@mkdir -p ./bin
	@echo "Building for darwin-i386..."
	@env GOOS=darwin GOARCH=386 go build -o ./bin/podium-darwin-i386 ./main.go
	@echo "Building for darwin-x86_64..."
	@env GOOS=darwin GOARCH=amd64 go build -o ./bin/podium-darwin-x86_64 ./main.go
	@$(MAKE) cross-exec

cross-exec:
	@chmod +x bin/*

docker-build:
	@docker build -t podium .

docker-run:
	@docker run -i -t --rm -e PODIUM_REDIS_HOST=$(MYIP) -e PODIUM_REDIS_PORT=$(LOCAL_REDIS_PORT) -p 8080:8080 podium

docker-shell:
	@docker run -it --rm -e PODIUM_REDIS_HOST=$(MYIP) -e PODIUM_REDIS_PORT=$(LOCAL_REDIS_PORT) --entrypoint "/bin/bash" podium

docker-dev-build:
	@docker build -t podium-dev -f ./DevDockerfile .

docker-dev-run:
	@docker run -i -t --rm -p 8080:8080 podium-dev
