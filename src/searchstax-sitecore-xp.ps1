function Upload-Config($solrVersion, $token) {
    try {
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization", "Token $token")

        $configList = Invoke-RestMethod -Method Get -Headers $headers -uri $configUploadUrl

        $solrConfigPath = -join($xpConfigPath,$solrVersion,'.zip')

        if ($isUniqueConfigs) {
            foreach($collection in $coll){
                $confName = -join('',$sitecorePrefix,$collection)
                Write-Host $confName
                if($configList.configs -contains $confName) {
                    Write-Host "$confName exists already. Skipping."
                    continue
                }
                $form = @{
                    name = $confName
                    files = Get-Item -Path $solrConfigPath
                }
                # Write-Host $body
                Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
            }
        } else {
            $form = @{
                name = "sitecore_$sitecorePrefix"
                files = Get-Item -Path $solrConfigPath
            }
            if($configList.configs -contains "sitecore_$sitecorePrefix") {
                Write-Host "sitecore_$sitecorePrefix exists already. Skipping."
                continue
            }
            Invoke-RestMethod -Method Post -Form $form -Headers $headers -uri $configUploadUrl 
        }

    } catch {
        Write-Error -Message "Unable to upload config file. Error was: $_" -ErrorAction Stop
    }    
}

#TODO : Too many moving parts - Add try-catch blocks and make it fault tolerant
function Create-Collections($solr, $nodeCount) {
    Write-Host $solr
    if ($solrUsername.length -gt 0){
        $secpasswd = ConvertTo-SecureString $solrPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential($solrUsername, $secpasswd)
    }
    "Creating Collections ... "

    foreach($collection in $coll){
        $collection | Write-Host
        if ($isUniqueConfigs) {
            $url = -join($solr, "admin/collections?action=CREATE&name=",$sitecorePrefix,$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=",$sitecorePrefix,$collection)
        } else {
            $url = -join($solr, "admin/collections?action=CREATE&name=",$sitecorePrefix,$collection,"&numShards=1&replicationFactor=",$nodeCount,"&collection.configName=sitecore_$sitecorePrefix")
        }

        
        if ($solrUsername.length -gt 0){
            Invoke-WebRequest -Uri $url -Credential $credential
        }
        else {
            Invoke-WebRequest -Uri $url
            # Write-Host $url
        }
        
    }
}

function Update-ConnectionStringsConfig ($solr) {
    "Updating ConnectionStrings.Config file"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\ConnectionStrings.config")
    $xpath = "//connectionStrings/add[@name='solr.search']"
    # $solr = Get-SolrUrl $token
    $solr = $solr.substring(0,$solr.length-1)
    if ($solrUsername.length -gt 0) {
        $solr = -join("https://",$solrUsername,":",$solrPassword,"@",$solr.substring(8,$solr.length-8))
    }
    $solr = -join($solr,";solrCloud=true")
    $attributeKey = "connectionString"
    $attributeValue = $solr
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-EnableSearchProvider {
    "Updating Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\Sitecore\ContentSearch\Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config")
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.Provider']"
    $attributeKey = "value"
    $attributeValue = "Solr"
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-MaxNumberOfSearchResults {
    "Updating Sitecore.ContentSearch.config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\Sitecore\ContentSearch\Sitecore.ContentSearch.config")
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.SearchMaxResults']"
    $attributeKey = "value"
    $attributeValue = $searchMaxResults
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-EnableBatchMode {
    "Updating Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\App_Config\Sitecore\ContentSearch\Sitecore.ContentSearch.Solr.DefaultIndexConfiguration.config")
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.Update.BatchModeEnabled']"
    $attributeKey = "value"
    $attributeValue = "true"
    Update-XML $path $xpath $attributeKey $attributeValue
    $xpath = "//configuration/sitecore/settings/setting[@name='ContentSearch.Update.BatchSize']"
    $attributeKey = "value"
    $attributeValue = $batchSize
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-WebConfig {
    "Updating Web.Config"
    $path = -join($pathToWWWRoot, "\", $sitecorePrefix,".sc\Web.config")
    $xpath = "//configuration/appSettings/add[@key='search:define']"
    $attributeKey = "value"
    $attributeValue = "Solr"
    Update-XML $path $xpath $attributeKey $attributeValue
}

function Update-SitecoreConfigs ($sitecoreVersion, $solr) {
    if ($sitecoreVersion -eq "9.0.2") {
        Update-WebConfig
        Update-ConnectionStringsConfig $solr
        Update-EnableSearchProvider
        Update-MaxNumberOfSearchResults
        Update-EnableBatchMode
    } Elseif ($sitecoreVersion -eq "9.1.1") {
        Update-WebConfig
        Update-ConnectionStringsConfig $solr
    } Elseif ($sitecoreVersion -eq "9.2.0") {
        Update-WebConfig
        Update-ConnectionStringsConfig $solr
    } Elseif ($sitecoreVersion -eq "9.3.0") {
        Update-WebConfig
        Update-ConnectionStringsConfig $solr
    } Elseif ($sitecoreVersion -eq "10.0.0") {
        Update-WebConfig
        Update-ConnectionStringsConfig $solr
    } Elseif ($sitecoreVersion -eq "10.1.0") {
        Update-WebConfig
        Update-ConnectionStringsConfig $solr
    } Elseif ($sitecoreVersion -eq "10.1.1") {
        Update-WebConfig
        Update-ConnectionStringsConfig $solr
    }

}