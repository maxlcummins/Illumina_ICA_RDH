// sistr.nf
nextflow.enable.dsl = 2
 
process SISTR {
    // Container image for SISTR
    container 'quay.io/biocontainers/sistr_cmd:1.1.1--pyh864c0ab_2'

    // Resource allowance
    cpus 1
    memory '8 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/SISTR', mode: 'symlink'
    
    input:
        tuple val(sample_id), path("${sample_id}.fasta")

    output:
        path("*.tab"), emit: report
        path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # Run SISTR
    sistr \\
        --qc \\
        $args \\
        --threads $task.cpus \\
        --alleles-output ${sample_id}-allele.json \\
        --novel-alleles ${sample_id}-allele.fasta \\
        --cgmlst-profiles ${sample_id}-cgmlst.csv \\
        --output-prediction ${sample_id} \\
        --output-format tab \\
        ${sample_id}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sistr: \$(echo \$(sistr --version 2>&1) | sed 's/^.*sistr_cmd //; s/ .*\$//' )
    END_VERSIONS
    """
}

process SISTR_aggregate {
    // Container image
    container 'quay.io/biocontainers/mlst:2.23.0--hdfd78af_0'

    // Resource allowance
    cpus 1
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'Results/summaries', mode: 'symlink'
    
    input:
        path reports

    output:
        path("sistr_report.tsv"), emit: report

    when:
        task.ext.when == null || task.ext.when

    script:
        def args = task.ext.args ?: ''
        """
        # Combine reports
        cat ${reports} > tmp_file
        
        # 2. Use `awk` to process the temporary file and generate the final report.
        awk 'BEGIN {FS=OFS="\\t"}               #    - Set the field separator (`FS`) and output field separator (`OFS`) to tab (`\t`).
        NR==1 {                                 #    - For the first line (header), search for the column named "fasta_filepath".
            for (i=1; i<=NF; i++) {
                if (\$i == "fasta_filepath") {
                    col=i;
                    break;
                }
            }
            print "name", \$0;                  #    - Once the "fasta_filepath" column is found, store its index and add a new "name" column at the beginning.
            next
        }                                                               #    - For all subsequent lines (data rows):
        {                                                               #        - Extract the file name from the "fasta_filepath" by splitting the path on "/".
            n = split(\$col, arr, "/");                                 
            base = arr[n];                                              
            sub(/\\\\.fasta\$/, "", base);                              #        - Remove the ".fasta" extension from the extracted file name.
            print base, \$0                                             #        - Prepend the file name (without extension) to the original line, creating a new column named "name".
        }' tmp_file > sistr_report.tsv
        """
}