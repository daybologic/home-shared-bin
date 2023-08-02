<?php
define("JOB_FILE","job.json");
define("OUTPUT_FILE","output.json");

if(file_exists(JOB_FILE)) {
    echo "Existing job found - resume (Delete job.json to abort)\n";
    $config=json_decode(file_get_contents(JOB_FILE));
}else{
    $config=(object) array();
    $config->accountId=readline("Account Id: ");
    $config->region=readline("Region: ");
    $config->vaultName=readline("VaultName: ");

    exec('aws glacier initiate-job --vault-name '.$config->vaultName.'  --account-id '. $config->accountId.' --job-parameters \'{"Type": "inventory-retrieval"}\' --region '.$config->region.' > '.OUTPUT_FILE);
    $config->job=json_decode(file_get_contents(OUTPUT_FILE)); //decode job output
    file_put_contents(JOB_FILE, json_encode($config));
}

echo "Checking Job\n";
do {
    exec('aws glacier describe-job --vault-name ' . $config->vaultName . '  --account-id ' . $config->accountId . ' --job-id=\'' . $config->job->jobId . '\' > ' . OUTPUT_FILE);
    $result = json_decode(file_get_contents(OUTPUT_FILE));
    if($result->StatusCode=='InProgress'){
        echo "Still in progress - waiting 5 min\n";
        sleep(60*5);
    }else{
        continue;
    }
    echo "Status: " . $result->StatusCode."\n";
}while($result->StatusCode=='InProgress');

if($result->StatusCode=='Succeeded'){
    echo "Inventory is ready to delete archives\n";
    exec('aws glacier get-job-output --vault-name ' . $config->vaultName . '  --account-id ' . $config->accountId . ' --job-id=\'' . $config->job->jobId . '\'  ' . OUTPUT_FILE);
    $string = file_get_contents ( OUTPUT_FILE ) ;
    $json = json_decode($string, true ) ;
    foreach ( $json [ 'ArchiveList' ] as $jsonArchives )
    {
        echo 'Delete Archive: ' . $jsonArchives [ 'ArchiveId' ] . "\n" ;
        exec ( 'aws glacier delete-archive --archive-id="' . $jsonArchives [ 'ArchiveId' ] . '" --vault-name ' . $config->vaultName . ' --account-id ' . $config->accountId . ' --region ' . $config->region) ;
    }
    echo "All archives deleted - Deleting vault itself\n";
    exec('aws glacier delete-vault --vault-name ' . $config->vaultName . '  --account-id ' . $config->accountId . ' --region '.$config->region.' > '.OUTPUT_FILE);
    echo file_get_contents(OUTPUT_FILE);
}




