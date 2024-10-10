// rasusa.nf
nextflow.enable.dsl = 2
  
process RASUSA {
    // Container image for RASUSA
    container 'staphb/rasusa:2.0.0'
    
    // Resource allowance
    cpus 2
    memory '3 GB'

    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/RASUSA', mode: 'symlink'
    
    // Define inputs: sample ID and filtered FASTQ files from FASTP
    input:
        tuple val(sample_id), path("${sample_id}_filt_clean.R1.fastq.gz"), path("${sample_id}_filt_clean.R2.fastq.gz")
    
    // Define outputs: sample ID and filtered FASTQ files
    output:
        tuple val(sample_id), path("${sample_id}_filt_clean_sub.R1.fastq.gz"), path("${sample_id}_filt_clean_sub.R2.fastq.gz"), emit: filt_clean_sub_reads
        path "versions.yml", emit: versions
    
    // Define the script to execute RASUSA
    script:
    """
    # Run Rasusa
    rasusa \\
        reads \\
        --coverage 50 \\
        --genome-size 5mb \\
        --seed 1 \\
        -o ${sample_id}_filt_clean_sub.R1.fastq.gz \\
        -o ${sample_id}_filt_clean_sub.R2.fastq.gz \\
        ${sample_id}_filt_clean.R1.fastq.gz \\
        ${sample_id}_filt_clean.R2.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rasusa: \$(rasusa --version 2>&1 | sed -e "s/rasusa //g")
    END_VERSIONS
    """
}