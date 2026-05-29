#!/usr/bin/env bash

# ---- Metadata configuration ----
#SBATCH -A Sis25_barausse
#SBATCH --job-name=LISA_SBI                  # The name of your job, you'll se it in squeue.
#SBATCH --mail-type=ALL                      # Mail events (NONE, BEGIN, END, FAIL, ALL). Sends you an email when the job begins, ends, or fails; you can combine options.
#SBATCH --mail-user=rsriniva@sissa.it        # Where to send the mail
##SBATCH --output=%x-o%j.log              
##SBATCH --error=%x-e%j.log               

# ---- CPU resources configuration  ----  |  Clarifications at https://slurm.schedmd.com/mc_support.html

#SBATCH -N 1                        # Use N node(s)
#SBATCH --ntasks-per-node=1         # one Slurm task per node; torchrun will spawn 1 process per GPU

#SBATCH --cpus-per-task=5           # CPU threads for dataloading/etc. (adjust if needed)
#SBATCH --gpus-per-node=1           # Number of GPUs per node
#SBATCH --mem=120000MB              # Memory per node

# ---- Partition, Walltime and Output ----

#SBATCH --partition=boost_usr_prod           # Time limit 24:00:00
##SBATCH --time=12:59:59                      # format: HH:MM:SS

#SBATCH --qos=boost_qos_dbg                  # Time limit 00:30:0CQT#SBATCH --time=00:29_str22x4:59
#SBATCH --time=00:29:59                      # format: HH:MM:SS

##SBATCH --qos=boost_qos_lprod
##SBATCH --time=10:59:59  

## SBATCH --nodelist=lrdn[0001-0999]      # (LEONARDO faulty nodes likely above 1k)

# ==== End of SLURM part (resource manager part) ===== #


# ==== Modules part (load all the modules) ===== #
#   Load all the modules that you need for your job to execute.
#   Additionally, export all the custom variables that you need to export.

# # # keep Spack’s Anaconda out of the way
# module unload anaconda3 2>/dev/null || true

# set -euo pipefail

module purge
module load cuda/12.2  # if required on Leonardo

source ~/miniconda3/etc/profile.d/conda.sh
conda activate few

export HDF5_USE_FILE_LOCKING=FALSE

# ==== End of Modules part (load all the modules) ===== #

# ==== Info part (say things) ===== #
  # DO NOT MODIFY. This part prints useful info on your output file.
#
NOW=`date +%H:%M-%a-%d/%b/%Y`
echo '------------------------------------------------------'
echo 'This job is allocated on '$SLURM_JOB_CPUS_PER_NODE' cpu(s)'
echo 'Job is running on node(s): '
echo  $SLURM_JOB_NODELIST
echo '------------------------------------------------------'
echo 'WORKINFO:'
echo 'SLURM: job starting at           '$NOW
echo 'SLURM: sbatch is running on      '$SLURM_SUBMIT_HOST
echo 'SLURM: executing on cluster      '$SLURM_CLUSTER_NAME
echo 'SLURM: executing on partition    '$SLURM_JOB_PARTITION
echo 'SLURM: working directory is      '$SLURM_SUBMIT_DIR
echo 'SLURM: current home directory is '$(getent passwd $SLURM_JOB_ACCOUNT | cut -d: -f6)
echo ""
echo 'JOBINFO:'
echo 'SLURM: job identifier is         '$SLURM_JOBID
echo 'SLURM: job name is               '$SLURM_JOB_NAME
echo ""
echo 'NODEINFO:'
echo 'SLURM: number of nodes is        '$SLURM_JOB_NUM_NODES
echo 'SLURM: number of cpus/node is    '$SLURM_JOB_CPUS_PER_NODE
echo 'SLURM: number of gpus/node is    '$SLURM_GPUS_PER_NODE
echo 'SLURM: gpus on node (env) is     '$SLURM_GPUS_ON_NODE
echo '------------------------------------------------------'
#
# ==== End of Info part (say things) ===== #
echo "Started Analysis"

# Threads / CPU binding
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
export MKL_NUM_THREADS=${SLURM_CPUS_PER_TASK}

# DDP rendezvous
export MASTER_ADDR=$(scontrol show hostnames "$SLURM_JOB_NODELIST" | head -n 1)
export MASTER_PORT=$(( 20000 + RANDOM % 40000 ))

export NCCL_IB_DISABLE=0

# Your per-rank dataloader workers (4 works well)
export NUM_WORKERS_PER_RANK=2
export PREFETCH_FACTOR=1
export PIN_MEMORY=1
export PERSISTENT_WORKERS=0

# export SCHEDULER_ENABLED=0 for constant LR; if using a scheduler, set WARMUP_STEPS and WARMUP_START_FACTOR as needed
export WARMUP_STEPS=100
export WARMUP_START_FACTOR=0.05
export ETA_MIN_FACTOR=0.1
export AMP_ENABLED=0
export SCHEDULER_ENABLED=1

export HDF5_USE_FILE_LOCKING=FALSE


# NCCL (recommended defaults; keep minimal)
export NCCL_DEBUG=WARN

########### DEBUGGING ENV VARS (uncomment if needed; lots of prints, can slow) ###########
# export NCCL_DEBUG=INFO
# export NCCL_ASYNC_ERROR_HANDLING=1
# export NCCL_BLOCKING_WAIT=1
# export TORCH_NCCL_ASYNC_ERROR_HANDLING=1
# export TORCH_DISTRIBUTED_DEBUG=DETAIL

# export PLOT_TGT_HIST=1

export INTRINSIC=TRUE
export EPH1=125                  # Phase 1 epochs (overrides INTRINSIC default of 125)
export EPH2=0                    # Phase 2 epochs
export EPH3=0                    # Phase 3 epochs

export QUICKTEST=FALSE
export QUICKTRAIN=FALSE

export RETRAIN=TRUE              # TRUE: resume + train; FALSE: load existing and skip training
export PHASE=1 # 1, 2, 3
export LRFAC=1.0
export TRAINBATCH=512            # per-GPU microbatch (forward/backward); not the outer H5 batch

export EMBD_DIM=128              # embedding dim into the flow (default = d_model)
export DIM=128
export FF=1024
export HD=8
export NL=8
# export CH=16
# export STR=2
# export NSTR=4
export PATCH=16                   # PatchTransformer patch side length: 0 = disabled (use CNN+Transformer);
                                 #   any nonzero value selects the PatchTransformer variant
                                 #   (1D for TD inputs, 2D for CQT inputs) and uses that as the patch size.
                                 #   With the analytic track mask (frac_on ~30%), the bands are thin
                                 #   diagonal stripes ~3-8 freq bins wide. PATCH=16 lets the patch-keep
                                 #   mechanism cleanly drop all-noise patches; PATCH=32 mixes too much
                                 #   noise inside each kept patch. Drop to 8 if you want even finer
                                 #   masking at 4x the attention cost.
export PATCH_KEEP_PCT=50        # 2D PatchTransformer: % of patches to keep, ranked by the
                                 #   per-patch mean of the binary track mask loaded from
                                 #   <directory>/signal_template_N{N}.npz (now produced by
                                 #   `python scripts/compute_track_mask.py --out <dir> --n 256`,
                                 #   replacing the legacy empirical mean-amplitude template).
                                 #   100 = no selection. Compute scales as O(K^2):
                                 #   keep_pct=25 -> ~16x faster attention.
export CQT_MASK_PIXELS=1         # 1 = zero out non-mask pixels in data_transform (default ON).
                                 #   Off (=0) keeps the full CQT and only uses the mask for patch
                                 #   ranking. With analytic track masks (~30% frac_on) this is the
                                 #   primary compression knob.

export CQT_STATS_ENABLED=TRUE    # TRUE: per-(C,F,T) standardization with stats fixed across samples
                                 #   - Stats computed once from training H5 shards on rank 0, saved to <dir>/cqt_stats.npz
                                 #   - Preserves cross-sample SNR; subtracts the common time-frequency template
                                 #   - Set CQT_STATS_FORCE=1 to recompute even if the file already exists
export CQT_STATS_NSAMPLES=4096   # Number of samples to use when computing CQT stats
export CQT_STATS_MAXFILES=32     # Max number of H5 files to use when computing CQT stats
export CQT_STATS_FORCE=1         # Force recomputation of CQT stats even if the file already exists (useful if you change CQT_STATS_NSAMPLES or CQT_STATS_MAXFILES)

# --- Signal-template controls (only used when PATCH_KEEP_PCT < 100) ---
# Reads noise-free CQTs from <directory>/TRAIN_DATA_dt<dt>/no_noise/*.h5 (produced by
# emri_gen_pipeline_nonoise.py) and aggregates them into <directory>/signal_template_N{N}.npz.
# 0 = use all samples / all files; otherwise overrides the budget.
# SIGNAL_TEMPLATE_FORCE follows the same semantics as CQT_STATS_FORCE; if unset it falls
# back to CQT_STATS_FORCE.
export SIGNAL_TEMPLATE_NSAMPLES=0   # 0 = use every sample in every no_noise file
export SIGNAL_TEMPLATE_MAXFILES=0   # 0 = use every no_noise file
export SIGNAL_TEMPLATE_FORCE=1


# Launch ONE Slurm task per node that owns all GPUs on the node.
# torchrun then spawns one worker process per GPU (DDP best practice).
srun --ntasks=${SLURM_JOB_NUM_NODES} --ntasks-per-node=1 \
     --gpus-per-task=${SLURM_GPUS_PER_NODE} \
     --cpu-bind=cores --kill-on-bad-exit=1 \
     --output=LOGS/few/nGPU_CQT_3x_m256-ff1024-h4-l6-ch16_str2x4_INTRINSIC_4runs_nt1024_KEEP12p5.node%N.out \
     --error=LOGS/few/nGPU_CQT_3x_m256-ff1024-h4-l6-ch16_str2x4_INTRINSIC_4runs_nt1024_KEEP12p5.node%N.err \
     bash -lc 'torchrun \
       --nnodes=$SLURM_JOB_NUM_NODES \
       --nproc_per_node=$SLURM_GPUS_PER_NODE \
       --node_rank=$SLURM_NODEID \
       --master_addr=$MASTER_ADDR \
       --master_port=$MASTER_PORT \
       emri_test_multiGPU.py'

nvidia-smi

# ==== END OF JOB COMMANDS ===== #

# Wait for processes, if any.
echo "Waiting for all the processes to finish..."
wait
