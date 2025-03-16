#!/bin/bash
apptainer exec --fakeroot --nv \
  --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/features_db:/mnt/features_db \
  --bind /lus/eagle/projects/RAPINS/APACE/data_hyun_official/:/mnt/alphafold_data \
  --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/input:/mnt/input \
  --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/output:/mnt/output \
 ./alphapulldown.sif \
  python /app/AlphaPulldown/alphapulldown/scripts/run_multimer_jobs.py \
    --mode=custom \
    --monomer_objects_dir=/mnt/features_db \
    --data_dir=/mnt/alphafold_data \
    --protein_lists=/mnt/input/test_protein_list.txt \
    --output_path=/mnt/output \
    --num_cycle=3 \
    --num_predictions_per_model=1 \
    --models_to_relax=All

# Features calculation script create_individual_features.py has several optional FLAGS: