#!/usr/bin/env python3
"""
merge_mobtyper_results.py

Aggregate MOB-suite mobtyper_results.txt files from many isolate folders.
"""

from pathlib import Path
import pandas as pd

# ── 1. Top-level directory that holds one subfolder per isolate ────────────────
TOP_DIR     = Path("/home/manueljara/Documents/0_ML_AMR_project/Plasmid_analysis/mob_batch")
OUTPUT_FILE = Path("combined_mobtyper_results.csv")   # use .tsv if you prefer

# ── 2. Gather all mobtyper_results.txt files ───────────────────────────────────
mob_files = sorted(TOP_DIR.glob("*/mobtyper_results.txt"))

if not mob_files:
    raise SystemExit(f"No mobtyper_results.txt files found under {TOP_DIR}")

print(f"Found {len(mob_files)} mobtyper result files.")

# ── 3. Read, tag with Sample_ID, accumulate ───────────────────────────────────
frames = []
for f in mob_files:
    df = pd.read_csv(f, sep="\t")      # mobtyper outputs tab-separated text
    sample_id = f.parent.name          # folder name = isolate ID
    df.insert(0, "Sample_ID", sample_id)
    frames.append(df)

# ── 4. Concatenate and save ───────────────────────────────────────────────────
combined = pd.concat(frames, ignore_index=True)

sep = "\t" if OUTPUT_FILE.suffix.lower() == ".tsv" else ","
combined.to_csv(OUTPUT_FILE, sep=sep, index=False)

print(f"Combined MOB-suite table written to {OUTPUT_FILE} "
      f"(rows: {combined.shape[0]}, columns: {combined.shape[1]})")
