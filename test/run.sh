#!/usr/bin/env bash
# Acceptance test for oxo-flow-eager port.
# Usage: ./test/run.sh            (uses ./main.oxoflow)
set -euo pipefail
cd "$(dirname "$0")/.."
OXO=${OXO:-oxo-flow}

echo "==> validate"
"$OXO" validate main.oxoflow

echo "==> lint (warnings are acceptable, errors are not)"
"$OXO" lint main.oxoflow

echo "==> dry-run with default config"
"$OXO" dry-run main.oxoflow --samples first:1 > /tmp/oxo-dryrun-$$.txt 2>&1
grep -q "would execute" /tmp/oxo-dryrun-$$.txt

echo "==> dry-run with run_lanemerge=true (gated multi-lane mode)"
"$OXO" dry-run main.oxoflow --samples first:1 run_lanemerge=true > /tmp/oxo-dryrun-gated-$$.txt 2>&1
grep -q "lanemerge" /tmp/oxo-dryrun-gated-$$.txt

echo "==> dry-run with bam_input=true (BAM-to-FASTQ entry point)"
sed -e 's/^bam_input = false/bam_input = true/' \
    -e 's|^input_bam = ""|input_bam = "test/fixtures/bam/S1.bam"|' \
    main.oxoflow > .tmp.oxoflow
"$OXO" dry-run .tmp.oxoflow --samples first:1 > /tmp/oxo-dryrun-bam-$$.txt 2>&1
grep -qE "^  [0-9]+\. convert_bam_cohort_S1  \[run" /tmp/oxo-dryrun-bam-$$.txt
grep -qE "^  [0-9]+\. fastqc_baminput_cohort_S1  \[run" /tmp/oxo-dryrun-bam-$$.txt
grep -q 'results/convert_bam/S1_R2.fastq.gz' /tmp/oxo-dryrun-bam-$$.txt
rm -f .tmp.oxoflow

echo "==> debug: expanded commands contain no literal {wildcards}"
"$OXO" debug main.oxoflow | grep -q '{sample}' && { echo "unexpanded wildcards in debug output"; exit 1; } || true

echo "PASS"
