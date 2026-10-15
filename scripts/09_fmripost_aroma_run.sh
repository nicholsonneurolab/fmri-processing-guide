#!/bin/bash
set -e

# Input and output directories
topdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021
bidsdir="${topdir}/Nifti"
fmriprepdir="${bidsdir}/derivatives/fmriprep"
outputdir="${bidsdir}/derivatives/fmripost_aroma"
workdir="${topdir}/work/fmripost_aroma"

# Participant and computational resources
subj=(01)
nthreads=8
ompnthreads=4
mem=12000

# Check input directories 
if [[ ! -d "$fmriprepdir" ]]; then
    echo "ERROR: fMRIPrep derivatives not found"
    exit 1
fi

# Create output and working directories
mkdir -p "$outputdir" "$workdir"

# Run fMRIPost-AROMA
docker run --rm -it \
  --platform linux/amd64 \
  -v "${bidsdir}:/data:ro" \
  -v "${fmriprepdir}:/prep:ro" \
  -v "${outputdir}:/out" \
  -v "${workdir}:/work" \
  nipreps/fmripost-aroma:latest \
  /data /out participant \
  --participant-label "${subj[@]}" \
  --derivatives /prep \
  --denoising-method nonaggr \
  --nprocs "$nthreads" \
  --omp-nthreads "$ompnthreads" \
  --mem "$mem" \
  --skip-bids-validation \
  --notrack \
  -w /work
