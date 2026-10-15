#!/bin/bash

# Define the BIDS dataset directory
bidsdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021/Nifti

# Loop through all participants
#for subj in sub-01; do
for subj in "$bidsdir"/sub-*; do
    thissubj=$(basename "$subj")
    input="${subj}/anat/${thissubj}_T1w.nii"
    output="${subj}/anat/${thissubj}_T1w_defaced.nii"

    if [ -f "$input" ]; then
        echo "Defacing ${thissubj}..."
        pydeface "$input" --outfile "$output"
    else
        echo "T1w image not found for ${thissubj}, skipping..."
    fi
done
