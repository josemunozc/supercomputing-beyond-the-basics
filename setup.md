---
title: Setup
---


You can already log in to Falcon and run jobs. This lesson takes you from
there to running your work faster and more reliably. Everything is built
around one Python program that is fine on a laptop but disappointing on a
supercomputer, and through live coding we find out why and fix it step by step.

:::::::::::::::::::::::::::::::::::::: prereq
## Prerequisites

- A Falcon user account and a project to run jobs under (contact us if you
  need temporary access to a training project, see [Setup](learners/setup.md))
- Comfort with the Linux command line: moving around directories, copying
  files and editing a text file
- Experience submitting a simple Slurm batch job (`sbatch`, `squeue`)
- No Python programming is needed
::::::::::::::::::::::::::::::::::::::::::::::::


## After this lesson you will be able to

- Set up SSH keys for passwordless access
- Identify the CPU and GPU architectures on Falcon and explain how they affect software
- Find and load additional software and Python packages
- Write more robust job scripts using Slurm environment variables and shell safeguards
- Estimate resource requirements and measure job efficiency
- Use `tmux` and live monitoring tools in interactive sessions
- Use a profiler to find performance bottlenecks
- Run many tasks with array jobs and GNU Parallel, and explain QOS limits
- Run applications on GPU partitions


## Data Sets

<!--
FIXME: place any data you want learners to use in `episodes/data` and then use
       a relative link ( [data zip file](data/lesson-data.zip) ) to provide a
       link to it, replacing the example.com link.
-->
Download the [data zip file](data/data.zip) and unzip it to your Desktop

## Software Setup

Attendees need a program to connect via SSH to the Falcon supercomputer.

Remember you need to enable [Cardiff VPN][cardiff-vpn-students] client to connect to
Falcon and our [documentation website][arcca-docs].

**Optional**: Install Python and Numpy on your laptop to run `sweep.py` included in the
[data zip file](data/data.zip) to obtain base runtimes for comparison
with Falcon. 

**Optional**: Install [Linaro Forge (remote client only)][linaro-forge] to analyse
profiler files.

<!--
::::::::::::::::::::::::::::::::::::::: discussion

### Details

Setup for different systems can be presented in dropdown menus via a `spoiler`
tag. They will join to this discussion block, so you can give a general overview
of the software used in this lesson here and fill out the individual operating
systems (and potentially add more, e.g. online setup) in the solutions blocks.

:::::::::::::::::::::::::::::::::::::::::::::::::::
-->
:::::::::::::::: spoiler

### Windows

Use Powershell or PuTTY

::::::::::::::::::::::::

:::::::::::::::: spoiler

### MacOS

Use Terminal.app

::::::::::::::::::::::::


:::::::::::::::: spoiler

### Linux

Use Terminal

::::::::::::::::::::::::

