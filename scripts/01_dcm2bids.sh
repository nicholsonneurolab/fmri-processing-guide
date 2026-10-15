#!/bin/bash

set -e

# Updated on October 2026
# Define pathways
topdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021
dcmdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021/Dicom
onsetdir=/Users/mengfan/Developer/fmri-preprocessing-guide/data/Spider2021/Onsets
mkdir -p ${topdir}/Nifti
niidir=${topdir}/Nifti

# Create dateset_description.json file
rm -f ${niidir}/dataset_description.json # remove the description file if it exists

jo -p \
  "Name=Spider2021 Imaging Data" \
  "BIDSVersion=1.6.0" \
  "DatasetType=raw" \
  "License=CC0" \
  "GeneratedBy[]=$(jo \
    "Name=dcm2niix" \
    "Version=v1.0.20260724")" \
  "SourceDatasets[]=$(jo \
    "DOI=doi:10.18112/openneuro.ds004630.v1.1.3")" \
  "Authors[]=Mengfan Zhang" \
  "Authors[]=Alexander Karner" \
  "Authors[]=Kathrin Kostorz" \
  "Authors[]=Sophia Shea" \
  "Authors[]=David Steyrl" \
  "Authors[]=Filip Melinscak" \
  "Authors[]=Ronald Sladky" \
  "Authors[]=Cindy Sumaly Lor" \
  "Authors[]=Frank Scharnowski" \
  "HEDVersion=8.4.0" \
  > "${niidir}/dataset_description.json"

# Create shared events JSON description
cat > "${niidir}/task-passiveview_events.json" <<'EOF'
{
  "onset": {
    "Description": "Onset time of the event relative to the beginning of the functional acquisition",
    "Units": "s"
  },
  "duration": {
    "Description": "Duration of the event",
    "Units": "s"
  },
  "event": {
    "Description": "Event type or experimental condition"
  },
  "trial": {
    "Description": "Trial number"
  },
  "picture ID": {
    "Description": "Identifier of the picture presented during the trial"
  },
  "jitter": {
    "Description": "Jitter duration associated with the trial",
    "Units": "s"
  },
  "time from script start": {
    "Description": "Time elapsed from the start of the experimental script",
    "Units": "s"
  },
  "StimulusPresentation": {
    "OperatingSystem": "Windows 11",
    "ScreenOrigin": ["center", "center"],
    "SoftwareName": "PsychoPy",
    "SoftwareVersion": "2020.1.2",
    "Code": "https://github.com/univiemops/spider20-fmri-data/blob/main/exp/spider20_v4.py"
  }
}
EOF

# Create anat, func and fmap folders
for subj in "$dcmdir/"*; do
#for subj in sub-01; do
	thissubj=${subj##*/}
	echo "Processing subject $thissubj"

mkdir -p ${niidir}/${thissubj}/anat
mkdir -p ${niidir}/${thissubj}/func
mkdir -p ${niidir}/${thissubj}/fmap

for direcs in func; do
dcm2niix -o ${niidir}/${thissubj} -f ${thissubj}_%f_%p -i y ${dcmdir}/${thissubj}/
done

cd ${niidir}/${thissubj}

# Organize anat folder
anatfiles=$(ls -1 *t1* | wc -l)
for ((i=1;i<=${anatfiles};i++)); do
Anat=$(ls *t1*)   
tempanat=$(ls -1 $Anat | sed '1q;d') # Capture new file to change
tempanatext="${tempanat##*.}"
tempanatfile="${tempanat%.*}"
mv ${tempanatfile}.${tempanatext} ${niidir}/${thissubj}/anat/${thissubj}_T1w.${tempanatext} # Rename file and move it to anat folder
echo "${tempanat} changed to ${thissubj}_T1w.${tempanatext}"
done

## add SpoilingType to T1w JSON
cd "${niidir}/${thissubj}/anat"
jq '. + {"SpoilingType":"RF"}' "${thissubj}_T1w.json" > tmp.json && mv tmp.json "${thissubj}_T1w.json"

# Organize func folder
cd "${niidir}/${thissubj}"

## passive viewing
funcfiles=$(ls -1 *epi_r* | wc -l)
for ((i=1;i<=${funcfiles};i++)); do
Func=$(ls *epi_r*)   
tempfunc=$(ls -1 $Func | sed '1q;d') 
tempfuncext="${tempfunc##*.}"
tempfuncfile="${tempfunc%.*}"
run=${tempfuncfile: -1}
mv ${tempfuncfile}.${tempfuncext} ${niidir}/${thissubj}/func/${thissubj}_task-passiveview_run-${run}_bold.${tempfuncext} # Rename file and move it to func folder
echo "${tempfunc} changed to ${thissubj}_task-passiveview_run-${run}_bold.${tempafuncext}"
done

## resting state
restfiles=$(ls -1 *rest* | wc -l)
for ((i=1;i<=${restfiles};i++)); do
Rest=$(ls *rest*)
temprest=$(ls -1 $Rest | sed '1q;d')
temprestext="${temprest##*.}"
temprestfile="${temprest%.*}"
temppart=$(echo $temprestfile |cut -d '_' -f5)
mv ${temprestfile}.${temprest##*.} ${niidir}/${thissubj}/func/${thissubj}_task-rest${temppart}_bold.${temprestext}
echo "${temprest} changed to ${thissubj}_task-rest${temppart}_bold.${temprestext}"
done

# Organize fmap folder
## phase difference files
phasefiles=$(ls -1 *e2_ph* | wc -l)
for ((i=1;i<=${phasefiles};i++)); do
Phase=$(ls *e2_ph*)
tempphase=$(ls -1 $Phase | sed '1q;d')
tempphaseext="${tempphase##*.}"
tempphasefile="${tempphase%.*}"
mv ${tempphasefile}.${tempphase##*.} ${niidir}/${thissubj}/fmap/${thissubj}_phasediff.${tempphaseext}
echo "${tempphase} changed to ${thissubj}_phasediff.${tempphaseext}"
done

## magnitude files
magfiles=$(ls -1 *field_mapping* | wc -l)
for ((i=1;i<=${magfiles};i++)); do
Mag=$(ls *field_mapping*)
tempmag=$(ls -1 $Mag | sed '1q;d')
tempmagext="${tempmag##*.}"
tempmagfile="${tempmag%.*}"
number=${tempmagfile: -1}
mv ${tempmagfile}.${tempmag##*.} ${niidir}/${thissubj}/fmap/${thissubj}_magnitude${number}.${tempmagext}
echo "${tempmag} changed to ${thissubj}_magnitude${number}.${tempmagext}"
done

## spcify field map intended for to phasediff json file
cd ${niidir}/${thissubj}
intendedfiles="$(ls func/*_bold.nii)"

cd ${niidir}/${thissubj}/fmap
phdiffjson=$(ls *phasediff.json*)
jq '. |= . + {"IntendedFor":[], "B0FieldIdentifier":"phasediff_fmap", "SpoilingType":"RF"}' ${phdiffjson} > intendedadd.json
for item in $intendedfiles; do
jq --arg value "bids::${thissubj}/${item}" '.IntendedFor |= . + [$value]' intendedadd.json > tmp.json && mv tmp.json intendedadd.json
done

mv intendedadd.json ${phdiffjson}

## add B0FieldIdentifier to magnitude1 and magnitude2
for magjson in *magnitude1.json *magnitude2.json; do
jq '. + {"B0FieldIdentifier":"phasediff_fmap", "SpoilingType":"RF"}' "$magjson" > tmp.json && mv tmp.json "$magjson"
done

# Add TaskName, B0FieldSource, Instructions and TaskDescription to func JSON files
cd "${niidir}/${thissubj}/func"

for funcjson in *_bold.json; do
    jsonname="${funcjson%.*}"
    taskfield=$(echo "$jsonname" | cut -d '_' -f2 | cut -d '-' -f2)

    if [[ "$taskfield" == "passiveview" ]]; then
        instructions="Look at the images presented on the screen and pay attention to them."
        description="Participants viewed neutral and spider images during functional MRI acquisition, including catch trials to assess attention."
	      cogatlas="https://www.cognitiveatlas.org/id/trm_4c899211a965c/"
        cogpo="http://wiki.cogpo.org/index.php?title=Passive_Viewing_Paradigm"

    elif [[ "$taskfield" == "restpre" ]]; then
        instructions="Keep your eyes open, remain still, and look at the fixation cross."
        description="Resting-state fMRI recording acquired before the passive-viewing task."
	      cogatlas="https://www.cognitiveatlas.org/id/trm_4c8a834779883/"
        cogpo="http://wiki.cogpo.org/index.php?title=Rest"

    elif [[ "$taskfield" == "restpost" ]]; then
        instructions="Keep your eyes open, remain still, and look at the fixation cross."
        description="Resting-state fMRI recording acquired after the passive-viewing task."
	      cogatlas="https://www.cognitiveatlas.org/id/trm_4c8a834779883/"
        cogpo="http://wiki.cogpo.org/index.php?title=Rest"
        
    fi

    jq --arg task "$taskfield" \
       --arg instr "$instructions" \
       --arg desc "$description" \
       --arg coga "$cogatlas" \
       --arg cogp "$cogpo" \
       '. + {
           "TaskName": $task,
           "B0FieldSource": "phasediff_fmap",
           "Instructions": $instr,
           "TaskDescription": $desc,
	         "CogAtlasID": $coga,
           "CogPOID": $cogp,
	         "PartialFourier": 0.875,
           "PartialFourierDirection": "PHASE"
       }' "$funcjson" > tasknameadd.json && mv tasknameadd.json "$funcjson"

    echo "TaskName, B0FieldSource, Instructions and TaskDescription added to ${funcjson}"
done

# Create event tsv files
cd ${onsetdir}/${thissubj}

i=1
for f in $(ls -1 *.csv); do
awk -F';' '{ if ($6==0) $6=4; if ($6==1 || $6==2 || $6==3) $6=0; print $0 }' OFS=';' "${f}" > temp.csv
awk -F';' '{print $4,$6,$1,$2,$3,$5,$8}' OFS='\t' temp.csv > temp2.csv
sed -e '1s/catch/duration/' temp2.csv > temp3.csv
cat temp3.csv | sed '2d;$d' | sed 's/,/\t/g' | tr -d '\r' > "${niidir}/${thissubj}/func/${thissubj}_task-passiveview_run-${i}_events.tsv"
i=$(( i + 1 ))
rm **temp**
done

done
