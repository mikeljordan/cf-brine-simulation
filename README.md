# Reproducibility image for salt precipitation and multiphase geothermal flow

This repository provides the Docker image used to reproduce the simulations and figures for

> Oguntola, M. B., Duran, O., Keilegavlen, E., Berre, I. (2026).  
> *Mathematical Modeling of Salt Precipitation and Multi-Phase Flow in High Enthalpy Fractured Geothermal Systems.*

The image contains the PorePy paper branch, ParaView 6.1.0, Python plotting dependencies, LaTeX support for Matplotlib text rendering, and the H₂O--NaCl thermodynamic lookup tables required by the simulations. The Dockerfile builds the image from `porepy/dev:latest`, switches to the `cf-dfm-salt-precipitation` branch, downloads the VTK lookup tables from Zenodo, and verifies their MD5 checksums during the build.

The thermodynamic lookup tables (~3 GB) are pulled from a Zenodo deposit:

> Oguntola, M. B. (2026).
> *Thermodynamic lookup tables for H₂O–NaCl systems based on Driesner & Heinrich (2007) correlations.*
> Zenodo. [doi:10.5281/zenodo.20394023](https://doi.org/10.5281/zenodo.20394023)

---

## Repository contents

This Docker repository contains only the files needed to build and run the reproducibility image:

```text
Dockerfile
entrypoint.sh
README.md
.dockerignore
.gitignore
```

The simulation source code, YAML configuration files, ParaView state files, plotting scripts, and benchmark reference data are pulled from the PorePy paper branch during the Docker build.

---

## Prerequisites

You need:

- Docker installed on the host machine.
- Internet access during the Docker build.
- Sufficient disk space for the Docker image and simulation outputs.
- On Apple Silicon machines, build the image explicitly for `linux/amd64`.

No local installation of PorePy, Python, ParaView, or LaTeX is required on the host.

---

## Build the Docker image

From the directory containing the `Dockerfile`, run:

```bash
docker build --platform linux/amd64 \
  -t h2o-nacl-geothermal-simulator:v1.0.0 .
```

The build performs smoke tests at the end:

```text
python -m geothermal_flow.simulation_driver --help
python -m geothermal_flow.make_figures --help
pvbatch --version
latex --version
kpsewhich lmodern.sty
```

These tests fail the build early if the simulation driver, figure driver, ParaView, or LaTeX setup is broken.

After the build finishes, confirm that the image exists:

```bash
docker images
```

You should see:

```text
h2o-nacl-geothermal-simulator   v1.0.0
```

---

## Run the container

Create a host directory for simulation outputs and figures:

```bash
mkdir -p work
```

Start the container:

```bash
# Start container in background
docker run -dit \
  --name geothermal-run \
  -v "$PWD/work:/workdir/data" \
  h2o-nacl-geothermal-simulator:v1.0.0

# Attach to it
docker exec -it geothermal-run /bin/bash
```

Inside the container, you will land in:

```text
/workdir/porepy/src/porepy/examples
```

The container uses symbolic links so that the simulation and figure workflow write outputs to `/workdir/data`, which is bind-mounted to `work/` on the host. The Dockerfile links these directories:

```text
visualization -> /workdir/data/visualization
output        -> /workdir/data/output
csv           -> /workdir/data/csv
figures       -> /workdir/data/figures
```

The entrypoint creates these output directories at container startup, after the host bind mount is active.

---

## Run the simulations

Run commands from inside the container.

### Benchmark

```bash
python -m geothermal_flow.simulation_driver \
  --config geothermal_flow/configs/benchmark.yaml
```

Expected host output:

```text
work/visualization/benchmark/
```

### Example 1

Disconnected-fracture case with mild clogging, `φ = 0.1`.

```bash
python -m geothermal_flow.simulation_driver \
  --config geothermal_flow/configs/example1.yaml
```

Expected host output:

```text
work/visualization/example1/
```

### Example 2

Disconnected-fracture case with stronger clogging, `φ = 1.0`.

```bash
python -m geothermal_flow.simulation_driver \
  --config geothermal_flow/configs/example2.yaml
```

Expected host output:

```text
work/visualization/example2/
```

### Example 3

Connected-fracture case.

```bash
python -m geothermal_flow.simulation_driver \
  --config geothermal_flow/configs/example3.yaml
```

Expected host output:

```text
work/visualization/example3/
```

---

## Recommended simulation order

For full figure reproduction, run:

```bash
python -m geothermal_flow.simulation_driver --config geothermal_flow/configs/benchmark.yaml
python -m geothermal_flow.simulation_driver --config geothermal_flow/configs/example1.yaml
python -m geothermal_flow.simulation_driver --config geothermal_flow/configs/example2.yaml
python -m geothermal_flow.simulation_driver --config geothermal_flow/configs/example3.yaml
```

The benchmark is the shortest useful smoke test. Some full examples may take a long time, depending on hardware.

---

## Generate figures

The Docker image uses a Docker-specific figure manifest:

```text
geothermal_flow/configs/figures.yaml
```

This file points ParaView to the Linux container path:

```text
/opt/paraview/bin/pvbatch
```

Generate all figures:

```bash
python -m geothermal_flow.make_figures \
  --config geothermal_flow/configs/figures.yaml
```

Generate selected figures:

```bash
python -m geothermal_flow.make_figures \
  --config geothermal_flow/configs/figures.yaml \
  --figures figure8 figure9
```

Preview commands without executing them:

```bash
python -m geothermal_flow.make_figures \
  --config geothermal_flow/configs/figures.yaml \
  --dry-run
```

Final figures are written to:

```text
work/figures/
```

Intermediate extracted data are written to:

```text
work/csv/
work/output/
```

---

## Figure dependencies

Some figures depend on more than one simulation.

| Figures | Required simulation output |
|---|---|
| `figure6` | benchmark |
| Example 1 figures | example1 |
| Example 2 figures | example2 |
| Example 3 figures | example3 |
| Comparison figures involving `φ = 0.1` and `φ = 1.0` | example1 and example2 |

In particular, near-well and production-diagnostics comparison figures require both Example 1 and Example 2 outputs.

---

## Output structure on the host

After simulations and figure generation, the host `work/` directory will look like:

```text
work/
  visualization/
    benchmark/
    example1/
    example2/
    example3/

  csv/
    benchmark/
    example1/
    example2/
    example3/

  output/
    example1/
    example2/

  figures/
    benchmark/
    example1/
    example2/
    example3/
```

Because `work/` is mounted from the host, these files remain after the container exits.

---

## Re-entering the container

The container is removed when you exit because of `--rm`, but the image and host outputs remain.

To re-enter:

```bash
docker run --rm -it \
  -v "$PWD/work:/workdir/data" \
  h2o-nacl-geothermal-simulator:v1.0.0
```

---

## Running long simulations

For long simulations, consider running the container with a name:

```bash
docker run -it \
  --name geothermal-run \
  -v "$PWD/work:/workdir/data" \
  h2o-nacl-geothermal-simulator:v1.0.0
```

Then, from another terminal, you can attach or inspect the container:

```bash
docker exec -it geothermal-run bash
```

When finished, remove it manually:

```bash
docker rm geothermal-run
```

For remote machines, use `tmux` or `screen` so that the terminal session is not lost.

---

## Troubleshooting

### `ModuleNotFoundError: geothermal_flow`

Make sure you are running commands from inside the container. The default working directory should be:

```text
/workdir/porepy/src/porepy/examples
```

Check with:

```bash
pwd
```

### Output directory errors

If you see errors involving paths such as:

```text
visualization/benchmark
csv/
output/
figures/
```

make sure the container was started with the host mount:

```bash
-v "$PWD/work:/workdir/data"
```

The entrypoint creates the required output subdirectories under `/workdir/data` at startup.

### ParaView warnings

ParaView may print rendering warnings such as OpenGL, OpenVKL, or texture-cleanup warnings. If the expected PNG file is produced, these warnings are usually harmless.

For headless rendering problems, use:

```bash
xvfb-run -a python -m geothermal_flow.make_figures \
  --config geothermal_flow/configs/figures_docker.yaml \
  --figures figure8
```

### LaTeX or Matplotlib text errors

The image installs LaTeX packages required by the plotting scripts, including `lmodern`. The build checks this with:

```text
kpsewhich lmodern.sty
```

If LaTeX errors still occur, rebuild the image from the current Dockerfile.

### Zenodo VTK table download fails

The build downloads the VTK lookup tables from Zenodo record `20394023` and verifies their MD5 checksums. If the download or checksum check fails, retry the build. A persistent failure may indicate a network or Zenodo availability issue.

---

## Saving the Docker image for Zenodo

After testing, save the image as a compressed archive:

```bash
docker image save h2o-nacl-geothermal-simulator:v1.0.0 \
  | gzip > h2o_nacl_geothermal_simulator_v1.0.0.tar.gz
```

Create a checksum:

```bash
shasum -a 256 h2o_nacl_geothermal_simulator_v1.0.0.tar.gz \
  > h2o_nacl_geothermal_simulator_v1.0.0.tar.gz.sha256
```

To load the image later:

```bash
docker load -i h2o_nacl_geothermal_simulator_v1.0.0.tar.gz
```

Then run:

```bash
docker run --rm -it \
  -v "$PWD/work:/workdir/data" \
  h2o-nacl-geothermal-simulator:v1.0.0
```

---

## Citation

If you use this image, please cite:

- **Paper**: Oguntola, M. B., Duran, O., Keilegavlen, E., Berre, I. (2026).
  *Mathematical Modeling of Salt Precipitation and Multi-Phase Flow in High
  Enthalpy Fractured Geothermal Systems.*
- **Thermodynamic tables**: Oguntola, M. B. (2026).
  *Thermodynamic lookup tables for H₂O–NaCl systems based on Driesner & Heinrich (2007) correlations.*
  Zenodo. [doi:10.5281/zenodo.20394023](https://doi.org/10.5281/zenodo.20394023)