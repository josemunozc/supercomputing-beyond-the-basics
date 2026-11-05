---
title: "Introduction"
teaching: 10 # teaching time in minutes
exercises: 2 # exercise time in minutes
---

:::::::::::::::::::::::::::::::::::::: questions 

- What's the problem we are trying to solve?
- Is it suitable for a supercomputer?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Run a simple Python script locally and measure runtimes.

::::::::::::::::::::::::::::::::::::::::::::::::

## Introduction

For this lesson we will role play as a student developing two small functions
to implement some well known statistical techniques on relatively large
matrices:

 - Principal Component Analysis, a dimensionality-reduction technique,
   useful for summarising many measurements into fewer underlying "factors".
 - Mean pairwise distance calculation, taking the first m rows and computing
   the average Euclidean distance between every pair of rows

<!--
:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::: instructor

Inline instructor notes can help inform instructors of timing challenges
associated with the lessons. They appear in the "Instructor View"

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
-->
::::::::::::::::::::::::::::::::::::: challenge 

## Challenge 1: Run the program.

What is the output of this command? How long it takes?

```shell
$ python sweep.py 42
```
Try it a few times with different seed numbers.

:::::::::::::::::::::::: solution 

## Output
 
```output
(42, 0.004810541356349191, 109.50135188527557, 23.97225150000304)
```
The last element in the array provides the program runtime.
:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::


::::::::::::::::::::::::::::::::::::: challenge 

## Challenge 2: What Numpy version do we have?

:::::::::::::::::::::::: solution 

```python
>>> import numpy as np
>>> np.__version__
'1.24.3'
```
:::::::::::::::::::::::::::::::::
::::::::::::::::::::::::::::::::::::::::::::::::


## The code
This is the base code we will be using in this course. You can copy it from here or donwload it
with th [data zip file](https://example.com/FIXME).

~~~ {#sweep.py .python}
# sweep.py
import sys, time
import numpy as np

# Creates a relatively large matrix of random numbers (drawn from a standard normal distribution).
# Uses a seed (passed in from the command line) so the data is reproducible —
# same seed → same numbers every time.
# This is essential for science: results must be verifiable.
def make_data(seed, n=12000, p=6000):
    return np.random.default_rng(seed).standard_normal((n, p))

# Principal Component Analysis, a dimensionality-reduction technique;
# useful for summarising many measurements into fewer underlying "factors"
# The function below uses BLAS/LAPACK heavily: threaded and sensitive to CPU kernels
def pca_variance(X, k=10):
    # Centre the data (subtract each column's mean).
    Xc = X - X.mean(axis=0)
    # Build the covariance matrix
    cov = Xc.T @ Xc / (len(Xc) - 1)
    # compute eigenvalues
    w = np.linalg.eigvalsh(cov)[::-1]
    #Return the fraction of total variance explained by the top 10 components
    return w[:k].sum() / w.sum()

# Compute mean pairwise distance
# Takes the first m rows and computes the average Euclidean distance between every pair of rows
# deliberately naive loop: single-threaded, vectorise it later
def mean_pair_distance(X, m=800):
    total = 0.0
    for i in range(m):
        for j in range(i + 1, m):
            total += np.sqrt(((X[i] - X[j]) ** 2).sum())
    return total / (m * (m - 1) / 2)

if __name__ == "__main__":
    seed = int(sys.argv[1])
    t0 = time.perf_counter()
    X = make_data(seed)
    out = (seed, pca_variance(X), mean_pair_distance(X), time.perf_counter() - t0)
    np.savetxt(f"result_{seed}.csv", [out], delimiter=",")
    print(out)
~~~

<!--
## Figures

You can use standard markdown for static figures with the following syntax:

`![optional caption that appears below the figure](figure url){alt='alt text for
accessibility purposes'}`

![You belong in The Carpentries!](https://raw.githubusercontent.com/carpentries/logo/master/Badge_Carpentries.svg){alt='Blue Carpentries hex person logo with no text.'}

::::::::::::::::::::::::::::::::::::: callout

Callout sections can highlight information.

They are sometimes used to emphasise particularly important points
but are also used in some lessons to present "asides": 
content that is not central to the narrative of the lesson,
e.g. by providing the answer to a commonly-asked question.

::::::::::::::::::::::::::::::::::::::::::::::::


## Math

One of our episodes contains $\LaTeX$ equations when describing how to create
dynamic reports with {knitr}, so we now use mathjax to describe this:

`$\alpha = \dfrac{1}{(1 - \beta)^2}$` becomes: $\alpha = \dfrac{1}{(1 - \beta)^2}$

Cool, right?

-->
::::::::::::::::::::::::::::::::::::: keypoints 

- A relatively simple program can become a challenge when we need to *scale up*.
- For example, when we need to handle bigger datasets in disk or memory.
- Or we need to work with more complex models that require more compute power (*High Performance Computing or HPC*).
- Or when we need to run the program many many times (*High Throughtput Computing or HTC*).
- Or all of the above...

::::::::::::::::::::::::::::::::::::::::::::::::
[r-markdown]: https://rmarkdown.rstudio.com/
