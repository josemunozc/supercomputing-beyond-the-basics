---
title: 'Estimating resources'
teaching: 10
exercises: 2
---


:::::::::::::::::::::::::::::::::::::: questions
 
- How much resource should I ask for?
- How do I submit a job, follow it and find its output?
- Is my script faster on Falcon than on my laptop?
::::::::::::::::::::::::::::::::::::::::::::::::
 
::::::::::::::::::::::::::::::::::::: objectives
 
- Use the CPUs, memory and run time of your laptop as a starting point for a resource request.
- Explain the difference between tasks and CPUs per task.
- Submit a job with `sbatch`, follow it with `squeue` and read its output files.
- Compare the run time on Falcon with the run time on your laptop.
::::::::::::::::::::::::::::::::::::::::::::::::
 
Our researcher has her script working on her laptop, and the software is available on Falcon. Now she needs to run it
there. On a laptop you just type `python sweep.py 42`. On Falcon you describe what you need in a **job script**, and
the scheduler runs it for you on a compute node.
 
## How much resource should I ask for?
 
Slurm needs to know three things before it can place your job: how many CPUs, how much memory and for how long. If you
have no idea yet, the best starting point is the machine where the script already runs: your laptop.
 
Find out what your laptop has:
 
::::::::::::::::::::::::::::::::: tab
 
**Windows (PowerShell)**
 
```powershell
Get-CimInstance Win32_Processor | Select-Object NumberOfCores, NumberOfLogicalProcessors
(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
```
 
**macOS**
 
```bash
sysctl -n hw.physicalcpu hw.logicalcpu
echo "$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 )) GB"
```
 
**Linux**
 
```bash
nproc
free -h
```
 
:::::::::::::::::::::::::::::::::
 
If you prefer a graphical tool, the Task Manager (Windows) or Activity Monitor (macOS) shows the same numbers.
 
Next, time the script on your laptop, so that you have something to compare with later:
 
```bash
time python sweep.py 42                 # macOS and Linux
Measure-Command { python sweep.py 42 }  # Windows PowerShell
```
 
Note the **real** (or total) time. The script also writes its own measured time into `result_42.csv`; you will meet
that in a moment.
 
We now have a first guess for each setting:
 
| What Slurm needs | Option            | First guess from the laptop |
|------------------|-------------------|-----------------------------|
| CPUs             | `--cpus-per-task` | the number of CPUs your laptop has, for example 8 |
| Memory           | `--mem`           | the memory your laptop has, for example 16G |
| Run time         | `-t`              | a few times the time you measured, for example 5 minutes |
 
:::::::::::::::::::::::::::::::::::::: callout
 
## This is a starting point, not the answer
 
Your laptop's memory is shared with the operating system and your browser, and your script probably uses far less than
the full amount. The run time on Falcon may differ from the laptop. We start from the laptop numbers because it is a
sensible first guess, and in the **efficiency** episode we measure what the job really used and adjust.
 
Two things to keep in mind meanwhile:
 
- If the job runs out of time, Slurm stops it (state `TIMEOUT`), so leave a safety margin on the first run.
- If it needs more memory than you asked for, Slurm kills it (state `OUT_OF_MEMORY`).

Asking for far more than you need is also not free: bigger and longer requests usually wait longer in the queue.
 
::::::::::::::::::::::::::::::::::::::::::::::::
 
## Tasks or CPUs?
 
Many people's first attempt at "8 CPUs" is `--ntasks=8`. That is a different thing:
 
- A **task** is one process, for example one MPI rank. `--ntasks=8` asks for eight separate processes, which may be
  placed on different nodes.
- **CPUs per task** are the CPUs that each process can use for its own threads. `--cpus-per-task=8` asks for eight
  CPUs for one process, always on the same node.

Our `sweep.py` is **one** Python process, and NumPy's linear algebra library runs several threads inside it. That is
one task with several CPUs:
 
```bash
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
```
 
With `--ntasks=8 --cpus-per-task=1` the job script would still run a single Python process. If Slurm spread the eight
tasks over several nodes, the CPUs on the other nodes would be reserved for you and sit idle. Even when the tasks happen
to land on one node, the request does not say what you mean.
 
:::::::::::::::::::::::::::::::::::::: challenge
 
## Challenge: tasks or CPUs?
 
What would you request for each of these?
 
1. A single-threaded Python script.
2. A NumPy script that uses a multi-threaded linear algebra library on 8 CPUs.
3. An MPI program that starts 16 processes, each using one CPU.
4. An MPI program that starts 4 processes, each using 8 OpenMP threads.
::::::::::::::::::::::::::::::::::::: solution
 
1. `--ntasks=1 --cpus-per-task=1`
2. `--ntasks=1 --cpus-per-task=8`
3. `--ntasks=16 --cpus-per-task=1`
4. `--ntasks=4 --cpus-per-task=8` (32 CPUs in total)

The rule of thumb: tasks count processes, CPUs per task count the threads inside each process.
 
:::::::::::::::::::::::::::::::::::::
 
::::::::::::::::::::::::::::::::::::::::::::::::
 
## The job script
 
Open a new file with a text editor and type (or paste) the script. Save it as `sweep-test.sh`:
 
```bash
#!/bin/bash --login
#SBATCH -J sweep-test
#SBATCH -o %x.o.%j
#SBATCH -e %x.e.%j
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH -A <project-code>
#SBATCH -t 00:05:00
#SBATCH -p webmo_teaching
 
# give us access to numpy (it is an extension of this bundle)
module purge
module load SciPy-bundle/2023.07-gfbf-2023a
 
python sweep.py 42
```
 
Line by line:
 
| Line | Meaning |
|---|---|
| `#!/bin/bash --login` | run the script with Bash as a login shell |
| `#SBATCH -J sweep-test` | the name of the job, shown in the queue |
| `#SBATCH -o %x.o.%j` | standard output goes to this file; `%x` is the job name and `%j` the job number |
| `#SBATCH -e %x.e.%j` | error messages go to this file |
| `--ntasks`, `--cpus-per-task` | one process with 8 CPUs (see above) |
| `--mem=16G` | memory for the whole job |
| `-A <project-code>` | the project the usage is charged to |
| `-t 00:05:00` | time limit: 5 minutes |
| `-p webmo_teaching` | the partition (group of nodes) to run on |
| `module purge`, `module load ...` | the software, as in the previous episode |
| `python sweep.py 42` | the command: run the script with seed 42 |
 
Lines starting with `#SBATCH` look like comments to Bash, but Slurm reads them. They must come **before** the first
command, otherwise they are ignored.
 
## Submit it
 
Make sure `sweep.py` is in the same directory (copy it with `scp`, which is much more pleasant now that you have SSH
keys), then submit:
 
```bash
sbatch sweep-test.sh
```
 
```output
Submitted batch job 853278
```
 
Follow the job in the queue:
 
```bash
squeue -u $USER
```
 
```output
 JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
858933 webmo_tea sweep-te c.c10458  R       0:10      1 cca0030
```
 
`ST` is the state: `PD` means pending (waiting for resources) and `R` means running. The job disappears from the list
when it finishes. If you change your mind, `scancel 853278` removes it.
 
When the job has finished, look at what it left behind:
 
```bash
ls
```
 
```output
result_42.csv  sweep-test.e.858933  sweep-test.o.858933  sweep-test.sh  sweep.py
```
 
- `sweep-test.o.858933` is the standard output, which is empty for our script.
- `sweep-test.e.858933` holds the error messages. **Always look here first** if something went wrong.
- `result_42.csv` is the result of the script.

```bash
cat sweep-test.e.858933
cat result_42.csv
```
 
```output
42.0000,0.0048,109.5014,19.3128
```
 
The columns are the seed, the fraction of variance explained, the mean distance, and the **time the script measured for
itself in seconds** (the last number).
 
## Is Falcon faster than my laptop?
 
There are two clocks to look at. The script measures its own run time, and Slurm measures the time of the whole job,
which includes loading the module and starting Python:
 
```bash
sacct -j 858933 --format=JobID,Elapsed,NCPUS,State
```
 
```output
JobID           Elapsed      NCPUS      State
------------ ---------- ---------- ----------
858933         00:00:16          8  COMPLETED
858933.batch   00:00:16          8  COMPLETED
858933.exte+   00:00:16          8  COMPLETED
```
 
:::::::::::::::::::::::::::::::::::::: challenge
 
## Challenge: Falcon against my laptop
 
Fill in this table, using the same seed on both machines:
 
| | Laptop | Falcon |
|---|---|---|
| CPUs | | |
| Time reported by the script (last column of `result_42.csv`) | | |
| Total time (`time` on the laptop, `Elapsed` from `sacct`) | | |
 
1. Which was faster?
2. Does the outcome match what you expected from a *supercomputer*?
3. What might explain it?
::::::::::::::::::::::::::::::::::::: solution
 
The results differ between laptops, so there is no single answer. Many people find the times are similar, and some find
Falcon slower.
 
Possible reasons, which we will test during the lesson:
 
- A single core of a modern laptop can be as fast as, or faster than, a single core on a cluster node. A cluster is
  powerful because it has **many** cores and nodes, not because each one is faster.
- Part of our script is a plain Python loop that runs on one core, however many we ask for.
- Only the linear algebra part can use several CPUs, and the benefit of extra CPUs falls off quickly.

::::::::::::::::::::::::::::::::::::::::::::::::
 
::::::::::::::::::::::::::::::::::::::::::::::::
 
## What happens if I run it again?
 
Run the job a second time and look at `result_42.csv`:
 
```bash
sbatch sweep-test.sh
ls -l result_42.csv
```
 
The file has the same name and is **silently overwritten**. The first result is gone, the second job's output files
are new, and we have no record of which job produced which result. That is fine for a test, but not for the hundreds of
runs we are about to do. We deal with it in the next episode.
 
:::::::::::::::::::::::::::::::::::::: callout
 
## Quick reference
 
| Command | What it does |
|---|---|
| `sbatch script.sh` | submit a job |
| `squeue -u $USER` | list your pending and running jobs |
| `scancel <jobid>` | cancel a job |
| `sacct -j <jobid> --format=JobID,Elapsed,NCPUS,State` | look at a finished job |
 
::::::::::::::::::::::::::::::::::::::::::::::::
 
:::::::::::::::::::::::::::::::::::::::: keypoints
 
- Start your resource request from the machine where the code already runs, then measure and refine.
- `--ntasks` counts processes and `--cpus-per-task` counts threads per process. A multi-threaded Python script is one task with several CPUs.
- `#SBATCH` lines must come before the first command.
- `sbatch` submits, `squeue` shows the queue, `scancel` cancels and `sacct` shows finished jobs.
- Look in the `.e` file first when something goes wrong.
- A supercomputer is many computers, not a faster computer: a first run is often no faster than a laptop.
- Re-running a job in the same directory overwrites its results.
::::::::::::::::::::::::::::::::::::::::::::::::
 
:::::::::::::::::::::::::::::::::::::: instructor
 
## Instructor notes
 
**Timing.** About 25 minutes of live coding and 15 of exercises. Have learners type the script rather than paste it,
and submit it all at about the same time. The training partition should keep the wait short, but check it beforehand.
 
**The resource values are deliberately generous.** 16 GB is far more than this script needs, and 8 CPUs are far more
than it can use. This sets up the efficiency episode, where `seff` shows the waste. Do not fix it now; say that we will
come back to it.
 
**Check before the session.**
 
- Replace the illustrative outputs with the real ones, and the project and partition placeholders.
- Run the script on a few different laptops, or have your own timings, so you know what to expect. A recent laptop with
  fast cores may beat a cluster core, which is good for the message but should not come as a surprise.
- Confirm that the `time`, `sysctl` and PowerShell commands work on the machines learners will use.
- The tab group syntax (`tab`) depends on your Workbench version. If it does not render, use three separate headings.

**Common problems.**
 
- `Invalid account or account/partition combination specified`: the project or partition is wrong or the learner does
  not belong to the project.
- A script written or pasted in a Windows editor can contain Windows line breaks. Slurm then complains about DOS line
  breaks, or Bash reports a bad interpreter. Create or edit the file on Falcon, or convert it with `dos2unix`.
- `#SBATCH` lines placed after a command are silently ignored.
- `module: command not found` when `--login` is missing from the first line.
- The job ends with `TIMEOUT` or `OUT_OF_MEMORY` when learners reduce the limits too far. Use it as a teaching moment.
- Learners look in the `.o` file for errors instead of the `.e` file.
- Someone runs `python sweep.py 42` directly on the login node instead of submitting it. Remind them of the previous
  episode.
 
::::::::::::::::::::::::::::::::::::::::::::::::

