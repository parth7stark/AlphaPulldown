#!/bin/bash -l
#PBS -l select=2:system=polaris
#PBS -l place=exclhost
#PBS -l filesystems=home:eagle
#PBS -q debug-scaling
#PBS -N test_multi_node_separate_protein_list
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
nodes=$(cat "$PBS_NODEFILE" | sort -u)
nodes_array=($nodes)

echo "Allocated nodes: $nodes"
node_count=${#nodes_array[@]}
echo "Number of nodes: $node_count"

# List of protein files - adjust these paths to your actual protein lists
protein_lists=(
  "/mnt/input/protein_list_1.txt"
  "/mnt/input/protein_list_2.txt" 
  "/mnt/input/protein_list_3.txt"
  # Add more as needed
)
# Need to have /mnt to maintain earlier format
# --protein_lists=/mnt/input/test_protein_list.txt \

cd /lus/eagle/projects/RAPINS/parth/AlphaPulldown

# Launch one container per node with its own protein list
for (( i=0; i<${node_count}; i++ )); do
  if [ $i -lt ${#protein_lists[@]} ]; then
    current_node=${nodes_array[$i]}
    protein_list=${protein_lists[$i]}
    
    echo "Starting job on node $current_node with protein list: $protein_list"
    
    # Set the current node as its own head node
    head_node_ip=$(getent hosts $current_node | awk '{print $1}' | head -n 1)
    port=6379
    ip_head=$head_node_ip:$port
    
    echo "Node $current_node using head_node_ip: $head_node_ip and ip_head: $ip_head"
    
    # Launch the job on the specific node
    mpiexec -n 1 --ppn 1 --depth=32 --cpu-bind depth \
      --hosts $current_node \
      --env OMP_NUM_THREADS=32 \
      --env OMP_PLACES=threads \
      --env head_node_ip=$head_node_ip \
      --env ip_head=$ip_head \
      --env port=$port \
      --env RAY_TMPDIR="/tmp" \
      apptainer exec --fakeroot --nv \
        --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/features_db/Homo_sapiens/:/mnt/features_db \
        --bind /lus/eagle/projects/RAPINS/APACE/data_hyun_official/:/mnt/alphafold_data \
        --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/input:/mnt/input \
        --bind /lus/eagle/projects/RAPINS/parth/pulldown_runfiles/output/ray:/mnt/output \
        ./alphapulldown.sif \
        /app/AlphaPulldown/alphapulldown/run_structure_prediction_polaris.sh \
          --mode=custom \
          --monomer_objects_dir=/mnt/features_db \
          --data_dir=/mnt/alphafold_data \
          --protein_lists=$protein_list \
          --output_path=/mnt/output/ \
          --num_cycle=3 \
          --num_predictions_per_model=1 \
          --models_to_relax=All \
          --fold_backend=APACE \
          --model_preset=multimer \
          --random_seed=42 &
    
    echo "Job started on node $current_node with head node IP: $head_node_ip"
  fi
done

# Wait for all background jobs to complete
wait
echo "All jobs completed"