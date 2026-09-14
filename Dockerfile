# =============================================================================
# cva6-priv-sva — reproducible toolchain for the formal proofs.
# One OSS-CAD-Suite release = Yosys + SymbiYosys + Z3 + yosys-slang, pinned
# with its sha256 in tools/oss-cad-suite.sh (CI runs the same script).
# The repo (incl. the pinned cva6 submodule) is mounted at /workspace
#
# build:  docker build -t cva6-priv-sva .   (from the repo root: COPY needs tools/)
# run:    docker run --rm -it -v "$PWD":/workspace cva6-priv-sva
#         then:  make versions && make verify-pmp
# =============================================================================

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates make patch \
    && rm -rf /var/lib/apt/lists/*

COPY tools/oss-cad-suite.sh /tmp/oss-cad-suite.sh
RUN bash /tmp/oss-cad-suite.sh /opt && rm /tmp/oss-cad-suite.sh
ENV PATH="/opt/oss-cad-suite/bin:${PATH}"

RUN yosys -q -m slang -p "help read_slang" >/dev/null

WORKDIR /workspace

RUN echo "=== tool versions ===" && \
    echo "yosys:   $(yosys --version 2>&1)" && \
    echo "sby:     $(sby --help 2>&1 | head -1)" && \
    echo "z3:      $(z3 --version 2>&1)" && \
    echo "oss-cad: $(cat /opt/oss-cad-suite/VERSION)" && \
    echo "(run 'make versions' at runtime for the pinned CVA6 commit)"

CMD ["/bin/bash"]
