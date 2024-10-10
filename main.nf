// main.nf

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Check input path parameters to see if they exist
def checkPathParamList = [ params.fastq_folder ]
for (param in checkPathParamList) { 
    if (param) { 
        file(param, checkIfExists: true) 
    } 
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Place config files here

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Import the FASTP and SHOVILL modules
//include { SCRUBBER } from './scrubber.nf'
include { RASUSA } from './rasusa.nf'
include { FASTP } from './fastp.nf'
include { SHOVILL } from './shovill.nf'
include { QUAST } from './quast.nf'
include { QUAST_aggregate } from './quast.nf'
include { SHIGAPASS } from './shigapass.nf'
include { SHIGAPASS_aggregate } from './shigapass.nf'
include { SISTR } from './sistr.nf'
include { SISTR_aggregate } from './sistr.nf'
include { MLST } from './mlst.nf'
include { MLST_aggregate } from './mlst.nf'
include { ABRITAMR } from './abritamr.nf'
include { ABRITAMR_aggregate } from './abritamr.nf'
include { MASHTREE } from './mashtree.nf'
include { EMMTYPER } from './emmtyper.nf'
include { EMMTYPER_aggregate } from './emmtyper.nf'
//include { CHECKM2_DATABASEDOWNLOAD } from './checkm2_db.nf'
include { CHECKM2 } from './checkm2_predict.nf'
include { KRAKEN2 } from './kraken2.nf'
include { BRACKEN } from './bracken.nf'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    // Step 1: Pair R1 and R2 FASTQ.gz files with their sample IDs
    ch_samples = Channel.fromFilePairs("${params.fastq_folder}/*{R1,R2}.fastq.gz", size: 2)
        .map { sample_id, files -> 
            def read1 = files.find { it.name.endsWith('.R1.fastq.gz') }
            def read2 = files.find { it.name.endsWith('.R2.fastq.gz') }
            tuple(sample_id, read1, read2)
        }

    // View our samples
    ch_samples.view()

    // Step 1b: define databases
    emmtyper_db = Channel.value("/${params.database_dir}/emmtyper/alltrimmed.fa")
    mashscreen_db = Channel.value("/${params.database_dir}/RefSeqSketchesDefaults.msh")
    scrubber_db = Channel.value("/${params.database_dir}/human_filter.db.20240718v2")
    checkm2_db = Channel.value("/${params.database_dir}/checkm2/checkm2_db_v2.dmnd")
    kraken2_db = Channel.value("/${params.database_dir}/k2_standard")

    // Step 2: Pass the paired samples to the SCRUBBER process
    //scrubber_out = SCRUBBER(ch_samples, scrubber_db)
    
    // Step 3: Pass the paired samples to the FASTP process
    fastp_out = FASTP(ch_samples)

    // Step 4: Pass the paired samples to the RASUSA process
    rasusa_out = RASUSA(fastp_out.filt_clean_reads)

    // Step 5: Pass the FASTP outputs to the SHOVILL process
    shovill_out = SHOVILL(rasusa_out.filt_clean_sub_reads)

    // Step 6: Pass the SHOVILL outputs to the QUAST process
    quast_out = QUAST(shovill_out.assembly)

            // Step 6b: Collect all QUAST reports into a single channel
    quast_reports = quast_out.report.collect()

            // Step 6c: Aggregate QUAST data
    quast_aggregate = QUAST_aggregate(quast_reports)

    // Step 7: Pass the SHOVILL outputs to the SISTR process
    sistr_out = SISTR(shovill_out.assembly)

            // Step 7b: Collect all SISTR reports into a single channel
    sistr_reports = sistr_out.report.collect()

            // Step 7c: Aggregate SISTR data
    sistr_aggregate = SISTR_aggregate(sistr_reports)

    // Step 8: Pass the SHOVILL outputs to the SHIGAPASS process
    shigapass_out = SHIGAPASS(shovill_out.assembly)

            // Step 8b: Collect all SHIGAPASS reports into a single channel
    shigapass_reports = shigapass_out.report.collect()

            // Step 8c: Aggregate SHIGAPASS data
    shigapass_aggregate = SHIGAPASS_aggregate(shigapass_reports)

    // Step 9: Pass the SHOVILL outputs to the SHIGAPASS process
    mlst_out = MLST(shovill_out.assembly)
    
        // Step 9b: Collect all MLST reports into a single channel
    mlst_reports = mlst_out.report.collect()

        // Step 9c: Aggregate MLST data
    mlst_aggregate = MLST_aggregate(mlst_reports)

    // Step 10: Pass the SHOVILL outputs to the ABRITAMR process
    abritamr_out = ABRITAMR(shovill_out.assembly)

        // Step 10b: Collect all MLST reports into a single channel
    abritamr_reports = abritamr_out.report.collect()

        // Step 10c: Aggregate MLST data
    abritamr_aggregate = ABRITAMR_aggregate(abritamr_reports)

    // Step 11: Collect all assemblies for mashtree
    shovill_assemblies = shovill_out.assembly.map { it[1] }.collect()

        // Step 11b
    mashtree_out = MASHTREE(shovill_assemblies)

    // Step 12
    emmtyper_out = EMMTYPER(shovill_out.assembly, emmtyper_db)

        // Step 12b: Collect all MLST reports into a single channel
    emmtyper_reports = emmtyper_out.report.collect()

        // Step 12c: Aggregate MLST data
    emm_typer_aggregate = EMMTYPER_aggregate(emmtyper_reports)
    
    // Step 13: Download CheckM2 Database
    //checkm2_db = CHECKM2_DATABASEDOWNLOAD(5571251)

    // Step 14: Run CheckM2
    CHECKM2(shovill_assemblies, checkm2_db)

    // Step 15: Pass the FASTP outputs to the Kraken2 process
    kraken2_out = KRAKEN2(rasusa_out.filt_clean_sub_reads, kraken2_db)

    // Step 16: Pass the FASTP outputs to the Kraken2 process
    bracken_out = BRACKEN(kraken2_out.report, kraken2_db)


}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
