# Reproducibility image for "Mathematical Modeling of Salt Precipitation and Multi-Phase Flow in High Enthalpy Fractured Geothermal Systems"

This repository provides a Docker image to reproduce the simulations and
figures in the paper

> Oguntola, M. B., Duran, O., Keilegavlen, E., Berre, I. (2026).
> *Mathematical Modeling of Salt Precipitation and Multi-Phase Flow
> in High Enthalpy Fractured Geothermal Systems.*

The image bundles all dependencies, source code, thermodynamic lookup tables,
and figure-generation scripts required to reproduce the benchmark and the three
fractured-reservoir examples (Examples 1, 2, and 3) presented in the paper.

---

## What this repository contains

Only four files:

| File | Purpose |
|---|---|
| `Dockerfile` | Recipe used to build the reproducibility image. |
| `README.md` | This document. |
| `.dockerignore` | Files excluded from the Docker build context. |
| `.gitignore` | Files excluded from version control. |

All simulation source code, configuration files, and figure-generation scripts
are pulled by Docker during the build from the upstream `cf-dfm-salt-precipitation`
branch of [PorePy](https://github.com/pmgbergen/porepy) and the
`cf_brine_iterative_solver` branch of
[porepy-iterative-solvers](https://github.com/pmgbergen/porepy-iterative-solvers).

The large thermodynamic lookup tables (~3 GB) are pulled from a permanent
Zenodo deposit:

> Oguntola, M. B. (2026).
> *Thermodynamic lookup tables for H₂O–NaCl systems based on Driesner & Heinrich (2007) correlations.*
> Zenodo. [doi:10.5281/zenodo.20394023](https://doi.org/10.5281/zenodo.20394023)

---

## Prerequisites

- Docker (version 20 or newer). Install instructions for major platforms
  are at https://docs.docker.com/get-docker/.
- About **15 GB of free disk space** for the built image (ParaView and the
  thermodynamic tables together account for most of this).
- Internet access during the build. After the image is built, simulations
  and figure generation run entirely offline.

No local installation of PorePy, Python, or ParaView is required on the host.

---

## Quick start

### 1. Clone this repository

```bash
git clone https://github.com/<your-username>/cf-brine-simulation.git
cd cf-brine-simulation
```

### 2. Build the image

```bash
docker build -t geothermal-flow:paper .
```

The build downloads PorePy, `porepy-iterative-solvers`, ParaView, and the
thermodynamic lookup tables. MD5 checksums on the downloaded tables are
verified against the values published in the Zenodo deposit; the build fails
immediately if any file is corrupted.

### 3. Create a work directory on the host

```bash
mkdir -p work
```

This directory will hold simulation outputs and figures. Anything the
container writes to its internal `visualization/`, `output/`, `csv/`, and
`figures/` directories will appear in subdirectories of `work/` on your
machine.

### 4. Launch the container

```bash
docker run --rm -it \
    -v "$PWD/work:/workdir/data" \
    geothermal-flow:paper
```

You will land in an interactive bash shell inside the container, at the
directory containing the simulation code.

---

## Running simulations

From inside the container, run any of the four cases:

```bash
# Numerical benchmark (Section 4 of the paper)
python -m geothermal_flow.simulation_driver \
    --config geothermal_flow/configs/benchmark.yaml

# Example 1 — disconnected fractures, mild clogging (φ = 0.1)
python -m geothermal_flow.simulation_driver \
    --config geothermal_flow/configs/example1.yaml

# Example 2 — disconnected fractures, strong clogging (φ = 1.0)
python -m geothermal_flow.simulation_driver \
    --config geothermal_flow/configs/example2.yaml

# Example 3 — connected fracture chain (φ = 2.0)
python -m geothermal_flow.simulation_driver \
    --config geothermal_flow/configs/example3.yaml
```

Each simulation writes `.pvd` and `.vtu` files to
`work/visualization/<case_name>/` on your host machine. Outputs persist
between container runs because of the bind mount in step 4.

Runtimes vary substantially across cases. Some configurations may run for
several days. Run the benchmark first as a smoke test of the workflow before
launching the longer examples.

---

## Generating figures

Once simulations have completed (see dependencies below), generate figures
with the figure driver:

```bash
# Generate every figure described in the paper
python -m geothermal_flow.make_figures \
    --config geothermal_flow/configs/figures_docker.yaml

# Generate selected figures only
python -m geothermal_flow.make_figures \
    --config geothermal_flow/configs/figures_docker.yaml \
    --figures figure9 figure15

# Preview the commands that would run without executing them
python -m geothermal_flow.make_figures \
    --config geothermal_flow/configs/figures_docker.yaml \
    --dry-run
```

Figures appear in `work/figures/` on the host.

### Figure-to-simulation dependencies

| Figures | Required simulations |
|---|---|
| `figure6` | benchmark |
| `figure8`, `figure9`, `figure10`, `figure11`, `figure12`, `figure13` | example1 |
| `figure14` | example2 |
| `figure15`, `figure16` | example1 **and** example2 |
| `figure17`, `figure18`, `figure19` | example3 |

For details on how individual figures are constructed (ParaView rendering,
CSV extraction, Matplotlib panel assembly), see the developer README at
`src/porepy/examples/geothermal_flow/README.md` on the
[`cf-dfm-salt-precipitation` branch of PorePy](https://github.com/pmgbergen/porepy/tree/cf-dfm-salt-precipitation/src/porepy/examples/geothermal_flow).

---

## Exiting and re-entering

To exit the container, type `exit` or press `Ctrl-D`. The container stops
and is removed (`--rm`), but the host directory `work/` retains every output
file.

To re-enter for additional simulations or figure generation, repeat step 4.
The image itself remains cached locally — the build only runs once.

---

## Notes on long-running simulations

Some configurations require multi-day runs. A few practical points:

- Container outputs persist on the host because of `-v "$PWD/work:/workdir/data"`.
  If the container stops unexpectedly (host reboot, terminal closed, etc.),
  the partial results in `work/visualization/<case_name>/` are not lost.
- For unattended runs, prefer `tmux` or `screen` on the host so the terminal
  session survives disconnects.
- If you need to monitor a simulation from another shell while it runs, use
  `docker exec` to attach a second shell to the same container — but this
  requires omitting `--rm` and naming the container with `--name <some-name>`.

---

## Troubleshooting

### The build fails at the Zenodo download step

Check that you have internet access during the build. If the download succeeds
but the MD5 verification fails, the file may have been corrupted during
download — retry the build. Persistent failures may indicate a Zenodo outage;
the deposit at https://doi.org/10.5281/zenodo.20394023 should be permanently
available.

### ParaView fails to render figures with an OpenGL error

The image includes Xvfb to provide a virtual display server. If figure
generation reports OpenGL-related warnings (e.g. OpenVKL initialisation
errors), check whether the output PNG was nonetheless produced before
treating the warnings as failures. ParaView's offscreen rendering
sometimes prints these warnings without failing.

### `Cannot connect to the Docker daemon`

The Docker daemon is not running. On macOS or Windows, launch Docker Desktop.
On Linux, run `sudo systemctl start docker`. You may also need to add your
user to the `docker` group to avoid `sudo`.

### Permission denied on the `work/` directory

On Linux hosts, files created inside the container by `root` may not be
writable by your host user. Either run the container with `--user $(id -u):$(id -g)`
or change ownership afterwards with `sudo chown -R $USER work/`.

---

## Citing this work

If you use this image or any of its components, please cite:

- **Paper**: Oguntola, M. B., Duran, O., Keilegavlen, E., Berre, I. (2026).
  *Mathematical Modeling of Salt Precipitation and Multi-Phase Flow in High
  Enthalpy Fractured Geothermal Systems.*
- **Thermodynamic tables**: Oguntola, M. B. (2026).
  *Thermodynamic lookup tables for H₂O–NaCl systems based on Driesner & Heinrich (2007) correlations.*
  Zenodo. [doi:10.5281/zenodo.20394023](https://doi.org/10.5281/zenodo.20394023)
- **PorePy**: Keilegavlen, E., Berge, R. L., Fumagalli, A., Starnoni, M.,
  Stefansson, I., Varela, J., Berre, I. (2021). *PorePy: An open-source
  software for simulation of multiphysics processes in fractured porous media.*
  Computational Geosciences, 25, 243–265.
- **Driesner correlations**: Driesner, T., Heinrich, C. A. (2007). *The system
  H₂O–NaCl. Part I: Correlation formulae for phase relations in
  temperature–pressure–composition space from 0 to 1000 °C, 0 to 5000 bar,
  and 0 to 1 X_NaCl.* Geochimica et Cosmochimica Acta, 71, 4880–4901.

---

## License

This repository (the Dockerfile and supporting files) is released under the
MIT License. The PorePy source code is released under its own license terms;
see the PorePy repository. The thermodynamic lookup tables on Zenodo are
released under CC BY 4.0.