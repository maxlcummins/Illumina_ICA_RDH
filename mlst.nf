// mlst.nf
nextflow.enable.dsl = 2
 
process MLST {
    // Container image for MLST
    container 'quay.io/biocontainers/mlst:2.23.0--hdfd78af_0'

    // Resource allowance
    cpus 1
    memory '4 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/MLST', mode: 'symlink'
    
    input:
        tuple val(sample_id), path("${sample_id}.fasta")

    output:
        path("${sample_id}.txt"), emit: report

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # Run mlst
    mlst \\
        $args \\
        --threads $task.cpus \\
        ${sample_id}.fasta \\
        > ${sample_id}.txt
    """
}

process MLST_aggregate {
    // Container image
    container 'quay.io/biocontainers/mlst:2.23.0--hdfd78af_0'

    // Resource allowance
    cpus 1
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/summaries', mode: 'symlink'
    
    input:
        path reports

    output:
        path("mlst_report.tsv"), emit: report
        path "versions.yml", emit: versions

    when:
        task.ext.when == null || task.ext.when

    script:
        def args = task.ext.args ?: ''
        """
        # Combine reports
        cat ${reports} > mlst_report.tsv
        sed -i 's/\\.fasta//g' mlst_report.tsv


        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            mlst: \$( echo \$(mlst --version 2>&1) | sed 's/mlst //' )
        END_VERSIONS
        """
}