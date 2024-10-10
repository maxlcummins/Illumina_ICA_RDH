// mashtree.nf
nextflow.enable.dsl = 2
 
process MASHTREE {
    // Container image for MASHTREE
    container 'quay.io/biocontainers/mashtree:1.2.0--pl526h516909a_0'

    // Resource allowance
    cpus 4
    memory '8 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/MASHTREE', mode: 'symlink'
    
    input:
        path fasta_files

    output:
        path("mash.tsv"), emit: mash_table
        path("mash.dnd"), emit: mashtree
        path "versions.yml", emit: versions

    script:
    """
    mashtree \\
        --numcpus $task.cpus \\
        --outmatrix mash.tsv \\
        --outtree mash.dnd \\
        ${fasta_files}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mashtree: \$( echo \$( mashtree --version 2>&1 ) | sed 's/^.*Mashtree //' )
    END_VERSIONS
    """
}