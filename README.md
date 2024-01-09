# Bulk_RNA-seq
Custom pipeline for Bulk RNA-seq analysis


# Workflow description

Two quantification methods are available in this workflow :  
* **STAR Raw Counts :** This method generates a count table with integer values corresponding to exact aligned read numbers for each gene. Reads are first mapped using **STAR**, then quantified using **featureCount**.
* **RSEM Estimation :** This method generates a table with floating point numbers corresponding to transcript expression estimation, obtained by normalizing the mapped reads according to transcripts sizes. Expression estimation is then carried out by **RSEM**.
  
<img src="https://github.com/JosephLeger/Bulk_RNA-seq/blob/main/img/pipeline.png"  width="90%" height="90%">


### Common steps
1. **Preparing the reference :** To perform mapping to reference genome/transcriptome, it must be indexed first. To do so, it requires reference genome (FASTA file) and genome annotation (GTF file) available for download in Ensembl.org gateway.  
*Note : For a qauntification with **featureCount** genome indexing must be preformed with **STAR**, whereas for transcript expression estimation it must be performed with **RSEM**.*

2. **Quality Check :** Quality of each FASTQ file is performed using **FastQC**. A quality control report per file is then obtained, providing information on the quality of the bases, the length of the reads, the presence of adapters, etc. To make it easier to visualize the results, all reports are then pooled and analyzed simultaneously using **MultiQC**. 

3. **Trimming :** According to the conclusions drawn from the quality control of the reads, a trimming step is often necessary. This step makes it possible to clean the reads, for example by eliminating sequences enriched in adapters, or by trimming poor quality bases at the ends of the reads. For this, the **Trimmomatic** tool needs to be provided with the adapter sequences used for sequencing if an enrichment has been detected.  
A quality control is carried out on the FASTQ files resulting from trimming to ensure that the quality obtained is satisfactory.

### STAR Raw Counts Workflow 
4. **Alignment to the genome :** This step consists of aligning the FASTQ files to the previously indexed reference genome in order to identify the regions from which the reads come. The **STAR** tool thus generates BAM files containing the reads aligned to the genome.

5. **Alignment Quality Check :** In order to analyze the proportion of correctly aligned reads, the **MultiQC** tool can be directly used to pool the quality control of the BAM files resulting from the alignment.

6. **Quantification :** This step will transform the BAM files containing the aligned reads into a count table usable for further analyzes in R or Python.

### RSEM Estimation Workflow 
4. **Transcripts estimation :** This step consists of aligning the FASTQ files to the reference transcriptome previously indexed with **RSEM** to make an estimate of the abundance of each transcript. For each FASTQ file, several files result, in particular a BAM file and a .stat folder which will make it possible to control the quality of the alignment. There are also .genes.results and .isoforms.results files containing respectively the results of the estimation of expression by genes or by transcripts which will be used for further analyzes in R or Python.

5. **Alignment Quality Check :** In order to analyze the proportion of correctly aligned reads, the **MultiQC** tool can be directly used to pool the quality control of the BAM files resulting from the alignment.


# Initialization and recommendations

### Scripts
All required scripts are available in the script folder in this directory. The workflow is coded in Shell language and is supposed to be launched under a Linux environment.  
Moreover, 
To get more information about using these scripts, enter the command `sh <script.sh> help`.  

### Environments  
This custom pipeline was written to be used on a computing cluster with tools already pre-installed in the form of modules. Modules are so loaded using `module load <tool_name>` command.   
If you are running the pipeline in another context, you will need to remove these lines from the scripts and load manually required tools.  


### Requirments
```
Name                        Version
fastqc                      0.11.9
multiqc                     1.13
trimmomatic                 0.39
rsem                        1.3.2
star                        2.7.5a
```

### Project diretcory
To start the workflow, create a new directory for the project and put previously downloaded scripts inside. Create a 'Raw' subdirectory and put all the raw FASTQ files inside.  
Raw FASTQ files must be compressed in '.fq.gz' or '.fastq.gz' format. If it is not the case, you need to compress them using `gzip Raw/*.fastq`.  

# Workflow Step by Step
# Common Steps
## 1. Preparing the reference
This step only needs to be carried out during the first alignment. The genome or transcriptome once indexed can be reused as a reference for subsequent alignments.  
First, you need to download reference genome FASTA file and annotaion GTF file.  
```bash
# Example with mouse genome from Ensembl.org
wget https://ftp.ensembl.org/pub/release-108/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz
wget https://ftp.ensembl.org/pub/release-108/gtf/mus_musculus/Mus_musculus.GRCm39.108.gtf.gz
```
Then, use provided scritps in refindex folder of this repository according to the workflow you aim to perform.  

### Genome indexing
Syntax : ```sh STAR_refindex.sh <FASTA> <GTF>```  
```bash
sh STAR_refindex.sh ./Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz ./Mus_musculus.GRCm39.108.gtf.gz
```

### Transcriptome indexing
Syntax : ```sh RSEM_refindex.sh <FASTA> <GTF> <build_name>```  
```bash
sh RSEM_refindex.sh ./Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz ./Mus_musculus.GRCm39.109.gtf.gz mm39.108
```

## 2. Quality Check
Syntax : ```sh QC.sh <input_dir>```  
To launch quality check using **FastQC** on raw gzipped FASTQ files located in 'Raw' folder, launch :  
```bash
sh QC.sh Raw
```
It generates one quality report per file. Once all reports are created, pool them in a single file using **MultiQC**.  
Syntax : ```sh MultiQC.sh <input_dir>```  
```bash
sh MultiQC.sh QC/Raw
```
Pooled results are available in **QC/MultiQC/QC_Raw_MultiQC.html** file.  

## 3. Trimming
Syntax : ```sh Trim.sh [options] <SE|PE> <input_dir>```  
If low quality bases or adapter enrichment is detected, you will need to perform trimming step.  
Provided trimming script allow several options :
* S (Slingdingwindow) : Perform a sliding window trimming, cutting once the average quality within the window falls below a threshold. By considering multiple bases, a single poor quality base will not cause the removal of high quality data later in the read.  
* L (Leading) : Remove low quality bases from the beginning. As long as a base has a value below this threshold the base is removed and the next base will be investigated.  
* T (Trailing) : Remove low quality bases from the end. As long as a base has a value below this threshold the base is removed and the next base will be investigated.     
* M (Minlen) : This module removes reads that fall below the specified minimal length.   
* I (Illuminaclip) : Cuts adapters and other Illumina-specific sequences present in the reads.  
*For more details, please read [Trimmomatic Manual](http://www.usadellab.org/cms/uploads/supplementary/Trimmomatic/TrimmomaticManual_V0.32.pdf).*
 
To do so for paired-end files, identify adapter sequences to trim in a FASTA file and launch :  
```bash
sh Trim.sh -S 4:15 -L 3 -T 3 -M 36 -I ./Ref/NexteraPE-PE.fa:2:30:10 PE Raw
```

# STAR Raw Counts
## 4. Alignment to genome














