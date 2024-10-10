// shovill.nf
nextflow.enable.dsl = 2
 
process ABRITAMR {
    // Container image for ABRITAMR
    container 'quay.io/biocontainers/abritamr:1.0.19--pyhdfd78af_0'

    // Resource allowance
    cpus 1
    memory '8 GB'
    
    // Kubernetes pod annotations (if applicable)
    pod annotation: 'scheduler.illumina.com/presetSize', value: 'standard-small'
    pod annotation: 'volumes.illumina.com/scratchSize', value: '100GiB'
    
    // Publish outputs to the 'out' directory using symlinks
    publishDir 'out/ABRITAMR', mode: 'symlink'
    
    input:
        tuple val(sample_id), path("${sample_id}.fasta")

    output:
        path("${sample_id}.summary_matches.txt"), emit: report
        path "versions.yml"                                  , emit: versions

    script:
    """
    abritamr run \\
        --contigs ${sample_id}.fasta \\
        --prefix results \\
        --jobs $task.cpus

        # Rename output files to prevent name collisions
    mv results/summary_matches.txt ./${sample_id}.summary_matches.txt
    mv results/summary_partials.txt ./${sample_id}.summary_partials.txt
    mv results/summary_virulence.txt ./${sample_id}.summary_virulence.txt
    mv results/amrfinder.out ./${sample_id}.amrfinder.out
    if [ -f results/abritamr.txt ]; then
        # This file is not always present
        mv results/abritamr.txt ./${sample_id}.abritamr.txt
    fi


    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        abritamr: \$(echo \$(abritamr --version 2>&1) | sed 's/^.*abritamr //' ))
    END_VERSIONS
    """
}

process ABRITAMR_aggregate {
    container 'quay.io/biocontainers/abritamr:1.0.19--pyhdfd78af_0'

    cpus 1
    
    publishDir 'Results/summaries', mode: 'symlink'
    
    input:
        path reports

    output:
        path("abritamr_report.tsv")

    when:
        task.ext.when == null || task.ext.when

    script:
        def output_file = "abritamr_report.tsv"
        """
        #!/usr/bin/env python

        import pandas as pd
        import os

        # Create an empty list
        dataframes = []

        # Input files from Nextflow (received as a space-separated string of file paths)
        input_files = '${reports}'.split()

        # Process each file, setting the basename as the 'name' column
        for file in input_files:
            df = pd.read_csv(file, sep="\t", index_col=None)

            # Rename Isolate column to name
            df.rename(columns={'Isolate': 'name'}, inplace=True)

            # Set the name column to be equal to the sample name
            df['name'] = os.path.basename(file).replace(".summary_matches.txt", "")

            # Append the dataframe to the list
            dataframes.append(df)

        # Concatenate our dataframes into a single one
        combined = pd.concat(dataframes)

        # If there's an existing 'name' column, replace any missing values with the basename
        combined['name'].fillna(os.path.basename(file), inplace=True)

        # Write our output file to text
        combined.to_csv('${output_file}', sep="\t", index=False)
        """
}