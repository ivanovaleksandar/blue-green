FROM golang AS build_base

WORKDIR /app

ENV GO111MODULE=on
COPY go.mod .
# COPY go.sum .
RUN go mod download

FROM build_base AS binary_builder
COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -installsuffix cgo

FROM alpine

COPY --from=binary_builder /app /app

EXPOSE 3000

ENTRYPOINT ["/app/blue-green"]