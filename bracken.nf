// bracken.nf
nextflow.enable.dsl = 2
 
process BRACKEN {
    // Container image for BRACKEN
    container 'quay.io/biocontainers/bracken:2.9--py38h2494328_0'

    // Resource allowance
    cpus 8
    memory '16 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-medium'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/BRACKEN', mode: 'symlink'
    
    // Define inputs: sample ID and filtered FASTQ files from FASTP
    input:
        tuple val(sample_id), path("${sample_id}.kraken2.report.txt")
        path kraken2_db
    
    // Define outputs: Assembly FASTA and log files
    output:
    tuple val(sample_id), path("${sample_id}.bracken.report.txt")                           , emit: report
    tuple val(sample_id), path("${sample_id}.bracken_kraken2_style.report.txt")                           , emit: kraken_style_report
    path "versions.yml"                                            , emit: versions
    
    // Define the script to execute BRACKEN
    script:
    def args = task.ext.args ?: ''
    """
    bracken \\
        ${args} \\
        -d '${kraken2_db}' \\
        -i '${sample_id}.kraken2.report.txt' \\
        -o '${sample_id}.bracken.report.txt' \\
        -w '${sample_id}.bracken_kraken2_style.report.txt'

    awk 'NR==1 {print "name_file\\t" \$0; next} {print "'${sample_id}'" "\\t" \$0}' '${sample_id}.bracken.report.txt' > '${sample_id}.bracken.report.with_name.txt'

    # Optionally, replace the original file with the modified one
    mv '${sample_id}.bracken.report.with_name.txt' '${sample_id}.bracken.report.txt'        

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bracken: \$(echo \$(bracken -v) | cut -f2 -d'v')
    END_VERSIONS
    """
}
