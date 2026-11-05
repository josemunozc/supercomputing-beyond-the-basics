---
title: "Finding the software and libraries you need"
teaching: 20
exercises: 15
---
 
:::::::::::::::::::::::::::::::::::::: questions
 
- Where do Python and NumPy come from on Falcon, and is the Python on the login node the one I should use?
- How do I search for software, including Python packages hidden inside bundle modules?
- How do I choose between several versions of the same software?
- Why must I not run my script on the login node?
::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives
 
- Explain why the system Python on the login node is not the one to use, and why compute work must not run there.
- Search for software with `module spider` and understand what an extension is.
- Make `module avail` show extensions with `LMOD_AVAIL_EXTENSIONS`.
- Read a module name and choose a consistent set of modules.
- Load modules and check that the right Python and NumPy are being used.
::::::::::::::::::::::::::::::::::::::::::::::::

## The first thing our researcher meets
 
Our researcher's script needs Python and NumPy. After logging in to Falcon, she tries Python: 

```bash
python
```
 
```output
Python 3.9.25 (main, Aug  6 2026, 00:00:00)
[GCC 11.5.0 20240719 (Red Hat 11.5.0-14)] on linux
Type "help", "copyright", "credits" or "license" for more information.
```
 
```python
>>> import numpy as np
>>> np.__path__
['/usr/lib64/python3.9/site-packages/numpy']
>>> np.__version__
'1.23.5'
```


Python and NumPy are both there. Can she just run her script?
 
This is the Python that comes with the operating system, and it is not the one to use for your work:
 
- Its versions are whatever the operating system provides, which may be older than your code expects.
- It is managed with the operating system rather than as part of the software stack we install and test for the compute
  nodes.
- You cannot switch it for another version, and a script that depends on it is harder to reproduce later.

There is a bigger problem, too.

## Why not run the script on the login node?
 
The login node is shared by everyone, and it is a very large machine. Check how many CPUs Python can see:
 
```bash
python -c "import os; print(os.cpu_count(), len(os.sched_getaffinity(0)))"
```
 
```output
192 192
```

Libraries such as NumPy do their heavy linear algebra with a multi-threaded library (BLAS/LAPACK), and by default it
starts **one thread for every CPU it can see**. Run our script here and a single `python` command quietly tries to use
all 192 CPUs. Everyone else's shells, editors and file transfers slow down, and the script itself does not run faster,
because the problem is too small to use 192 threads well.
 
:::::::::::::::::::::::::::::::::::::: callout
 
## Please do not run the script on the login node
 
Use the login node to edit files, submit jobs and check results. Run anything that computes through Slurm, using
`sbatch` or an interactive allocation, where you get only the CPUs you asked for. We will look at controlling the
thread count properly when we write the job script.
 
::::::::::::::::::::::::::::::::::::::::::::::::


So where should we get Python and NumPy from? Falcon provides software through **environment modules** (Lmod), and
each module sets up your shell to use one piece of software. Maybe NumPy has a module of its own?
 
```bash
module load numpy
```
 
```output
Lmod has detected the following error: These module(s) or extension(s) exist but cannot be loaded as requested: "numpy"
   Try: "module spider numpy" to see how to load the module(s).
```
 
And searching the list of available modules does not help either:
 
```bash
module avail numpy
```
 
```output
No module(s) or extension(s) found!
If the avail list is too long consider trying:

"module --default avail" or "ml -d av" to just list the default modules.
"module overview" or "ml ov" to display the number of modules for each name.

Use "module spider" to find all possible modules and extensions.
Use "module keyword key1 key2 ..." to search for all possible modules matching any of the "keys".
```
 
So is NumPy on Falcon as a module or not?


## Modules and extensions
 
Many Python packages are not installed as separate modules. They are installed together as a **bundle**, and each
package inside the bundle is an **extension** of that module. For example, one module can provide Python itself plus
NumPy, SciPy and pandas. Listing every extension in `module avail` would bury the list of modules in thousands of lines,
so they are hidden by default.
 
There are two ways to see them.

### Searching with `module spider`
 
`module spider` searches all the software on the system, including extensions:
 
```bash
module spider numpy
```
 
```output
----------------------------------------------------------------------------
  numpy:
----------------------------------------------------------------------------
     Versions:
        numpy/1.21.3 (E)
        numpy/1.25.1 (E)
        numpy/1.26.2 (E)
        numpy/1.26.4 (E)
        numpy/2.3.1 (E)
        numpy/2.3.2 (E)

Names marked by a trailing (E) are extensions provided by another module.
 
----------------------------------------------------------------------------
  For detailed information about a specific "numpy" package (including how to load the modules) use the module's full name.
  Note that names that have a trailing (E) are extensions provided by other modules.
  For example:

     $ module spider numpy/2.3.2

----------------------------------------------------------------------------
```
 
The `(E)` marks an extension. Ask about one version to find out which module provides it:
 
```bash
module spider numpy/1.25.1
```
 
```output
----------------------------------------------------------------------------
  numpy: numpy/1.25.1 (E)
----------------------------------------------------------------------------
    This extension is provided by the following modules. To access the extension you must load one of the following modules. Note that any module names in parentheses show the module location in the software hierarchy.


       SciPy-bundle/2023.07-gfbf-2023a


Names marked by a trailing (E) are extensions provided by another module.

```
 
So the module to load for this course is `SciPy-bundle/2023.07-gfbf-2023a`, not `numpy`.



### Showing extensions in `module avail`
 
Setting an environment variable makes `module avail` include extensions too:
 
```bash
export LMOD_AVAIL_EXTENSIONS=yes
module avail numpy
```
 
This is the "full view". It can make the plain `module avail` list very long, so use it with a search term. To keep the
setting in future sessions, add the `export` line to your `~/.myenv` file.
 
:::::::::::::::::::::::::::::::::::::: callout
 
## Searching the output with grep
 
Lmod prints its messages to the error stream, so `module avail | grep numpy` shows nothing useful. Redirect the error
stream into the pipe:
 
```bash
module avail 2>&1 | grep -i numpy
```
 
::::::::::::::::::::::::::::::::::::::::::::::::


## Reading a module name
 
```
SciPy-bundle/2023.07-gfbf-2023a
```
 
| Part           | Meaning                                    |
|----------------|--------------------------------------------|
| `SciPy-bundle` | the software (a bundle of Python packages) |
| `2023.07`      | the version of the bundle                  |
| `gfbf-2023a`   | the **toolchain**: the compiler and maths libraries it was built with, and its release generation |
 
The toolchain matters. Modules built with the same toolchain generation (here `2023a`) are designed to work together.
**Do not mix generations** in one session (for example a `2023a` module with a `2024a` one), because mismatched
libraries can cause confusing errors.
 
Loading a module also loads what it depends on. Load it, then check what you got:
 
```bash
module load SciPy-bundle/2023.07-gfbf-2023a
module list
which python
python -c "import numpy; print(numpy.__version__, numpy.__file__)"
```
 
You should now see Python and NumPy from the module tree (the path starts with the software directory, not `/usr`),
instead of the 3.9 and 1.23.5 we saw at the start. This check is a cheap, one-second command, so it is fine on the
login node. Running the script is not.
 
:::::::::::::::::::::::::::::::::::::: challenge
 
## Challenge: find the software
 
Start with a clean session: `module purge`.
 
1. `module spider numpy` lists several versions. Which module provides the **newest** one?
2. List which other extensions that module contains, for example whether it includes SciPy and pandas.
3. Load that module and print the NumPy version and where it was imported from.

::::::::::::::::::::::::::::::::::::: solution
 
1. `module spider numpy` shows the versions. Run `module spider numpy/2.3.2`, and the module under
   "provided by the following modules" is the one to load.
2. `module spider SciPy-bundle/2025.07-gfbf-2025b` or `module help SciPy-bundle/2025.07-gfbf-2025b`
    describes the module and lists the extensions it contains. After setting `LMOD_AVAIL_EXTENSIONS=yes`,
    `module avail scipy` and `module avail pandas` show them too.
3. ```bash
   module load SciPy-bundle/2025.07-gfbf-2025b
   python -c "import numpy; print(numpy.__version__, numpy.__file__)"
   ```
 
:::::::::::::::::::::::::::::::::::::
 
::::::::::::::::::::::::::::::::::::::::::::::::


:::::::::::::::::::::::::::::::::::::: challenge
 
## Challenge: choosing consistently
 
If you also need a plotting library. `module avail matplotlib` suggests a module from the `2024a` toolchain, among
others, but your NumPy module uses `2023a`.
 
1. What can go wrong if you load both?
2. What would you do instead?

::::::::::::::::::::::::::::::::::::: solution
 
1. Modules from different toolchain generations were built against different compilers and libraries. Loading both can
   fail outright or load clashing libraries, so a script that imports one package may crash with errors that do not
   mention modules at all.
2. Look for a matching module: `module load matplotlib/3.7.2-gfbf-2023a` will load a set of libraries compatible with
   our `2023a` toolchain. If you need additional libraries and you cannot find them available for your selected
   toolchain, ask us.
:::::::::::::::::::::::::::::::::::::
 
::::::::::::::::::::::::::::::::::::::::::::::::
 
:::::::::::::::::::::::::::::::::::::: challenge
 
## Optional challenge: how many CPUs will my job see?
 
You saw 192 on the login node. Once you have an interactive allocation (see
[the interactive sessions episode](LINK-TO-INTERACTIVE-EPISODE)) that asked for 4 CPUs, run the same one-liner inside
it. Do the two numbers differ, and what does that tell you about where to run your script?
 
::::::::::::::::::::::::::::::::::::: solution
 
Inside a Slurm job the second number (`len(os.sched_getaffinity(0))`) should be the number of CPUs you were allocated
(for example 4), while `os.cpu_count()` may still report all the CPUs of the node. The allocation limits where your
processes can run, which is why the compute nodes are the place for your script.
 
:::::::::::::::::::::::::::::::::::::
 
::::::::::::::::::::::::::::::::::::::::::::::::



:::::::::::::::::::::::::::::::::::::::: keypoints
 
- Python packages are often extensions inside a bundle module, and `module load numpy` fails if there is no module with that name.
- `module spider` finds everything, including extensions, and tells you which module to load.
- `export LMOD_AVAIL_EXTENSIONS=yes` makes `module avail` show extensions as well.
- A module name has the form software/version-toolchain, and modules in one session should share a toolchain generation.
- In job scripts use `--login`, `module purge`, and full module names.
::::::::::::::::::::::::::::::::::::::::::::::::


:::::::::::::::::::::::::::::::::::::: instructor
 
## Instructor notes
 
**Timing.** About 20 minutes of live coding and 15 of exercises. Let learners predict the result of each command before
you run it. If time is short, drop the optional CPU-count challenge, which also fits the interactive sessions episode.
 
**Do not run `sweep.py` on the login node in the session.** The `os.cpu_count()` check makes the point without loading
the node. The actual effect is shown later on a compute node, with `htop` open next to the job.
 
**Check before the session.**
 
- Run every command on the node type used for the course and replace the illustrative outputs with the real ones.
  The Python and NumPy session at the start is from the login node.
- Make sure there is something to find: a NumPy version from at least two toolchain generations, so the choosing
  challenge works. Adjust the matplotlib example to match what is installed.
- Confirm that `os.sched_getaffinity(0)` inside a Slurm job shows the allocated CPUs on Falcon, because it depends on how
  Slurm's CPU binding is configured.
- If Falcon uses a spider cache, very recently installed software may not show up until it is refreshed, which can
  confuse a live demo.

**Software differs by architecture.** The software trees on Falcon differ by CPU type, which you can see in the
install paths (for example `.../amd/zen4/...` versus `.../intel/cascadelake/...`). The modules listed can therefore
depend on the node you are on. This links to the architectures episode, and an optional extension is to run
`module spider numpy` in an interactive session on a different node type and compare. Confirm that this matches how
Falcon is configured before presenting it.
 
**Common problems.**
 
- Typing `module load numpy` and concluding that NumPy is missing.
- Mixing toolchain generations, which produces errors that do not mention modules.
- Piping `module avail` into `grep` without `2>&1`.
- Forgetting `--login` in a job script, so `module: command not found`.
- Running a "quick test" of the real script on the login node.
::::::::::::::::::::::::::::::::::::::::::::::::

