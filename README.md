# Nextflow code for comparing WES samples. Steps to run the pipeline are described below.

## Prerequisites to run Nextflow code

Install Anaconda  
Create a conda environment  
Install Nextflow in conda environment  
Clone https://github.com/philge/wes-relation.git  
Change directory to Nextflow code folder (./wes-relation), prepare samplesheet.csv  

Run command:  
```console
nextflow run main.nf --input samplesheet.csv -with-report run_report.html --outdir results --fasta /*/genome.fa -resume -profile conda
```

## Credits

Code was originally written by Philge Philip.  

## Contributions and Support

# AUTHORS:
Philge Philip <philgev2@gmail.com>
