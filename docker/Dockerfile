FROM golang:1.13.3-buster as builder

#RUN adduser --no-create-home --disabled-password --uid 1 --gid 1 daemon

WORKDIR $GOPATH/src/github.com/matt-g-everett/homeauto-api/

COPY . .

RUN go get -d -v

RUN CGO_ENABLED=0 GOOS=linux go build -ldflags "-w -s" -a -installsuffix cgo -o /go/bin/homeauto-api .


FROM scratch

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /go/bin/homeauto-api /go/bin/homeauto-api

# The microservice makes calls to https endpoints so we need the standard set of CA certs
COPY --from=builder /usr/share/ca-certificates /usr/share/ca-certificates
COPY --from=builder /etc/ssl/certs /etc/ssl/certs

USER daemon

ENTRYPOINT ["/go/bin/homeauto-api"]
