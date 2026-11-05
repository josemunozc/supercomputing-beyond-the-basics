---
title: "Measuring efficiency with sacct and seff"
teaching: 25
exercises: 20
---

:::::::::::::::::::::::::::::::::::::: questions

- How can I see what my finished jobs asked for and what they actually used?
- Why is the CPU efficiency of a job almost never 100%?
- Why can a job that took far longer still report a high efficiency?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Use `sacct` to list your jobs and compare requested and used resources.
- Read the output of `seff`, including CPU and memory efficiency.
- Explain low efficiency with the serial fraction of a program.
- Explain why CPU efficiency alone can be misleading, and what to check alongside it.
- Use the measurements to right-size a job request.

::::::::::::::::::::::::::::::::::::::::::::::::

In the last episode we measured **run times**. Run time is only half of the story. A job can finish quickly and still waste
most of what it was given, and what you request affects how long your jobs wait and how much is left for other people. Slurm
records what every job asked for and what it used, and two tools show it:

- `sacct` reads the job accounting records and shows what ran, for how long, with which resources.
- `seff` summarises one job as an efficiency report.

## Looking at your jobs with sacct

List today's jobs:

```bash
sacct -X -S today --format=JobID,JobName%12,NCPUS,Elapsed,State
```

```output
JobID            JobName      NCPUS    Elapsed       State
------------ ------------ ---------- ----------  ----------
859044         sweep-test         16   00:00:15   COMPLETED
859046         sweep-test         16   00:00:16   COMPLETED
859059           sweep-c1          1   00:00:39   COMPLETED
859060           sweep-c2          2   00:00:35   COMPLETED
859061           sweep-c4          4   00:00:31   COMPLETED
859062           sweep-c8          8   00:00:21   COMPLETED
859063          sweep-c16         16   00:00:15   COMPLETED
859064          sweep-c32         32   00:00:14   COMPLETED
```

- `-X` shows one line per job. Without it you also get a line for each step of the job (`.batch` and so on).
- `-S today` shows jobs that started today. You can also give a date, such as `-S 2026-11-01`, or use `-j <jobid>` for one
  job.
- `--format` chooses the columns. `%12` sets the width of a column, so long names are not cut. `sacct --helpformat` lists
  every field.

The fields that matter most for efficiency:

| Field | Meaning |
|-------|---------|
| `NCPUS` (or `AllocCPUS`) | CPUs allocated to the job |
| `Elapsed` | wall-clock time the job ran for, the time on the clock on the wall |
| `ReqMem` | memory requested |
| `MaxRSS` | the most memory the job used at any moment (shown on the job's steps, see below) |
| `State`, `ExitCode` | how the job ended |

Memory is recorded per step, so to see it, leave out `-X`:

```bash
sacct -j 859062 --format=JobID,State,ReqMem,MaxRSS,Elapsed
```

```output
JobID             State     ReqMem     MaxRSS    Elapsed
------------ ---------- ---------- ---------- ----------
859062        COMPLETED        16G              00:00:21
859062.batch  COMPLETED              1745040K   00:00:21
859062.exte+  COMPLETED                     0   00:00:21
```

`MaxRSS` is given in kilobytes: here about 1.6 GB, from the 16 GB that was requested.

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: read your history

Run `sacct` for the jobs you submitted today.

1. How many jobs ran, and did all of them complete?
2. Which job used the most CPUs, and which ran longest?
3. For one job, find the memory it requested and the most it used.

::::::::::::::::::::::::::::::::::::: solution

1. Count the lines of `sacct -X -S today -n`, and read the `State` column. Jobs that stopped with `TIMEOUT`,
   `OUT_OF_MEMORY` or `FAILED` did not complete normally.
2. Compare the `NCPUS` and `Elapsed` columns.
3. Run `sacct -j <jobid> --format=JobID,ReqMem,MaxRSS` without `-X`, and look at the `.batch` line for `MaxRSS`.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## A one-page summary with seff

`seff` takes a job number and calculates the efficiency report for you:

```bash
seff 859062
```

```output
Job ID: 859062
Cluster: cluster
User/Group: c.myuser/c.myuser
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 8
CPU Utilized: 00:01:21
CPU Efficiency: 48.21% of 00:02:48 core-walltime
Job Wall-clock time: 00:00:21
Memory Utilized: 1.66 GB
Memory Efficiency: 10.40% of 16.00 GB (16.00 GB/node)
```

Line by line:

| Line | Meaning |
|---|---|
| `Cores per node` | the CPUs the job was given |
| `Job Wall-clock time` | how long the job ran, as `Elapsed` in `sacct` |
| `CPU Utilized` | the CPU time used, added up over all the CPUs |
| `core-walltime` | the CPU time the job *could* have used: CPUs multiplied by wall-clock time (8 CPUs × 21 s = 168 s) |
| `CPU Efficiency` | `CPU Utilized` divided by `core-walltime` |
| `Memory Utilized` / `Memory Efficiency` | the peak memory used, and what share of the request that is |

So this job kept its 8 CPUs busy for 48% of the time they were reserved, and used about 10% of the memory we asked for.

:::::::::::::::::::::::::::::::::::::: callout

## Very short jobs

Slurm records CPU and memory use by sampling while the job runs, and how often depends on the site's accounting settings.
For jobs that last only a few seconds, the memory figure can be missing or lower than the real peak, so treat the memory
numbers of tiny test jobs with caution and check them on a longer run.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: seff on the scaling jobs

Run `seff` on your jobs from the scaling test with 1, 8 and 32 CPUs, and fill in:

| CPUs | Wall-clock time | CPU Utilized | CPU Efficiency | Memory Utilized |
|---:|---|---|---:|---|
| 1 | | | | |
| 8 | | | | |
| 32 | | | | |

1. How does `CPU Utilized` change as the CPU count grows?
2. How does `CPU Efficiency` change?
3. Compare the CPU efficiency with the "efficiency" (speedup divided by CPUs) that we calculated in the previous episode.

::::::::::::::::::::::::::::::::::::: solution

1. It increases from between 1 to 8 CPUs, but then stays roughly the same level from 8 to 32 CPUs. The amount of *work* is
   the about the same above 8 CPUs.
2. It falls steadily, because the wall-clock time shrinks only a little while the number of reserved CPUs grows.
3. The two numbers should be close. We explain why below.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## Why is efficiency not 100%?

Think of what the 8 CPUs of our job are doing over time:

```
CPU 1:  [ serial loop ================ ][ linear algebra ]
CPU 2:  [ idle  ....................... ][ linear algebra ]
CPU 3:  [ idle  ....................... ][ linear algebra ]
  :
CPU 8:  [ idle  ....................... ][ linear algebra ]
```

During the serial part (the plain Python loop) one CPU works and seven are reserved but idle. Idle CPUs add nothing to `CPU
Utilized`, but they are part of the `core-walltime` the job holds. This is the same serial fraction that gave us Amdahl's
law in the previous episode, now seen as wasted reservation.

<!--
The two views are the same number. If the work takes `T(1)` seconds of CPU time on one CPU, and the job on `N` CPUs takes
`T(N)` seconds on the clock, then when there is no other waste:

```
CPU efficiency = CPU time used / (N × wall-clock time) = T(1) / (N × T(N)) = speedup / N
```

For the 8-CPU job: 21.88 / (8 × 16.39) = 16.7%, and `seff` reports about the same. The serial fraction is the main reason
for this job's low efficiency.
-->
Other common reasons for an efficiency below 100%:

- **Waiting for input or output.** A job reading or writing files on a busy filesystem leaves its CPUs idle.
- **Waiting for other processes.** In programs that use several processes, some wait while others catch up (load
  imbalance).
- **Asking for more CPUs than the program can use.** For example, requesting 16 CPUs for a program that runs on one.
- **Time spent starting up.** Loading modules and starting Python is a fixed cost that is more noticeable in short jobs.


<!--
:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: predict the efficiency

Using the table in the previous episode (21.88 s on 1 CPU, 13.09 s on 32 CPUs), predict the CPU efficiency of the 32-CPU
job before looking at `seff`. Then check.

::::::::::::::::::::::::::::::::::::: solution

Efficiency = 21.88 / (32 × 13.09) = 5.2%. If `seff` shows a noticeably higher value, some of the CPU time was spent on
something other than the useful work, and that is the subject of the next section.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::
-->
## Why a slower job can still look efficient

Now the 128-CPU job from the scaling test, which was about seven times *slower* than one CPU:

```bash
seff 853318
```

```output
Job ID: 853318
Cluster: <cluster>
User/Group: c.myuser/c.myuser
State: COMPLETED (exit code 0)
Nodes: 1
Cores per node: 128
CPU Utilized: 03:05:00
CPU Efficiency: 88.49% of 03:29:04 core-walltime
Job Wall-clock time: 00:01:38
Memory Utilized: 1.10 GB
Memory Efficiency: 6.88% of 16.00 GB
```

The efficiency is high, and the job was terrible. Look at `CPU Utilized`. The *work* in this problem is about 22 seconds
of CPU time, as the single-CPU job showed. This job recorded **three hours**.

`seff` measures how **busy** the CPUs were, not how much **useful work** they did. Anything that keeps a CPU occupied counts
as utilised:

- **Spinning.** Threads that wait for each other in a tight loop, checking again and again whether the others have
  arrived, are busy by the operating system's measure. If one thread out of 128 is delayed, the other 127 may spin until
  it catches up, many times per second.
- **Stalling on memory.** A CPU that is waiting for data to arrive from memory still counts as in use.
- **Doing extra work.** Splitting a small problem into 128 pieces creates bookkeeping, and the bookkeeping is also
  counted.

We do not yet know which of these affected our job. We will look inside it with a profiler in a later episode. But *any*
of them gives the same signature: a long run time, and a total CPU time far above the single-CPU job's.

::::::::::::::::::::::::::::::::::::: callout

## How to read efficiency

Never judge a job by one number.

1. **Compare the wall-clock time** with a smaller run. If more CPUs made it slower, nothing else matters.
2. **Compare `CPU Utilized` with a single-CPU run of the same problem.** A healthy job uses about the same total CPU time
   as it did on one CPU, perhaps a bit more. If the total has ballooned, the CPUs are busy with something other than
   your work.
3. **Then look at the efficiency.** A *low* efficiency reliably means wasted resources. A *high* efficiency means the CPUs
   were busy, not that they were useful.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: which job would you rather run?

Three jobs ran the same problem:

| Job | CPUs | Wall-clock time | CPU Utilized | CPU Efficiency |
|---|---:|---|---|---:|
| A | 1 | 22 s | 22 s | 100% |
| B | 8 | 19 s | 25 s | 16% |
| C | 128 | 98 s | 3 h 05 min | 88% |

1. Which finished first? Which is the most efficient?
2. Which one(s) used the least CPU-time, counting the CPUs reserved?
3. Which would you run again, and why?

::::::::::::::::::::::::::::::::::::: solution

1. B finished first (19 s). A is the most efficient by the percentage, and C looks second best, but it was the slowest.
2. Reserved CPU-time is CPUs × wall-clock: A is 22 s, B is 152 s, C is 12,544 s. A is cheapest by a wide margin.
3. A, unless the 3 seconds saved by B are worth seven times the reservation. C is the worst by every measure despite its
   88%. Its efficiency figure says only that the CPUs were never idle, and that they were busy doing little of use.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## Right-sizing the request

Use what we have measured to ask for what the job needs. For our script:

| | First guess (from the laptop) | What we measured | A better request |
|---|---|---|---|
| CPUs | 8 | speedup of 1.2 on 4 CPUs, 1.3 on 8 | 1 to 4 |
| Memory | 16 GB | about 1.6 GB peak | 2 GB |
| Time | 5 minutes | about 20 to 25 seconds | 2 minutes |

Keep a safety margin, because a job that runs out of memory or time is killed (`OUT_OF_MEMORY` or `TIMEOUT`) and you lose
the result. A margin of two to three times the measured time and well above the peak memory is sensible for short jobs. 
Smaller and shorter requests usually start sooner and leave more of the node for other users.

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: right-size and compare

1. Edit the job script with a request that you think is better: fewer CPUs, less memory and a shorter time.
2. Submit it, and when it finishes compare `seff` with the original 8-CPU job.
3. Did the wall-clock time change? Did the efficiency?

::::::::::::::::::::::::::::::::::::: solution

With 2 to 4 CPUs the run time should be within a few seconds of the 8-CPU job, while the CPU efficiency rises (30% to
58% in our measurements for 4 and 2 CPUs) and the memory efficiency rises from about 2% to about 15%. The same result for a
fraction of the resources, which is what right-sizing means.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

## Quick reference

| Command | What it shows |
|---|---|
| `sacct -X -S today --format=JobID,JobName%12,NCPUS,Elapsed,State` | your jobs from today |
| `sacct -j <jobid> --format=JobID,ReqMem,MaxRSS,Elapsed` | memory requested and used |
| `sacct --helpformat` | every field you can ask for |
| `seff <jobid>` | efficiency summary of one job |

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::: keypoints

- `sacct` shows what your finished jobs requested and used. `seff` summarises one job as CPU and memory efficiency.
- CPU efficiency is the CPU time used divided by (CPUs × wall-clock time). With no other waste it equals speedup divided by CPUs.
- Idle CPUs during the serial part of a program are the main reason efficiency is below 100%.
- `seff` measures how busy the CPUs were, not how useful: spinning, memory stalls and extra work all count as busy.
- Judge a job by wall-clock time first, then by total CPU time compared with a one-CPU run, and only then by efficiency.
- Use measured time and peak memory, plus a safety margin, to right-size the next request.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: instructor

## Instructor notes

**Timing.** About 25 minutes of teaching and 20 of exercises. The best use of time is the three `seff` reports side by side
(1, 8 and 128 CPUs), then the "which job would you rather run?" challenge.

**Check before the session.**

- Run `seff` on your own 1, 8, 32, 64 and 128 CPU jobs and replace the illustrative numbers. The point of the section on
  high efficiency depends on the 128-CPU job really showing a high CPU efficiency and a much larger `CPU Utilized` than the
  single-CPU job. Confirm that on your data, and adjust the wording if it does not.
- If you find the cause of the 128-CPU slowdown (see the previous episode), say so in that section and here.
- Confirm that `seff` is available to learners, that the `Cluster:` line reads sensibly, and which memory values it
  reports for very short jobs. Run one of the small jobs and check `MaxRSS`.
- Make sure the account and partition let learners see their own jobs with `sacct` without extra options.

**A useful comparison.** If users can see their jobs in a web tool such as XDMoD, show the same jobs there as a "looking at
many jobs" view. It makes the same point at the scale of a whole project.

**Common problems.**

- `seff` prints nothing or zeros for a job that has not finished. It reports only completed jobs.
- Reading `sacct` times with a different format: `Elapsed` is `HH:MM:SS`, while `TotalCPU` can show fractions of a second
  or days (`1-02:03:04`).
- Forgetting that `MaxRSS` is on the `.batch` line, so it does not appear with `-X`.
- Treating a high CPU efficiency as proof that a job is healthy.
- Right-sizing too aggressively: setting limits equal to the measurement, so the next run is killed.

::::::::::::::::::::::::::::::::::::::::::::::::
