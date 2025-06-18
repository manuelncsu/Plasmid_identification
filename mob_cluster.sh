#!/usr/bin/env bash
# run_mobsuite_batch.sh  — MOB-suite v3.1.8+ workflow
# ------------------------------------------------------------
# For every *.fna / *.fna.gz assembly in $ASM_DIR:
#   1) mob_recon    → plasmid & chromosome bins
#   2) mob_typer    → Inc, MOB class, MPF, mobility, pMLST
#   3) Collect all plasmid bins into one FASTA with unique IDs
#   4) mob_cluster → 95 % ANI clusters, append ClusterID column
#   5) Produce all_mobtyper_withCluster.{tsv,csv}
# ------------------------------------------------------------

set -euo pipefail
shopt -s nullglob

############################ CONFIG ############################
ASM_DIR="assemblies"      # folder with *.fna OR *.fna.gz
OUT_DIR="mob_batch"
CPU_PER_JOB=8             # threads per sample / clustering
JOBS=4                    # parallel assemblies (adjust to CPU cores)
###############################################################

mkdir -p "$OUT_DIR"

##################### per-sample function ######################
run_one() {
    asm="$1"
    sample=$(basename "$asm"); sample=${sample%%.fna*}    # strip .fna(.gz)
    out="$OUT_DIR/$sample"
    mkdir -p "$out"

    echo "[${sample}]  mob_recon …"
    mob_recon -i "$asm" -o "$out" -n "$CPU_PER_JOB" --force

    echo "[${sample}]  mob_typer …"
    mob_typer  -i "$asm" \
               -o "$out/mobtyper_results.txt" \
               -n "$CPU_PER_JOB"
}
export -f run_one
export OUT_DIR CPU_PER_JOB
###############################################################

echo "==> Processing $(ls "$ASM_DIR"/*.fna* | wc -l) assemblies"
parallel -j "$JOBS" run_one ::: "$ASM_DIR"/*.fna*

# ------------------------------------------------------------
# 1. Merge mob_typer summaries
merged_raw="$OUT_DIR/all_mobtyper_raw.tsv"
echo -e "Sample\tPlasmid\tReplicon\tMOB\tMPF\tMobility\tpMLST" > "$merged_raw"

# Use a while loop with find to process each file and prepend the sample name
find "$OUT_DIR" -type f -name 'mobtyper_results.txt' | while read -r mobtyper_file; do
    sample=$(basename "$(dirname "$mobtyper_file")") # Extract sample name from parent directory
    # Skip header (NR==1) and prepend sample name to each line
    awk -v s="$sample" 'NR==1{next} {print s"\t"$0}' "$mobtyper_file" >> "$merged_raw"
done

# ------------------------------------------------------------
# 2. Build ONE multi-FASTA of plasmid bins with unique IDs
ALL_PLS="$OUT_DIR/all_plasmids.fasta"
: > "$ALL_PLS"      # truncate / create file

find "$OUT_DIR" -type f -name 'plasmid_*.fasta' | while read -r pf; do
    sample=$(basename "$(dirname "$pf")")        # parent folder = sample
    # Replace header ">" with ">sample|original_header"
    awk -v s="$sample" 'BEGIN{OFS=""}
        /^>/{sub(/^>/,">"s"|"); print; next}
        {print}' "$pf" >> "$ALL_PLS"
done
PLASMID_COUNT=$(grep -c '^>' "$ALL_PLS")

# ------------------------------------------------------------
# 3. Cluster plasmids & append ClusterID
if (( PLASMID_COUNT > 0 )); then
  echo "==> Clustering $PLASMID_COUNT plasmids"
  mob_cluster \
      --mode build \
      --infile "$ALL_PLS" \
      --mob_typer_file "$merged_raw" \
      --taxonomy all \
      --outdir "$OUT_DIR/cluster_all" \
      --num_threads "$CPU_PER_JOB"

  CLMAP="$OUT_DIR/cluster_all/plasmid_clusters.txt"

  echo "==> Merging ClusterID into final table"
  awk 'FNR==NR{cid[$1]=$2; next}
       FNR==1{print $0"\tClusterID"; next}
       {print $0"\t" ( ($2 in cid)?cid[$2]:"NA") }' \
       "$CLMAP" "$merged_raw" \
       > "$OUT_DIR/all_mobtyper_withCluster.tsv"
else
  echo "==> No plasmids detected; skipping clustering"
  cp "$merged_raw" "$OUT_DIR/all_mobtyper_withCluster.tsv"
fi

# ------------------------------------------------------------
# 4. Optional CSV copy
csvtk tsv2csv "$OUT_DIR/all_mobtyper_withCluster.tsv" \
      > "$OUT_DIR/all_mobtyper_withCluster.csv"

echo "✓ Pipeline finished"
echo "    Final tables:"
echo "    $OUT_DIR/all_mobtyper_withCluster.tsv"
echo "    $OUT_DIR/all_mobtyper_withCluster.csv"