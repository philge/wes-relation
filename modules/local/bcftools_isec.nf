process BCFTOOLS_ISEC {
    tag "$meta.id"
    label 'process_medium'

    conda "bioconda::bcftools"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bcftools:1.18--h8b25389_0':
        'biocontainers/bcftools:1.18--h8b25389_0' }"

    input:
    tuple val(meta), path(vcfs)
    tuple val(meta), path(tbis)

    output:
    tuple val(meta), path("variants_stats.txt"), emit: results
    path  "versions.yml"              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args   ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    vcfList = vcfs.collect()
    """
    bcftools isec  \\
        $args \\
        -p $prefix \\
        -Oz \\
        ${vcfList.join(' ')}
    zcat $prefix/0002.vcf.gz | grep -v "^#" | wc -l > shared_variants.txt
    zcat $prefix/0000.vcf.gz $prefix/0001.vcf.gz $prefix/0002.vcf.gz | grep -v "^#" | wc -l > total_variants.txt
    awk 'NR==FNR{shared=\$1; next} {total=\$1} END{printf "Percentage of shared variants: %.2f%%\\n", (shared/total)*100}' shared_variants.txt total_variants.txt > variants_stats.txt
    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bcftools: \$(bcftools --version 2>&1 | head -n1 | sed 's/^.*bcftools //; s/ .*\$//')
    END_VERSIONS
    """
}