process PLINK_VCF {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::plink bioconda::bcftools"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/plink2:2.00a2.3--h712d239_1' :
        'biocontainers/plink2:2.00a2.3--h712d239_1' }"

    input:
    tuple val(meta), path(vcfs)
    tuple val(meta), path(tbis)

    output:
    tuple val(meta), path("*.genome")    , emit: genome
    path "versions.yml"                , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def mem_mb = task.memory.toMega()
    vcfList = vcfs.collect()
    """
    bcftools merge ${vcfList.join(' ')} > merged.vcf
    plink \\
        --double-id \\
        --threads $task.cpus \\
        --memory $mem_mb \\
        $args \\
        --vcf merged.vcf \\
        --genome \\
        --out ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        plink2: \$(plink2 --version 2>&1 | sed 's/^PLINK v//; s/ 64.*\$//' )
    END_VERSIONS
    """
}