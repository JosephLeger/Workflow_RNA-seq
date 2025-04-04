# Workflow description

This workflow was designed to perform analyzes of Bulk RNA-sequencing data, from FASTQ files to the identification of differentially expressed genes.   
  
It is deliberately not automated, and requires launching the scripts manually one after the other, keeping full user control and allowing custom options, whilst retaining some standardization and repeatability. Therefore, it is well suited for users who want to perform analyzes step by step by taking the time to understand the results of one step before launching the next one, and possibly change the parameters accordingly.  

Two quantification methods are available in this workflow :  
* **STAR Raw Counts :** This method generates a count table with integer values corresponding to exact aligned read numbers for each gene. Reads are first mapped using **STAR**, then quantified using **featureCount**.
* **RSEM Estimation :** This method generates a table with decimal numbers corresponding to transcript expression estimation, obtained by normalizing the mapped reads according to transcript sizes. Expression estimation is then carried out by **RSEM**.

<p align="center">
<img src="https://github.com/JosephLeger/Workflow_RNA-seq/blob/main/img/pipeline.png"  width="90%" height="90%">
</p>

### Common steps
0. **Preparation of references :** To perform mapping to reference genome/transcriptome, it must be indexed first. To do so, it requires reference genome (FASTA file) and genome annotation (GTF file) available for download in Ensembl.org gateway.  

1. **Quality Check :** Quality of each FASTQ file is assessed using **FastQC**. A quality control report per file is then obtained, providing information on the quality of the bases, the length of the reads, the presence of adapters, etc. To make the visualization of the results easier, all reports are then pooled and analyzed simultaneously using **MultiQC**. 

2. **Trimming :** According to the conclusions drawn from the quality control of the reads, a trimming step is often necessary. This step makes it possible to clean the reads, for example by eliminating sequences enriched in adapters, or by trimming poor quality bases at the ends of the reads. For this, **Trimmomatic** needs to be provided with the adapter sequences used for sequencing if an enrichment has been detected.  
A quality control is carried out on the FASTQ files resulting from trimming to ensure that the quality obtained is satisfactory.

### STAR Raw Counts Workflow 
3. **Alignment to the genome :** Clean FASTQ files are then mapped to the previously indexed reference genome in order to identify the regions from which the reads come. **STAR** thus generates BAM files containing the reads aligned to the genome.  
A quality control is carried out on the BAM files resulting from alignment to ensure reads were correctly mapped.

4. **Quantification :** This step uses **subread** featureCounts function to convert the BAM files containing the aligned reads into a count table usable for further analyzes.  

### RSEM Estimation Workflow 
3. **Transcripts estimation :** Clean FASTQ files are then mapped to the previously indexed reference genome in order to identify the regions from which the reads come. **STAR** and **RSEM** are used to make an estimate of the abundance of each transcript. Resulting .genes.results and .isoforms.results files contain respectively the results of the estimation of expression by genes or by transcripts which will be used for further analyzes.  
A quality control is carried out on the BAM files resulting from alignment to ensure reads were correctly mapped.

### Post-Processing Data Analysis
Following data analyzes are performed locally using R or Python. A complete script for basic DESeq2 analysis while performing STAR Raw Counts Workflow is provided in R script folder.  

*Supplementary scripts are also available in ./scripts/extra folder of this repository.*  

# Initialization and recommendations

### Scripts
All required scripts are available in the [script folder](https://github.com/JosephLeger/Workflow_RNA-seq/tree/main/scripts) of this repository.   
To get more information about using these scripts, enter the command `sh <script_name.sh> help`.  

### Environments  
The workflow is encoded in Shell language and is supposed to be launched under a Linux environment.  
Moreover, it was written to be used on a computing cluster using **Simple Linux Utility for Resource Management (SLURM)** Workload Manager.  
All script files launch tasks as **sbatch** task submission. To successfully complete the workflow, wait for all the jobs in a step to be completed before launching the next one.  
You have to install all required tools in a conda environment using provided provided [Workflow_RNA-seq.yaml](https://github.com/JosephLeger/Workflow_RNA-seq/blob/main/Workflow_RNA-seq.yaml) reciept file.  

### Requirments
```
Name                        Version
fastqc                      0.11.9
multiqc                     1.13
trimmomatic                 0.39
samtools                    1.6
rsem                        1.3.2
star                        2.7.10b
subread                     2.0.1

```
Install all required tools using :
```bash
conda env create -f Workflow_RNA-seq.yaml
```

### Project directory
To start the workflow, create a new directory for the project and put previously downloaded scripts inside. Create a 'Raw' subdirectory and put all the raw FASTQ files inside.  
Raw FASTQ files must be compressed in '.fq.gz' or '.fastq.gz' format. If it is not the case, you need to compress them using `gzip Raw/*.fastq`.  

For the following example, this type of folder tree is used :

<p align="left">
<img src="https://github.com/JosephLeger/Workflow_RNA-seq/blob/main/img/paths.png"  width="50%" height="50%">
</p>

# Workflow in a Nutshell  
```bash
# Quality Check
sh 1_QC.sh Raw
# Trimming
sh 2_Trim.sh -S 4:15 -L 5 -T 5 -M 36 -I ../Ref/Trimmomatic/NexteraPE-PE.fa:2:30:10 PE Raw
# Quality Check
sh 1_QC.sh Trimmed/Trimmomatic/Paired

# Using STAR
sh 3_STAR.sh PE Trimmed/Trimmomatic/Paired ../Ref/refdata-STAR-mm39.108/GenomeDir
sh 1_QC.sh STAR
sh 4_Count.sh PE STAR ../Ref/Genome/Mus_musculus.GRCm39.108.gtf

# Using RSEM
sh 3_RSEM.sh -B true PE Trimmed/Trimmomatic/Paired ../Ref/refdata-RSEM-mm39.108/mm39.108
sh 1_QC.sh RSEM
```

# Workflow Step by Step
## Common Steps
### 0. Preparation of references
This step only needs to be carried out during the first alignment. The genome or transcriptome once indexed can be reused as a reference for subsequent alignments.  
First, you need to download reference genome FASTA file and annotaion GTF file in the Genome folder.  
```bash
# Example with mouse genome from Ensembl.org
wget https://ftp.ensembl.org/pub/release-108/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz
wget https://ftp.ensembl.org/pub/release-108/gtf/mus_musculus/Mus_musculus.GRCm39.108.gtf.gz

# Unzip downloaded files
gunzip Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz
gunzip Mus_musculus.GRCm39.108.gtf.gz
```
Then, create a directory for the reference and use provided scripts in refindex folder of this repository according to the workflow you aim to perform.  

#### STAR indexing
Syntax : ```sh STAR_refindex.sh <FASTA> <GTF>```  
```bash
sh STAR_refindex.sh ../Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Genome/Mus_musculus.GRCm39.108.gtf
```

#### RSEM indexing
Syntax : ```sh RSEM_refindex.sh <FASTA> <GTF> <build_name>```  
```bash
sh RSEM_refindex.sh ../Genome/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa ../Genome/Mus_musculus.GRCm39.109.gtf mm39.108
```
*Once indexing is done, every following steps are performed directly in the project directory.*  


### 1. Quality Check
Syntax : ```sh QC.sh <input_dir>```  
```bash
sh 1_QC.sh Raw
```
Pooled results are available in ./QC/MultiQC/QC_Raw_MultiQC.html file.  

### 2. Trimming
If low quality bases or adapter enrichment is detected, you will need to perform trimming step.  
Provided trimming script allow several options :
* **-S** (Slingdingwindow) : Perform a sliding window trimming, cutting once the average quality within the window falls below a threshold.  
* **-L** (Leading) : Remove low quality bases from the beginning.  
* **-T** (Trailing) : Remove low quality bases from the end.   
* **-M** (Minlen) : This module removes reads that fall below the specified minimal length.  
* **-I** (Illuminaclip) : Cuts adapters and other Illumina-specific sequences present in the reads.
  
*For more details, please read [Trimmomatic Manual](http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/TrimmomaticManual_V0.32.pdf).*  
  
Syntax : ```sh Trim.sh [options] <SE|PE> <input_dir>```  
```bash
sh 2_Trim.sh -S 4:15 -L 3 -T 3 -M 36 -I ../Ref/Trimmomatic/NexteraPE-PE.fa:2:30:10 PE Raw
```

Perform a quality check after trimming to ensure all adapters and low quality bases have been removed correctly.  
```bash
sh 1_QC.sh Trimmed/Trimmomatic/Paired
```  
  
## STAR Raw Counts
### 3. Alignment to genome
Syntax : ```sh STAR.sh <SE|PE> <input_dir> <refindex>```
```bash
sh 3_STAR.sh PE Trimmed/Trimmomatic/Paired ../Ref/refdata-STAR-mm39.108/GenomeDir
```

Perform a quality check after alignment to ensure reads were correctly mapped.  
```bash
sh 1_QC.sh STAR
```  

### 4. Quantification
Syntax : ```sh Count.sh <SE|PE> <input_dir> <GTF>```
```bash
sh 4_Count.sh PE STAR ../Ref/Genome/Mus_musculus.GRCm39.108.gtf
```

## RSEM Estimation
### 3. Transcripts Estimation
Because RSEM will generate specific files after the estimation of the expression, it is possible to ignore output BAM files generation using **-B false** option. This could be usefull to avoid saturation of disk storage space.  
  
Syntax : ```sh RSEM.sh [options] <SE|PE> <input_dir> <refindex>```   
```bash
sh 3_RSEM.sh -B true PE Trimmed/Trimmomatic/Paired ../Ref/refdata-RSEM-mm39.108/mm39.108
```

Perform a quality check after alignment to ensure reads were correctly mapped.  
```bash
sh 1_QC.sh RSEM
```





