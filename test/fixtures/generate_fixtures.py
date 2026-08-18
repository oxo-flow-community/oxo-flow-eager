#!/usr/bin/env python3
"""Generate the tiny synthetic aDNA fixtures for oxo-flow-eager.

The previous hand-made kit was 4 reads per sample: DamageProfiler's
-t 15 position threshold and preseq's duplicate-count curve both need
real depth, and the live run died with 'No reads processed. Can't
create any output' (DamageProfiler) right where the pipeline expects
statistics. This generator emits 2000 pairs per sample drawn from ~40
source positions (~50x per position, well above the -t 15 threshold),
with ~25% PCR-duplicated pairs at 2-8x multiplicity (preseq lc_extrap
needs >=4 duplicate-count levels) and 5'-end C-to-T damage so the
damage profiles have real signal. Insert sizes 60-90bp keep the pairs
mergeable by AdapterRemoval.

Regenerate with:  python3 test/fixtures/generate_fixtures.py
"""
import gzip
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
REF = os.path.join(HERE, "reference", "genome.fa")
READ_LEN = 100
PAIRS = 2000
SOURCE_POSITIONS = 40
SEED = 3

COMP = str.maketrans("ACGT", "TGCA")


def load_genome():
    seq = []
    for line in open(REF):
        if line.startswith(">"):
            continue
        seq.append(line.strip())
    return "".join(seq)


def mutate(seq, rng, rate=0.005):
    bases = list(seq)
    for i in range(len(bases)):
        if rng.random() < rate:
            bases[i] = rng.choice([b for b in "ACGT" if b != bases[i]])
    return "".join(bases)


def damage5p(seq, rng, rate=0.08, span=4):
    """aDNA cytosine deamination: C->T enriched at the 5' end."""
    bases = list(seq)
    for i in range(min(span, len(bases))):
        if bases[i] == "C" and rng.random() < rate:
            bases[i] = "T"
    return "".join(bases)


def revcomp(seq):
    return seq[::-1].translate(COMP)


def write_sample(name, rng):
    genome = load_genome()
    g = len(genome)
    # spread the sources so positions cover the contig (strand + offsets)
    starts = sorted(rng.sample(range(0, g - 120), SOURCE_POSITIONS))
    os.makedirs(RAW, exist_ok=True)
    r1_lines, r2_lines = [], []
    for i in range(PAIRS):
        start = starts[i % SOURCE_POSITIONS] + rng.randint(-3, 3)
        insert = rng.randint(60, 90)
        frag = genome[start : start + insert]
        r1 = damage5p(mutate(frag[:READ_LEN], rng), rng)
        r2 = damage5p(revcomp(mutate(frag[-READ_LEN:], rng)), rng)
        # /1 and /2 suffixes: AdapterRemoval v2 requires mate identifiers
        # (live: 'Error reading FASTQ record at line 1; aborting').
        rid = f"@FIXTURE:read{i} {name} length={READ_LEN}"
        q = "?" * READ_LEN
        r1_lines.append((rid + "/1", r1, q))
        r2_lines.append((rid + "/2", r2, q))
        # PCR duplicates at 2-8x multiplicity for preseq's count curve
        if i % 4 == 0:
            mult = rng.choice([1, 2, 3, 7])
            for k in range(mult):
                r1_lines.append((rid + f" dup{k}/1", r1, q))
                r2_lines.append((rid + f" dup{k}/2", r2, q))
    with gzip.open(os.path.join(RAW, f"{name}_R1.fastq.gz"), "wt") as f1, gzip.open(
        os.path.join(RAW, f"{name}_R2.fastq.gz"), "wt"
    ) as f2:
        for (h1, s1, q1), (h2, s2, q2) in zip(r1_lines, r2_lines):
            f1.write(f"{h1}\n{s1}\n+\n{q1}\n")
            f2.write(f"{h2}\n{s2}\n+\n{q2}\n")


def main():
    write_sample("S1", random.Random(SEED))
    write_sample("S2", random.Random(SEED + 1))
    print(f"eager fixtures regenerated: {PAIRS} damaged pairs x 2 samples")


if __name__ == "__main__":
    main()
