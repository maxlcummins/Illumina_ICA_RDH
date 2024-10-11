
// quast.nf

nextflow.enable.dsl = 2
 
process QUAST {
    // Container image for QUAST
    container 'quay.io/biocontainers/quast:5.2.0--py39pl5321h2add14b_1'

    // Resource allowance
    cpus 1
    memory '8 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/QUAST', mode: 'symlink'
    
    input:
        tuple val(sample_id), path("${sample_id}.fasta")

    output:
        path("${sample_id}/report.tsv"), emit: multiqc_report
        path("${sample_id}/${sample_id}_quast.tsv"), emit: report
        path "versions.yml"                                  , emit: versions

    script:
    """
    quast.py \\
        ${sample_id}.fasta \\
        -o ${sample_id} \\
        --threads $task.cpus \\

    cp ${sample_id}/transposed_report.tsv ${sample_id}/${sample_id}_quast.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quast: \$(quast.py --version 2>&1 | sed 's/^.*QUAST v//; s/ .*\$//')
    END_VERSIONS
    """
}

process QUAST_aggregate {
    // Container image
    container 'quay.io/biocontainers/quast:5.2.0--py39pl5321h2add14b_1'

    // Resource allowance
    cpus 1
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/summaries', mode: 'symlink'
    
    input:
        path reports

    output:
        path("quast_report.tsv")

    when:
        task.ext.when == null || task.ext.when

    script:
        def args = task.ext.args ?: ''
        """
        # Combine reports
        cat ${reports} > tmp_file
        # Change "Assembly" column to "name" (to standardise index)
        sed -i 's/^Assembly/name/g' tmp_file
        awk 'NR==1 || \$0 != header { if(NR==1){header=\$0}; print }' tmp_file > quast_report.tsv
        """
}
