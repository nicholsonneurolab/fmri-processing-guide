
# Define directories
bidsdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021/Nifti
backupdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Backup/T1w_with_face

# Create the backup folder if it doesn't exist
mkdir -p "$backupdir"

# Loop through all participants
for subj in "$bidsdir"/sub-*; do
#for subj in sub-01; do
    [ -d "$subj/anat" ] || continue

    thissubj=$(basename "$subj")
    anatdir="${subj}/anat"

    original="${anatdir}/${thissubj}_T1w.nii"
    defaced="${anatdir}/${thissubj}_T1w_defaced.nii"

    if [ -f "$original" ] && [ -f "$defaced" ]; then

        # Move the original T1w image into the backup folder
        mv "$original" "$backupdir"

        # Rename the defaced image to the original BIDS filename
        mv "$defaced" "$original"

        echo "Completed ${thissubj}"
    else
        echo "Missing original or defaced image for ${thissubj}, skipping..."
    fi
done

