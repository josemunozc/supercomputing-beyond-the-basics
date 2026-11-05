---
title: "Using GPUs"
teaching: 20
exercises: 15
---

<!-- TODO(author): every block marked "output" below is illustrative. Replace it with real output from a GPU node on Falcon. -->
<!-- TODO(author): fill in the GPU partition name(s), the exact --gres syntax, the GPU types available (the table below has only the V100 we have tested), and whether CPUs or memory are tied to the GPUs. -->
<!-- TODO(author): check that the sizes in make_data() match your sweep.py, and replace <project-code> and <gpu-partition>. -->

:::::::::::::::::::::::::::::::::::::: questions

- How do I get access to a GPU on Falcon?
- Why is the software different on GPU nodes?
- How does a Python program use a GPU?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Request a GPU in an interactive session and in a job script.
- Find and load the software for GPU nodes, and know why it is not visible elsewhere.
- Check that the GPU is visible to your program.
- Describe what a simple GPU kernel written in Python does.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

## A demonstration of access, not a recipe for speed

Our example is **very small** and not really suited to a GPU. We use it because it lets us walk through everything you need to
use a GPU partition (the request, the modules, the checks) in a few minutes. Do not expect it to be faster than the CPU
version, and we will see why.

::::::::::::::::::::::::::::::::::::::::::::::::

## GPUs on Falcon

A **GPU** is a processor with thousands of simple cores that run the same instructions on many data items at once. Programs have
to be written, or called through a library, so that they use it. GPU nodes are a separate group of nodes, reached through their own
**partition**, and you must ask for the GPU explicitly. If you do not, your job runs on the node without one.

Please refer to [our documentation][arcca-docs-partitions] for a full list of GPU hardware available on Falcon.

GPU models differ a lot, and not only in speed. One difference is **double-precision (FP64)** speed, which matters because our
script uses 64-bit floating point numbers. Some GPUs are very fast at single precision and much slower at double.

### Asking for a GPU

In Slurm, a GPU is a *generic resource* (`gres`):

```bash
#SBATCH -p <gpu-partition>
#SBATCH --gres=gpu:1
```

`gpu:1` is one GPU of any type available in that partition. Inside the job, Slurm normally sets `CUDA_VISIBLE_DEVICES` to the
GPU(s) you were given, which is how a program knows which ones it may use.

## The software is different too

On the CPU nodes we load `SciPy-bundle/2025.07-gfbf-2025b`. To use the GPU from Python we also need **Numba with CUDA support**:

```bash
module load SciPy-bundle/2025.07-gfbf-2025b
module load numba-cuda/0.20.0-foss-2025b-CUDA-12.9.1
```

The second module is built against a CUDA toolkit (the `CUDA-12.9.1` in its name), and it is **not visible on the login nodes or on
compute nodes without a GPU**. If you search for it from the wrong place you will find nothing, and conclude it does not exist.
To see it, you have to be on a GPU node or modify the MODULEPATH environment variable as suggested [here][arcca-docs-software-apps].

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: find the module

1. On the login node, run `module spider numba-cuda`. What do you get?
2. Start an interactive session on a GPU node (see below), and run it again.
3. Run `module spider numba` as well. How many entries are there, and which one is the right one for the GPU?

::::::::::::::::::::::::::::::::::::: solution

1. Nothing useful: the module is not visible from there.
2. The module is found, with the full name `numba-cuda/0.20.0-foss-2025b-CUDA-12.9.1`.
3. There is a plain `numba` module as well, which does **not** work for the GPU (see the next callout). The one with `cuda` in
   its name is the right one.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

## The wrong Numba gives a confusing error

If you load the ordinary `numba` module and try to use the GPU, you do not get a message about modules. We saw this:

```output
numba.cuda.cudadrv.driver.CudaAPIError: [201] Call to cuCtxGetDevice results in CUDA_ERROR_INVALID_CONTEXT
```

At the same time `cuda.detect()` happily lists the GPU, while `cuda.is_available()` says `False`. The GPU, the driver and your
job request are all fine: you simply loaded the wrong module. If a CUDA error looks mysterious, check `module list` first.

::::::::::::::::::::::::::::::::::::::::::::::::

## Getting on a GPU node

We use an interactive session, as in the earlier episode, but on the GPU partition and with a GPU:

```bash
srun -A <project-code> -p <gpu-partition> --gres=gpu:1 -n 1 -c 4 --mem=8G -t 00:30:00 --pty bash
```

Check what you were given:

```bash
hostname
echo ${CUDA_VISIBLE_DEVICES}
nvidia-smi
```

```output
hawkccs2104.falcon.supercomputingwales.ac.uk
0
Thu Nov  5 11:15:11 2026
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 580.178.04             Driver Version: 580.178.04     CUDA Version: 13.0     |
+-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  Tesla V100-PCIE-16GB           Off |   00000000:3B:00.0 Off |                    0 |
| N/A   29C    P0             25W /  250W |       0MiB /  16384MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+

+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI              PID   Type   Process name                        GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

`nvidia-smi` is the GPU's equivalent of `htop`: it shows each GPU, its memory use and its utilisation. Now load the modules and
check that Python can use the GPU:

```bash
module purge
module load SciPy-bundle/2025.07-gfbf-2025b
module load numba-cuda/0.20.0-foss-2025b-CUDA-12.9.1
python -c "from numba import cuda; print(cuda.is_available()); cuda.detect()"
```

```output
True
Found 1 CUDA devices
id 0    b'Tesla V100-PCIE-16GB'                              [SUPPORTED]
                      Compute Capability: 7.0
                           PCI Device ID: 0
                              PCI Bus ID: 59
                                    UUID: GPU-5ffddc60-df24-e822-3ab5-5cb484368f82
                                Watchdog: Disabled
             FP32/FP64 Performance Ratio: 2
Summary:
	1/1 devices are supported
```

`True` and a supported device is what you want. Do this **before** running anything long: it takes a second and catches the problems
described above. Type `exit` to leave the session when you are done.

## The program

We take our script and move the pair-distance calculation to the GPU, with a **kernel**: a function that runs on the GPU, once for
each of many threads at the same time. The PCA part stays on the CPU. The file is `sweep_numba.py`:

```python
@cuda.jit
def pair_dist_kernel(X, m, out):
    i = cuda.grid(1)                      # global thread index = row number
    if i < m:
        acc = 0.0
        for j in range(i + 1, m):
            s = 0.0
            for k in range(X.shape[1]):
                d = X[i, k] - X[j, k]
                s += d * d
            acc += math.sqrt(s)
        out[i] = acc


def mean_pair_distance_gpu(X, m=800):
    m = min(m, len(X))                    # the kernel must never read beyond the data
    d_X = cuda.to_device(np.ascontiguousarray(X[:m]))      # copy the data to the GPU
    d_out = cuda.device_array(m, dtype=np.float64)         # room for one result per row
    threads = 128
    blocks = (m + threads - 1) // threads
    pair_dist_kernel[blocks, threads](d_X, m, d_out)       # one GPU thread per row
    cuda.synchronize()                                     # launches are asynchronous
    return d_out.copy_to_host().sum() / (m * (m - 1) / 2)  # copy the results back
```

What happens:

1. `cuda.to_device` copies the data from the computer's memory to the **GPU's own memory**. The two memories are separate, and
   the copy takes time.
2. The kernel is launched with 800 threads (as 7 blocks of 128). Each thread works out the distances from **one row** to all the
   later rows, which is the loop we had before, shared out over the threads. The check `if i < m` is for the extra threads in
   the last block.
3. `cuda.synchronize()` waits for the GPU to finish, because a launch returns immediately.
4. `copy_to_host` brings one number per row back, and the CPU adds them up.

The full script also stops with a clear message if no GPU is found, and, because the **first call compiles** the kernel and starts
the GPU, it makes that call on a small case and checks the answer against SciPy before the real run.

:::::::::::::::::::::::::::::::::::::: callout

## A kernel is not the only way

For linear algebra you rarely need to write a kernel. Libraries such as CuPy (and PyTorch or JAX) offer GPU versions of numpy
operations, such as the matrix product and the eigenvalue solver in `pca_variance`, with few code changes. Write your own kernel
with Numba when no library routine does what you need, as with our loop.

::::::::::::::::::::::::::::::::::::::::::::::::

## The job script

```bash
#!/bin/bash --login
#SBATCH -J sweep-gpu
#SBATCH -o %x.o.%j
#SBATCH -e %x.e.%j
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --gres=gpu:1
#SBATCH -A <project-code>
#SBATCH -t 00:10:00
#SBATCH -p gpu_v100

set -euo pipefail

module purge
module load SciPy-bundle/2025.07-gfbf-2025b
module load numba-cuda/0.20.0-foss-2025b-CUDA-12.9.1

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}
SEED=${1:-42}

echo "GPU(s) visible to the job: ${CUDA_VISIBLE_DEVICES:-none}"
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv

WORKDIR=/scratch/SCWFXXXXX/${USER}/sweep-gpu/${SLURM_JOB_ID}
mkdir -p "${WORKDIR}"
cp "${SLURM_SUBMIT_DIR}/sweep_numba.py" "${WORKDIR}"
cd "${WORKDIR}"

python sweep_numba.py "${SEED}"

cp "result_${SEED}.csv" "${SLURM_SUBMIT_DIR}/result_${SEED}_gpu_${SLURM_JOB_ID}.csv"
cd "${SLURM_SUBMIT_DIR}"
rm -rf -- "${WORKDIR:?}"
```

It is our usual script, with three differences: the GPU partition, `--gres=gpu:1`, and the extra module. Note that
`${CUDA_VISIBLE_DEVICES:-none}` has a default, because with `set -u` an unset variable would stop the script, which is exactly
what we would want to know about, but with a readable message instead. Submit and look at the output:

```bash
sbatch sweep-gpu.sh
```

```bash
cat sweep-gpu.o.<jobid>
```

```output
GPU(s) visible to the job: 0
name, memory.total [MiB], driver_version
Tesla V100-PCIE-16GB, 16384 MiB, 580.178.04
Using GPU: Tesla V100-PCIE-16GB
pair distances on the GPU: 1.34 s
```

<!-- TODO(author): replace the output above with the real output, including the real time. -->

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: is the GPU faster?

Compare the total time reported in the last column of the result files from the CPU job (episode "Improving the code", 8 CPUs) and from
the GPU job, for the same seed.

1. Which was faster?
2. The PCA part runs on the CPU in both. What else is different between them?
3. What would you change to give the GPU a fair chance?

::::::::::::::::::::::::::::::::::::: solution

Your numbers decide the answer, and for this small problem the GPU version is often no faster, and can be slower. Reasons:

- The first GPU call includes the **start-up and compilation** of the kernel, which takes a noticeable time.
- The data has to be **copied** to the GPU and the results back, and 800 rows is little work to pay for that.
- **800 threads is far too few** for a GPU, which can keep tens of thousands busy. Most of it sits idle.
- Our kernel is simple: neighbouring threads read memory far apart, which GPUs handle poorly.
- The PCA, which dominates, still runs on the CPU.

For a fair test: a much larger `m`, the timing of a second call (after compilation), and, for the PCA, a GPU library such as CuPy.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: diagnose the error

A colleague's GPU job fails with `CUDA_ERROR_INVALID_CONTEXT` on the first `cuda.to_device`. `nvidia-smi` in the same job lists
a GPU. What do you check, in order?

::::::::::::::::::::::::::::::::::::: solution

1. `module list`: is `numba-cuda` loaded, and not just `numba`? This is the cause we found.
2. `python -c "from numba import cuda; print(cuda.is_available())"`: it should be `True`.
3. `echo ${CUDA_VISIBLE_DEVICES}` and `nvidia-smi`: did the job really get a GPU (`--gres`) and is the right partition used?
4. Whether the CUDA version in the module name is supported by the node's driver (ask the support team if in doubt).

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

## Watching the GPU

As with `htop` earlier, you can watch a running job from a second shell in the same allocation
(`srun --jobid=<id> --overlap --pty bash`, inside `tmux`) with `watch -n 1 nvidia-smi`. Our job is too short to see much, so
try it with a bigger `m`: the GPU utilisation and memory use change while the kernel runs.

::::::::::::::::::::::::::::::::::::::::::::::::

## What we have learned

Our researcher started with a script that was no faster on a supercomputer than on a laptop. Along the way we:

- connected securely and conveniently with SSH keys, and found the software with `module spider`;
- wrote a job script that is safe against overwriting and typos, with Slurm variables and `set -euo pipefail`;
- measured how the code scales, and met Amdahl's law;
- checked efficiency with `sacct` and `seff`, and watched a job run with `tmux`, `htop` and `ps`;
- found the bottleneck with a profiler, and improved the code;
- ran many analyses with array jobs or GNU Parallel, and learned why the scheduler limits and the job length matter;
- used a GPU partition.

The main lesson is the one we started with: **a supercomputer is many computers, not a faster computer.** Measure first, ask
for what you need, and use the many computers on the many analyses.

:::::::::::::::::::::::::::::::::::::::: keypoints

- GPU nodes are in separate partitions, and you ask for a GPU explicitly (`--gres=gpu:1`).
- The software for GPU nodes can be a different set of modules, and may be visible only on GPU nodes. Check `module list`.
- Check that Python sees the GPU (`cuda.is_available()`, `nvidia-smi`) before running anything long.
- A kernel runs on the GPU with many threads at once. Data has to be copied to and from the GPU, which takes time.
- A GPU is not automatically faster: small problems, start-up, transfers and double-precision speed all matter.
- Libraries such as CuPy save you from writing kernels for common operations.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: instructor

## Instructor notes

**Timing.** About 20 minutes of teaching and 15 of exercises. This is the part that can be shortened if you are running late.

**What has and has not been tested.** The kernel logic and the host code were checked in Numba's CUDA simulator on a small case
(the result agreed with SciPy), not on a real GPU. Run the whole sequence on a GPU node before the session.

**Check before the session.**

- Fill in the partition, `--gres` syntax and GPU types. Check whether the GPU partition ties CPUs or memory to GPUs, and adjust
  `--cpus-per-task` and `--mem`.
- **GPU nodes are scarce.** Learners may queue for a long time. Consider a reservation for the session, or have a recorded run
  and its output ready so the lesson can continue.
- Confirm `module spider numba-cuda` shows nothing on the login node, and the full name on the GPU node. Confirm the plain
  `numba` module does give the confusing error on your system if you plan to demonstrate it.
- Confirm the driver on the GPU nodes supports the CUDA version in the module name.
- Replace the illustrative outputs, and check the time for a larger `m`.
- Make sure `sweep-numba.py` uses the same sizes as `sweep.py` (see `make_data`).

**Common problems.**

- Searching for the module on the login node and concluding it does not exist.
- Loading `numba` instead of `numba-cuda`.
- Forgetting `--gres=gpu:1`, so the job runs on a GPU node with no GPU visible, or in a CPU partition.
- Leaving an interactive GPU session open, which holds a scarce resource.
- Timing the first GPU call and reading the compilation time as the speed of the GPU.
- A large `m` for the kernel with the naive access pattern can be slow. This is a demonstration of access, not of tuning.

::::::::::::::::::::::::::::::::::::::::::::::::
