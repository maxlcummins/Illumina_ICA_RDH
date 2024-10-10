// fastp.nf
nextflow.enable.dsl = 2
  
process FASTP {
    // Container image for FASTP
    container 'quay.io/biocontainers/fastp:0.23.4--h5f740d0_0'
    
    // Resource allowance
    cpus 1
    memory '3 GB'

    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/FASTP', mode: 'symlink'
    
    // Define inputs: sample ID and paired FASTQ files
    input:
        tuple val(sample_id), path("${sample_id}_clean.R1.fastq.gz"), path("${sample_id}_clean.R2.fastq.gz")
    
    // Define outputs: sample ID and filtered FASTQ files
    output:
        tuple val(sample_id), path("${sample_id}_filt_clean.R1.fastq.gz"), path("${sample_id}_filt_clean.R2.fastq.gz"), emit: filt_clean_reads
        path "versions.yml", emit: versions
        path "*.json", emit: report_json
        path "*.html", emit: report_html
    
    // Define the script to execute FASTP
    script:
    """
    fastp \
        -i ${sample_id}_clean.R1.fastq.gz \
        -I ${sample_id}_clean.R1.fastq.gz  \
        -o ${sample_id}_filt_clean.R1.fastq.gz \
        -O ${sample_id}_filt_clean.R2.fastq.gz \
        -q 25 \
        --thread ${task.cpus} \
        -j ${sample_id}.json \
        -h ${sample_id}.html

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            fastp: \$(fastp --version 2>&1 | sed -e "s/fastp //g")
        END_VERSIONS
    """
}