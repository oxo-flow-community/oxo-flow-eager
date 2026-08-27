# oxo-flow-eager — Ancient DNA (aDNA): QC, mapping, damage estimation and genotyping

> ★ Verified · ⇄ Official port of [`nf-core/eager`](https://github.com/nf-core/eager) @ `2.5.3` — same tools, same versions, same commands. Part of the [oxo-flow-community catalog](https://oxo-flow-community.github.io/).

[![CI](https://github.com/oxo-flow-community/oxo-flow-eager/actions/workflows/ci.yml/badge.svg)](https://github.com/oxo-flow-community/oxo-flow-eager/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

This workflow turns a directory of paired-end ancient DNA (aDNA) sequencing
reads into a complete, publication-ready analysis: FastQC raw QC, an optional
fastp poly-G complexity filter, AdapterRemoval adapter clipping and read
merging, BWA aln mapping with ancient-DNA parameters, picard MarkDuplicates
(or DeDup) deduplication, preseq library-complexity curves, DamageProfiler
damage-pattern estimation, Qualimap BAM QC, optional pileupCaller genotyping
with eigenstrat SNP coverage, and a final MultiQC report. Every rule runs the
same pinned tool versions as the upstream pipeline, in the same container, so
`results/` is reproducible from the same input.

## Installation

### 1. Install oxo-flow

This workflow requires **oxo-flow >= 0.12.0**. The recommended way is the
prebuilt release binary:

```bash
curl -fL -o oxo-flow.tar.gz \
  https://github.com/Traitome/oxo-flow/releases/latest/download/oxo-flow-latest-x86_64-unknown-linux-gnu.tar.gz
tar xzf oxo-flow.tar.gz
sudo mv oxo-flow /usr/local/bin/
```

Alternatively via conda: `conda install -c bioconda oxo-flow-cli` (note: the
bioconda package may lag behind releases). Binaries for other platforms are on
the [releases page](https://github.com/Traitome/oxo-flow/releases).

### 2. Get this workflow

```bash
git clone https://github.com/oxo-flow-community/oxo-flow-eager.git
cd oxo-flow-eager
```

### 3. Requirements

Derived from `main.oxoflow`:

- **Input data** — a directory of paired-end FASTQ pairs,
  `test/fixtures/raw/<sample>_R1.fastq.gz` and `<sample>_R2.fastq.gz`
  (directory input mode; the sample name is the text before the `_R1`/`_R2`
  suffix). Point the workflow at your own directory via the rule inputs.
  Only paired-end reads are supported (the PE/SE-mixed merge branch of the
  upstream is not ported); set `single_end = false` (the default).
- **Optional — multi-lane input** (`run_lanemerge=true`): name the pairs
  `test/fixtures/raw/<sample>_L<lane>_R1.fastq.gz` / `_R2.fastq.gz` (the
  lane-tagged style of upstream's TSV input mode). The `lanemerge` /
  `lanemerge_r2` rules concatenate each sample's per-lane pairs into one
  merged pair (`results/lanemerging/`) that feeds AdapterRemoval (and
  `hostremoval_input_fastq`); samples whose files are not lane-tagged keep
  using the default-named pair. Requires **oxo-flow >= 0.16.0** with
  `input_groups` support (Traitome/oxo-flow#231); on older engines the gate
  is inert and the default single-pair path is unchanged.
- **Reference genome** — a **plain, uncompressed FASTA** via `fasta=...`
  (default: the bundled fixture `test/fixtures/reference/genome.fa`). The
  workflow builds the `.fai` index, the picard sequence dictionary and the
  BWA index itself into `results/reference_genome/`. A `.gz`-compressed FASTA
  is **not** supported (upstream's `unzip_reference` pre-step is not ported —
  pass a plain FASTA or the index rules fail).
- **Optional — genotyping** (off by default): enabling
  `run_genotyping=true genotyping_tool='pileupcaller'` requires
  `pileupcaller_snpfile=...` (SNP file) and `pileupcaller_bedfile=...`
  (BED file); the rule fails fast without them, mirroring upstream's
  exit-1 check.
- **Compute** — the largest rule needs **4 CPUs / 8 GB RAM**
  (`bwa_aln`); the reference-index and MultiQC rules use up to 8 GB
  (`make_seq_dict`, `make_bwa_index`, `multiqc`); the base-process default
  is 1 CPU / 7 GB / 24 h. Memory scales with the number of samples.
- **Tools** — the workflow runs every rule in a **single Docker container
  with a pinned image**, `nfcore/eager:2.5.3` (one image for all rules,
  matching upstream's `process.container`), so you need **Docker** (or
  Singularity, via oxo-flow's container support) at runtime. No manual
  conda environment setup: the container bundles the pinned conda tools
  documented in `envs/eager.yaml` (the upstream `environment.yml` verbatim).
  `validate`, `lint` and `dry-run` need no container — only a real run does.

## Usage

```bash
# 1. install oxo-flow (see Installation)
# 2. prepare data: test/fixtures/raw/<sample>_R1.fastq.gz / _R2.fastq.gz
#    (directory input mode; sample = text before the _R1/_R2 suffix)
# 3. preview the plan
oxo-flow dry-run main.oxoflow
# 4. run
oxo-flow run main.oxoflow -j 8
# 5. run a subset
oxo-flow run main.oxoflow -t multiqc --samples first:2
```

Key config knobs (all upstream defaults; `KEY=VALUE` overrides work):

- `skip_fastqc`, `skip_adapterremoval`, `skip_preseq`, `skip_deduplication`,
  `skip_damage_calculation`, `skip_qualimap` — skip QC steps
- `complexity_filter_poly_g=true` — enable the fastp poly-G filter
  (as upstream, only samples with 2-colour chemistry are filtered:
  also set `colour_chemistry=2`, e.g. NextSeq/NovaSeq; with the
  default `4` no sample is filtered, exactly as upstream)
- `dedupper='dedup'` — use DeDup instead of picard MarkDuplicates
- `run_genotyping=true genotyping_tool='pileupcaller'` — enable pileup
  genotyping; requires `pileupcaller_snpfile=... pileupcaller_bedfile=...`
  (the rule fails fast without them, mirroring upstream's exit-1 check)
- `fasta=...` — reference genome FASTA (default: bundled fixture)
- `clip_forward_adaptor` / `clip_reverse_adaptor` — adapter sequences
- `bwaalnn/bwaalnk/bwaalnl/bwaalno` — BWA aln parameters (Oliva et al. 2021)
- `run_lanemerge=true` — multi-lane input mode: merge each sample's
  `_L<lane>_`-tagged pairs before clipping (see Requirements; needs
  oxo-flow >= 0.16.0 with `input_groups` support)

## Source

Ported from **[nf-core/eager](https://github.com/nf-core/eager)**, version
`2.5.3` (MIT license), commit
`3f9d64ced5e287391bcd5517a0c40153a01268e5`. The port runs the same single
container as upstream (`nfcore/eager:2.5.3`, one image for all processes,
matching upstream's `process.container`) with the same pinned conda tool
versions (`envs/eager.yaml` is the upstream `environment.yml` verbatim).
Created 2026-08-15; this workflow may lag behind upstream releases. See
[NOTICE.md](NOTICE.md) for attribution.

## Fidelity

Every upstream process of nf-core/eager 2.5.3 (63 total: 56 top-level
processes plus 7 conditional/indented ones — `makeBWAIndex`,
`makeBT2Index`, `unzip_reference`, `seqtype_merge`, `mtnucratio`,
`nuclear_contamination`, `decomp_kraken`) is listed below.
The 17 processes on the default-parameters main path (directory input,
paired-end, `mapper=bwaaln`, `dedupper=markduplicates`) are ported
byte-faithfully. The non-default branches are ported as `rules/branches.oxoflow`
(each gated on its upstream param, off by default) — including the full
metagenomic screening chain (bbduk complexity filter, kraken, kraken_parse,
kraken_merge, malt, maltextract; note the old "needs the upstream's bundled
MALT install (no conda package)" exclusion reason was wrong — the upstream
`environment.yml` pins `bioconda::malt=0.61` and `bioconda::hops=0.35`, so
MALT and MaltExtract ship inside the pinned `nfcore/eager:2.5.3` container).
The multi-lane raw-level merges (`lanemerge`, `lanemerge_hostremoval_fastq`)
are ported as a gated mode (`run_lanemerge`, off by default) built on the
`input_groups` engine primitive (Traitome/oxo-flow#231, oxo-flow >= 0.16.0) —
see the rows below. The remaining `not ported` rows are the BAM-level
library/seqtype channel merges (the port's model has one library per sample),
the unported BAM pass-through mode (`indexinputbam`), or nf-core boilerplate
(`output_documentation`, `get_software_versions`).

| Upstream process | oxo-flow rule | Tool (version) | Notes |
|---|---|---|---|
| unzip_reference | `unzip_reference` | pigz 2.6 | `gunzip -c` into the canonical reference path; `when = config.unzip_reference` (default false — pass a plain FASTA as before) |
| makeFastaIndex | `make_fasta_index` | samtools 1.12 | `samtools faidx` verbatim. Port copies the input to `results/reference_genome/fasta_index/reference.fa` (canonical name; upstream publishes `<fasta-base>.fai` only when `--save_reference`) |
| makeSeqDict | `make_seq_dict` | picard 2.26.0 | `picard -Xmx8192M CreateSequenceDictionary` verbatim; output named `reference.dict` (upstream `<fasta-base>.dict`) |
| makeBWAIndex | `make_bwa_index` | bwa 0.7.17 | `cp` into `BWAIndex/` + `bwa index` verbatim; canonical file name `reference.fa` |
| fastqc | `fastqc` | fastqc 0.11.9 | `fastqc -t N -q r1 r2` + rename `*_fastqc.zip` → `*_raw_fastqc.zip` verbatim (per-instance scoped rename; zips moved to `zips/` like the upstream publishDir saveAs) |
| fastp | `fastp` | fastp 0.20.1 | Off by default, same as upstream (`complexity_filter_poly_g=false`). PE branch flags verbatim. **Upstream feeds fastp only the 2-colour-chemistry branch** (`ch_input_for_fastp.twocol`, main.nf lines 723-746): with the default `colour_chemistry=4` fastp runs on zero samples even when the flag is on. The port mirrors this gate (`when = complexity_filter_poly_g && colour_chemistry == 2`); use `colour_chemistry=2` to actually filter poly-G |
| adapter_removal | `adapter_removal` | adapterremoval 2.3.2, adapterremovalfixprefix 0.0.5, pigz 2.6 | Default PE collapse branch verbatim: `--collapse --trimns --trimqualities`, cat of the 5 gz parts (`<base>.pe.collapsed.gz` etc. — the `.pe` basename AR writes, as upstream), `AdapterRemovalFixPrefix \| pigz -p <cpus-1>`. The `cat` operands are explicit per-sample names (shared results dir; upstream globs the workdir). When fastp is enabled the input switches to the fastp outputs (upstream channel mix); the AR basename stays the default-path one (`{r1.baseName}_L0` with the `_R1` suffix as upstream derives it) |
| fastqc_after_clipping | `fastqc_after_clipping` | fastqc 0.11.9 | Verbatim; zips to `zips/` |
| bwa | `bwa_aln` | bwa 0.7.17, samtools 1.12 | Verbatim PE branch: `bwa aln -n/-l/-k/-o` (Oliva 2021 defaults), `bwa samse` with the eager `@RG` string, `samtools sort -@ <cpus-1>`, `samtools index`. `.sai` written into the mapping dir (upstream workdir-local) |
| bwamem | `bwamem` | bwa 0.7.17, samtools 1.12 | `bwa mem -t N` + sort + index with the eager @RG string; `when = config.mapper == 'bwamem'` |
| bowtie2 | `bowtie2` | bowtie2 2.4.4, samtools 1.12 | `bowtie2 -x reference -1/-2` + sort + index; `when = config.mapper == 'bowtie2'` |
| makeBT2Index | `make_bt2_index` | bowtie2 2.4.4 | `bowtie2-build` into `results/reference_genome/bt2_index/`; `when = config.mapper == 'bowtie2'` |
| circulargenerator | `circulargenerator` | circularmapper 1.93.5, bwa | `circulargenerator -e -i -s` + `bwa index` on the elongated fasta; `when = config.mapper == 'circularmapper'` |
| circularmapper | `circularmapper` | bwa + circularmapper 1.93.5 | `bwa aln` on the elongated reference + `realignsamfile` + sort/index; `when = config.mapper == 'circularmapper'` |
| convertBam | `convert_bam` | samtools 1.12, pigz | `samtools bam2fq | pigz`; `when = config.bam_input` (default false — the fixture is FASTQ) |
| indexinputbam | — | samtools 1.12 | not ported — indexes the input BAM for upstream's BAM pass-through mode (`bam != 'NA' && !run_convertinputbam`, main.nf 657); the port's BAM-input mode routes through `convert_bam` (bam2fq) instead and nothing downstream consumes the input BAM directly, so no index is needed |
| hostremoval_input_fastq | `hostremoval_input_fastq` | extract_map_reads.py (bundled) | PE branch verbatim (`-m`, `-of`/`-or`, `-t`); `when = config.hostremoval_input_fastq` |
| samtools_flagstat | `samtools_flagstat` | samtools 1.12 | Verbatim: `samtools flagstat > {libraryid}_flagstat.stats` |
| samtools_filter | `samtools_filter_{bwaaln,bwamem,bowtie2,circularmapper}` | samtools 1.12, pigz 2.6 | Four per-mapper rules sharing ONE output set; each is gated `when = config.run_bam_filtering && config.mapper == '<mapper>'` (mutually exclusive, so the released engine needs no any-mode semantics) and takes its mapper's mapped BAM as `BAM="{input[0]}"` (`results/mapping/bwa/{sample}_PE.mapped.bam` / `results/mapping/bwa/{sample}.mapped.bam` / `results/mapping/bt2/{sample}.mapped.bam` / `results/mapping/circularmapper/{sample}.mapped.bam`). The shared body carries the minreadlength-0 branches selected by `bam_unmapped_type`: `discard` (`-F4 -q <thr>`, default) and `fastq` (upstream `-f4` / `-F4 -q` + `samtools fastq -tN \| pigz -p <cpus-1>` + `rm`, the metagenomic-chain producer), both verbatim. The discard branch additionally writes an EMPTY `{sample}.unmapped.fastq.gz` placeholder — the engine requires every declared output to exist, and it is never consumed (the metagenomic rules are gated on `bam_unmapped_type == 'fastq'`). The `keep`/`bam`/`both` branches fail fast with a clear error; bwaaln variant live-verified on tx-ubuntu 2026-08-27 (run_bam_filtering=true, 15 succeeded / 0 failed) |
| samtools_flagstat_after_filter | `samtools_flagstat_after_filter` | samtools 1.12 | `samtools flagstat` on the filtered BAM; `when = config.run_bam_filtering` |
| picard_addorreplacereadgroups | `picard_addorreplacereadgroups` | picard 2.26.0, samtools | verbatim RG replacement for MultiVCFAnalyzer; `when = run_genotyping && genotyping_tool == 'ug' && run_multivcfanalyzer` |
| markduplicates | `markduplicates` | picard 2.26.0, samtools 1.12 | Default dedupper. picard MarkDuplicates verbatim (`-Xmx4096M`, `REMOVE_DUPLICATES=TRUE AS=TRUE`, `VALIDATION_STRINGENCY=SILENT`) + `samtools index`. INPUT points at the mapped BAM directly instead of upstream's workdir-local `mv {bam} {libraryid}.bam` rename (the shared results dir must keep the mapped BAM for preseq/flagstat) |
| dedup | `dedup` | dedup 0.12.8, samtools 1.12 | Alternative dedupper (off by default, `dedupper='dedup'`). Verbatim: `dedup -Xmx4g -i ... -o . -u`, `mv *.log dedup.log`, in-place `samtools sort`, index. Upstream's `mv {bam} {libraryid}.bam` becomes a `cp` (shared-results-dir equivalent, same effect) |
| preseq | `preseq` | preseq 3.1.2 | Verbatim default branch: `preseq c_curve -s 1000 -o <base>.preseq -B <mapped bam>`. The `-H` (dedup mode) and `lc_extrap` branches are the alternate `preseq_mode`/`dedupper` combinations |
| bedtools | `bedtools_coverage` | bedtools 2.30.0, pigz | verbatim genome.txt + `bedtools coverage` breadth/depth; `when = config.run_bedtools_coverage` |
| damageprofiler | `damageprofiler` | damageprofiler 0.4.9 | Verbatim: `-Xmx4g -i <rmdup bam> -r <fasta> -l 100 -t 15 -o . -yaxis_damageplot 0.30`; output lands in `results/damageprofiler/<bam-basename>/` as upstream |
| mapdamage_calculation | `mapdamage_calculation` | mapdamage2 2.2.1 | verbatim `mapDamage -i -r --ymax --no-stats`; `when = !skip_damage_calculation && damage_calculation_tool == 'mapdamage'` |
| mapdamage_rescaling | `mapdamage_rescaling` | mapdamage2 2.2.1, samtools | verbatim `--rescale --rescale-out --seq-length` + index; `when = config.run_mapdamage_rescaling` |
| mask_reference_for_pmdtools | `mask_reference_for_pmdtools` | bedtools 2.30.0 | `bedtools maskfasta`; `when = pmdtools_reference_mask && run_pmdtools` |
| pmdtools | `pmdtools` | pmdtools 0.60, samtools | verbatim calmd|pmdtools filter + range chain incl. the 141 trap; `when = config.run_pmdtools` |
| bam_trim | `bam_trim` | bamutil 1.0.15, samtools | `bam trimBam -L -R` (double-stranded none-UDG clip values) + sort/index; `when = config.run_trim_bam` |
| post_ar_fastq_trimming | `post_ar_fastq_trimming` | fastp 0.20.1 | PE branch verbatim (`--trim_front1/2 --trim_tail1/2`); `when = config.run_post_ar_trimming` |
| lanemerge | `lanemerge` + `lanemerge_r2` | cat (pigz 2.6) | ported as a gated mode (`run_lanemerge=true`, off by default): the two rules group each sample's lane-tagged pairs (`{sample}_L{lane}_R{1,2}.fastq.gz`) via `input_groups` (group_by = sample, keep = lane; Traitome/oxo-flow#231, oxo-flow >= 0.16.0) and `cat` the pair into one merged fastq (`results/lanemerging/{sample}_R{1,2}_lanemerged.fq.gz`) consumed by fastp / adapter_removal / hostremoval_input_fastq. Deviations: upstream merges the per-library collapsed fastqs AFTER AdapterRemoval (main.nf 1125) and only merges R2 when `single_end=false`; the port merges the raw per-lane pairs pre-clipping (the raw-level `lanemerge_hostremoval_fastq` semantics) and always merges R2 (the port is pure-PE). Samples without lane-tagged files are untouched; with the gate off (or on a released engine without `input_groups`) the default single-pair path is byte-identical, and a fail-fast `{input}` guard prevents silently empty merges. Merged-content E2E passed locally 2026-08-27 (byte-identical to the single-pair inputs); full container run queued for tx-ubuntu |
| lanemerge_hostremoval_fastq | `hostremoval_input_fastq` (shell switch) | extract_map_reads.py (bundled) | ported as part of the gated mode: when `run_lanemerge=true` the rule feeds the merged pair from `results/lanemerging/` instead of the raw one — upstream's raw-level merge-into-hostremoval semantics (main.nf 1197). Without lane-tagged files the raw pair is used, exactly as before |
| library_merge | — | samtools 1.12 | not ported — structural: upstream merges the per-LIBRARY dedup BAMs of a sample (`samtools merge`, main.nf 1967); the port's directory-input model has ONE library per sample (library = sample, lane = 0) and one BAM per sample at every stage, so there are no multi-library BAMs to merge. `input_groups` cannot express it either — it groups FILES of a pattern, and the port has no per-library file dimension. Declare each library as its own sample (or pre-merge) before running |
| additional_library_merge | — | samtools 1.12 | not ported — structural: same constraint as `library_merge` (merges the per-library bam_trim BAMs, main.nf 2320); the port has one BAM per sample per stage |
| seqtype_merge | — | samtools 1.12 | not ported — structural: upstream merges the per-seqtype mapped BAMs of mixed PE/SE libraries into one BAM per library (`samtools merge`, main.nf 1597); the port is pure-PE (sample = text before `_R1`/`_R2`) with one mapped BAM per sample, so there are no mixed-PE/SE BAMs to merge. Convert SE samples to PE or run SE-only samples separately |
| qualimap | `qualimap` | qualimap 2.2.2d | Default path, ported: `qualimap bamqc -bam <rmdup bam> -nt 2 -outdir . -outformat "HTML" --java-mem-size=4G` verbatim; output lands in `results/qualimap/<bam-base>_bamqc/` as upstream |
| genotyping_pileupcaller | `genotyping_pileupcaller` | samtools 1.12, sequencetools 1.5.2 | Off by default, same as upstream (`run_genotyping=false`). Verbatim: `samtools mpileup -B --ignore-RG -q 30 -Q 30 [-l <bed>] -f <fasta> <bams> \| pileupCaller --randomHaploid --sampleNames <csv> [-f <snp>] -e pileupcaller.double` (single-instance fan-in; `-e` prefix `pileupcaller.double` = PE strandedness). `-l`/`-f` render only when `pileupcaller_bedfile`/`pileupcaller_snpfile` are set, exactly as upstream's dummy-file check (main.nf lines 2608-2609); without them the rule fails fast with upstream's error message — upstream exits 1 at workflow start (main.nf lines 74-78), the port's guard lives in the rule shell because oxo-flow has no params-validation stage |
| genotyping_ug | `genotyping_ug` | gatk3 3.5, bgzip | verbatim RealignerTargetCreator → IndelRealigner → UnifiedGenotyper → bgzip; `when = run_genotyping && genotyping_tool == 'ug'` |
| genotyping_hc | `genotyping_hc` | gatk4 4.2.0.0, bgzip | verbatim HaplotypeCaller flags + bgzip; `when = run_genotyping && genotyping_tool == 'hc'` |
| genotyping_freebayes | `genotyping_freebayes` | freebayes 1.3.5, bgzip | verbatim `freebayes -f -p -C [-g]` + bgzip; `when = run_genotyping && genotyping_tool == 'freebayes'` |
| genotyping_angsd | `genotyping_angsd` | angsd 0.935 | verbatim bam.filelist + `angsd -GL -doGlF`; `when = run_genotyping && genotyping_tool == 'angsd'` |
| bcftools_stats | `bcftools_stats` | bcftools 1.12 | `bcftools stats <vcf.gz> -F <fasta>`; `when = config.run_bcftools_stats` (source VCF via `bcftools_stats_source`) |
| eigenstrat_snp_coverage | `eigenstrat_snp_coverage` | eigenstratdatabasetools 1.0.2, python 3.9.4 | Off by default, same as upstream. Verbatim: `eigenstrat_snp_coverage -i pileupcaller.double >double_eigenstrat_coverage.txt` + `parse_snp_cov.py` (bundled upstream script, called via `python3 scripts/parse_snp_cov.py` — oxo-flow does not auto-add `bin/` to PATH) |
| metagenomic_complexity_filter | `metagenomic_complexity_filter` | bbduk 38.92 | verbatim `bbduk.sh -Xmx<g>g in=... threads=N entropymask=f entropy=<entropy> out=<in>_lowcomplexityremoved.fq.gz 2> <in>_bbduk.stats` — the output keeps upstream's `${input}_lowcomplexityremoved.fq.gz` naming; `when = metagenomic_complexity_filter && run_bam_filtering && bam_unmapped_type == 'fastq'` (upstream validates the same combination at workflow start, main.nf 115-122) |
| malt | `malt` | malt 0.61 | verbatim `malt-run -J-Xmx<g>g -t N -v -o . -d <db> [-a . -f SAM] -id -m -at -top <min-supp> -mq --memoryMode -i <all fastqs>` — one instance over ALL samples' unmapped reads (upstream `collect()`); reads the entropy-filtered fastqs when the complexity filter is on (upstream channel switch); `--database` is split into `malt_db` + `kraken2_db`; the percent/reads min-support exclusivity check (main.nf 129-134) is a shell guard; the per-input `.rma6` outputs are undeclared (no fixed template) — only `malt.log` is declared; NOT yet live-verified; `when = run_metagenomic_screening && run_bam_filtering && bam_unmapped_type == 'fastq' && metagenomic_tool == 'malt'` |
| maltextract | `maltextract` | hops 0.35 | verbatim `MaltExtract -Xmx<g>g -t <taxon_list> -i <rma6s> -o results/ -r <ncbifiles> -p N -f -a --minPI <flags>` + `postprocessing.AMPS.r -r results/ -m -t N -n <taxon_list> -j`; requires `maltextract_taxon_list` + `maltextract_ncbifiles` (fail-fast guard); consumes the rma6s via glob with a DAG edge through `malt.log`; NOT yet live-verified; `when = run_maltextract && metagenomic_tool == 'malt'` (upstream verbatim) |
| kraken | `kraken` | kraken2 2.1.2 | verbatim `kraken2 --db <db> --threads N --output <prefix>.kraken.out --report-minimizer-data --report <prefix>.kraken2_report <fastq>` + `cut -f1-3,6-8 > <prefix>.kreport`; reads the entropy-filtered fastq when the complexity filter is on (upstream channel switch); the output prefix is normalized to `{sample}.unmapped.fastq` in both branches (upstream prefixes by the input basename — see deviations); live-verified on tx-ubuntu 2026-08-27 (synthetic 2-taxon kraken2 DB built in-container via `kraken2-build --add-to-library` with `kraken:taxid|` headers; 14/14 injected alien reads classified as *Alienus syntheticus*, 18 succeeded / 0 failed); `when = run_metagenomic_screening && run_bam_filtering && bam_unmapped_type == 'fastq' && metagenomic_tool == 'kraken'` |
| kraken_parse | `kraken_parse` | python 3.9.4 | verbatim `kraken_parse.py -c <min_support_reads> -or <read csv> -ok <kmer csv> <kreport>` (upstream script bundled in `scripts/`, called via `python3 scripts/kraken_parse.py` — oxo-flow does not auto-add `bin/` to PATH); gated on the same `when` as kraken (upstream no-ops the process via an empty channel); live-verified on tx-ubuntu 2026-08-27 (same run as kraken) |
| kraken_merge | `kraken_merge` | python 3.9.4 | verbatim `merge_kraken_res.py -or kraken_read_count.csv -ok kraken_kmer_duplication.csv` (upstream script bundled in `scripts/`; it scans the working dir for the per-sample CSVs, which the fan-in gathers into one instance); gated on the same `when` as kraken; live-verified on tx-ubuntu 2026-08-27 (same run as kraken) |
| decomp_kraken | `kraken` (folded in) | kraken2 2.1.2 | folded into the kraken shell: a `.tar.gz` `kraken2_db` is unpacked in place (`tar xzf`, `mkdir -p <db>`, `mv *.k2d <db>/`) — no when-expression can test a filename suffix (deviation, documented below) |
| sexdeterrmine | `sexdeterrmine` | sexdeterrmine 1.1.2 | verbatim sexdeterrmine.py run; `when = config.run_sexdeterrmine` |
| sexdeterrmine_prep | `sexdeterrmine_prep` | sexdeterrmine 1.1.2 | verbatim sexdeterrmine_prep.py; `when = config.run_sexdeterrmine` |
| mtnucratio | `mtnucratio` | sequencetools 1.5.2 | verbatim `mtnucratio -Xmx`; `when = config.run_mtnucratio` |
| nuclear_contamination | `nuclear_contamination` | angsd 0.935 (contaminationX) | verbatim contaminationX invocation; `when = config.run_nuclear_contamination` |
| endorSpy | `endor_spy` | endorSpy | `endorS.py -o json -n <sample> <flagstat>`; `when = config.run_endor_spy` (upstream runs it unconditionally; the port gates it to keep the default path unchanged) |
| print_nuclear_contamination | `print_nuclear_contamination` | grep | report row extraction; `when = config.run_nuclear_contamination` |
| multivcfanalyzer | `multivcfanalyzer` | multivcfanalyzer 0.85.2, pigz | verbatim cohort run over all UG VCFs (expand_inputs over `multivcf_samples`); `when = run_genotyping && genotyping_tool == 'ug' && run_multivcfanalyzer` |
| vcf2genome | `vcf2genome` | vcf2genome 0.91, pigz | verbatim consensus call incl. refMod/uncertainty fastas; `when = config.run_vcf2genome` |
| multiqc | `multiqc` | multiqc 1.16 | `multiqc -f --config assets/multiqc_config.yaml .` (the upstream `--title/--filename` run-name flags are nf-core boilerplate and are dropped). Module files are staged into per-module subdirs mirroring the upstream multiqc process inputs; staging is guarded so skipped modules are simply absent. Report at `results/multiqc/multiqc_report.html` |
| output_documentation | — | — | not ported — nf-core boilerplate docs process (markdown_to_html.py of static run docs); upstream runs it unconditionally, so porting it would change the default plan for zero analytical value |
| get_software_versions | — | — | not ported — nf-core boilerplate versions process (scrapes `$workflow`/`$nextflow` native variables into a versions.yml; a versions.yml has no oxo-flow equivalent, and `scrape_software_versions.py` targets Nextflow env vars) |

Additional deviations from upstream (all on the default path):

- The `publishDir` mechanism has no oxo-flow equivalent: outputs are written
  directly at the `results/...` paths upstream publishes to (see
  `output = [...]` in `main.oxoflow`); `publish_dir_mode`/`saveAs` are
  folded into the shells where they rename files.
- Reference files use the canonical name `reference.fa` (and
  `reference.dict`) in `results/reference_genome/` instead of the input
  fasta basename; all reference-consuming rules point at those copies.
- Upstream labels are baked into per-rule `[rules.resources]`:
  `sc_tiny` 1 cpu/1G/4h, `sc_small` 1/4G, `sc_medium` 1/8G, `mc_small`
  2/4G, `mc_medium` 4/8G, plus the base-process default (1 cpu/7G/24h)
  used by the undefined `mc_tiny` label (eigenstrat_snp_coverage).
  JVM heaps are byte-identical (`-Xmx8192M`, `-Xmx4096M`, `-Xmx4g`,
  `--java-mem-size=4G`).
- Gated-mode deviations (`run_lanemerge=true`, off by default):
  - upstream runs `lanemerge` on the per-library collapsed fastqs AFTER
    AdapterRemoval (main.nf 1125, a small post-collapse cat of the `.pe`
    pair); the port merges the raw per-lane pairs BEFORE clipping (the
    `lanemerge_hostremoval_fastq` raw-level semantics, main.nf 1197) so
    that clipping, mapping, dedup, damage and QC all run on the merged
    pair exactly once. The lane-tagged naming (`{sample}_L{lane}_R{1,2}`)
    is upstream's TSV input-mode style; upstream detects multi-lane from
    the sample sheet, the port gates on `run_lanemerge` (auto-detection
    from filenames is impossible for a when-expression). Only R1 was
    upstream's documented lanemerge concern; the port merges R2 as well
    (pure-PE, both ends must exist).
  - `fastqc` runs on the merged pair in gated mode (twin rule
    `fastqc_lanemerged` with an exclusive when-gate); upstream runs
    FastQC on the per-lane input fastqs.
  - samples with lane-tagged files mixed with default-named files in one
    directory: lane-tagged samples flow through the merged path, the
    others through the default path (shell existence-check switch in
    fastp / adapter_removal / hostremoval_input_fastq).
  - local E2E 2026-08-27 (dev engine, no container): merged pairs
    byte-identical to the single-pair inputs (S1: 3635 reads, S2: 3602
    reads, R1/R2 counts equal). Full container run queued for tx-ubuntu
    (docker daemon unavailable on the authoring machine).
- Metagenomic-chain deviations (`rules/branches.oxoflow` B32-B37, all off by
  default):
  - upstream's run-level validation (main.nf 115-137) becomes rule gates +
    fail-fast shell guards (oxo-flow has no params-validation stage).
  - `kraken_parse`/`kraken_merge` carry the same `when` as `kraken`
    (upstream no-ops them via empty channels).
  - `decomp_kraken` (`.tar.gz` kraken2 DB unpack) is folded into the
    `kraken` shell — no when-expression can test a filename suffix.
  - the kraken output prefix is normalized to `{sample}.unmapped.fastq`
    in both filter branches (upstream prefixes by the input basename,
    which differs when the complexity filter is on).
  - MALT `.rma6` outputs are undeclared (per-input names, no fixed
    template; `.sai` precedent); only `malt.log` is declared and
    `maltextract` consumes the rma6s via glob with a DAG edge through
    `malt.log`.
  - upstream's single `--database` param is split into `malt_db` and
    `kraken2_db`.
  - each `samtools_filter_<mapper>` variant writes an empty `{sample}.unmapped.fastq.gz`
    placeholder in discard mode (engine output-existence contract; never
    consumed — the metagenomic rules are gated on `bam_unmapped_type == 'fastq'`).
  - the kraken metagenomic chain (kraken/kraken_parse/kraken_merge) is
    live-verified on tx-ubuntu 2026-08-27 with a synthetic 2-taxon
    kraken2 DB (build recipe: `kraken2-build --add-to-library` with
    `kraken:taxid|N|` sequence headers — a manual `seqid2taxid.map`
    alone builds an EMPTY table, and the map must be sorted);
    `bam_unmapped_type=fastq` + `run_bam_filtering` + 
    `run_metagenomic_screening` + `metagenomic_tool=kraken`, 18
    succeeded / 0 failed. The MALT half (malt/maltextract) remains NOT
    live-verified (needs a MALT index DB, not yet available on the test
    server).
- A `.gz`-compressed reference FASTA is not supported (upstream's
  `unzip_reference` pigz pre-step is not ported): pass a plain FASTA.
- Upstream's startup parameter validation (e.g. the pileupCaller
  bed/snp exit-1 check, main.nf lines 74-78) has no oxo-flow
  equivalent: the checks live as fail-fast guards at the top of the
  affected rule shells (`genotyping_pileupcaller`), so an invalid
  invocation fails when the rule runs rather than at workflow start.
- Upstream `errorStrategy retry` (signals 143/137/104/134/139/140, max 3)
  and the exit-1 retry on dedup/markduplicates/damageprofiler/qualimap are
  not ported (oxo-flow has no signal-based retry); `preseq`'s
  `errorStrategy 'ignore'` is likewise not ported.
- The conditional `preserve5p`/`mergedonly` AR branches (both off by
  default) are not ported; their config keys are kept with upstream
  defaults.
- `run_pmdtools`, `run_trim_bam`, `run_post_ar_trimming`,
  `run_mapdamage_rescaling`, `run_bedtools_coverage`, `run_vcf2genome`,
  `run_multivcfanalyzer`, `run_sexdeterrmine`, `run_mtnucratio`,
  `run_nuclear_contamination`, `run_endorSpy`, `run_convertinputbam`,
  `run_hostremoval` and the non-default mapper/dedupper/damage-tool/
  genotyping-tool choices are all ported as the gated branch rules above
  (the port's keys are `run_endor_spy`, `bam_input` and
  `hostremoval_input_fastq` where the upstream names `run_endorSpy`,
  `run_convertinputbam` and `hostremoval_input_fastq` differ);
  `run_bam_filtering` (incl. the metagenomic screening chain under
  `run_metagenomic_screening` with `metagenomic_tool` = `kraken`/`malt`) IS
  ported. Default values are kept in `[config]` where a config key exists.

## Test

```bash
bash test/run.sh
```

Runs `validate`, `lint` (warnings acceptable, errors not), a `dry-run`
that must execute, and a debug check that no literal `{wildcards}` leak
into expanded commands. CI runs the same script on every push.

## Live verification (tx-ubuntu, oxo-flow 0.14.1, eager docker image 2.5.3)

All 14 branch smoke steps live-passed on the mini fixture:

| Step | Branch | Status |
|---|---|---|
| E1 | default path (regression) | ✅ |
| E2 | mapper = bwamem | ✅ |
| E3 | mapper = bowtie2 | ✅ |
| E4 | run_bam_filtering | ✅ |
| E5 | run_endor_spy | ✅ |
| E6 | run_post_ar_trimming | ✅ |
| E7 | damage_calculation_tool = mapdamage | ✅ |
| E8 | run_mapdamage_rescaling | ✅ |
| E9 | run_trim_bam | ✅ |
| E10 | run_pmdtools | ✅ |
| E11 | genotyping = freebayes | ✅ |
| E12 | genotyping = hc | ✅ |
| E13 | run_bcftools_stats | ✅ |
| E14 | run_mtnucratio (mini fallback — no MT contig in the fixture) | ✅ |

The metagenomic chain (E15: `bam_unmapped_type=fastq` +
`metagenomic_complexity_filter` + kraken; E16: malt + maltextract) is not
part of the live-verified set yet — it passes `validate`/`dry-run` and needs
a real MALT/kraken database on the test server.

## License

Apache-2.0. Copyright (c) 2026 oxo-flow-community. This workflow is a port
of [nf-core/eager](https://github.com/nf-core/eager) (MIT); upstream
attribution in [NOTICE.md](NOTICE.md), upstream license text in
[LICENSE.upstream](LICENSE.upstream).
