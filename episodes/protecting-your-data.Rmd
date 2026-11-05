---
title: "Making the job script safe"
teaching: 25
exercises: 15
---

:::::::::::::::::::::::::::::::::::::: questions

- How do I stop one job from overwriting the results of another?
- How can the job script tell me about the job it is running in?
- How do I make a job script stop when something goes wrong, instead of carrying on?
- Where should a job write its files, and who cleans up afterwards?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Use Slurm environment variables to give files and directories unique names.
- Protect a script against typos and failures with `set -euo pipefail`.
- Use curly brackets around variable names to avoid silent naming mistakes.
- Run a job in a scratch directory, copy the results back and clean up.

::::::::::::::::::::::::::::::::::::::::::::::::

At the end of the last episode we ran the same job twice and the second run silently replaced `result_42.csv`. In a few
episodes our researcher will run hundreds of jobs, so the job script needs to be more careful first. Starting from the
script we had:

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
#SBATCH -p <partition>

module purge
module load SciPy-bundle/2023.07-gfbf-2023a

python sweep.py 42
```

## Slurm tells the job about itself

When a job starts, Slurm defines a set of **environment variables** that describe it. Add this line to the script, submit
it, and look at the `.o` file:

```bash
env | grep '^SLURM_' | sort
```

```output
SLURM_CPUS_PER_TASK=8
SLURM_JOB_ID=853278
SLURM_JOB_NAME=sweep-test
SLURM_JOB_NODELIST=<node>
SLURM_JOB_PARTITION=<partition>
SLURM_MEM_PER_NODE=16384
SLURM_NTASKS=1
SLURM_SUBMIT_DIR=/shared/home/c.myuser/sweep
...
```

The list is long. These are the ones we will use most:

| Variable | What it holds |
|---|---|
| `SLURM_JOB_ID` | the unique number of this job |
| `SLURM_JOB_NAME` | the name given with `-J` |
| `SLURM_SUBMIT_DIR` | the directory you ran `sbatch` from |
| `SLURM_CPUS_PER_TASK` | the CPUs per task you asked for (only set if you asked) |
| `SLURM_JOB_NODELIST` | the node(s) the job runs on |

Two uses follow immediately. The job number is **unique**, so it makes file and directory names that no other job can
share. And values such as the CPU count come from the request itself, so the script does not need editing when the
request changes.

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: which variable?

Which Slurm variable would you use to:

1. give a result file a name that no other job will use?
2. copy a file back to the directory the job was submitted from?
3. tell numpy how many threads to use, matching the CPUs you requested?

::::::::::::::::::::::::::::::::::::: solution

1. `SLURM_JOB_ID`
2. `SLURM_SUBMIT_DIR`
3. `SLURM_CPUS_PER_TASK`, for example `export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}`

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## Curly brackets protect variable names

We want result files called something like `result_42_853278.csv`, built from a seed and the job number. Here is a
natural first attempt, which you can test directly in the terminal with no job involved:

```bash
SEED=42
SLURM_JOB_ID=853278
echo result_$SEED_$SLURM_JOB_ID.csv
```

```output
result_853278.csv
```

The seed has vanished, and there is no error message. Bash reads `$SEED_` as a variable called `SEED_`, because the
underscore is allowed in variable names. That variable does not exist, so it expands to nothing. Curly brackets mark
exactly where the name ends:

```bash
echo result_${SEED}_${SLURM_JOB_ID}.csv
```

```output
result_42_853278.csv
```

Always write `${NAME}`, even when it is not strictly needed. It costs nothing and removes a whole class of silent
mistakes. If a path may contain spaces, put the whole thing in double quotes too: `"${WORKDIR}"`.

## Making the script stop when something goes wrong

By default Bash carries on after an error. For a job script that is dangerous, because later commands then run on the
results of a mistake. Three settings fix the worst cases. Put them at the top of the script, after the `#SBATCH` lines:

```bash
set -euo pipefail
```

| Setting | What it does |
|---|---|
| `-e` | stop the script as soon as a command fails |
| `-u` | treat a variable that was never set as an error |
| `-o pipefail` | a pipeline fails if **any** command in it fails, not only the last one |

:::::::::::::::::::::::::::::::::::::: callout

## Write it as `set -euo pipefail`

`-o pipefail` is a separate option, written as two words. Something like `set -eu -pipefail` does not turn it on. Bash
reads `-pipefail` as a string of unrelated one-letter options.

::::::::::::::::::::::::::::::::::::::::::::::::

Each one is easiest to understand through the mistake it catches. These run in a terminal and do not need a job.

**`-u` catches a mistyped variable.** Without it, the typo below silently expands to nothing:

```bash
SEED=42
echo "Running seed ${SEDD}"
```

```output
Running seed
```

```bash
set -u
echo "Running seed ${SEDD}"
```

```output
bash: SEDD: unbound variable
```

The same option turns the earlier `$SEED_` mistake into an error you can see.

**`-e` stops a script that has already gone wrong.** Imagine the work directory does not exist:

```bash
cd /no/such/directory
echo "Now working in $(pwd)"
```

```output
bash: cd: /no/such/directory: No such file or directory
Now working in /home/c.myuser
```

Without `-e`, the script carried on in the wrong directory. With `set -e` it stops at the failed `cd`. In a real job
that could be the difference between writing files in the wrong place and a clean failure.

**`-o pipefail` catches failures inside a pipeline.** A very common way to keep a log is to pipe the output through
`tee`:

```bash
false | tee log.txt; echo "exit status: $?"
```

```output
exit status: 0
```

`false` failed, but the pipeline reported success because `tee` succeeded. After `set -o pipefail`:

```bash
set -o pipefail
false | tee log.txt; echo "exit status: $?"
```

```output
exit status: 1
```

The same applies to Slurm. A job script reports the exit status of its **last command**. If `python` fails and a later
command succeeds, Slurm records the job as `COMPLETED` even though no result was produced. With `set -e`, the failure
is recorded as `FAILED`, with the exit code, which you can see with `sacct`.

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: what would have caught it?

For each mistake, say which of `-e`, `-u`, `-o pipefail` or curly brackets would have prevented a silent failure.

1. `cp result_$SEED_$SLURM_JOB_ID.csv ${SLURM_SUBMIT_DIR}` copies the wrong file or none at all.
2. `cd ${WROKDIR}` (a typo) is followed by commands that write files in the current directory.
3. `python sweep.py 4r | tee run.log` fails, but the job ends as `COMPLETED`.
4. `pyton sweep.py 42` (a typo) is followed by `cp result_42.csv ...`.

::::::::::::::::::::::::::::::::::::: solution

1. Curly brackets (`${SEED}_`) prevent it. `set -u` turns it into a visible error.
2. `set -u` stops the script because `WROKDIR` was never set.
3. `set -o pipefail`, together with `set -e` so that the failure ends the script.
4. `set -e` stops at `pyton: command not found`, so the job is marked `FAILED` and the copy is never attempted.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: callout

## A safety net, not a guarantee

`set -e` has exceptions: commands that are part of an `if` test or are followed by `||` are allowed to fail. Treat it as
a net for common accidents, not a replacement for checking results.

Some set-up scripts (for example `conda activate`, and occasionally a module) refer to variables that are not set. If a
job stops with an "unbound variable" error that comes from inside one of them, wrap just that line in `set +u` and
`set -u`.

::::::::::::::::::::::::::::::::::::::::::::::::

## Working on scratch

So far the job wrote its results next to the script. Falcon also has a large, fast area for job data called **scratch**,
at `/scratch/SCWFXXXXX/`, where `SCWFXXXXX` is your project code. A tidy pattern is:

1. create a new, unique directory on scratch for each job;
2. copy the inputs there and run the job in it;
3. copy the results you want to keep back to your own directory, with unique names;
4. delete the scratch directory.

<!-- TODO(author): say here what home and scratch are for (quota, backup, any automatic purge of scratch). -->

Scratch has a **quota**: by default 3 TB and 3 million files. Both limits count, and files left behind by finished jobs
count towards them.

<!-- TODO(author): give the command learners should use to check their quota and usage, e.g. [site quota command]. -->

:::::::::::::::::::::::::::::::::::::: challenge

## Challenge: which limit comes first?

Another application leaves 2,000 files and 5 GB of data in its scratch directory after every job, and nobody removes
them. How many jobs can you run before you reach each limit of 3 TB and 3 million files? Which one stops you first?

::::::::::::::::::::::::::::::::::::: solution

- Files: 3,000,000 / 2,000 = 1,500 jobs.
- Space: 3 TB is about 3,000 GB, and 3,000 GB / 5 GB = about 600 jobs.

The space quota is reached first, after about 600 jobs. Either one makes new writes fail, so jobs that run after that
point can fail in confusing ways. Cleaning up after each job avoids the problem.

:::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::::::::::::::

## The improved job script

Putting it all together:

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
#SBATCH -p <partition>

# stop on errors, unset variables and failures inside pipelines
set -euo pipefail

module purge
module load SciPy-bundle/2023.07-gfbf-2023a

# use the CPUs we asked for (more about this in the next episode)
export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}

# the seed is the first argument of the script, 42 if none is given
SEED=${1:-42}

# a unique work directory on scratch for this job
WORKDIR=/scratch/SCWFXXXXX/${USER}/sweep-test/${SLURM_JOB_ID}
mkdir -p "${WORKDIR}"

# copy inputs to the work directory and change dir
cp "${SLURM_SUBMIT_DIR}/sweep.py" "${WORKDIR}"
cd "${WORKDIR}"

echo "Job ${SLURM_JOB_ID}: seed ${SEED} on $(hostname) with ${SLURM_CPUS_PER_TASK} CPUs"

# run main program
python sweep.py "${SEED}"

# copy outputs back, with a unique name
cp "result_${SEED}.csv" "${SLURM_SUBMIT_DIR}/result_${SEED}_${SLURM_JOB_ID}.csv"

# clean up scratch (only reached if everything above succeeded)
cd "${SLURM_SUBMIT_DIR}"
rm -rf -- "${WORKDIR:?}"
```

What changed:

- `set -euo pipefail` protects the whole script.
- `export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}` makes numpy use exactly the CPUs we asked for. If we change the
  request, this line follows. If `--cpus-per-task` is missing from the script, `set -u` makes the job fail immediately
  instead of guessing.
- `SEED=${1:-42}` takes the seed from the command line (`sbatch sweep-test.sh 43`), with 42 as the default. We can now
  run different seeds without editing the file.
- The work directory and the result file both contain `${SLURM_JOB_ID}`, so nothing is overwritten.
- Everything in `${...}` is quoted, in case a path contains spaces.
- The cleanup comes last. If any earlier step fails, `set -e` stops the script before it, so the scratch directory and
  its files are **kept** for you to investigate.

:::::::::::::::::::::::::::::::::::::: callout

## Be careful with `rm -rf`

`${WORKDIR:?}` stops the script with an error if `WORKDIR` is unset or empty. Without it, a mistake such as
`rm -rf ${WORKDIR}/*` with an empty variable becomes `rm -rf /*`. Always build deletion commands from a variable that
cannot be empty, and never delete with a wildcard if you can name the directory.

::::::::::::::::::::::::::::::::::::::::::::::::

Submit it twice, with two different seeds:

```bash
sbatch sweep-test.sh 42
sbatch sweep-test.sh 43
```

```output
Submitted batch job 853301
Submitted batch job 853302
```

When both have finished:

```bash
ls
```

```output
result_42_853301.csv  result_43_853302.csv  sweep-test.e.853301  sweep-test.e.853302
sweep-test.o.853301   sweep-test.o.853302   sweep-test.sh        sweep.py
```

Every result and every log has its own name.

## What is left behind?

The script removes its scratch directory on success. If a job fails, or if you choose to keep data, the directory
stays. Look for old directories now and then:

```bash
ls /scratch/SCWFXXXXX/${USER}/sweep-test/
```

Check what you are about to delete before you delete it. For example, list the directories that have not been touched
for 30 days, and only then remove them:

```bash
find /scratch/SCWFXXXXX/${USER}/sweep-test -mindepth 1 -maxdepth 1 -mtime +30
```

You can add the removal to the job script, as above, or clean up by hand afterwards. Automatic cleanup is the safer
default for quota, and keeping data from failed jobs is the safer default for debugging, which is why the script
removes the directory only after everything succeeded.

:::::::::::::::::::::::::::::::::::::::: keypoints

- Slurm defines environment variables such as `SLURM_JOB_ID`, `SLURM_SUBMIT_DIR` and `SLURM_CPUS_PER_TASK` inside every job.
- Put `${SLURM_JOB_ID}` in file and directory names so that jobs cannot overwrite each other.
- Always write `${NAME}` with curly brackets, so Bash cannot misread where a variable name ends.
- Start job scripts with `set -euo pipefail` to stop on errors, unset variables and failed pipelines.
- Run in a unique scratch directory, copy back what you need and delete the directory only after everything succeeded.
- Scratch has a quota on space and on the number of files. Leftover files count against both.

::::::::::::::::::::::::::::::::::::::::::::::::

:::::::::::::::::::::::::::::::::::::: instructor

## Instructor notes

**Timing.** About 25 minutes of live coding and 15 of exercises. The small `echo` and `cd` demonstrations run in a
terminal on the login node and need no job, so they are safe and quick. Do them live and let learners predict each
result first.

**Check before the session.**

- Replace the illustrative outputs, `SCWFXXXXX`, and the project and partition placeholders. Make sure each learner can
  create a directory under their scratch path.
- Fill in the scratch policy and the quota command, and run the commands yourself first.
- Check that `module load` works under `set -u` on Falcon. If a module prints an "unbound variable" error, use the
  `set +u` workaround from the callout.
- Run the final script once and check that the scratch directory is removed.

**A useful extra demonstration.** Introduce a deliberate typo (`pyton sweep.py "${SEED}"`) and submit. Use `sacct` to show
`FAILED` with exit code 127, and `ls` on scratch to show that the directory was kept. Then remove `set -e` and show the
same job ending as `COMPLETED` even though no result exists. This is the best demonstration of why `-e` matters.

**This episode prepares later ones.** `OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK}` is used in the scaling episode, where
the CPU count is changed from the command line (`sbatch -c 4 sweep-test.sh`). The seed argument and unique names lead
to array jobs, where `SLURM_ARRAY_TASK_ID` provides the seed.

**Common problems.**

- Windows line endings in a script written elsewhere (see the previous episode).
- `set -eu -pipefail` copied from somewhere: it does not enable `pipefail`.
- `SLURM_CPUS_PER_TASK: unbound variable` because the script has no `--cpus-per-task`, which is `set -u` doing its job.
- `rm -rf` guards: stress `${WORKDIR:?}` and never deleting with wildcards.
- Learners clean up scratch by hand before the job has finished.

::::::::::::::::::::::::::::::::::::::::::::::::
