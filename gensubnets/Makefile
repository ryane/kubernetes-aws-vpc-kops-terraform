NAME = $(shell awk -F\" '/^\t+name / { print $$2 }' ./main.go)
VERSION = $(shell awk -F\" '/^\t+version / { print $$2 }' ./main.go)
REPO = ryane

build: $(shell find . -name '*.go')
	go build

docker: $(shell find . -name '*.go')
	CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .
	docker build --force-rm --rm -t ${REPO}/${NAME}:${VERSION} .
	rm -f main

push: docker
	docker push ${REPO}/${NAME}:${VERSION}
