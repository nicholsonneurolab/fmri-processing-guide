#!/bin/bash
set -e

# Input and output directories
topdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021
bidsdir="${topdir}/Nifti"
outputdir="${bidsdir}/derivatives/mriqc"

docker run --rm \
  -v "$bidsdir":/data:ro \
  -v "$outputdir":/out \
  nipreps/mriqc:24.0.2 \
  /data /out group \
  --no-sub