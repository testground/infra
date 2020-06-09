FROM golang:alpine AS build

RUN apk add --no-cache -U make git mercurial subversion bzr fossil

RUN cd / && git clone https://github.com/goproxyio/goproxy.git

RUN cd /goproxy && git checkout v2.0.2 &&\
    export CGO_ENABLED=0 &&\
    make

FROM golang:alpine

RUN apk add --no-cache -U git mercurial subversion bzr fossil

COPY --from=build /goproxy /goproxy

VOLUME /go

EXPOSE 8081

ENTRYPOINT ["/goproxy"]
CMD []
