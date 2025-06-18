# Makefile for building src-helper Go project for ARM and AMD64 Linux

BINARY_NAME=picontrol-linux
SRC_DIR=.

.PHONY: all clean build-amd64 build-arm

all: build-amd64 build-arm

build-amd64:
	GOOS=linux GOARCH=amd64 go build -o $(BINARY_NAME) $(SRC_DIR)/main.go

build-arm:
	GOOS=linux GOARCH=arm64 go build -o $(BINARY_NAME)-arm $(SRC_DIR)/main.go

clean:
	rm -f $(BINARY_NAME) $(BINARY_NAME)-arm
