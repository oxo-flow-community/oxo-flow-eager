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

echo "==> debug: expanded commands contain no literal {wildcards}"
"$OXO" debug main.oxoflow | grep -q '{sample}' && { echo "unexpanded wildcards in debug output"; exit 1; } || true

echo "==> dry-run with bam_input=true (BAM pass-through: indexinputbam co-produces the mapped BAM)"
sed -e 's/^bam_input = false$/bam_input = true/' \
    -e 's|^input_bam = ""$|input_bam = "test/fixtures/input.bam"|' \
    main.oxoflow > .indexinputbam-test-tmp.oxoflow
grep -q '^bam_input = true$' .indexinputbam-test-tmp.oxoflow
grep -q '^input_bam = "test/fixtures/input.bam"$' .indexinputbam-test-tmp.oxoflow
trap 'rm -f .indexinputbam-test-tmp.oxoflow' EXIT
"$OXO" dry-run .indexinputbam-test-tmp.oxoflow --samples first:1 > /tmp/oxo-dryrun-indexinputbam-$$.txt 2>&1
grep -qE "^  [0-9]+\. indexinputbam[^ ]*  \[run" /tmp/oxo-dryrun-indexinputbam-$$.txt \
  || { echo "indexinputbam not scheduled in bam-input mode"; exit 1; }
grep -qE "^  [0-9]+\. samtools_flagstat[^ ]*  \[run" /tmp/oxo-dryrun-indexinputbam-$$.txt \
  || { echo "BAM chain (samtools_flagstat) must consume the co-produced mapped BAM"; exit 1; }
if grep -qE "^  [0-9]+\. bwa_aln[^ ]*  \[run" /tmp/oxo-dryrun-indexinputbam-$$.txt; then
  echo "bwa_aln must not run in bam-input mode (the input BAM is already mapped)"
  exit 1
fi
if grep -qE "^  [0-9]+\. fastqc[^ ]*  \[run" /tmp/oxo-dryrun-indexinputbam-$$.txt; then
  echo "FASTQ preprocessing chain (fastqc) must not run in pure BAM-input mode"
  exit 1
fi
if grep -qE "^  [0-9]+\. convert_bam[^ ]*  \[run" /tmp/oxo-dryrun-indexinputbam-$$.txt; then
  echo "convert_bam must not run unless run_convertinputbam=true"
  exit 1
fi
grep -qE "^  [0-9]+\. indexinputbam[^ ]*  \[run" /tmp/oxo-dryrun-$$.txt \
  && { echo "indexinputbam must not run in default FASTQ mode"; exit 1; } || true
rm -f .indexinputbam-test-tmp.oxoflow
trap - EXIT

echo "PASS"
