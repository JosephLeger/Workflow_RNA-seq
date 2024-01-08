<style>body {text-align: justify}
<\style>

# Bulk_RNA-seq
Custom pipeline for Bulk RNA-seq analysis


# Workflow description

Two quantification methods are available in this workflow :  
* **Raw Counts :** This method generates a count table with integer values corresponding to exact aligned read numbers for each gene. Reads are first mapped using **STAR**, then quantified using **featureCount**.
* **Estimation :** This method generates a table with floating point numbers corresponding to transcript expression estimation, obtained by normalizing the mapped reads according to transcripts sizes. Expression estimation is then carried out by **RSEM**.

<img src="https://github.com/JosephLeger/Bulk_RNA-seq/blob/main/img/pipeline.png"  width="90%" height="90%">


### Common steps
1. **Preparing the reference :** To perform mapping to reference genome/transcriptome, it must be indexed first. To do so, it requires reference genome (FASTA file) and genome annotation (GTF file) available for download in Ensembl.org gateway.
*Note : For a qauntification with **featureCount** genome indexing must be preformed with **STAR**, whereas for transcript expression estimation it must be performed with **RSEM**.*

2. **Quality Check :** Quality of each FASTQ file is performed using **FastQC**. A quality control report per file is then obtained, providing information on the quality of the bases, the length of the reads, the presence of adapters, etc. To make it easier to visualize the results, all reports are then pooled and analyzed simultaneously using **MultiQC**. 

3. **Trimming :** According to the conclusions drawn from the quality control of the reads, a trimming step is often necessary. This step makes it possible to clean the reads, for example by eliminating sequences enriched in adapters, or by trimming poor quality bases at the ends of the reads. For this, the **Trimmomatic** tool needs to be provided with the adapter sequences used for sequencing if an enrichment has been detected.
A quality control is carried out on the FASTQ files resulting from trimming to ensure that the quality obtained is satisfactory.

### Raw Counts Workflow 
4. **Alignment to the genome :** This step consists of aligning the FASTQ files to the previously indexed reference genome in order to identify the regions from which the reads come. The **STAR** tool thus generates BAM files containing the reads aligned to the genome.

5. **Alignment Quality Check :** In order to analyze the proportion of correctly aligned reads, the **MultiQC** tool can be directly used to pool the quality control of the BAM files resulting from the alignment.

6. **Quantification :** This step will transform the BAM files containing the aligned reads into a count table usable for further analyzes in R or Python.

### Workflow Estimation
4. **Transcripts estimation :** This step consists of aligning the FASTQ files to the reference transcriptome previously indexed with **RSEM** to make an estimate of the abundance of each transcript. For each FASTQ file, several files result, in particular a BAM file and a .stat folder which will make it possible to control the quality of the alignment. There are also .genes.results and .isoforms.results files containing respectively the results of the estimation of expression by genes or by transcripts which will be used for further analyzes in R or Python.

5. **Alignment Quality Check :** In order to analyze the proportion of correctly aligned reads, the **MultiQC** tool can be directly used to pool the quality control of the BAM files resulting from the alignment.


# Initialization and recommendations

### Scripts
All required scripts are available in the script folder in this directory. The workflow is coded in Shell language and is supposed to be launched under a Linux environment.  
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

### 





















