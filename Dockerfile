# # Base image for AMD64 builds
# FROM --platform=linux/amd64 rocm/dev-centos-7:6.1.2-complete AS unified-builder-amd64

# # Arguments for tools and dependencies
# ARG CMAKE_VERSION=3.22.1
# ARG GOLANG_VERSION=1.22.8
# ARG CUDA_VERSION_11=11.3.1
# ARG CUDA_VERSION_12=12.4.0

# # Copy and execute the dependency installation script
# COPY ./scripts/rh_linux_deps.sh /
# RUN CMAKE_VERSION=${CMAKE_VERSION} GOLANG_VERSION=${GOLANG_VERSION} sh /rh_linux_deps.sh

# # Install CUDA for the specified versions
# RUN yum-config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel7/x86_64/cuda-rhel7.repo && \
#     dnf clean all && \
#     dnf install -y \
#     zsh \
#     cuda-$(echo ${CUDA_VERSION_11} | cut -f1-2 -d. | sed -e "s/\./-/g") \
#     cuda-$(echo ${CUDA_VERSION_12} | cut -f1-2 -d. | sed -e "s/\./-/g")

# # Environment setup
# ENV PATH /opt/rh/devtoolset-10/root/usr/bin:/usr/local/cuda/bin:$PATH
# ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/cuda/lib64
# ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs:/opt/amdgpu/lib64
# ENV GOARCH amd64
# ENV CGO_ENABLED 1
# WORKDIR /go/src/github.com/ollama/ollama/

# # AMD64 runners stage
# FROM --platform=linux/amd64 unified-builder-amd64 AS runners-amd64
# COPY . .
# ARG OLLAMA_SKIP_CUDA_GENERATE
# ARG OLLAMA_SKIP_CUDA_11_GENERATE
# ARG OLLAMA_SKIP_CUDA_12_GENERATE
# ARG CUDA_V11_ARCHITECTURES="50;52;53;60;61;62;70;72;75;80;86"
# ARG CUDA_V12_ARCHITECTURES="60;61;62;70;72;75;80;86;87;89;90;90a"
# RUN --mount=type=cache,target=/root/.ccache \
#     if grep "^flags" /proc/cpuinfo | grep avx >/dev/null; then \
#         make -j $(expr $(nproc) / 2); \
#     else \
#         make -j 5; \
#     fi

# # Build stage for AMD64
# FROM --platform=linux/amd64 runners-amd64 AS build-amd64
# COPY . .
# COPY --from=runners-amd64 /go/src/github.com/ollama/ollama/dist/ dist/
# COPY --from=runners-amd64 /go/src/github.com/ollama/ollama/build/ build/
# ARG GOFLAGS
# ARG CGO_CFLAGS
# RUN --mount=type=cache,target=/root/.ccache \
#     go build -trimpath -o dist/linux-amd64/bin/ollama .
# RUN cd dist/linux-$GOARCH && \
#     tar --exclude runners -cf - . | pigz --best > ../ollama-linux-$GOARCH.tgz

# # Runtime stage for AMD64
# FROM --platform=linux/amd64 ubuntu:22.04 AS runtime-amd64
# RUN apt-get update && \
#     apt-get install -y ca-certificates && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*
# COPY --from=build-amd64 /go/src/github.com/ollama/ollama/dist/linux-amd64/bin/ /bin/
# COPY --from=build-amd64 /go/src/github.com/ollama/ollama/dist/linux-amd64/lib/ /lib/

# # Entrypoint for the runtime container
# EXPOSE 11434
# ENV OLLAMA_HOST 0.0.0.0
# ENTRYPOINT ["/bin/ollama"]
# CMD ["serve"]




# Use the existing built image as the base for the new build
FROM --platform=linux/amd64 570188313908.dkr.ecr.us-east-1.amazonaws.com/base-ollama:0.0.1 AS existing-build

# Install Go if it's not already installed in the existing image
RUN curl -sSL https://golang.org/dl/go1.22.8.linux-amd64.tar.gz | tar -C /usr/local -xz && \
    ln -s /usr/local/go/bin/go /usr/bin/go

# Set up necessary build environment
ENV GOARCH amd64
ENV CGO_ENABLED 1
WORKDIR /go/src/github.com/ollama/ollama/

# Copy the new Golang code (assuming the code is in the current directory)
COPY . .

# Rebuild the Golang binary with the new code
RUN --mount=type=cache,target=/root/.ccache \
    go build -trimpath -o dist/linux-amd64/bin/ollama .

# Runtime stage
FROM --platform=linux/amd64 ubuntu:22.04 AS runtime-amd64
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
    
# Copy the new binary from the previous build stage
COPY --from=existing-build /go/src/github.com/ollama/ollama/dist/linux-amd64/bin/ /bin/

# Entrypoint for the runtime container
EXPOSE 11434
ENV OLLAMA_HOST 0.0.0.0
ENTRYPOINT ["/bin/ollama"]
CMD ["serve"]
