#!/usr/bin/env bash

###############################################################################
# validate_pipeline.sh
#
# Validate the multi-source extraction pipeline components.
#
# This script:
# 1. Checks all required scripts exist and are executable
# 2. Validates configuration files
# 3. Tests utility functions
# 4. Performs dry-run validation (no API calls)
#
# Usage: ./validate_pipeline.sh [--verbose]
#
# Exit codes:
#   0: All validations passed
#   1: Validation failures detected
###############################################################################

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

VERBOSE=false
if [ "${1:-}" = "--verbose" ]; then
    VERBOSE=true
fi

# Counters
PASS=0
FAIL=0
WARN=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log_pass() { echo -e "${GREEN}✓${NC} $*"; PASS=$((PASS + 1)); }
log_fail() { echo -e "${RED}✗${NC} $*"; FAIL=$((FAIL + 1)); }
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; WARN=$((WARN + 1)); }
log_info() { [ "$VERBOSE" = true ] && echo -e "${BLUE}ℹ${NC} $*" || true; }
log_section() { echo -e "\n${BLUE}═══ $* ═══${NC}"; }

###############################################################################
# Script Existence Checks
###############################################################################
log_section "Script Validation"

REQUIRED_SCRIPTS=(
    "extraction/obsidian.sh"
    "extraction/readwise.sh"
    "extraction/readwise_client.sh"
    "extraction/extract_parallel.sh"
    "synthesis/consolidate.sh"
    "synthesis/generate_digest.sh"
    "distribution/generate_drafts_v2.sh"
    "utils/format_intermediate.sh"
    "daily_runner_v2.sh"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        if [ -x "$script_path" ]; then
            log_pass "$script exists and is executable"
        else
            log_fail "$script exists but is not executable"
        fi
    else
        log_fail "$script not found"
    fi
done

###############################################################################
# Configuration Validation
###############################################################################
log_section "Configuration Validation"

CONFIG_DIR="$PROJECT_ROOT/config/platforms"

if [ -d "$CONFIG_DIR" ]; then
    log_pass "Platform config directory exists"

    # Check for at least one config file
    CONFIG_COUNT=$(find "$CONFIG_DIR" -name "*.yaml" -o -name "*.yml" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$CONFIG_COUNT" -gt 0 ]; then
        log_pass "Found $CONFIG_COUNT platform configuration(s)"
    else
        log_warn "No platform configurations found"
    fi

    # Validate each config has required fields
    for config_file in "$CONFIG_DIR"/*.yaml "$CONFIG_DIR"/*.yml; do
        [ -f "$config_file" ] || continue
        config_name=$(basename "$config_file")

        if grep -q "platform:" "$config_file"; then
            log_pass "$config_name has platform section"
        else
            log_fail "$config_name missing platform section"
        fi

        log_info "Validated: $config_name"
    done
else
    log_fail "Platform config directory not found: $CONFIG_DIR"
fi

###############################################################################
# Environment Validation
###############################################################################
log_section "Environment Validation"

# Check for .env.example
if [ -f "$PROJECT_ROOT/.env.example" ]; then
    log_pass ".env.example exists"
else
    log_warn ".env.example not found"
fi

# Check for jq (required for Readwise)
if command -v jq &> /dev/null; then
    log_pass "jq is installed"
else
    log_fail "jq is not installed (required for Readwise integration)"
fi

# Check for Claude Code
if command -v claude &> /dev/null; then
    log_pass "Claude Code CLI is available"
else
    log_warn "Claude Code CLI not found (required for synthesis)"
fi

# Check for yq (optional, for YAML parsing)
if command -v yq &> /dev/null; then
    log_pass "yq is installed (enhanced YAML parsing)"
else
    log_warn "yq not installed (will use basic YAML parsing)"
fi

###############################################################################
# Utility Function Tests
###############################################################################
log_section "Utility Function Tests"

# Source utility functions
source "$SCRIPT_DIR/utils/format_intermediate.sh"

# Test ensure_daily_output_dir
TEST_DIR="/tmp/claude/validate_test_$$"
mkdir -p "$TEST_DIR"
OUTPUT=$(ensure_daily_output_dir "$TEST_DIR" "2024-01-01")
if [ -d "$OUTPUT" ] && [ -d "$OUTPUT/drafts" ]; then
    log_pass "ensure_daily_output_dir creates correct structure"
    rm -rf "$TEST_DIR"
else
    log_fail "ensure_daily_output_dir failed"
fi

# Test create_intermediate_header
HEADER_TEST=$(create_intermediate_header "test-source" "test-category" "2024-01-01" "5")
if echo "$HEADER_TEST" | grep -q "source: test-source" && \
   echo "$HEADER_TEST" | grep -q "category: test-category"; then
    log_pass "create_intermediate_header generates correct format"
else
    log_fail "create_intermediate_header output incorrect"
fi

# Test create_item
ITEM_TEST=$(create_item "Test Title" "http://example.com" "tag1, tag2" "Test content here")
if echo "$ITEM_TEST" | grep -qF "### Item: Test Title" && \
   echo "$ITEM_TEST" | grep -qF "**Source**: http://example.com"; then
    log_pass "create_item generates correct format"
else
    log_fail "create_item output incorrect"
fi

###############################################################################
# Syntax Validation
###############################################################################
log_section "Bash Syntax Validation"

for script in "${REQUIRED_SCRIPTS[@]}"; do
    script_path="$SCRIPT_DIR/$script"
    if [ -f "$script_path" ]; then
        if bash -n "$script_path" 2>/dev/null; then
            log_pass "$script syntax valid"
        else
            log_fail "$script has syntax errors"
        fi
    fi
done

###############################################################################
# Summary
###############################################################################
log_section "Validation Summary"

echo ""
echo -e "Total: $((PASS + FAIL))"
echo -e "Passed: ${GREEN}$PASS${NC}"
echo -e "Failed: ${RED}$FAIL${NC}"
echo -e "Warnings: ${YELLOW}$WARN${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    exit 0
else
    echo -e "${RED}Validation failed with $FAIL error(s)${NC}"
    exit 1
fi
