# CVTree: sequential and OpenMP implementations

This program reads protein sequences, constructs composition vectors, and calculates similarity scores for every unique pair of input datasets.

## Included files

- `improved_before.cpp`: original sequential implementation, before changes.
- `improved.cpp`: modified implementation with correctness fixes, phase timing, and OpenMP parallelisation.
- `list.txt`: number and names of the input datasets.
- `data/`: the 41 protein FASTA datasets used for testing.
- `tidy.cpp`: additional original reference implementation; not used by the build instructions below.
- `benchmark_final.cmd`: runs repeated serial and OpenMP benchmarks using 1 through 8 OpenMP threads and checks the numerical output of each run.
- `summarise_final.ps1`: summarises the benchmark results and calculates median execution time, speedup, and parallel efficiency.

The modified implementation parallelises composition-vector preparation and pairwise comparisons. Comparison results are printed sequentially in a fixed order.

## Software requirements

- Windows with an x64 C++ toolchain.
- Microsoft Visual Studio or Visual Studio Build Tools with the Desktop development with C++ workload installed.
- MSVC compiler with OpenMP support.

Tested compiler: MSVC 19.51.36256 for x64.

VS Code can be used to edit the source. Run the compilation and execution commands below in the x64 Native Tools Command Prompt for VS.

## Hardware requirements

A multicore CPU is needed to benefit from multiple OpenMP threads.

On the tested MSVC data model, composition-vector construction requires approximately 0.75 GiB of temporary arrays per active construction worker, in addition to retained sparse vectors, application overhead, and memory needed by Windows.

Four concurrent construction workers therefore require approximately 3 GiB for temporary arrays alone.

Test machine:

- CPU: Intel Core Ultra 7 258V (2.20 GHz)
- Installed RAM: 32.0 GB (31.5 GB usable)
- System: 64-bit Windows, x64-based processor

## Input datasets

The supplied `data/` directory contains 41 `.faa` files containing protein sequences in FASTA format. `list.txt` selects these files.

The first value in `list.txt` is the number of datasets. Each subsequent entry is a filename without the `data/` prefix or `.faa` extension.

For example, `AcMNPV` identifies `data/AcMNPV.faa`.

The supplied list produces:

```text
41 × 40 / 2 = 820
```

unique pairwise comparisons.

Keep `list.txt` and `data/` together in the project root. The program uses paths relative to its working directory, not the executable's location.

The reader retains assumptions from the original implementation: dataset names up to nine characters, supported uppercase amino-acid symbols, and at least five consecutive residues immediately after each FASTA header. Use the supplied dataset for reproducing these results.

## Build

Open the x64 Native Tools Command Prompt and change into the project folder containing the source files, `list.txt`, and `data/`.

Create output directories:

```cmd
if not exist build mkdir build
if not exist results mkdir results
```

Compile the original sequential version:

```cmd
cl /nologo /EHsc /O2 /std:c++17 /fp:precise improved_before.cpp /Fo"build\before.obj" /Fe"build\cvtree_before.exe"
```

Compile the modified sequential version:

```cmd
cl /nologo /EHsc /O2 /std:c++17 /fp:precise improved.cpp /Fo"build\serial.obj" /Fe"build\final_serial.exe"
```

Compile the modified OpenMP version:

```cmd
cl /nologo /EHsc /O2 /std:c++17 /fp:precise /openmp improved.cpp /Fo"build\openmp.obj" /Fe"build\final_openmp.exe"
```

Without `/openmp`, the guarded OpenMP directives are excluded. The modified sequential executable therefore contains the same correctness fixes, algorithm, and timing code as the parallel executable but executes sequentially.

## Run

Run all commands from the project root.

Original sequential version:

```cmd
build\cvtree_before.exe > results\before.txt
```

Modified sequential version:

```cmd
build\final_serial.exe > results\serial.txt
```

Modified parallel version with two threads:

```cmd
set OMP_DYNAMIC=FALSE
set OMP_NUM_THREADS=2
build\final_openmp.exe > results\parallel.txt
```

Change `OMP_NUM_THREADS` to select another thread count between 1 and 8.

The terminal remains quiet while output is redirected into a file. Wait for the command prompt to return before entering the next command.

Immediately after a run, check its exit code:

```cmd
echo Exit code: %ERRORLEVEL%
```

A successful run should return 0.

Display the modified program's timings:

```cmd
findstr /C:"seconds" results\parallel.txt
```

The modified program reports vector-preparation time, pair-comparison time, and total elapsed wall time.

## Validate numerical output

Run the modified sequential implementation:

```cmd
build\final_serial.exe > results\serial.txt
```

Extract its pairwise results to create the expected baseline:

```cmd
findstr /C:" -> " results\serial.txt > results\expected_pairs.txt
```

Run the OpenMP implementation, for example using two threads:

```cmd
set OMP_DYNAMIC=FALSE
set OMP_NUM_THREADS=2
build\final_openmp.exe > results\parallel.txt
```

Extract the parallel pairwise results:

```cmd
findstr /C:" -> " results\parallel.txt > results\parallel_pairs.txt
```

Check the number of comparison lines:

```cmd
find /C " -> " results\expected_pairs.txt results\parallel_pairs.txt
```

Both files should contain 820 lines for the supplied dataset.

Compare the results:

```cmd
fc /b results\expected_pairs.txt results\parallel_pairs.txt
```

The expected result is:

```text
FC: no differences encountered
```

Timing and progress messages are excluded from this comparison.

## Final performance benchmark

Before running the benchmark, ensure that `final_serial.exe` and `final_openmp.exe` have been compiled and create the expected output file:

```cmd
build\final_serial.exe > results\serial.txt
findstr /C:" -> " results\serial.txt > results\expected_pairs.txt
```

Run:

```cmd
benchmark_final.cmd
```

The benchmark tests:

- modified sequential execution,
- 1 OpenMP thread,
- 2 OpenMP threads,
- 3 OpenMP threads,
- 4 OpenMP threads,
- 5 OpenMP threads,
- 6 OpenMP threads,
- 7 OpenMP threads,
- 8 OpenMP threads.

Each configuration receives one unmeasured warm-up run followed by five measured runs.

The execution order is reversed on alternating rounds to reduce consistent first- or last-run bias.

Every run is compared against `results\expected_pairs.txt` to confirm that the parallel implementation produces the same numerical results as the modified sequential implementation.

A successful benchmark ends with:

```text
SUCCESS: all measured runs completed and matched the baseline.
```

## Summarise benchmark results

After the benchmark has completed, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\summarise_final.ps1
```

The script generates:

```text
results\final_raw.csv
results\final_summary.csv
```

`final_raw.csv` contains the timing results from all measured runs.

`final_summary.csv` contains median vector-preparation time, pair-comparison time, total execution time, speedup, and parallel efficiency for the sequential version and OpenMP thread counts from 1 through 8.

Speedup is calculated relative to the median execution time of the modified sequential implementation.

## Performance measurements

The report compares repeated runs of the modified sequential executable and the modified OpenMP executable using identical compiler optimisation settings.

The original sequential source is included separately to show the implementation before changes and to demonstrate the sequential optimisation process.

Performance results, profiling results, speedup, efficiency, and analysis of the parallel implementation are presented in the accompanying report.