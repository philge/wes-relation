/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl=2

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowWesrelation.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.fasta ]

for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'samplesheet not specified!' }
if (params.fasta) { fasta = file(params.fasta) } else { exit 1, 'fasta not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//

// MODULES
include { FASTQ_CHECK } from '../subworkflows/local/fastq_check'
include { FASTP } from '../modules/local/fastp'
include { BWA_INDEX } from '../modules/local/bwaindex'
include { BWA_MEM } from '../modules/local/bwamem'
include { SAMTOOLS_FAIDX } from '../modules/local/faidx'
include { PICARD_MARKDUPLICATES } from '../modules/local/picardmarkdup'
include { GATK4_HAPLOTYPECALLER } from '../modules/local/haplotypecaller'
include { GATK4_CREATESEQUENCEDICTIONARY } from '../modules/local/createsequencedictionary'
include { GATK4_VARIANTFILTRATION } from '../modules/local/variantfiltration'
include { BCFTOOLS_ISEC } from '../modules/local/bcftools_isec'
include { PLINK_VCF } from '../modules/local/plink_vcf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/modules/fastqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow WES_RELATION {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //

    FASTQ_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(FASTQ_CHECK.out.versions)
    
    //
    // MODULE: Run FastQC
    //
    FASTQC (
        FASTQ_CHECK.out.reads
    ).html.set { fastqc_html }
    fastqc_zip  = FASTQC.out.zip
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // MODULE: Run FASTP
    //
    FASTP (
        FASTQ_CHECK.out.reads
    )
    ch_versions = ch_versions.mix(FASTP.out.versions.first())

    //
    // MODULE: Run BWA_INDEX
    //
    def meta = [:]
    meta.id = "genome"
    BWA_INDEX (
        tuple meta, fasta
    )
    ch_versions = ch_versions.mix(BWA_INDEX.out.versions)

    //
    // MODULE: Run BWA_MEM
    //
    BWA_MEM (
        FASTP.out.reads,
        BWA_INDEX.out.index,
        fasta
    )
    ch_versions = ch_versions.mix(BWA_MEM.out.versions.first())

    //
    // MODULE: Run SAMTOOLS_FAIDX
    //
    SAMTOOLS_FAIDX (
        tuple meta, fasta
    )
    ch_versions = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    //
    // MODULE: Run GATK4_CREATESEQUENCEDICTIONARY
    //
    GATK4_CREATESEQUENCEDICTIONARY (
        SAMTOOLS_FAIDX.out.fa
    )
    ch_versions = ch_versions.mix(GATK4_CREATESEQUENCEDICTIONARY.out.versions)

    //
    // MODULE: Run PICARD_MARKDUPLICATES
    //
    PICARD_MARKDUPLICATES (
        BWA_MEM.out.bam
    )
    ch_versions = ch_versions.mix(PICARD_MARKDUPLICATES.out.versions.first())

    //
    // MODULE: Run GATK4_HAPLOTYPECALLER
    //
    GATK4_HAPLOTYPECALLER (
        PICARD_MARKDUPLICATES.out.bam,
        PICARD_MARKDUPLICATES.out.bai,
        SAMTOOLS_FAIDX.out.fa,
        SAMTOOLS_FAIDX.out.fai,
        GATK4_CREATESEQUENCEDICTIONARY.out.dict
    )
    ch_versions = ch_versions.mix(GATK4_HAPLOTYPECALLER.out.versions.first())

    //
    // MODULE: Run GATK4_VARIANTFILTRATION
    //
    GATK4_VARIANTFILTRATION (
        GATK4_HAPLOTYPECALLER.out.vcf,
        GATK4_HAPLOTYPECALLER.out.tbi,
        SAMTOOLS_FAIDX.out.fa,
        SAMTOOLS_FAIDX.out.fai,
        GATK4_CREATESEQUENCEDICTIONARY.out.dict
    )
    .vcf
    .map {
        meta1, vcf ->
            def meta_clone = meta1.clone()
            meta_clone.id = "SAMPLES"
            [ meta_clone, vcf ]
    }
    .groupTuple(by: [0])
    .set { samplesVcfs }

    GATK4_VARIANTFILTRATION.out.tbi.map {
        meta2, tbi ->
            def meta_clone = meta2.clone()
            meta_clone.id = "SAMPLES"
            [ meta_clone, tbi ]
    }
    .groupTuple(by: [0])
    .set { samplesTbis }
    ch_versions = ch_versions.mix(GATK4_VARIANTFILTRATION.out.versions.first())

    // Process to compare variants between two samples
    //
    // MODULE: Run BCFTOOLS_ISEC
    //
    BCFTOOLS_ISEC (
        samplesVcfs,
        samplesTbis
    )
    ch_versions = ch_versions.mix(BCFTOOLS_ISEC.out.versions.first())

    // Process to perform IBD analysis
    //
    // MODULE: Run PLINK2_VCF
    //
    PLINK_VCF (
        samplesVcfs,
        samplesTbis
    )
    ch_versions = ch_versions.mix(PLINK_VCF.out.versions.first())

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
    }
    NfcoreTemplate.summary(workflow, params, log)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
