---
title: "Running many analyses: array jobs and GNU Parallel"
teaching: 35
exercises: 25
---

:::::::::::::::::::::::::::::::::::::: questions

- How do I run the same analysis many times with different inputs?
- Why does the cluster limit how many jobs I can submit, and what can I do about it?
- When is an array job a bad idea, and what is the alternative?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Write and submit an array job that uses the task number as the input.
- Follow, cancel and rerun individual tasks of an array.
- Explain what a QOS limit is, why it exists, and what to do if you need more.
- Explain why very short array tasks are a problem for the scheduler.
- Run many small tasks inside one Slurm job with GNU Parallel, with the right number of threads.
- Choose between the two approaches for a given workload.

::::::::::::::::::::::::::::::::::::::::::::::::

Our researcher is now happy with the speed of one run. But a single seed is not a study: she wants **100 seeds**. Running
`sbatch sweep-test.sh 1`, then 2, then 3 by hand is tedious and error-prone, and a `for` loop of `sbatch` commands creates
100 unrelated jobs that you then have to track one by one. Slurm has a better tool: the **array job**.

## Array jobs

An array job is **one submission that creates many tasks**. All tasks run the same script, and each one is told its own
number by an environment variable, `SLURM_ARRAY_TASK_ID`. We use that number as the seed.

Here is our job script from the previous episodes. The changes are the `-o` and `-e` file names, the `--array` line, and the
way the seed is chosen (explained below the script).

```bash
#!/bin/bash --login
#SBATCH -J sweep-array
#SBATCH -o logs/%x.o.%A_%a
#SBATCH -e logs/%x.e.%A_%a
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH -A <project-code>
#SBATCH -t 00:05:00
#SBATCH -p webmo_teaching
#SBATCH --array=1-4

set -euo pipefail

module purge
module load SciPy-bundle/2025.07-gfbf-2025b

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

# the task number is the seed
SEED=${SLURM_ARRAY_TASK_ID}

# one folder for all the results, one work directory per task on scratch
# and a new directory to keep our log files
RESULTS_DIR=${SLURM_SUBMIT_DIR}/results
WORKDIR=/scratch/SCWFXXXXX/${USER}/sweep-array/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}
LOGDIR=${SLURM_SUBMIT_DIR}/logs
mkdir -p "${RESULTS_DIR}" "${WORKDIR}" "${LOGDIR}"

cp "${SLURM_SUBMIT_DIR}/sweep_pdist.py" "${WORKDIR}"
cd "${WORKDIR}"

echo "Array ${SLURM_ARRAY_JOB_ID}, task ${SLURM_ARRAY_TASK_ID} (job ${SLURM_JOB_ID}), seed ${SEED}, node $(hostname)"

python sweep_pdist.py "${SEED}"

# copy back with a unique name, then clean up scratch
cp "result_${SEED}.csv" "${RESULTS_DIR}/result_${SEED}_${SLURM_JOB_ID}.csv"
cd "${SLURM_SUBMIT_DIR}"
rm -rf -- "${WORKDIR:?}"
```

Everything else is exactly what we wrote in the [Protecting your data](protecting-your-data.Rmd) episode. The new ingredients are:

| Item | Meaning |
|---|---|
| `#SBATCH --array=1-4` | create tasks numbered 1, 2, 3 and 4 |
| `SLURM_ARRAY_TASK_ID` | the number of **this** task |
| `SLURM_ARRAY_JOB_ID` | the number of the **whole array**, the same for every task |
| `SLURM_JOB_ID` | the job number of **this task**, different for every task |
| `%A` and `%a` in file names | the array job number and the task number |

<!--
:::::::::::::::::::::::::::::::::::::: callout

## Create the log directory first

The log files go into a `logs` folder, to keep the working directory tidy when there are hundreds of tasks. Slurm does
**not** create that folder for you. Run `mkdir -p logs` before the first submission. If it does not exist, the job
runs but its output and error files cannot be written, and you will be left wondering where they are.

::::::::::::::::::::::::::::::::::::::::::::::::
-->

### Submit four tasks

```bash
sbatch sweep-array.sh
```

```output
Submitted batch job 853400
```

```bash
squeue -u $USER
```

```output
   JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
860266_2 webmo_tea sweep-ar c.myuser  R       0:05      1 cca0030
860266_3 webmo_tea sweep-ar c.myuser  R       0:05      1 cca0030
860266_4 webmo_tea sweep-ar c.myuser  R       0:05      1 cca0030
860266_1 webmo_tea sweep-ar c.myuser  R       0:06      1 cca0030
```

The tasks are listed as `<array number>_<task number>`. A task that is still waiting is shown as `PD`, and a block of waiting
tasks can be folded into one line such as `853400_[3-4]`. When they have finished:

```bash
sacct -X -j 860266 --format=JobID,State,Elapsed,ExitCode
```

```output
JobID             State    Elapsed ExitCode
------------ ---------- ---------- --------
860266_1      COMPLETED   00:00:22      0:0
860266_2      COMPLETED   00:00:17      0:0
860266_3      COMPLETED   00:00:22      0:0
860266_4      COMPLETED   00:00:22      0:0
```

```bash
ls results logs
```

```output
results:
result_1_860267.csv  result_2_860268.csv  result_3_860269.csv  result_4_860266.csv

logs:
sweep-array.e.860266_1  sweep-array.e.860266_3  sweep-array.o.860266_1  sweep-array.o.860266_3
sweep-array.e.860266_2  sweep-array.e.860266_4  sweep-array.o.860266_2  sweep-array.o.860266_4
```

The job numbers in the result names are examples: every task has its own, so no result can overwrite another. To put them
all in one file for plotting:

```bash
cat results/result_*.csv > all_results.csv
```

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: predict the names

You change the script to `#SBATCH --array=10-12` and submit it. The array gets the job number 853500.

1. Which seeds will be run?
2. What will the three log files for standard output be called?
3. What does `squeue` show while the first of the three is running?

::::::::::::::::::::::::::::::::::::: solution

1. 10, 11 and 12.
2. `logs/sweep-array.o.853500_10`, `logs/sweep-array.o.853500_11` and `logs/sweep-array.o.853500_12`.
3. A line with `853500_10` in the `JOBID` column in state `R`, and the other two as `PD` (or folded into `853500_[11-12]`).

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

### Managing an array

| Task | Command |
|---|---|
| Change the size without editing the script | `sbatch --array=1-100 sweep-array.sh` |
| Run only some tasks | `sbatch --array=3,7,12 sweep-array.sh` |
| Run at most 10 at the same time | `sbatch --array=1-100%10 sweep-array.sh` |
| Cancel the whole array | `scancel 853400` |
| Cancel one task | `scancel 853400_3` |
| Find failed tasks | `sacct -X -j 853400 --format=JobID,State,ExitCode` and look for anything but `COMPLETED` |
| Rerun the failed ones | `sbatch --array=3,7 sweep-array.sh` |

Because each task has its own log files and its own result, a failure in one task does not affect the others, and rerunning
only the failures is straightforward.

## Scaling up: 100 seeds

The four tasks worked. Now the real thing:

```bash
sbatch --array=1-100 sweep-array.sh
```

Depending on how the limits are set, one of two things happens. Either the submission is refused at once:

```output
sbatch: error: QOSMaxSubmitJobPerUserLimit
sbatch: error: Batch job submission failed: Job violates accounting/QOS policy (job submit limit, user's size and/or time limits)
```

or it is accepted, but only some tasks run and the others stay pending with a reason that names the limit:

```bash
sbatch --array=1-10 run_array.sh
squeue -u $USER
```

```output
             JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
     860340_[5-10] webmo_tea sweep-ar c.c10458 PD       0:00      1 (QOSMaxJobsPerUserLimit)
          860340_1 webmo_tea sweep-ar c.c10458  R       0:10      1 cca0030
          860340_2 webmo_tea sweep-ar c.c10458  R       0:10      1 cca0030
          860340_3 webmo_tea sweep-ar c.c10458  R       0:10      1 cca0030
          860340_4 webmo_tea sweep-ar c.c10458  R       0:10      1 cca0030
```

We have hit a **QOS limit**.

## What is a QOS limit?

A **QOS** (quality of service) is a named set of rules attached to your jobs: the priority they get, and limits on what a
user may have at once. The limits typically cover:

- the number of jobs you may have **submitted** (waiting and running) at any one time;
- the number you may have **running** at any one time;
- the total CPUs or memory you may use at once, and the longest time a job may ask for.

Each task of an array counts as a job, so an array of 100 tasks counts as 100.

You can look at the limits yourself:

```bash
sacctmgr show qos format=Name%20,GraceTime,PreemptMode,Flags%25,UsageThres,UsageFactor,MaxTRES%15,MaxWall,MaxTRESPU%15,MaxJobsPU,MaxSubmitPU
```

(The column names differ between Slurm versions. `sacctmgr show qos --help` lists them.)

You can find more details about Falcon partitions and their limits in our [documentation website][arcca-docs-partitions].

### Why do the limits exist?

They are there to **protect the cluster, and all its users, from mistakes**, including honest ones:

- A typo such as `--array=1-100000` instead of `1-100`.
- A loop or a script that submits jobs and, because of a bug, keeps submitting.
- A job that submits more jobs, and each of those does the same.
- One user's thousands of waiting jobs pushing everybody else's down the queue.

The scheduler has to keep track of every job: where it could run, when, and in which order. It has a finite capacity, and when
it is overloaded, everything slows down for everybody, including commands such as `squeue` and `sbatch`. The limits keep the
total number of jobs in a range the scheduler can handle.

### What if I really need more?

The limits are not fixed for ever. They **can be changed for a particular user** once we know what you intend to do.
[Contact us][contact-arcca] and tell us:

- what the analysis is and roughly how many jobs it needs;
- how long each job runs, and how many CPUs and how much memory it needs;
- how many you want to have running at once;
- whether it is a one-off or a regular need, and whether the work could be organised into fewer, longer jobs (see below).

:::::::::::::::::::::::::::::::::::::: callout

## Do not work around the limit

A loop that submits a few jobs, waits, and submits a few more defeats the purpose of the limit and causes exactly the load the limit
is meant to prevent. If you hit a limit, there is a better way: ask us, or reorganise the work, as described next.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: working under a limit

Suppose a user may have at most 50 jobs submitted at once, and needs to run 500 analyses of about 20 seconds each.

1. Why does `--array=1-500%10` not help?
2. Suggest two ways to get the work done without asking for a higher limit.
3. What would you tell the support team if you did ask for a higher limit?

::::::::::::::::::::::::::::::::::::: solution

1. `%10` limits how many tasks **run** at once, but all 500 tasks are still **submitted**, so the limit on submitted jobs is
   still exceeded.
2. Make each task do more work: for example 50 array tasks of 10 seeds each (see the callout on batching below), or one job
   that runs all 500 with GNU Parallel (next section).
3. What the analysis is, 500 runs of about 20 seconds each, the resources per run, and why the work could not be organised into
   fewer, longer jobs. Most likely the support team will suggest the batching or GNU Parallel approach anyway, for the reasons in
   the next section.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## Short array tasks are a problem

Our example has a more important problem than the limit: each task runs for **well under a minute**. Look at one of the finished
tasks and compare two numbers: the time Slurm says the job took, and the time the script measured for itself (the last column of
its result file):

```bash
sacct -X -j 853400_1 --format=JobID,Elapsed
cut -d, -f4 results/result_1_*.csv
```

The difference is **overhead**: loading the module, starting Python, copying files to and from scratch. It is a few seconds per
task here. Out of sight there is more: every task is a separate job that the scheduler must place, set up on a node, track and
record in the accounting database, and clean up afterwards.

For a task that lasts an hour, all this is lost in the noise. For a task of 20 seconds it is a large share of the work, and it
gets worse in bulk:

- **Many short tasks put a load on the scheduler.** Thousands of tasks that each live for seconds mean thousands of start-ups
  and clean-ups per hour. This can slow the scheduler for **everybody**, including people whose jobs are perfectly reasonable.
- **They are wasteful.** Each task pays the start-up cost again, and the CPUs sit idle while the node is set up and torn down.
- **They can take longer overall.** Each task waits in the queue separately, so 100 tiny jobs can take much longer to finish than
  one job that runs them all.

:::::::::::::::::::::::::::::::::::::: callout

## Our recommendation

**Use array jobs for analyses that each take more than about an hour.** For shorter tasks, group them into fewer, longer jobs
(next sections). The 20-second tasks we use in this course are an illustration of the mechanics, and a bad fit for the real
thing.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: measure the overhead

1. For one of your four tasks, calculate the difference between `Elapsed` (from `sacct`) and the time the script reported.
2. What share of the task's time is it?
3. What would the share be for a task that really computes for one hour, if the overhead stays the same?

::::::::::::::::::::::::::::::::::::: solution

Your numbers will differ. As an example: if `Elapsed` is 21 s and the script reported 16 s, the overhead is 5 s, or about 24% of
the time. For a one-hour task with 5 s of overhead, the share is 5/3600, or about 0.1%. The scheduler's own work is not visible
in these numbers, but it grows with the **number** of jobs, not with how long they run.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

## A middle way: several seeds per task

If you want to keep an array but your tasks are short, make each one do several seeds in a loop. With 10 seeds per task, 100
seeds need only 10 tasks:

```bash
#SBATCH --array=1-10

SEEDS_PER_TASK=10
FIRST=$(( (SLURM_ARRAY_TASK_ID - 1) * SEEDS_PER_TASK + 1 ))
LAST=$(( SLURM_ARRAY_TASK_ID * SEEDS_PER_TASK ))

for SEED in $(seq "${FIRST}" "${LAST}"); do
    python sweep.py "${SEED}"
    cp "result_${SEED}.csv" "${RESULTS_DIR}/result_${SEED}_${SLURM_JOB_ID}.csv"
done
```

The job count drops by a factor of 10, and the start-up cost is paid once per task.

::::::::::::::::::::::::::::::::::::::::::::::::

## Alternative: GNU Parallel

**GNU Parallel** is a command-line tool that runs many commands at the same time and keeps a fixed number going until the list
is finished. Inside **one** Slurm job, it fills all the CPUs you were given with independent tasks. To Slurm this is a single job,
so it creates no extra load on the scheduler, and no QOS limit on the number of jobs is involved.

Here is a script that runs 100 seeds, 16 at a time, on a single 16-CPU allocation:

```bash
#!/bin/bash --login
#SBATCH -J sweep-parallel
#SBATCH -o %x.o.%j
#SBATCH -e %x.e.%j
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=40G
#SBATCH -A <project-code>
#SBATCH -t 00:15:00
#SBATCH -p webmo_teaching

set -euo pipefail

module purge
module load SciPy-bundle/2025.07-gfbf-2025b
module load parallel                 # check the exact name with: module spider parallel

# number of seeds (override with: sbatch --export=ALL,NSEEDS=200 sweep-parallel.sh)
NSEEDS=${NSEEDS:-100}

# ONE thread per task, and as many tasks at once as there are CPUs
THREADS_PER_TASK=1
export OMP_NUM_THREADS=${THREADS_PER_TASK}
JOBS=$(( SLURM_CPUS_PER_TASK / THREADS_PER_TASK ))

RESULTS_DIR=${SLURM_SUBMIT_DIR}/results
WORKDIR=/scratch/SCWFXXXXX/${USER}/sweep-parallel/${SLURM_JOB_ID}
mkdir -p "${RESULTS_DIR}" "${WORKDIR}"

cp "${SLURM_SUBMIT_DIR}/sweep_pdist.py" "${WORKDIR}"
cd "${WORKDIR}"

echo "Job ${SLURM_JOB_ID}: ${NSEEDS} seeds, ${JOBS} at a time, ${THREADS_PER_TASK} thread(s) each, node $(hostname)"

# run the seeds. If some task fails, keep going, remember the status and report it at the end
PARALLEL_RC=0
seq 1 "${NSEEDS}" | parallel -j "${JOBS}" --joblog sweep.joblog python sweep_pdist.py {} || PARALLEL_RC=$?

# copy back whatever was produced, with the job number in the name
cp sweep.joblog "${RESULTS_DIR}/sweep_${SLURM_JOB_ID}.joblog"
for f in result_*.csv; do
    [ -e "${f}" ] || continue
    cp "${f}" "${RESULTS_DIR}/${f%.csv}_${SLURM_JOB_ID}.csv"
done

# clean up scratch only if everything worked
if [ "${PARALLEL_RC}" -eq 0 ]; then
    cd "${SLURM_SUBMIT_DIR}"
    rm -rf -- "${WORKDIR:?}"
else
    echo "WARNING: ${PARALLEL_RC} task(s) failed, keeping ${WORKDIR}"
fi

echo "Finished in ${SECONDS} s"
exit "${PARALLEL_RC}"
```

The key line is:

```bash
seq 1 "${NSEEDS}" | parallel -j "${JOBS}" --joblog sweep.joblog python sweep.py {}
```

- `seq 1 100` prints the numbers 1 to 100, one per line. Parallel reads them as its input.
- `{}` is replaced by each input in turn, so it runs `python sweep.py 1`, `python sweep.py 2`, and so on.
- `-j "${JOBS}"` is how many to run at the same time. **Always set it explicitly**, because otherwise parallel may count every
  CPU of the node, not just the ones in your allocation.
- `--joblog` writes one line per task, with its start time, run time and exit status.
- `|| PARALLEL_RC=$?` is the pattern from the `set -e` section: without it, one failed task would end the script before the
  results are copied back.

GNU Parallel's exit status is the number of tasks that failed, so Slurm still sees a failed job if anything went wrong. To list
the failures afterwards:

```bash
awk 'NR>1 && $7!=0' results/sweep_<jobid>.joblog
```

(Column 4 is the run time and column 7 is the exit status.) To rerun only the failed tasks, use the same job log with
`parallel --retry-failed`.

:::::::::::::::::::::::::::::::::::::: callout

## Count the threads and the memory

Two numbers have to be right in a script like this, and they are the ones that go wrong.

**Threads.** Each task is a full copy of our script, and numpy would start as many linear algebra threads as it can see. With 16
tasks at once and no limit, that is 16 × 16 = 256 threads fighting for 16 CPUs, which is slower than doing the tasks one at a
time (see the login node and 128-CPU stories from earlier episodes). Setting `OMP_NUM_THREADS=1` and running one task per CPU
avoids it. If a task is better with 2 threads, use `THREADS_PER_TASK=2` and parallel runs 8 at a time.

**Memory.** `--mem` is for the **whole job**, and 16 tasks run side by side. One task peaked at about 1.8 GiB in our profile, so
16 of them need about 29 GiB. We asked for 40 GB, which leaves a margin. Asking for the memory of **one** task would get the job
killed with `OUT_OF_MEMORY`.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: what does the efficiency say?

Run the Parallel script, and when it has finished:

```bash
seff <jobid>
```

1. What is the CPU efficiency, and how does it compare with the 8-CPU single run from the efficiency episode?
2. Compare `CPU Utilized` with 100 times the CPU time of one single-CPU run. What does it tell you?
3. Why is the efficiency not exactly 100%?

::::::::::::::::::::::::::::::::::::: solution

1. It should be much higher, because every CPU always has an independent task to run, with no serial bottleneck.
2. They should be similar. Here, unlike the 128-CPU job, the busy CPUs are doing useful work, so the total CPU time matches the
   work and does not balloon.
3. Some CPUs are idle at the beginning (copying files, loading the module), at the end when the last tasks finish while the
   others have none left to run, and during any serial start-up in each task.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: forget the thread setting

Run the Parallel script a second time with the line `export OMP_NUM_THREADS=${THREADS_PER_TASK}` commented out.

1. Predict first: faster, slower or the same?
2. Compare the run times (`sacct`) and `seff`. What do you see?

::::::::::::::::::::::::::::::::::::: solution

Expect it to be slower, possibly much slower, because of oversubscription: far more threads than CPUs. Whether `seff` looks
worse depends, as we saw earlier, on whether the extra threads are idle or spinning, so look at the run time first. The exact
effect depends on how Slurm limits the CPUs and how numpy counts them, which is a good reason to measure it.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

### Limits of GNU Parallel

- It uses **one node**: at most as many tasks at once as the node has CPUs. For more, combine it with an array (an array of a few
  large Parallel jobs), which is a good use of both.
- The allocation is held until the **last** task finishes. If task lengths vary a lot, CPUs sit idle at the end.
- A failed task does not affect the others, but you have to look in the job log to find it.

## Which one should I use?

| | Array job | GNU Parallel |
|---|---|---|
| Jobs the scheduler sees | one per task | one |
| Best for | long tasks (over about an hour) | many short tasks |
| Counts against job limits | every task | one job |
| A task fails | rerun just that task by number | use the job log and `--retry-failed` |
| Waiting in the queue | tasks can start as soon as space is free | the whole allocation has to be free at once |
| Spread over several nodes | automatically | no, one node |

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: choose an approach

Which approach would you use for each, and why?

1. 2,000 analyses of 30 seconds each, 1 CPU each.
2. 40 simulations of 6 hours each, 8 CPUs each.
3. 200 analyses of 10 minutes each, 1 CPU each.

::::::::::::::::::::::::::::::::::::: solution

1. GNU Parallel (or a few array tasks that each run a batch of seeds, optionally with Parallel inside). 2,000 separate 30-second
   jobs would be a heavy load on the scheduler for almost no computation.
2. An array job. The tasks are long, and each gets its own allocation.
3. In between. Either GNU Parallel on a single 16 to 32 CPU job, or an array in which each task runs several analyses. Ten
   minutes is above the 20 seconds of our example, but still short enough for the start-up and the number of jobs to matter.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

## Quick reference

| Command | What it does |
|---|---|
| `sbatch --array=1-100 job.sh` | submit a 100-task array |
| `sbatch --array=1-100%10 job.sh` | at most 10 tasks running at once |
| `scancel <array id>` or `scancel <array id>_<task>` | cancel all, or one task |
| `sacct -X -j <array id> --format=JobID,State,ExitCode` | state of every task |
| `squeue -u $USER -t PD -o "%.12i %.10T %r"` | why jobs are pending |
| `sacctmgr show qos format=Name,MaxJobsPU,MaxSubmitPU,MaxTRESPU` | the QOS limits |
| `seq 1 N | parallel -j K --joblog log.txt cmd {}` | run `cmd` for 1 to N, K at a time |

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::: keypoints

- An array job creates many tasks from one script. `SLURM_ARRAY_TASK_ID` tells each task which one it is, and `%A_%a` names its log files.
- Each task is a separate job: it can fail and be rerun on its own (`--array=3,7`), and it counts towards the job limits.
- A QOS limits what a user can have submitted, running or in use at once. The limits protect the cluster from mistakes and overload, and can be changed for a user once we know the intended use.
- Many short tasks load the scheduler and waste time on start-up. Use array jobs for analyses of more than about an hour, and group shorter work into fewer, longer jobs.
- GNU Parallel runs many tasks inside one Slurm job. Set the number of tasks at once (`-j`), the threads per task and the total memory deliberately.
- Choose by task length, number of tasks, differing resource needs and how you want failures handled.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: instructor

## Instructor notes

**Timing.** About 35 minutes of teaching and 25 of exercises. The array part and the QOS discussion take about half of it. The
overhead and "which approach" discussions are the most valuable, so protect that time.

**Do not let the whole class hit the limit.** If 20 learners each submit 100 tasks of 20 seconds, the class does to the scheduler
exactly what this episode warns against. Options: demonstrate the 100-task submission once, from the instructor account; ask
learners to submit it once, together, at a set time; or use a training QOS with a low limit so the effect is visible without the
load. Warn the people who run the cluster before the session.

**Check before the session.**

- Find out what really happens on Falcon when 100 tasks are submitted with the training account: is the submission refused, or do
  tasks wait? Note the exact message or reason, and update the section on scaling up. Also check how the `%` throttle looks, and
  the value of `MaxArraySize` (`scontrol show config | grep MaxArraySize`).
- Fill in the real limits and the contact address for limit requests.
- Check the `sacctmgr` column names on your Slurm version.
- Run both scripts end to end, and confirm the module name for GNU Parallel, and whether it prints a citation notice on first
  use (if so, mention that GNU Parallel asks to be cited in publications).
- Confirm the memory figure: peak memory per task, from `seff` or `MaxRSS`, times the number of tasks at once.
- Check how long 100 seeds take with 16 at a time, so the time limit in the script is realistic. Memory bandwidth shared between
  16 tasks can make each one slower than a single run.
- Confirm the job numbers of array tasks on Falcon and update the example outputs.

**A good demonstration of overhead.** Submit 100 tasks as an array and the same 100 with GNU Parallel on the same number of CPUs,
and compare the total time from submission to the last result. The array has to be scheduled task by task, and the difference
is usually striking. The queue state of the cluster at that moment affects it, so try it first.

**Common problems.**

- The `logs` directory does not exist, so the log files are not written.
- `--mem` set for one task in the Parallel script, and the job killed with `OUT_OF_MEMORY`.
- Forgetting `-j`, so parallel starts more tasks than CPUs.
- Forgetting the thread setting, and oversubscribing.
- `%10` mistaken for a limit on the number of tasks submitted. It limits only how many run at the same time.
- Windows line endings in the scripts (see the earlier episodes).
- Learners put `--array` in the script and also on the command line and wonder which wins. The command line does.

::::::::::::::::::::::::::::::::::::::::::::::::
