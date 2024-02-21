// modified version from nf-core module
process BWA_INDEX {
    tag "$meta.id"
    label 'process_medium'

    conda (params.enable_conda ? "bioconda::bwa" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bwa:0.7.17--hed695b0_7' :
        'quay.io/biocontainers/bwa:0.7.17--hed695b0_7' }"

    input:
    tuple val(meta), path(refFasta)

    output:
    path "bwa"         , emit: index
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p bwa
    bwa \\
        index \\
        -p bwa/${refFasta.getName()} \\
        ${refFasta}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bwa: \$(echo \$(bwa 2>&1) | sed 's/^.*Version: //; s/Contact:.*\$//')
    END_VERSIONS
    """
}
