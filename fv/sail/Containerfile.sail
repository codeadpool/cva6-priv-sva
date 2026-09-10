FROM ubuntu:24.04

ARG SAIL_VERSION=0.20.2
ARG OCAML_VERSION=5.4.1

ENV OPAMROOT=/opt/opam \
    OPAMYES=1 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
      opam build-essential libgmp-dev z3 pkg-config \
      ca-certificates curl bzip2 gawk diffutils \
    && rm -rf /var/lib/apt/lists/*

RUN opam init --bare --disable-sandboxing --no-setup \
    && opam switch create sail "ocaml-base-compiler.${OCAML_VERSION}" \
    && opam install "sail.${SAIL_VERSION}"

ENV PATH="/opt/opam/sail/bin:${PATH}"

RUN sail --version | tee /dev/stderr | grep -q "${SAIL_VERSION}"

WORKDIR /workspace
CMD ["bash"]
