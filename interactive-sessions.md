---
title: "Watching a job run: interactive sessions, tmux, htop and ps"
teaching: 30
exercises: 15
---

:::::::::::::::::::::::::::::::::::::: questions

- How do I get a shell on a compute node to try things out or to watch a program run?
- How can I keep that session alive if my connection drops, and look at two things at once?
- How can I see, while a program runs, how many CPUs it is really using?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Start an interactive session on a compute node and check what it gives you.
- Use `tmux` panes to run a program and monitor it side by side, and reattach after a disconnection.
- Read `htop` and `ps` output to see how many CPUs a program is using at a given moment.
- Recognise the point where our script changes from parallel to serial.

::::::::::::::::::::::::::::::::::::::::::::::::

In the last two episodes we looked at jobs **after** they finished. Now we watch one **while it runs**. We need three things:

1. a shell on a **compute node**, so that we do real work in the right place (an *interactive session*);
2. a way to keep that session alive and to see two things at once (`tmux`);
3. tools to look at what the program is doing (`htop` and `ps`).

## An interactive session

A batch job runs a script and ends. An **interactive session** gives you a shell on a compute node, with the CPUs, memory and
time you asked for, in which you type commands as you would on the login node. It is the right way to test a command, to
debug, and to watch a program.

```bash
srun -A <project-code> -p webmo_teaching -n 1 -c 8 --mem=2G -t 00:30:00 --pty bash
```

```output
srun: job 853340 queued and waiting for resources
srun: job 853340 has been allocated resources
[c.myuser@<node> ~]$
```

The request has the same ingredients as a job script, now on the command line (`-c 8` is eight CPUs for one task, as in
the earlier episodes), and `--pty bash` asks for a shell. If the cluster is busy you wait in the queue, as with any job.
When the prompt appears, check where you are:

```bash
hostname
echo ${SLURM_JOB_ID} ${SLURM_CPUS_PER_TASK}
```

```output
<node>
853340 8
```

The host name is now a compute node, not a login node. The Slurm variables from the earlier episodes exist here too.

:::::::::::::::::::::::::::::::::::::: callout

## An interactive session holds its resources until you leave

Nothing is running for you while you read a web page or get a coffee, but the CPUs are still reserved, and unavailable to
others. Ask only for what you need and a sensible time, and type `exit` as soon as you are finished.

Also, do not use `set -e` in an interactive shell. The first command that fails would close your session.

::::::::::::::::::::::::::::::::::::::::::::::::

Set up the same environment as in a job script, and a work directory on scratch:

```bash
module purge
module load SciPy-bundle/2023.07-gfbf-2023a
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

WORKDIR=/scratch/SCWFXXXXX/${USER}/interactive/${SLURM_JOB_ID}
mkdir -p "${WORKDIR}" && cd "${WORKDIR}"
cp "${SLURM_SUBMIT_DIR}/sweep.py" .
```

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: how many CPUs do I see?

In the ["Finding the software"](finding-software.Rmd) episode we ran this one-liner on the login node and got 192 twice:

```bash
python -c "import os; print(os.cpu_count(), len(os.sched_getaffinity(0)))"
```

Run it inside your interactive session. Do the two numbers differ? What does this tell you about where to run your script?

::::::::::::::::::::::::::::::::::::: solution

The second number, the CPUs your process is allowed to use, should equal the CPUs you asked for (8). The first can still show
all the CPUs of the node. Slurm limits where your processes can run, which is why compute work belongs on the compute nodes.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## Why tmux?

If your connection drops, the `srun` command in your terminal is killed, and so is your interactive session. We want the
session to survive. The trick is to start `tmux` **first**, on the login node, and run `srun` **inside** it. The `srun`
command then belongs to `tmux`, not to your network connection, and carries on while you are away. `tmux` also lets us split
the window into panes, to run the program in one and watch it in another.

The full guide to `tmux` is in the [Falcon tmux documentation page][arcca-docs-tmux], which you should keep open. Here are
the few keys we need. Every command starts with the **prefix**, `Ctrl+b`: press it, release it, then press the next key.

| Keys | Action |
|---|---|
| `tmux new -s monitor` | start a new session called `monitor` |
| `Ctrl+b` then `"` | split the window: one pane above the other |
| `Ctrl+b` then `%` | split the window: panes side by side |
| `Ctrl+b` then an arrow key | move to the neighbouring pane |
| `Ctrl+b` then `d` | **detach**: leave the session running and return to the normal shell |
| `tmux ls` | list your sessions |
| `tmux attach -t monitor` | reattach to a session |
| `Ctrl+b` then `[` | scroll back through the output (`q` to leave) |

:::::::::::::::::::::::::::::::::::::: callout

## Choose a login node

`falconlogin.cf.ac.uk` alternates between two login nodes (`falconlogin01` and `falconlogin02`), and a `tmux` session lives
only on the node where it was started. Connect to one of them by name, and use the same one when you reattach. A second
entry in your SSH config file, for example `Host falcon1` with `HostName falconlogin01.cf.ac.uk`, makes it easy.

::::::::::::::::::::::::::::::::::::::::::::::::

## Setting up the monitoring window

If you are in the interactive session from before, type `exit` to leave it, and log out. We will start again in the right order.

1. Connect to a login node and start `tmux`:

   ```bash
   ssh falcon1
   tmux new -s monitor
   ```

2. In this first pane, start the interactive session and set up the environment, exactly as above.

3. Split the window with `Ctrl+b` then `"`. The new pane is a shell on the **login node**, not on your compute node, because
   `tmux` itself runs on the login node. Find your job number:

   ```bash
   squeue -u $USER
   ```

   ```output
    JOBID PARTITION     NAME     USER ST       TIME  NODES NODELIST(REASON)
   853340 <partition>   interactive c.myuser  R       4:12      1 <node>
   ```

4. Start a second shell **inside the same allocation**, on the same compute node:

   ```bash
   srun --jobid=853340 --overlap --pty bash
   ```

   `--jobid` says which allocation to join. `--overlap` lets this new shell share the CPUs already held by the first, which
   Slurm otherwise may not allow. Check with `hostname` that both panes are on the same compute node.

Your window now has two panes on the same compute node: the program will run in the first, and we watch it from the second.

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: survive a disconnection

1. With both panes set up, detach with `Ctrl+b` then `d`.
2. Close your terminal window completely.
3. Open a new one, connect to **the same login node**, and reattach.
4. What is still there?

::::::::::::::::::::::::::::::::::::: solution

```bash
ssh falcon1
tmux ls
tmux attach -t monitor
```

Both panes are still there and still connected to the compute node. The interactive session never noticed the disconnection.
Had `srun` been started outside `tmux`, the session would have ended with your connection.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## Run the program and watch it

Our script has two stages: a linear algebra stage that can use several CPUs, followed by a plain Python loop that uses
one. A single run is short, so run it several times in a row in the first pane:

```bash
for s in 1 2 3 4 5; do python sweep.py ${s}; done
```

### Looking with htop

In the second pane:

```bash
htop -u $USER
```

<!-- TODO(author): add a screenshot of htop during the run here, saved in episodes/fig/ (a link to a missing image makes the sandpaper build report an error, so add it only once the file exists). -->

- The **bars at the top** show each CPU of the node. A compute node has many CPUs, and most belong to other users' jobs. Yours
  are the ones that light up when the program runs.
- In the process list, `python` has a **CPU%** column. A value of 100% means one CPU is fully used. A multi-threaded program
  can go above 100%: 800% means eight CPUs.
- The **RES** column is the memory the process is using. It should be close to the `MaxRSS` we saw with `sacct`.
- Press `F10` or `q` to quit. `F6` chooses the sort column, and `F5` shows the process tree.

Watch what happens each time `sweep.py` runs. For a few seconds many CPUs fill with load and the CPU% of `python` rises
towards 800%. Then it drops to about 100% and one CPU does everything for the rest of the run, until the next run starts the
cycle again.

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: spot the switch

Watch `htop` through a few runs.

1. How long does the burst on many CPUs last, compared with the single-CPU part?
2. Which part of `sweep.py` is each of them?
3. How does this match the results of the scaling test?

::::::::::::::::::::::::::::::::::::: solution

1. The many-CPU burst is short (a few seconds), and the single-CPU part is longer (more than ten seconds).
2. The burst is `pca_variance`, which uses a multi-threaded linear algebra library. The long single-CPU part is
   `mean_pair_distance`, the Python loop.
3. This is the picture of Amdahl's law: the serial part dominates the time, which is why more CPUs gave so little.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

### Looking with ps

`htop` is easy to read, but `ps` can be used in scripts, and shows exactly what each thread is doing. Find the program:

```bash
ps -u $USER -o pid,nlwp,pcpu,etime,cmd
```

```output
    PID NLWP %CPU     ELAPSED CMD
1124712    8  247       00:12 python sweep.py 1
```

- `NLWP` is the number of **threads**. Our process tops at 8, when the linear algebra library function starts execution..
- `%CPU` in `ps` is the CPU time **since the process started, divided by the time since it started**. It is an average over
  the whole life of the process, not a live reading, so it hides a change like the one we want to see. For that, look at the
  state of each thread.

Add `-L` to list one line per thread, with the CPU each thread last ran on (`PSR`) and its state (`STAT`):

```bash
$ ps -L -u $USER -o pid,lwp,psr,stat,pcpu,cmd
```

During the linear algebra, many threads are running (`R`):

```output
    PID     LWP PSR STAT %CPU CMD
1122514 1122514   4 Ss    0.0 /usr/bin/bash
1122761 1122761   2 Ss    0.0 /usr/bin/bash
1126961 1126961   5 S+    0.0 watch ps -L -u c.myuser -o pid,lwp,psr,stat,pcpu,cmd
1126972 1126972   4 Rl+   101 python sweep.py 2
1126972 1127139   7 Rl+   106 python sweep.py 2
1126972 1127140   1 Rl+   105 python sweep.py 2
1126972 1127141   2 Rl+   105 python sweep.py 2
1126972 1127142   2 Rl+   105 python sweep.py 2
1126972 1127143   3 Rl+   106 python sweep.py 2
1126972 1127144   6 Rl+   106 python sweep.py 2
1126972 1127145   5 Rl+   106 python sweep.py 2
1127150 1127150   3 S+    0.0 watch ps -L -u c.myuser -o pid,lwp,psr,stat,pcpu,cmd
1127151 1127151   0 R+    0.0 ps -L -u c.myuser -o pid,lwp,psr,stat,pcpu,cmd
  ...
```

During the Python loop, only one is, and the others sleep (`S`):

```output
PID     LWP     PSR STAT %CPU CMD
1122514 1122514   4 Ss    0.0 /usr/bin/bash
1122761 1122761   7 Ss    0.0 /usr/bin/bash
1126282 1126282   7 Rl+  96.3 python sweep.py 8
1126282 1126290   1 Sl+  91.1 python sweep.py 8
1126282 1126291   2 Sl+  91.5 python sweep.py 8
1126282 1126292   5 Sl+  91.5 python sweep.py 8
1126282 1126293   3 Sl+  91.7 python sweep.py 8
1126282 1126294   4 Sl+  91.7 python sweep.py 8
1126282 1126295   6 Sl+  91.8 python sweep.py 8
1126282 1126296   0 Sl+  91.7 python sweep.py 8
1126283 1126283   6 S+    0.0 watch ps -L -u c.myuser -o pid,lwp,psr,stat,pcpu,cmd
1126316 1126316   0 S+    0.0 watch ps -L -u c.myuser -o pid,lwp,psr,stat,pcpu,cmd
1126317 1126317   6 R+    0.0 ps -L -u c.myuser -o pid,lwp,psr,stat,pcpu,cmd
  ...
```

<!--
The workers did not go away. They are still there (NLWP is unchanged), but asleep. Counting the threads in the `R` state gives
a live measure of how many CPUs are busy, and `watch` repeats it every half second:

```bash
watch -n 0.5 'ps -L -o stat= -p $(pgrep -n -f "[s]weep.py") | grep -c "^R"'
```

The output jumps between `1` and `8` as the program switches between its two stages. (Writing `[s]weep.py` stops `pgrep`
from matching the `watch` command itself.) Press `Ctrl+c` to stop it.
:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: count the running threads

1. Run the `watch` command while the loop of five runs is going. What values do you see, and how long does each last?
2. Why is `%CPU` in `ps` a poor way to see the switch?

::::::::::::::::::::::::::::::::::::: solution

1. Mostly `1`, with a short spell at (about) the number of CPUs at the start of every run.
2. It is the CPU time since the start of the process divided by the time since the start of the process: an average over the
   process's whole life. A short burst of parallel work followed by a long serial one is averaged away.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::
-->

:::::::::::::::::::::::::::::::::::::: callout

## Busy is not the same as useful

`htop` and `ps` show which CPUs are **busy**, not whether the work they do is **useful**. A thread that spins, waiting for
other threads, looks just like a thread that computes. That is the same limit we met with `seff` in the previous episode,
and the reason a 128-CPU run can fill every bar and still be slow. To see *what* the busy CPUs are doing we need a profiler,
which is the subject of a later episode.

::::::::::::::::::::::::::::::::::::::::::::::::

## Watching a batch job

The technique in step 4 works for any running job, not only an interactive one. If you submitted a batch job and want to look
at its node, find its number with `squeue -u $USER`, and attach a shell to it:

```bash
srun --jobid=<jobid> --overlap --pty bash
htop -u $USER
```

You are now on the node where your job runs, and can watch it with the same tools. Please look, and do not change anything:
the job is not an interactive session, and anything you start there takes resources from it.

## Cleaning up

When you have finished:

1. Leave the monitoring shell with `exit`.
2. In the first pane, `exit` to end the interactive session and release the CPUs. Check with `squeue -u $USER` that the job is
   gone, and use `scancel <jobid>` if it is not.
3. Close the `tmux` panes with `exit`, or end the whole session with `tmux kill-session -t monitor`.

:::::::::::::::::::::::::::::::::::::: callout

## Quick reference

| Command | What it does |
|---|---|
| `srun ... --pty bash` | start an interactive session on a compute node |
| `srun --jobid=<id> --overlap --pty bash` | open another shell in a running job |
| `htop -u $USER` | live view of CPUs, memory and your processes |
| `ps -u $USER -o pid,nlwp,pcpu,etime,cmd` | your processes, with thread count |
| `ps -L -o pid,lwp,psr,stat,pcpu,cmd -p <pid>` | one line per thread, with its state |
| `watch -n 0.5 '<command>'` | repeat a command every half second |

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::::: keypoints

- An interactive session (`srun --pty bash`) gives you a shell on a compute node. Exit it when you are done, because it holds its resources.
- Start `tmux` on a named login node first and run `srun` inside it. The session then survives a lost connection.
- A second shell in the same allocation (`srun --jobid=<id> --overlap --pty bash`) lets you watch a running job.
- `htop` shows CPU use live. `ps -L` shows what each thread is doing, and the number of threads in state `R` is the number of busy CPUs.
- The `%CPU` in `ps` is an average over the process's life, not a live value.
- Our script is parallel for a few seconds and serial for the rest, which is what limited the speedup.
- Busy CPUs are not necessarily useful work. A profiler shows what they are doing.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: instructor

## Instructor notes

**Timing.** About 30 minutes of live coding and 15 of exercises. Do the setup together, step by step, because it is the
part most likely to go wrong. The disconnection demonstration (close the window, reconnect, reattach) is the one learners
remember.

**Check before the session.**

- Run the whole sequence on the node type learners will get. Confirm the exact `srun` command, that `module` works in the
  interactive shell (if it does not, start the shell with `bash -l`), and that `htop`, `watch` and `pgrep` are installed on
  the compute nodes.
- Confirm that `srun --jobid=<id> --overlap --pty bash` works, and what happens without `--overlap`. In recent Slurm versions
  a second step may wait for the first to release the CPUs.
- Check how long a run takes on the interactive CPUs, so that the burst is long enough to see in `htop`. With a few more CPUs
  the burst is shorter, and with fewer the serial part is a smaller share of the total.
- Confirm that the number of `R` threads really jumps between `1` and the CPU count in the `watch` output. Spinning threads
  also show as `R`, so the picture can be less clean than the text suggests, and the discrepancy is itself worth showing.
- Replace the illustrative outputs and add a real `htop` screenshot.
- Ask learners to use at most 8 CPUs, and a short time limit, so that the interactive sessions leave room on the partition.

**Mixed audience.** Windows users on PuTTY and MobaXterm need the terminal type set to `xterm-256color` for `tmux` and
`htop` to display well. Selecting text with the mouse may need the `Shift` key while `tmux` mouse mode is on. The `Ctrl+b`
prefix is the same on all systems. On a Mac, use the `Control` key, not `Command`.

**Common problems.**

- Starting `srun` before `tmux`, so that a lost connection ends the session.
- Using `tmux` on `falconlogin.cf.ac.uk`, then not finding the session after reconnecting to the other login node.
- Running `htop` in the second pane without attaching to the allocation, so it shows the login node.
- Forgetting `export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}` in the interactive shell, which changes the thread count.
- Forgetting to `exit` the interactive session, so the allocation stays reserved until its time limit.
- Reading the `%CPU` column of `ps` as a live figure.

::::::::::::::::::::::::::::::::::::::::::::::::
