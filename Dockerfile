# =============================================================================
# Reproducibility Docker image for:
#   "Mathematical Modeling of Salt Precipitation and Multi-Phase Flow
#    in High Enthalpy Fractured Geothermal Systems"
#   Oguntola, Duran, Keilegavlen, Berre (2026)
#
# Build:   docker build -t geothermal-flow:paper .
# Run:     docker run --rm -it -v "$PWD/work:/workdir/data" geothermal-flow:paper
# =============================================================================

# Base image: official PorePy development image (Python 3, gmsh, build tools)
FROM porepy/dev:latest

# -----------------------------------------------------------------------------
# Layer 1 — System packages
# ParaView for figure rendering, Xvfb for headless display, git-lfs and wget.
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        paraview \
        xvfb \
        wget \
        git-lfs \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

# -----------------------------------------------------------------------------
# Layer 2 — Python packages (extras beyond what PorePy provides)
# -----------------------------------------------------------------------------
RUN pip install --no-cache-dir \
        pyyaml \
        pypardiso \
        matplotlib \
        pyvista \
        pyamg \
        chemicals

# -----------------------------------------------------------------------------
# Layer 3 — PorePy: switch to the paper branch
# -----------------------------------------------------------------------------
WORKDIR /workdir/porepy

RUN git remote add paper_repo https://github.com/pmgbergen/porepy.git \
    && git fetch paper_repo \
    && git switch -c cf-dfm-salt-precipitation paper_repo/cf-dfm-salt-precipitation

# ENV PYTHONPATH="/workdir/porepy/src:${PYTHONPATH}"
ENV PYTHONPATH="/workdir/porepy/src:/workdir/porepy/src/porepy/examples:${PYTHONPATH}"

# -----------------------------------------------------------------------------
# Layer 4 — pp_solvers
# -----------------------------------------------------------------------------
WORKDIR /workdir

RUN git clone https://github.com/pmgbergen/porepy-iterative-solvers.git pp_solvers \
    && cd pp_solvers \
    && git checkout cf_brine_iterative_solver \
    && pip install --no-cache-dir -e .

# -----------------------------------------------------------------------------
# Layer 5 — Fetch large VTK lookup tables from Zenodo
# Dataset DOI: 10.5281/zenodo.20394023
# The tables are too large for Git; they are pinned to Zenodo record 20394023.
# MD5 checksums are verified to ensure the files match the ones used in the paper.
# -----------------------------------------------------------------------------
ENV VTK_DIR=/workdir/porepy/src/porepy/examples/geothermal_flow/model_configuration/constitutive_description/driesner_vtk_files
ENV ZENODO_RECORD=20394023

RUN mkdir -p ${VTK_DIR} \
    && cd ${VTK_DIR} \
    && wget --quiet --show-progress \
        https://zenodo.org/records/${ZENODO_RECORD}/files/XHP_l2_original.vtk \
        https://zenodo.org/records/${ZENODO_RECORD}/files/XHP_l2_original_salt_new.vtk \
        https://zenodo.org/records/${ZENODO_RECORD}/files/XTP_l2_original_salt_new.vtk \
    && echo "acab28fba73b4045b911b876234f478f  XHP_l2_original.vtk"           >  checksums.md5 \
    && echo "a05e6ab9a80c034ef5189731124a47a3  XHP_l2_original_salt_new.vtk"  >> checksums.md5 \
    && echo "66460551f036bfd7f674e25bcd1d6cd0  XTP_l2_original_salt_new.vtk"  >> checksums.md5 \
    && md5sum -c checksums.md5

# -----------------------------------------------------------------------------
# Layer 6 — Working directory and bind-mount setup
# Inside the container, the user's outputs are written into /workdir/data,
# which is bind-mounted from the host at runtime via -v.
# Symlinks redirect relative output paths transparently.
# -----------------------------------------------------------------------------
# WORKDIR /workdir/porepy/src/porepy/examples/geothermal_flow

# RUN mkdir -p /workdir/data \
#     && ln -s /workdir/data/visualization visualization \
#     && ln -s /workdir/data/output output \
#     && ln -s /workdir/data/csv csv \
#     && ln -s /workdir/data/figures figures

WORKDIR /workdir/porepy/src/porepy/examples

RUN mkdir -p /workdir/data/visualization \
             /workdir/data/output \
             /workdir/data/csv \
             /workdir/data/figures \
    && ln -s /workdir/data/visualization visualization \
    && ln -s /workdir/data/output output \
    && ln -s /workdir/data/csv csv \
    && ln -s /workdir/data/figures figures
    
RUN python -m geothermal_flow.simulation_driver --help \
    && python -m geothermal_flow.make_figures --help \
    && pvbatch --version

# Default to an interactive shell.
ENTRYPOINT ["bash"]