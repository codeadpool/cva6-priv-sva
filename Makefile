# =============================================================================
# cva6-priv-sva - formal verification of the CVA6 privileged ISA.
# Layout (CVA6 is a pinned submodule inside this repo - never edited):
#     cva6-priv-sva/cva6/   ← upstream CVA6 v5.3.0 @ 2ef1c1b
#     cva6-priv-sva/        ← this repo
# Each fv/checks/<cat>.sby is a real sby script with bmc/prove/cover tasks.
# Override CVA6=<path> if the submodule isn't in place yet.
# =============================================================================

CVA6         ?= $(realpath $(CURDIR)/cva6)
PROJECT_ROOT := $(realpath $(CURDIR))
RESULTS_DIR  ?= results
CHECKS_DIR   := fv/checks
# sby tasks run per category (override e.g.: make verify-pmp TASKS=prove)
TASKS        ?= bmc prove cover

CATEGORIES   := pmp csr trap priv mstatus vm probe

.DEFAULT_GOAL := help

# ── Help (default goal) ──────────────────────────────────────────────────────
.PHONY: help
help:
	@printf "cva6-priv-sva - formal verification of CVA6 privileged ISA\n\n"
	@printf "Targets:\n"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	    | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@printf "  \033[36mverify-<cat>\033[0m     Run one category (cat: $(CATEGORIES))\n"
	@printf "\nVariables:  CVA6=%s\n" "$(CVA6)"
	@printf "            TASKS='%s'  (override e.g. TASKS=prove)\n" "$(TASKS)"

# ── Toolchain + CVA6 version snapshot (audit trail for the paper) ─────────────
.PHONY: versions
versions:
	@printf "── tools ──\n"
	@printf "yosys:     %s\n" "$$(yosys --version 2>&1 | head -1)"
	@printf "sby:       %s\n" "$$(sby --help 2>&1 | head -1)"
	@printf "z3:        %s\n" "$$(z3 --version 2>&1)"
	@printf "\n── CVA6 ──\n"
	@if [ -e "$(CVA6)/.git" ]; then \
	    printf "path:      %s\n" "$(CVA6)"; \
	    printf "commit:    %s\n" "$$(git -C $(CVA6) rev-parse HEAD)"; \
	    printf "describe:  %s\n" "$$(git -C $(CVA6) describe --always --tags --dirty 2>/dev/null || echo n/a)"; \
	else \
	    printf "CVA6 not at $(CVA6) - run: git submodule update --init cva6\n"; \
	fi

# ── Verification ─────────────────────────────────────────────────────────────
.PHONY: verify-all $(addprefix verify-,$(CATEGORIES))

verify-all: $(addprefix verify-,$(CATEGORIES))
	@printf "═══ all categories complete ═══\n"

define VERIFY_RULE
verify-$(1):
	@found=0; \
	for f in $(CHECKS_DIR)/$(1)*.sby; do \
	    [ -f "$$$$f" ] || continue; found=1; \
	    base=$$$$(basename "$$$$f" .sby); \
	    for task in $(TASKS); do \
	        printf "── %s [%s] ──\n" "$$$$base" "$$$$task"; \
	        ( cd $(CHECKS_DIR) && sby -f -d \
	            "$(PROJECT_ROOT)/$(RESULTS_DIR)/$(1)/$$$${base}_$$$${task}" \
	            "$$$$base.sby" "$$$$task" ) || true; \
	    done; \
	done; \
	[ "$$$$found" = 1 ] || echo "no $(CHECKS_DIR)/$(1)*.sby"
	@printf "═══ $(1) complete ═══\n"
endef
$(foreach c,$(CATEGORIES),$(eval $(call VERIFY_RULE,$(c))))

# ── Results aggregation ──────────────────────────────────────────────────────
.PHONY: results
results:
	@printf "%-10s %-28s %-8s %s\n" "CATEGORY" "TASK" "TIME" "STATUS"
	@printf "%-10s %-28s %-8s %s\n" "--------" "----" "----" "------"
	@for c in $(CATEGORIES); do \
	    [ -d $(RESULTS_DIR)/$$c ] || continue; \
	    for d in $(RESULTS_DIR)/$$c/*/; do \
	        [ -d "$$d" ] || continue; \
	        t=$$(basename "$$d"); log="$$d/logfile.txt"; \
	        if [ -f "$$log" ]; then \
	            s=$$(grep -oE 'DONE \([A-Z]+' "$$log" | tail -1 | sed 's/DONE (//'); \
	            tm=$$(grep 'Elapsed clock time' "$$log" | tail -1 | grep -oE '\([0-9]+\)' | tail -1 | tr -d '()'); \
	            [ -z "$$s" ] && s="?"; [ -z "$$tm" ] && tm="?" || tm="$${tm}s"; \
	        else s="NO-LOG"; tm="-"; fi; \
	        printf "%-10s %-28s %-8s %s\n" "$$c" "$$t" "$$tm" "$$s"; \
	    done; \
	done

# ── Evidence curation ────────────────────────────────────────────────────────
.PHONY: evidence
evidence:
	@for c in $(CATEGORIES); do \
	    [ -d $(RESULTS_DIR)/$$c ] || continue; \
	    for d in $(RESULTS_DIR)/$$c/*/; do \
	        [ -d "$$d" ] || continue; t=$$(basename "$$d"); \
	        mkdir -p evidence/$$c/$$t; \
	        rm -f evidence/$$c/$$t/PASS evidence/$$c/$$t/FAIL evidence/$$c/$$t/ERROR \
	              evidence/$$c/$$t/UNKNOWN evidence/$$c/$$t/TIMEOUT evidence/$$c/$$t/trace*.vcd; \
	        cp -f "$$d/logfile.txt" "evidence/$$c/$$t/" 2>/dev/null || true; \
	        for m in PASS FAIL ERROR UNKNOWN TIMEOUT; do \
	            [ -f "$$d$$m" ] && cp -f "$$d$$m" "evidence/$$c/$$t/" || true; \
	        done; \
	        find "$$d" -maxdepth 2 -name 'trace*.vcd' \
	            -exec cp -f {} "evidence/$$c/$$t/" \; 2>/dev/null || true; \
	    done; \
	done; printf "evidence/ updated - review, then commit\n"

# ── Cleanup ──────────────────────────────────────────────────────────────────
.PHONY: clean clean-cat
clean:
	rm -rf $(RESULTS_DIR)/

clean-cat:
	@[ -n "$(CAT)" ] || { echo "usage: make clean-cat CAT=<category>"; exit 1; }
	rm -rf $(RESULTS_DIR)/$(CAT)/
