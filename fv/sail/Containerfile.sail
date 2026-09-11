FROM ubuntu:24.04@sha256:224a1869083a311ef3f13648a154ba79832fbef6364d31493642ca03082da254

ARG SAIL_URL=https://github.com/rems-project/sail/releases/download/0.20.2-binary/sail-Linux-x86_64.tar.gz
ARG SAIL_SHA256=26b59bcab2d66e9f220d317dfe45f8b09170ed70e59a824553d6f525134d1ff6

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl libgmp10 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/sail.tar.gz "$SAIL_URL" \
    && echo "$SAIL_SHA256  /tmp/sail.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/sail.tar.gz -C /opt \
    && rm /tmp/sail.tar.gz

ENV PATH="/opt/sail/bin:${PATH}"

RUN sail --version | tee /dev/stderr | grep -qw "0.20.2"

WORKDIR /workspace
CMD ["bash"]
