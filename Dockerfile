# Base builder for amd64
FROM 570188313908.dkr.ecr.us-east-1.amazonaws.com/base-ollama:0.0.1 AS builder-amd64
ARG CMAKE_VERSION
ARG GOLANG_VERSION
COPY ./scripts/rh_linux_deps.sh /
RUN CMAKE_VERSION=${CMAKE_VERSION} GOLANG_VERSION=${GOLANG_VERSION} sh /rh_linux_deps.sh
ENV PATH /opt/rh/devtoolset-10/root/usr/bin:$PATH
ENV CGO_ENABLED 1
ENV GOARCH amd64
WORKDIR /go/src/github.com/ollama/ollama

FROM --platform=linux/amd64 builder-amd64 AS build-amd64
COPY . .
ARG GOFLAGS
ARG CGO_CFLAGS
RUN --mount=type=cache,target=/root/.ccache \
    go build -trimpath -o dist/linux-amd64/bin/ollama .

# Base builder for arm64
FROM --platform=linux/arm64 rockylinux:8 AS builder-arm64
ARG CMAKE_VERSION
ARG GOLANG_VERSION
COPY ./scripts/rh_linux_deps.sh /
RUN CMAKE_VERSION=${CMAKE_VERSION} GOLANG_VERSION=${GOLANG_VERSION} sh /rh_linux_deps.sh
ENV PATH /opt/rh/gcc-toolset-10/root/usr/bin:$PATH
ENV CGO_ENABLED 1
ENV GOARCH arm64
WORKDIR /go/src/github.com/ollama/ollama

FROM --platform=linux/arm64 builder-arm64 AS build-arm64
COPY . .
ARG GOFLAGS
ARG CGO_CFLAGS
RUN --mount=type=cache,target=/root/.ccache \
    go build -trimpath -o dist/linux-arm64/bin/ollama .

EXPOSE 11434
ENV OLLAMA_HOST 0.0.0.0

ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]

FROM runtime-$TARGETARCH
EXPOSE 11434
ENV OLLAMA_HOST 0.0.0.0
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV NVIDIA_VISIBLE_DEVICES=all

ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]