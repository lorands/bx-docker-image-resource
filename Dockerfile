FROM golang:alpine AS builder

COPY . /go/src/github.com/concourse/docker-image-resource
ENV CGO_ENABLED 0
COPY assets/ /assets
RUN go build -o /assets/check github.com/concourse/docker-image-resource/cmd/check
RUN go build -o /assets/print-metadata github.com/concourse/docker-image-resource/cmd/print-metadata
RUN go build -o /assets/ecr-login github.com/concourse/docker-image-resource/vendor/github.com/awslabs/amazon-ecr-credential-helper/ecr-login/cmd
ENV CGO_ENABLED 1
RUN set -e; for pkg in $(go list ./...); do \
		go test -o "/tests/$(basename $pkg).test" -c $pkg; \
	done

FROM alpine:edge AS resource
RUN apk --no-cache add bash docker jq ca-certificates xz curl
COPY --from=builder /assets /opt/resource
RUN mv /opt/resource/ecr-login /usr/local/bin/docker-credential-ecr-login
WORKDIR /tmp
RUN curl -o /tmp/Bluemix_CLI.tar.gz https://public.dhe.ibm.com/cloud/bluemix/cli/bluemix-cli/0.7.1/IBM_Cloud_CLI_0.7.1_amd64.tar.gz && \
  tar zxvf Bluemix_CLI.tar.gz && \
  Bluemix_CLI/install_bluemix_cli && \
  rm -f /tmp/Bluemix_CLI.tar.gz && \
  rm -rf /tmp/Bluemix_CLI
WORKDIR /
RUN bx plugin install container-registry -r Bluemix
RUN bx config --check-version=false

# FROM resource AS tests
# COPY --from=builder /tests /tests
# ADD . /docker-image-resource
# RUN set -e; for test in /tests/*.test; do \
# 		$test -ginkgo.v; \
# 	done

FROM resource
