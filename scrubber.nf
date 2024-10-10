
// scrubber.nf
nextflow.enable.dsl = 2

VERSION = '2.2.1' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

process SCRUBBER {
    // Container image for SCRUBBER

    container 'quay.io/biocontainers/sra-human-scrubber:2.2.1--hdfd78af_0'
    
    // Resource allowance
    cpus 4
    memory '3 GB'

    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/SCRUBBER', mode: 'symlink'
    
    // Define inputs: sample ID and paired FASTQ files
    input:
        tuple val(sample_id), path(read1), path(read2)
        path scrubber_db
    
    // Define outputs: sample ID and filtered FASTQ files
    output:
        tuple val(sample_id), path("${sample_id}_clean.R1.fastq.gz"), path("${sample_id}_clean.R2.fastq.gz"), emit: clean_reads
        path "versions.yml", emit: versions
    
    // Define the script to execute SCRUBBER
    script:
    """
    # Process R1
    gzip -c -d $read1 > R1.fastq

    scrub.sh \
        -i R1.fastq \
        -o ${sample_id}_clean.R1.fastq \
        -p ${task.cpus} \
        -d ${scrubber_db}

    gzip ${sample_id}_clean.R1.fastq

    rm R1.fastq

    # Process R2
    gzip -c -d $read2 > R2.fastq

    scrub.sh \
        -i R2.fastq \
        -o ${sample_id}_clean.R2.fastq \
        -p ${task.cpus} \
        -d ${scrubber_db}


    gzip ${sample_id}_clean.R2.fastq

    rm R2.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        scrubber: $VERSION

        scrubber_DB: \$(/opt/scrubber/scripts/scrub.sh -t 2>&1 | grep "DB version")

    END_VERSIONS
    """
}
