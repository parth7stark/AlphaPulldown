#!/bin/bash
apptainer exec --fakeroot \
--bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/input:/mnt/fasta_inputs \
--bind /lus/eagle/projects/RAPINS/APACE/data_hyun_official/:/mnt/alphafold_data \
--bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/output:/mnt/output \
./alphapulldown.sif \
  python /app/AlphaPulldown/alphapulldown/scripts/create_individual_features.py \
    --fasta_paths=/mnt/fasta_inputs/hAGTR1_hANGTx25x32.fasta \
    --data_dir=/mnt/alphafold_data \
    --output_dir=/mnt/output \
    --max_template_date=2025-01-01

# Features calculation script create_individual_features.py has several optional FLAGS: