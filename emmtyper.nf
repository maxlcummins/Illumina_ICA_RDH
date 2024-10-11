// emmtyper.nf
nextflow.enable.dsl = 2
 
process EMMTYPER {
    // Container image for EMMTYPER
    container 'quay.io/biocontainers/emmtyper:0.2.0--py_0'

    // Resource allowance
    cpus 1
    memory '4 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/EMMTYPER', mode: 'symlink'
    
    input:
        tuple val(sample_id), path("${sample_id}.fasta")
        path emmtyper_db

    output:
        path("${sample_id}.tsv"), emit: report
        path "versions.yml", emit: versions

    script:
    """
    makeblastdb -in ${emmtyper_db} -dbtype nucl -title alltrimmed

    emmtyper \\
        --blast_db ${emmtyper_db} \\
        ${sample_id}.fasta \\
        > ${sample_id}.tsv 

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        emmtyper: \$( echo \$(emmtyper --version 2>&1) | sed 's/^.*emmtyper v//' )
    END_VERSIONS
    """
}


process EMMTYPER_aggregate {
    // Container image
    container 'quay.io/biocontainers/emmtyper:0.2.0--py_0'

    // Resource allowance
    cpus 1
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/summaries', mode: 'symlink'
    
    input:
        path reports

    output:
        path("emmtyper_report.tsv")

    when:
        task.ext.when == null || task.ext.when

    script:
        """
        # Combine reports
        cat ${reports} > tmp_file

        # Trim off file suffix from names
        sed -i 's/\\.tmp//g' tmp_file

        # Add header and create the final report
        echo -e "name\tnumber_of_clusters\temm-type\temm-like alleles\tEMM cluster" | cat - tmp_file > emmtyper_report.tsv
        """
}