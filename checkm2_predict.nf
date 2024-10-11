// shovill.nf
nextflow.enable.dsl = 2
 
process CHECKM2 {
    // Container image for CHECKM2
    container 'quay.io/biocontainers/checkm2:1.0.2--pyh7cba7a3_0'

    // Resource allowance
    cpus 8
    memory '16 GB'
    
    // Kubernetes pod annotations (if applicable)
//    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-medium'
//    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/CHECKM2', mode: 'symlink'
    
    // Define inputs: sample ID and assembly from SHOVILL
    input:
        path fasta_files
        path checkm2_database
    
    // Define outputs: checkM2 Quality Report
    output:
        path("quality_report.tsv"), emit: report
        path("versions.yml"), emit: versions
    
    // Define the script to execute CHECKM2
    script:
    """
    checkm2 \\
        predict \\
        --input $fasta_files \\
        --output-directory CheckM2 \\
        --threads ${task.cpus} \\
        --database_path ${checkm2_database}

    cp CheckM2/quality_report.tsv .

    sed -i 's/^Name/name/g' quality_report.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        checkm2: \$(checkm2 --version)
    END_VERSIONS
    """
}