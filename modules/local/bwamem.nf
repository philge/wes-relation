// modified version from nf-core module.
process BWA_MEM {
    tag "$meta.id"
    label 'process_high'

    conda (params.enable_conda ? "bioconda::bwa bioconda::samtools" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-fe8faa35dbf6dc65a0f7f5d4ea12e31a79f73e40:8110a70be2bfe7f75a2ea7f2a89cda4cc7732095-0' :
        '' }"

    input:
    tuple val(meta), path(reads)
    path(indexPath)
    path(fasta)

    output:
    tuple val(meta), path("*.bam"), emit: bam
    tuple val(meta), path("*.bai"), emit: bai
    path  "versions.yml"          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def PREFIX = "${meta.id}_1"

    """
    ([ $meta.single_end = true ]) && (bwa mem -R "@RG\\tID:${PREFIX}\\tSM:${PREFIX}" \\
            ${params.BWA_OPTS} \\
            -t $task.cpus \\
            "${indexPath}/${fasta.getName()}" \\
            "${reads[0]}" | \\
            samtools sort -o sorted.bam)

    ([ $meta.single_end = false ]) && (bwa mem -R "@RG\\tID:${PREFIX}\\tSM:${PREFIX}" \\
            ${params.BWA_OPTS} \\
            -t $task.cpus \\
            "${indexPath}/${fasta.getName()}" \\
            "${reads[0]}" "${reads[1]}" | \\
            samtools sort -o sorted.bam)

    samtools index sorted.bam
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(echo \$(bwa 2>&1) | sed 's/^.*Version: //; s/Contact:.*\$//')
        samtools: \$(echo \$(samtools --version 2>&1) | head -1 |cut -f2 -d' ')
    END_VERSIONS
    """
}
