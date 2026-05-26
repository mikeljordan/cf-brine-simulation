# =============================================================================
# Reproducibility Docker image for:
#   "Mathematical Modeling of Salt Precipitation and Multi-Phase Flow
#    in High Enthalpy Fractured Geothermal Systems"
#   Oguntola, Duran, Keilegavlen, Berre (2026)
#
# Build:   docker build -t h2o-nacl-geothermal-simulator:v1.0.0  .
# Run:     docker run --rm -it -v "$PWD/work:/workdir/data" h2o-nacl-geothermal-simulator:v1.0.0
# =============================================================================

# Base image: official PorePy development image (Python 3, gmsh, build tools)
FROM porepy/dev:latest

# -----------------------------------------------------------------------------
# Layer 1 — System packages
# -----------------------------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
        xvfb \
        wget \
        git-lfs \
        libxt6 \
        libgl1 \
        libxrender1 \
        libxcursor1 \
        libxinerama1 \
        libxrandr2 \
        libxi6 \
        libxss1 \
        libnss3 \
        libegl1 \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install

# -----------------------------------------------------------------------------
# Layer 2 — ParaView 6.1.0 (matches the development environment)
# Installed under /opt/paraview, then symlinked to the macOS-style path so the
# pvbatch entry in figures.yaml works unchanged inside the container.
# -----------------------------------------------------------------------------
ARG PV_URL=https://www.paraview.org/files/v6.1/ParaView-6.1.0-MPI-Linux-Python3.12-x86_64.tar.gz

RUN cd /tmp \
    && wget --quiet --show-progress "${PV_URL}" -O paraview.tar.gz \
    && mkdir -p /opt/paraview \
    && tar -xzf paraview.tar.gz -C /opt/paraview --strip-components=1 \
    && rm paraview.tar.gz \
    && /opt/paraview/bin/pvbatch --version

ENV PATH="/opt/paraview/bin:${PATH}"

# -----------------------------------------------------------------------------
# Layer 3 — Python packages (extras beyond what PorePy provides)
# -----------------------------------------------------------------------------
RUN pip install --no-cache-dir \
        pyyaml \
        pypardiso \
        matplotlib \
        pyvista \
        pyamg \
        chemicals

# -----------------------------------------------------------------------------
# Layer 4 — PorePy: switch to the paper branch
# -----------------------------------------------------------------------------
WORKDIR /workdir/porepy

RUN git remote add paper_repo https://github.com/pmgbergen/porepy.git \
    && git fetch paper_repo \
    && git switch -c cf-dfm-salt-precipitation paper_repo/cf-dfm-salt-precipitation


ENV PYTHONPATH="/workdir/porepy/src:/workdir/porepy/src/porepy/examples:${PYTHONPATH}"

# -----------------------------------------------------------------------------
# Layer 5 — pp_solvers
# -----------------------------------------------------------------------------
# WORKDIR /workdir

# RUN git clone https://github.com/pmgbergen/porepy-iterative-solvers.git pp_solvers \
#     && cd pp_solvers \
#     && git checkout cf_brine_iterative_solver \
#     && pip install --no-cache-dir -e .

# -----------------------------------------------------------------------------
# Layer 6 — Fetch large VTK lookup tables from Zenodo
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
# Layer 7 — Working directory and bind-mount setup
# Inside the container, the user's outputs are written into /workdir/data,
# which is bind-mounted from the host at runtime via -v.
# Symlinks redirect relative output paths transparently.
# -----------------------------------------------------------------------------

WORKDIR /workdir/porepy/src/porepy/examples

RUN mkdir -p /workdir/data/visualization \
             /workdir/data/output \
             /workdir/data/csv \
             /workdir/data/figures \
    && rm -rf visualization output csv figures \
    && ln -s /workdir/data/visualization visualization \
    && ln -s /workdir/data/output output \
    && ln -s /workdir/data/csv csv \
    && ln -s /workdir/data/figures figures

RUN python -m geothermal_flow.simulation_driver --help \
    && python -m geothermal_flow.make_figures --help \
    && pvbatch --version

# Default to an interactive shell.
ENTRYPOINT ["bash"]