# Bulk_RNA-seq
Custom pipeline for Bulk RNA-seq analysis


# Description du workflow

Deux méthodes de quantification sont disponibles dans ce workflow :  
* **Raw Counts :** Cette méthode permet d'obtenir une table de comptage contenant des valeurs entières correspondant au nombre exact de reads alignés sur chaque gène. Pour cela on réalise d'abord un alignement au génome de référence avec **STAR**, puis une quantification "exacte" avec **featureCount**.  
* **Estimation :** Cette méthode permet d'obtenir une table contenant des valeurs décimales correspondant à l'estimation de l'expression des transcrits, par normalisation des reads alignés selon la taille des transcrits. Pour cela on réalise une estimation de l'expression avec **RSEM**.  

<img src="[https://github.com/JosephLeger/Bulk_RNA-seq/edit/main/img/pipeline.png](https://github.com/JosephLeger/Bulk_RNA-seq/edit/main/README.md).jpg"  width="90%" height="90%">
