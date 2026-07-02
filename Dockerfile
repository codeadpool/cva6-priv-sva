# =============================================================================
# cva6-priv-sva — reproducible toolchain for the formal proofs.
# Pins ONE OSS-CAD-Suite release = Yosys + SymbiYosys + Z3 + yosys-slang.
# The repo (incl. the pinned cva6 submodule) is mounted at /workspace
#
# build:  docker build -t cva6-priv-sva .
# run:    docker run --rm -it -v "$PWD":/workspace cva6-priv-sva
#         then:  make versions && make verify-pmp
# =============================================================================

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates make \
    && rm -rf /var/lib/apt/lists/*

# Releases: https://github.com/YosysHQ/oss-cad-suite-build/releases
ARG OSS_CAD_DATE=20260407
ARG OSS_CAD_TAG=2026-04-07
RUN curl -fsSL \
        "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_TAG}/oss-cad-suite-linux-x64-${OSS_CAD_DATE}.tgz" \
    | tar xzf - -C /opt
ENV PATH="/opt/oss-cad-suite/bin:${PATH}"

RUN yosys -m slang -p "help read_slang" 2>&1 | head -1

WORKDIR /workspace

RUN echo "=== tool versions ===" && \
    echo "yosys:   $(yosys --version 2>&1)" && \
    echo "sby:     $(sby --help 2>&1 | head -1)" && \
    echo "z3:      $(z3 --version 2>&1)" && \
    echo "oss-cad: ${OSS_CAD_TAG}" && \
    echo "(run 'make versions' at runtime for the pinned CVA6 commit)"

CMD ["/bin/bash"]
