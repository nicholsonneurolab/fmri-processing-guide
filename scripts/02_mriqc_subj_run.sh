
#!/bin/bash
set -e

# Input and output directories
topdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021
bidsdir="${topdir}/Nifti"
outputdir="${bidsdir}/derivatives/mriqc"
workdir="${topdir}/work/mriqc"

# Participant and computational resources
subj=(01)                 # Single participant (default)
#subj=(01 02 03 04 05)     # Uncomment for multiple participants
nthreads=8
ompnthreads=4
mem=12  # GB

# Create output and working directories
mkdir -p "$outputdir" "$workdir"

# Run MRIQC
docker run --rm \
  -v "$bidsdir":/data:ro \
  -v "$outputdir":/out \
  -v "$workdir":/work \
  nipreps/mriqc:24.0.2 \
  /data /out participant \
  --participant-label "${subj[@]}" \
  --nprocs "$nthreads" \
  --omp-nthreads "$ompnthreads" \
  --mem-gb "$mem" \
  --work-dir /work \
  --no-sub # Disables submission of image quality metrics to MRIQC's database.
