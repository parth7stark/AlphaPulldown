#!/bin/bash
#PBS -l select=1:system=polaris
#PBS -l place=exclhost
#PBS -l filesystems=home:eagle
#PBS -q debug
#PBS -N test_new_IP_function
#PBS -l walltime=00:10:00
#PBS -k doe
#PBS -j oe
#PBS -A RAPINS
#PBS -M pp32@illinois.edu
#PBS -m abe

ml use /soft/modulefiles
ml spack-pe-base/0.8.1
ml use /soft/spack/testing/0.8.1/modulefiles
ml apptainer/main
ml load e2fsprogs

export BASE_SCRATCH_DIR=/local/scratch/ # For Polaris
export APPTAINER_TMPDIR=$BASE_SCRATCH_DIR/apptainer-tmpdir
mkdir -p $APPTAINER_TMPDIR

export APPTAINER_CACHEDIR=$BASE_SCRATCH_DIR/apptainer-cachedir
mkdir -p $APPTAINER_CACHEDIR

# For internet access
export HTTP_PROXY=http://proxy.alcf.anl.gov:3128
export HTTPS_PROXY=http://proxy.alcf.anl.gov:3128
export http_proxy=http://proxy.alcf.anl.gov:3128
export https_proxy=http://proxy.alcf.anl.gov:3128

apptainer version

MAXRAM=500000
GPUMEM=`nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits|tail -1`
echo "GPUMEM: $GPUMEM"
export XLA_PYTHON_CLIENT_MEM_FRACTION=`echo "scale=3;$MAXRAM / $GPUMEM"|bc`
export TF_FORCE_UNIFIED_MEMORY='1'

# Getting the node names
nodes=$(cat "$PBS_NODEFILE")
nodes_array=($nodes)

echo "nodes list $nodes"

head_node=${nodes_array[0]}

echo "head_node: $head_node"
head_node_ip=$(getent hosts $head_node | awk '{print $1}' | head -n 1)

port=6379
ip_head=$head_node_ip:$port
export ip_head
echo "IP Head: $ip_head"

export head_node_ip
export port
export RAY_TMPDIR="/tmp"

cd /lus/eagle/projects/RAPINS/parth/AlphaPulldown

# below line scheduled all ray predict to core 33
mpiexec -n 1 --ppn 1 --depth=32 --cpu-bind depth --env OMP_NUM_THREADS=32 --env OMP_PLACES=threads \
apptainer exec --fakeroot --nv \
  --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/features_db:/mnt/features_db \
  --bind /lus/eagle/projects/RAPINS/APACE/data_hyun_official/:/mnt/alphafold_data \
  --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/input:/mnt/input \
  --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/output/ray:/mnt/output \
 ./alphapulldown.sif \
  /app/AlphaPulldown/alphapulldown/run_structure_prediction_polaris.sh \
    --mode=custom \
    --monomer_objects_dir=/mnt/features_db \
    --data_dir=/mnt/alphafold_data \
    --protein_lists=/mnt/input/test_protein_list.txt \
    --output_path=/mnt/output \
    --num_cycle=3 \
    --num_predictions_per_model=1 \
    --models_to_relax=All \
    --fold_backend=APACE \
    --model_preset=multimer \
    --random_seed=42

# command: ['python3 /app/AlphaPulldown/alphapulldown/scripts/run_structure_prediction.py', '--output_directory', '/mnt/output', '--num_cycle', '3', '--num_predictions_per_model', '1', '--data_directory', '/mnt/alphafold_data', '--features_directory', '/mnt/features_db', '--pair_msa', '', '--nomsa_depth_scan', '', '--nomultimeric_template', '', '--fold_backend', 'APACE', '--nocompress_result_pickles', '', '--noremove_result_pickles', '', '--remove_keys_from_pickles', '', '--use_ap_style', '', '--use_gpu_relax', '', '--protein_delimiter', '+', '--models_to_relax', 'All', '--random_seed', '42', '--input', 'P30556+P01019:25-32']

    

# Features calculation script create_individual_features.py has several optional FLAGS:
