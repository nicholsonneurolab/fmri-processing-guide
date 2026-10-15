#!/bin/bash
set -e

# Input and output directories
topdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021
bidsdir="${topdir}/Nifti"
outputdir="${topdir}/Nifti/derivatives/fmriprep"
workdir="${topdir}/work/fmriprep"
fslicdir="/Users/mengfan/Developer/fmri-preprocessing-guide/data/license.txt"

# Participant and computational resources
subj=(01)                   # Single participant (default)
#subj=(01 02 03 04 05)     # Uncomment for multiple participants
nthreads=8
ompnthreads=4
mem=12000

# Pin a tested fMRIPrep version
fmriprep_version=25.2.5

# Create output and working directories
mkdir -p "$outputdir" "$workdir"

# Run fMRIPrep using Docker
docker run --rm -it \
  -v "${bidsdir}:/data:ro" \
  -v "${outputdir}:/out" \
  -v "${workdir}:/work" \
  -v "${fslicdir}:/opt/freesurfer/license.txt:ro" \
  nipreps/fmriprep:${fmriprep_version} \
  /data /out participant \
  --participant-label "${subj[@]}" \
  -w /work \
  --fs-license-file /opt/freesurfer/license.txt \
  --fs-no-reconall \
  --output-spaces MNI152NLin2009cAsym MNI152NLin6Asym:res-2 T1w \
  --stop-on-first-crash \
  --nthreads "$nthreads" \
  --omp-nthreads "$ompnthreads" \
  --mem-mb "$mem"
