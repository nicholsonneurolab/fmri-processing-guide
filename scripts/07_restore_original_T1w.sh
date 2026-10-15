
#!/bin/bash
set -e

# Directories
topdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021
bidsdir="${topdir}/Nifti"
backupdir="/Users/mengfan/Developer/fmri-preprocessing-guide/data/Backup"

originaldir="${backupdir}/T1w_with_face"
defaceddir="${backupdir}/T1w_defaced"

# Find all participants
shopt -s nullglob
subjects=("${bidsdir}"/sub-*)

if (( ${#subjects[@]} == 0 )); then
    echo "ERROR: No participants found."
    exit 1
fi

# Check all files before making changes
for subjectdir in "${subjects[@]}"; do
    [[ -d "$subjectdir" ]] || continue

    sub=$(basename "$subjectdir")
    filename="${sub}_T1w.nii"

    if [[ ! -f "${subjectdir}/anat/${filename}" ||
          ! -f "${originaldir}/${filename}" ||
          -e "${defaceddir}/${filename}" ]]; then
        echo "ERROR: Missing file or existing backup for ${sub}"
        exit 1
    fi
done

mkdir -p "$defaceddir"

# Swap defaced images for original images
for subjectdir in "${subjects[@]}"; do
    [[ -d "$subjectdir" ]] || continue

    sub=$(basename "$subjectdir")
    filename="${sub}_T1w.nii"

    echo "Restoring original T1w for ${sub}..."

    # Move defaced T1w to backup
    mv "${subjectdir}/anat/${filename}" \
       "${defaceddir}/${filename}"

    # Move original T1w into BIDS
    mv "${originaldir}/${filename}" \
       "${subjectdir}/anat/${filename}"
done

echo "Original T1w images restored for all participants."
