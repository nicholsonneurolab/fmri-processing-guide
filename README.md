# Lab Guide to fMRI Data Preparation and Processing

A beginner-friendly guide to preparing and processing functional MRI (fMRI) data using command-line tools, Docker containers, and reproducible workflows.

**Recommended workflow:** DICOM → BIDS conversion → BIDS validation → MRIQC (optional, recommended) → defacing → fMRIPrep → fMRIPost-AROMA (optional) → downstream analysis.

This guide covers dataset organization, validation, image quality assessment, participant privacy, preprocessing, and optional motion denoising. It does **not** cover first-level or group-level statistical modeling.

**Scope:** The examples primarily use Bash and a Linux-style terminal. Docker instructions also cover macOS and Windows; some commands (including `caffeinate`, Homebrew, and environment activation) are operating-system-specific. Windows users may need WSL2 or adapted paths. Docker Engine on Linux does not have the Docker Desktop resource-settings interface.

**Important:** This is a teaching template, **not a validated clinical or research pipeline**. Adapt and verify every script, metadata value, and software version against your dataset, operating system, and institutional requirements. Do not put identifiable participant data in a public repository or external AI service.

## Before You Start

- **Inputs:** Access to DICOM series for each participant, acquisition/protocol metadata, and (for task fMRI) appropriately matched event/onset files.
- **Basic skills:** Navigating folders in Terminal, editing paths in Bash scripts, and understanding where files are read and written.
- **Software:** Docker, plus the command-line utilities described below. PyDeface requires its own Python environment and FSL installation.
- **Resources:** MRI preprocessing may need substantial CPU, RAM, temporary disk space, and hours of runtime. The resource figures below are starting points, not guarantees.
- **Privacy:** Keep original identifiable images and any participant-code mapping in secure, access-controlled storage. Follow the lab's ethics, consent, and data-handling policies.
- **Working directory:** Unless otherwise noted, run example scripts from the **repository root**, the folder containing `scripts/`, using `bash scripts/<script_name>.sh`.

## Workflow at a Glance

| Stage | Main tool | Main result |
|---|---|---|
| DICOM conversion and organization | `dcm2niix` / `dcm2bids` / Bash | BIDS-organized MRI data |
| Validation | BIDS Validator | Naming and metadata issues to resolve |
| Quality assessment | MRIQC | Image-quality metrics and reports |
| Privacy preparation | PyDeface | Visually checked defaced anatomical images |
| Preprocessing | fMRIPrep | Preprocessed images, confounds, HTML reports |
| Optional motion denoising | fMRIPost-AROMA | Denoising outputs and reports |

## 0. Environment Setup
### 0.1. Installing Docker 

**What is Docker?**

[Docker](https://www.docker.com/) is a platform that allows applications to run in isolated environments called **containers**. Each container includes the software and dependencies needed to run a specific application.

In neuroimaging, Docker helps us run tools such as **MRIQC, fMRIPrep, and ICA-AROMA** without manually installing all their dependencies. This improves reproducibility and reduces software compatibility issues across computers.

**Step 1: Install Docker**

Download and install Docker for your operating system:

- **Windows / macOS:** [Download Docker Desktop](https://docs.docker.com/get-started/get-docker/)
- **Ubuntu / Linux:** [Install Docker Engine](https://docs.docker.com/engine/install/ubuntu/)

Follow the official installation instructions and ensure Docker is running.

**Step 2: Verify the installation**

Open Terminal and run:

```bash
docker --version
```

This should display the installed Docker version.

Next, run:

```bash
docker run hello-world
```

Docker will download and execute a small test container.

If you see **"Hello from Docker!"**, your installation is working correctly.

**Step 3: Configure Docker resources**

MRI preprocessing, especially fMRIPrep, can be computationally intensive and requires sufficient CPU, memory, and disk space.

1. Open Docker Desktop.
2. Navigate to **Settings → Resources**.
3. Adjust the resource limits based on your computer.

**Recommended settings:**
| Resource | Recommended |
|----------|-------------|
| CPU limit | >= 8 CPUs |
| Memory limit | >= 16 GB |
| Disk usage limit | >= 100 GB  |
| Swap | 4 GB or less|

If your computer has fewer resources, consider using 4 CPUs and 8–12 GB RAM, although preprocessing may be slower or require more memory.

Click **Apply & Restart** to save the changes.

> **Important:**
> - Leave sufficient CPU and RAM for your operating system.
> - On Windows using the WSL 2 backend, CPU and memory limits are managed through WSL rather than the Docker Desktop sliders.
> - The Docker disk usage limit is not the total storage needed for your MRI data. Ensure you have additional free space for BIDS datasets, derivatives, and temporary working files.
> - Docker Engine on Linux does not use the Docker Desktop resource settings interface.

You are now ready to use Docker containers for MRI preprocessing!


### 0.2. Installing Homebrew

**What is Homebrew?**

[Homebrew](https://brew.sh/) is a free package manager that simplifies installing and managing software from the command line. We will use Homebrew to install tools required for MRI preprocessing.

**Step 1: Install Homebrew**

Open Terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions to complete the installation.

> **Important:** After installation, **follow the instructions displayed in Terminal** to add Homebrew to your PATH.

**Step 2: Verify the installation**

Run:

```bash
brew --version
```

This should display the installed Homebrew version.


### 0.3. Installing packages using Homebrew

We will use Homebrew to install three command-line tools:

- **[jo](https://github.com/jpmens/jo):** A lightweight tool for creating JSON files from the command line.
- **[jq](https://jqlang.github.io/jq/):** A command-line tool for reading, filtering, and modifying JSON files.
- **[dcm2niix](https://github.com/rordenlab/dcm2niix):** Converts MRI data from DICOM (`.dcm`) to NIfTI (`.nii` or `.nii.gz`) format, along with JSON metadata.

Open Terminal and run:

```bash
brew install jo jq dcm2niix
```

To verify the installations, run:

```bash
jo -V
jq --version
dcm2niix -h
```

If all three commands display version or help information, the tools are installed successfully.



## 1. DICOM-to-BIDS Conversion and Validation

### 1.1. Approach 1: Writing your own bash script

One way to convert DICOM files into BIDS format is to write your own Bash script using `dcm2niix` and other command-line tools.

This approach is particularly useful for understanding the BIDS structure and learning how DICOM files are converted, renamed, and organized. It is also highly flexible and can be reused and adapted for different datasets.

**Recommended tutorial:** https://reproducibility.stanford.edu/bids-tutorial-series-part-1b/index.html

The tutorial provides an easy-to-follow introduction to converting DICOM files into BIDS format. However, some parts are outdated, particularly the creation and modification of JSON metadata files, as the BIDS specification has evolved over time.

To complement this tutorial, we provide an example Bash script that follows the same general approach while adding code to generate and update JSON metadata files, helping address common warnings reported by the BIDS Validator.

#### Raw data organization

Before running the conversion script, organize your raw data into the following directory structure:

```text
Project/
├── Dicom/
│   ├── sub-01/
│   │   └── [DICOM files]
│   ├── sub-02/
│   │   └── [DICOM files]
│   └── sub-03/
│       └── [DICOM files]
│
├── Onsets/
│   ├── sub-01/
│   │   ├── run-1.csv
│   │   └── run-2.csv
│   ├── sub-02/
│   │   ├── run-1.csv
│   │   └── run-2.csv
│   └── sub-03/
│       ├── run-1.csv
│       └── run-2.csv
│
└── Nifti/                # BIDS output (created by the script)
```

- **`Dicom/`**: Contains raw DICOM files for each participant, stored in separate subfolders (`sub-01`, `sub-02`, etc.).
- **`Onsets/`**: Contains experimental event/onset files (`.csv`) for each participant, organized into matching subfolders. These files are used to generate BIDS-compatible `_events.tsv` files.
- **`Nifti/`**: The output directory where converted and BIDS-organized data will be saved. This folder is automatically created by the script.

> **Note:** Participant folder names must match between `Dicom/` and `Onsets/`. The example script expects semicolon-delimited CSV onset files with a specific column layout. Adapt the event conversion code if your experimental files differ. Ensure that event files are correctly matched to their corresponding functional runs.

#### Example bash script

**Example script:** [01_dcm2bids.sh](scripts/01_dcm2bids.sh)

The example script follows the main steps described in the tutorial, including converting DICOM files to NIfTI format, organizing and renaming files according to BIDS conventions, and generating event files.

In addition, the script includes several updates to address common BIDS Validator warnings that may arise after following the original tutorial:

- Create and update `dataset_description.json`.
- Create and update task-related JSON metadata.
- Add missing MRI acquisition parameters to JSON files.
- Specify field map associations.

These additions help improve BIDS compatibility and reduce common validation warnings. However, the metadata values are dataset-specific and should always be checked against your actual MRI acquisition protocol.


Before running the script, update the directory paths at the beginning of the file:

```bash
topdir=/path/to/Project
dcmdir=${topdir}/Dicom
onsetdir=${topdir}/Onsets
```

To run the script, open Terminal, navigate to your GitHub project directory, and execute:

```bash
bash scripts/01_dcm2bids.sh
```

#### Important Notes

**a. Dataset-specific metadata**

This script was developed for a specific MRI dataset and acquisition protocol. Before using it, update the directory paths, file naming patterns, task information, and metadata to match your own dataset.

In particular, metadata fields such as SpoilingType, PartialFourier, PartialFourierDirection, task descriptions, and field map identifiers must be verified against the actual MRI acquisition parameters. Do not copy these values without checking their accuracy.

**b. Processing one or multiple participants**

By default, the example script processes only `sub-01`.

To process all participants in the DICOM directory, uncomment the following line:

```bash
for subj in "$dcmdir/"*; do
```

And comment out the single-subject line:

```bash
# for subj in sub-01; do
```

This allows the script to loop through all participant folders under the DICOM directory, assuming they follow the expected naming structure.



### 1.2. Approach 2: Using dcm2bids tool

[dcm2bids](https://unfmontreal.github.io/Dcm2Bids/) is a Python-based tool that automates DICOM-to-BIDS conversion using `dcm2niix` and a JSON configuration file. It can be installed directly or run through Docker.

**Installation options:**

Using pip:
```bash
pip install dcm2bids
```

Using Docker:
```bash
docker pull unfmontreal/dcm2bids:3.3.1
```

**The essential steps are:**

1. Install dcm2bids.
2. Inspect your DICOM data using `dcm2bids_helper` to identify imaging sequences and their metadata.
3. Create a JSON configuration file to map your imaging sequences to BIDS filenames.
4. Run `dcm2bids` with your DICOM directory, participant ID, and configuration file.

For detailed instructions and examples, follow the official documentation and tutorials:

- [dcm2bids documentation](https://unfmontreal.github.io/Dcm2Bids/)


> **Note:** Although `dcm2bids` automates much of the conversion process, you may still need to provide additional metadata and experimental event files to produce a complete BIDS dataset.


### 1.3. Approach 3: Using AI Skills for BIDS Conversion
> **Important - IMHR AI Usage Policy:**
> This approach should **only be used after attending the IMHR AI Workshops**. Lab members must use AI assistants **exclusively through the IMHR server**, rather than personal accounts or external AI services. Please familiarize yourself with the IMHR guidelines for using AI tools before proceeding.


Another approach is to use an AI coding assistant such as Claude Code or Codex with a specialized BIDS skill to help organize DICOM data, generate conversion scripts, and troubleshoot BIDS validation errors.

We recommend exploring the [Brain Imaging Data Structure (BIDS) Expert Skill](https://mcpmarket.com/tools/skills/brain-imaging-data-structure-bids-expert), which provides BIDS-related guidance to compatible AI coding assistants.

**Install Node.js and npm**

First, install [Node.js](https://nodejs.org/) using Homebrew. This also installs `npm` (Node Package Manager) and `npx`, which are needed to run the skill installer.

```bash
brew install node
```

Verify the installation:

```bash
node --version
npm --version
npx --version
```

**Install the BIDS skill**

Open Terminal and run:

```bash
npx skillfish add lingxling/awesome-skills-cn bids
```

Follow the on-screen instructions to install the skill for your supported AI coding assistant.

You can check installed skills using:

```bash
npx skillfish list
```

**Using the skill**

Once installed, open your AI coding assistant and ask it to help with tasks such as:

- Inspecting DICOM metadata and planning a BIDS directory structure.
- Generating or modifying DICOM-to-BIDS conversion scripts.
- Creating and updating BIDS JSON metadata files.
- Identifying and resolving BIDS Validator errors and warnings.

> **Note:** Always review AI-generated scripts and metadata, verify acquisition-specific parameters, and validate the final dataset using the [BIDS Validator](https://bids-standard.github.io/bids-validator/). Avoid sharing identifiable participant data with external AI services.


### 1.4. Validating Your BIDS Dataset

After converting your DICOM files into BIDS format, it is important to check whether your dataset follows the [BIDS specification](https://bids-specification.readthedocs.io/).

The **[BIDS Validator](https://bids-standard.github.io/bids-validator/)** is a tool that checks your dataset for missing files, incorrect naming conventions, incomplete metadata, and other BIDS-related issues.



## 2. MRI Quality Assessment Using MRIQC (Optional but Highly Recommended)

[MRIQC](https://mriqc.readthedocs.io/) is an automated tool for assessing the quality of MRI data. It extracts a range of image quality metrics (IQMs) from anatomical and functional MRI images and generates visual reports to help identify potential problems, such as head motion, image artifacts, and low signal quality.

Unlike fMRIPrep, which focuses on preprocessing MRI data, **MRIQC evaluates the quality of the original MRI acquisitions**. It can help researchers identify problematic scans before proceeding with downstream analyses.

Although MRIQC is **optional, we highly recommend including it in your workflow** to support data quality assessment and reproducibility.

### 2.1. When should you run MRIQC?

**We recommend running MRIQC immediately after converting your DICOM data into BIDS format and validating the dataset, before defacing the anatomical images.** This requires that identifiable images and MRIQC reports remain in secure storage.

This allows MRIQC to assess the original MRI data without modifications introduced by defacing. Although most MRIQC metrics are relatively insensitive to defacing, some measurements and visual quality assessments may be affected.

However, MRIQC typically takes around 15-60 minutes for each participant. If you prefer to proceed directly with preprocessing, you can skip MRIQC initially and return to it later.

There are therefore two possible workflows:

**Option 1: Run MRIQC before defacing (recommended)**

```text
DICOM
  ↓
BIDS Conversion
  ↓
BIDS Validation
  ↓
MRIQC
  ↓
Defacing
  ↓
fMRIPrep
  ↓
Downstream Analysis
```

**Option 2: Run MRIQC after fMRIPrep**

```text
DICOM
  ↓
BIDS Conversion
  ↓
BIDS Validation
  ↓
Defacing
  ↓
fMRIPrep
  ↓
Temporarily restore original T1w images
  ↓
MRIQC
  ↓
Restore defaced T1w images
  ↓
Downstream Analysis
```

The second option is a recovery workflow for datasets already processed. For new datasets, prefer the first workflow; it avoids repeatedly moving potentially identifiable anatomical images in and out of the BIDS dataset.

> **Important:** MRIQC should be run on the original BIDS images, not the preprocessed outputs from fMRIPrep. If you have already defaced your anatomical images, follow Section 2.4 to temporarily restore the original T1w images before running MRIQC.
>
> MRIQC reports may contain images with identifiable facial features. Keep these reports in secure, access-controlled storage and review them before sharing.

### 2.2. Preparation: Install MRIQC Using Docker

We use Docker to run MRIQC, similar to the fMRIPrep workflow described in Section 4.

**Step 1: Download the MRIQC Docker image**

Open Terminal and run:

```bash
docker pull nipreps/mriqc:24.0.2
```

**Step 2: Verify the installation**

```bash
docker run --rm nipreps/mriqc:24.0.2 --version
```

This should display the installed MRIQC version.



### 2.3. Running MRIQC after BIDS validation

Similar to the fMRIPrep workflow described in Section 3, we provide a Bash script to run MRIQC using Docker:

**Example script:** [02_mriqc_subj_run.sh](scripts/02_mriqc_subj_run.sh)

Before running the script, adjust the file paths, participant selection, and computational resources to match your dataset and computer configuration.

To run MRIQC, open Terminal, navigate to the repository root, and execute:

```bash
bash scripts/02_mriqc_subj_run.sh
```

MRIQC will generate image quality metrics and visual reports in the `derivatives/mriqc/` directory.

**Generate group-level reports**

After completing participant-level processing, you can generate group-level quality reports:

```bash
bash scripts/03_mriqc_group_run.sh
```

These reports summarize image quality metrics across participants, making it easier to identify potential outliers.

> **Note:** MRIQC may take several hours to complete. As with fMRIPrep, ensure your computer has sufficient resources, remains connected to power, and does not automatically enter sleep mode during processing.



### 2.4. Running MRIQC After Defacing and fMRIPrep

If you have already completed defacing and fMRIPrep, you can still run MRIQC on the original (non-defaced) T1w images.

Before proceeding, locate your original T1w images. These may be stored in a separate backup directory, another dataset location, or secure institutional storage, depending on how your data were organized.

To run MRIQC on the original images, you will need to temporarily replace the defaced T1w images in your BIDS dataset with their corresponding original versions.

We provide two example Bash scripts to help automate this process:

**Step 1: Restore the original T1w images**

```bash
bash scripts/07_restore_original_T1w.sh
```

This script temporarily restores the original T1w images to the BIDS dataset.

**Step 2: Run MRIQC**

Follow Section 2.3 to run MRIQC at the participant and group levels:

```bash
bash scripts/02_mriqc_subj_run.sh
bash scripts/03_mriqc_group_run.sh
```

**Step 3: Restore the defaced T1w images**

After MRIQC has finished, restore the defaced images:

```bash
bash scripts/08_restore_defaced_T1w.sh
```

> **Important:**
> - These scripts are examples based on a specific directory structure. Update the paths to match where your original and defaced T1w images are stored.
> - Ensure that the original T1w images are backed up before running the scripts.
> - MRIQC reports generated from original anatomical images may contain identifiable facial features and should also be stored securely.



### 2.5. Check the MRIQC Outputs

After successful processing, MRIQC generates individual quality-control reports and image quality metrics.

**Inspect the individual HTML reports**

Open the generated HTML reports in a web browser. Review the image quality metrics (IQMs), especially **tSNR** (temporal signal-to-noise ratio), **DVARS** (changes in signal intensity between consecutive volumes), **FD** (framewise displacement, indicating head motion), and **CJV** (coefficient of joint variation, reflecting anatomical image quality). Also inspect the visualizations for motion artifacts, signal dropout, and other potential image quality issues.

These metrics can help identify problematic scans, but they should be interpreted together with visual inspection rather than using a single metric to determine whether a scan should be excluded.

**Inspect the group-level reports**

Group-level reports summarize image quality metrics across participants.

These can help identify participants whose image quality differs substantially from the rest of the dataset.

> **Note:** MRIQC provides quantitative metrics and visual reports to support quality assessment, but it does not automatically determine whether a participant should be excluded. Researchers should review the results and establish appropriate quality-control criteria for their study.



## 3. Defacing Anatomical MRI Images

After converting DICOM files into BIDS format, validating the dataset, and optional quality control with MRIQC, the next step is **defacing**.

High-resolution anatomical MRI scans (especially T1-weighted images) contain not only brain structures but also facial features. These images can be used to reconstruct a recognizable 3D representation of a participant's face, potentially allowing the participant to be identified.

Therefore, **defacing is an important step for protecting participant privacy**, particularly before sharing MRI datasets with other researchers or making them publicly available.

Defacing removes or obscures facial structures while preserving brain tissue needed for subsequent analyses. Here, we use [PyDeface](https://github.com/poldracklab/pydeface) to deface anatomical MRI images.



### 3.1. Preparation: Install PyDeface

We recommend installing PyDeface in a separate Python environment to avoid dependency conflicts.

**Option 1: Using Anaconda or Miniconda (recommended if already installed)**

If you already have [Anaconda](https://www.anaconda.com/download) or Miniconda installed, use Conda to create a dedicated environment:

```bash
conda create -n pydeface python=3.15 -y  # example version; confirm PyDeface/FSL compatibility
conda activate pydeface
pip install pydeface
```

**Option 2: Without Anaconda**

You can use Python's built-in `venv` to create a virtual environment.

First, make sure Python is installed. On macOS, you can install it using Homebrew:

```bash
brew install python
```

Then create and activate a virtual environment:

```bash
python3 -m venv pydeface-env
source pydeface-env/bin/activate
python -m pip install pydeface
```

**Verify the installation**

For either option, run:

```bash
pydeface --help
```

> **Note:** PyDeface also requires [FSL](https://fsl.fmrib.ox.ac.uk/fsl/docs/install/index.html) for image registration. FSL must be installed and configured separately, regardless of which Python installation method you choose.


### 3.2. Step 1: Deface a T1-weighted image

For example, to deface the anatomical image of `sub-01`:

```bash
pydeface \
  /path/to/Project/Nifti/sub-01/anat/sub-01_T1w.nii \
  --outfile /path/to/Project/Nifti/sub-01/anat/sub-01_T1w_defaced.nii
```

Replace the example paths with the locations of your own images.

**Defacing all participants**

Instead of running PyDeface separately for each participant, we provide a Bash script that automatically loops through all participant folders and defaces their T1-weighted images.

**Example script:** [02_pydeface.sh](scripts/02_pydeface.sh)

Before running the script, update the BIDS dataset directory (`bidsdir`) to match your local setup.

Then open Terminal, navigate to the repository root, and run:

```bash
bash scripts/04_pydeface.sh
```

The script will generate a defaced T1w image for each participant while preserving the original image.


**Inspect the results**

After defacing, open the original and defaced images in an MRI viewer such as [FSLeyes](https://fsl.fmrib.ox.ac.uk/fsl/docs/#/utilities/fsleyes) or [MRIcroGL](https://www.nitrc.org/projects/mricrogl/).

Check that:

- Facial features have been removed sufficiently.
- Brain tissue, including the frontal and inferior regions, remains intact.
- No unexpected alterations have occurred in the anatomical image.

> **Note:** The filename containing `_defaced` is for inspection only and is not a standard BIDS anatomical filename. Once the output has been checked, replace the corresponding `sub-XX_T1w.nii` in a separate, defaced copy of your BIDS dataset. Keep the original dataset in secure, access-controlled storage.
>
> Defacing reduces re-identification risk but does not guarantee complete anonymization. Follow institutional privacy and data-sharing requirements.


### 3.3. Backing Up and Replacing the Original T1w Images

After defacing, **visually inspect all defaced T1w images** to ensure that facial features have been removed without affecting brain tissue.

Once the results have been verified, we need to replace the original T1w images with their defaced versions while keeping the original images in a separate backup folder.

We provide a Bash script to automate this process:

**Example script:** [05_replace_T1w.sh](scripts/05_replace_T1w.sh)

The script will:

- Move the original T1w images (with facial features) into `Backup/T1w_with_face/`.
- Rename the defaced images from `sub-XX_T1w_defaced.nii` to `sub-XX_T1w.nii`, following BIDS naming conventions.
- Automatically process all participants in the BIDS dataset.

Before running the script, update the directory paths to match your local setup:

```bash
bidsdir=/path/to/Project/Nifti
backupdir=/path/to/Project/Backup/T1w_with_face
```

Then run the script from the repository root:

```bash
bash scripts/05_replace_T1w.sh
```

> **Important:** The original T1w images contain potentially identifiable facial information. Keep the `Backup/T1w_with_face/` folder in secure, access-controlled storage, **outside the BIDS dataset and any public GitHub repository**. Make sure the defaced images have been visually inspected before running the replacement script.

### 3.4. Anonymization before data sharing

In addition to defacing anatomical images, researchers should ensure that the entire dataset is appropriately de-identified before public release. This includes replacing original participant identifiers with non-identifying subject codes (e.g., `sub-01`), removing personally identifiable information from DICOM and NIfTI headers and BIDS metadata files when necessary (e.g., JSON and TSV files), and removing or appropriately modifying identifying acquisition dates. Researchers should also inspect demographic and behavioral information for potential re-identification risks, particularly when combinations of variables could reveal a participant's identity. Any mapping between original participant identities and publicly released subject codes must be handled according to the repository's requirements and institutional ethics policies. Importantly, defacing alone does not guarantee anonymity, and researchers should review the complete dataset for identifying information before publication. Public sharing must also be consistent with participant consent and applicable ethical and legal requirements.



## 4. fMRI Preprocessing Using fMRIPrep

[fMRIPrep](https://fmriprep.org/) is an automated preprocessing pipeline for MRI data. It performs essential preprocessing steps, including motion correction, susceptibility distortion correction (when appropriate data are available), alignment between functional and anatomical images, and spatial normalization.

Compared with traditional preprocessing workflows implemented in software such as SPM, **fMRIPrep offers several advantages**:

- **Integration of multiple software packages:** fMRIPrep combines established neuroimaging tools (e.g., ANTs, FSL, and FreeSurfer), leveraging specialized algorithms for different preprocessing steps rather than relying on a single software package.
- **Automation and reproducibility:** fMRIPrep automatically adapts its workflow based on the available BIDS-formatted input data, reducing manual configuration and promoting consistent, reproducible preprocessing across participants and studies.
- **Comprehensive outputs:** fMRIPrep generates a rich set of outputs, including preprocessed images in native and standard spaces, brain masks, confound regressors (e.g., head motion parameters, framewise displacement, and CompCor components), and visual quality-control reports. These outputs support a wide range of downstream analyses.

Overall, fMRIPrep provides a standardized, reproducible, and flexible preprocessing framework that reduces manual effort while facilitating quality control and downstream analyses.

In this tutorial, we use fMRIPrep through Docker.

### 4.1. Before Running fMRIPrep

Make sure you have completed the following steps:

1. Converted your DICOM files into a BIDS-organized dataset.
2. Checked your dataset using the [BIDS Validator](https://bids-standard.github.io/bids-validator/).
3. Defaced the T1-weighted anatomical images and visually inspected the results.
4. Installed Docker Desktop and confirmed that it is running.
If the Docker image is not installed, download it using:

```bash
docker pull nipreps/fmriprep:25.2.5
```
5. Obtained a FreeSurfer license file (`license.txt`).

You can request a free FreeSurfer license from the [FreeSurfer website](https://surfer.nmr.mgh.harvard.edu/registration.html).


### 4.2. Configure the fMRIPrep Script

We provide a Bash script for running fMRIPrep using Docker:

**Example script:** [06_fmriprep_run.sh](scripts/06_fmriprep_run.sh)

Before running the script, review and adjust the file paths, computational resources, and output spaces to match your system and analysis requirements.

**Output directory structure**

For consistency in this guide, store outputs in a `derivatives/` directory **beside** the `Nifti/` BIDS input directory, under `Project/`. This keeps raw inputs separate from processing outputs. Ensure the paths in every Bash script match this layout.

For example:

```text
Project/
├── Nifti/                 # BIDS input dataset
│   ├── sub-01/
│   └── sub-02/
├── derivatives/
│   ├── fmriprep/
│   ├── mriqc/
│   └── fmripost_aroma/
└── work/

```

**Computational Resources**

For a Docker Desktop configuration with 14 CPUs and 16 GB of RAM, we recommend the following initial settings:

```bash
nthreads=8
ompnthreads=4
mem=12000
```

These parameters control resource allocation during preprocessing:

- `nthreads`: Maximum number of threads available to the fMRIPrep workflow.
- `ompnthreads`: Maximum number of OpenMP threads used by individual processing tasks.
- `mem`: Memory budget (in MB) used by fMRIPrep to schedule processing tasks.

Adjust these values based on the resources available to Docker and the demands of your dataset.


**FreeSurfer surface reconstruction**

The script includes the following option:

```bash
--fs-no-reconall
```

This option skips FreeSurfer's cortical surface reconstruction, reducing computational demands and processing time. It is appropriate when surface-based outputs are not required for downstream analyses.


### 4.3. Run fMRIPrep

Open Terminal and navigate to your project directory containing the `scripts` folder.

Run:

```bash
bash scripts/06_fmriprep_run.sh
```

fMRIPrep will begin preprocessing the selected participant.

Processing can take several hours or longer, depending on the amount of imaging data, available resources, and whether Docker uses CPU emulation.

**Important:** 

Before processing the entire dataset:

1. Test the script on a single participant to verify that the configuration works correctly.
2. **Check your computer's power and sleep settings** to ensure that it will not automatically enter sleep mode during preprocessing. fMRIPrep can take several hours to complete, depending on the dataset size and available computational resources.

For **macOS**, you can use `caffeinate` to prevent the computer from sleeping while the script runs:

```bash
caffeinate -i bash scripts/06_fmriprep_run.sh
```

For **Windows with Docker Desktop**, check **Settings → System → Power & battery → Screen, sleep & hibernate timeouts** and temporarily disable automatic sleep while the computer is plugged in.

 Keep your computer connected to a power source during preprocessing. You can restore your usual sleep settings once processing is complete.


### 4.4. Check the fMRIPrep Outputs

After successful preprocessing, fMRIPrep generates a derivatives directory containing preprocessed images, confound estimates, and quality-control reports.

The output structure will look approximately like this:

```text
Project/
├── Nifti/
├── derivatives/
│   └── fmriprep/
│       ├── sub-01/
│       │   ├── anat/
│       │   └── func/
│       ├── sub-01.html
│       └── dataset_description.json
├── work/
└── license.txt
```

The exact files depend on the available input images and preprocessing options.

**Inspect the HTML report**

Open the participant's HTML report in a web browser:

```text
derivatives/fmriprep/sub-01.html
```

Review the report carefully, particularly:

- Anatomical brain extraction and tissue segmentation.
- Alignment between functional and anatomical images.
- Spatial normalization to the MNI template.
- Susceptibility distortion correction, if applicable.
- Any warnings or processing issues.

A completed fMRIPrep run does not automatically guarantee good preprocessing quality. Always inspect the reports before proceeding.



## 5. Motion Denoising with fMRIPost-AROMA (Optional)

After completing fMRIPrep, you can use **fMRIPost-AROMA** to identify and reduce motion-related artifacts in the preprocessed fMRI data.

fMRIPost-AROMA applies ICA-AROMA (Independent Component Analysis-based Automatic Removal Of Motion Artifacts) to fMRIPrep derivatives.

### 5.1. Requirements

Before running fMRIPost-AROMA, make sure fMRIPrep has finished successfully and generated BOLD images in `MNI152NLin6Asym` space at 2 mm resolution.

### 5.2. Run fMRIPost-AROMA

Similar to fMRIPrep and MRIQC, we provide a Bash script to run fMRIPost-AROMA using Docker.

**Example script:** [09_fmripost_aroma_run.sh](scripts/09_fmripost_aroma_run.sh)

Before running the script, install the fMRIPost-AROMA image, and adjust the file paths, participant selection, and computational resources.

```bash
docker pull --platform linux/amd64 nipreps/fmripost-aroma:<tested-version>
```

Open Terminal, navigate to your project directory, and run:

```bash
bash scripts/09_fmripost_aroma_run.sh
```

By default, the script uses **non-aggressive denoising** (`--denoising-method nonaggr`).

The resulting outputs and reports will be saved in:

```text
Project/derivatives/fmripost_aroma/
```

After processing, inspect the generated reports and verify that the denoised BOLD images are available before using them in subsequent analyses.

> **Reproducibility note:** Replace `<tested-version>` with a specific image tag that you have verified, and use the same tag in `scripts/09_fmripost_aroma_run.sh`. Do not run the placeholder command unchanged.

> **Note:** ICA-AROMA is an optional denoising approach. Whether to use it depends on your analysis strategy, and additional nuisance regression or temporal filtering should be planned carefully to avoid redundant processing.


## 6. Expected Outputs and Final Checks

At the end of the workflow, you should have a BIDS-organized input dataset, a record of BIDS validation, MRIQC metrics and reports (if run), fMRIPrep derivatives and participant HTML reports, and optional fMRIPost-AROMA outputs. Exact filenames depend on your acquisitions and processing options.

Before downstream analysis, check that:

- BIDS validation errors have been reviewed and resolved where applicable.
- Anatomical images used for sharing have been defaced and visually inspected; original images remain protected.
- MRIQC reports and fMRIPrep HTML reports have been inspected for motion, artifacts, registration, and warnings.
- The fMRIPrep output spaces match the requirements of your denoising or analysis workflow.
- Script versions, container tags, parameters, and any exclusions are recorded for reproducibility.

## 7. Troubleshooting and Repository Checks

| Symptom | First things to check |
|---|---|
| `docker: command not found` or Docker cannot connect | Installation, running Docker daemon/Desktop, user permissions |
| Out-of-memory or terminated preprocessing | Docker/WSL2 memory limits, script `mem` and thread settings, available disk space |
| BIDS Validator errors | Filenames, sidecar JSON values, missing metadata, task events, fieldmap associations |
| Missing FreeSurfer license | `license.txt` path and Docker mount configuration |
| Script not found | Run from repository root; compare filename with files actually committed under `scripts/` |
| Missing output files | Input/output mounts, participant labels, log messages, selected output spaces |
| PyDeface/FSL errors | Active Python environment, FSL installation, dependency compatibility |

**Items to verify before publishing this guide:** Check that all linked scripts exist, that the chosen Python and container versions are supported, and that each script's paths agree with the `Project/Nifti`, `Project/derivatives`, and `Project/work` layout shown here. The linked Bash scripts were not included in this review, so their behavior has not been tested.
