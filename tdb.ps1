<#PSScriptInfo
.VERSION 1.0.3
.GUID 4ee202bc-b16f-46b4-a15b-72ae9f4ae177
.AUTHOR voytas75
.TAGS text database, database, simple, minimal
.PROJECTURI https://github.com/voytas75/tdb
.EXTERNALMODULEDEPENDENCIES
.RELEASENOTES
1.0.3: added listing tables.
1.0.2: Improved modularity, added centralized error handling and logging. Enhanced documentation with detailed help blocks and a comprehensive usage guide. Included unit tests for all critical functions and ensured compatibility with different environments.
1.0.1: initializing.
#>

<#
.SYNOPSIS
Simple Miniature Text Relational Database Management System (TDB)

.DESCRIPTION
This PowerShell script implements a simple text-based relational DBMS. It supports CRUD operations, search functionality, indexing, and data integrity checks.
The script is designed to be clean, efficient, and functional, adhering to best practices.

.PARAMETER configFilePath
Specifies the path to the configuration file. If not provided, the script will attempt to load the default configuration file from the script's directory.
#>

param (
    [Parameter(Mandatory = $false)]
    [string]$configFilePath
)

#region Script Metadata
# Define the current version of the script
$tdbVersion = "1.0.3"

# Get the script name from the invocation without the extension
$scriptname = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

# Default columns setting (system application setting)
$DefaultColumns = @("ID", "CreationTime")
#endregion Script Metadata

#region Functions
function Get-LatestVersion {
    param (
        [Parameter(Mandatory = $true)]
        [string]$scriptName
    )
  
    try {
        # Find the script on PowerShell Gallery
        $scriptInfo = Find-Script -Name $scriptName -ErrorAction Stop
  
        # Return the latest version
        return $scriptInfo.Version
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        #Write-Warning "Error occurred while trying to find the script '$scriptName' on PowerShell Gallery."
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath $config.LogFilePath  
        return
    }
}

function Get-CheckForScriptUpdate {
    param (
        [Parameter(Mandatory = $true)]
        [version]$currentScriptVersion,
        
        [Parameter(Mandatory = $true)]
        [string]$scriptName
    )
    try {
        # Retrieve the latest version of the script
        $latestScriptVersion = Get-LatestVersion -scriptName $scriptName
        if ($latestScriptVersion) {
            # Compare the current version with the latest version
            if (([version]$currentScriptVersion) -lt [version]$latestScriptVersion) {
                Write-Host " A new version ($latestScriptVersion) of $scriptName is available. You are currently using version $currentScriptVersion. " -BackgroundColor DarkYellow -ForegroundColor Blue
                write-Host "`n`n"
            } 
        }
        #else {
        #    Write-Warning "Failed to check for the latest version of the script."
        #}
    }
    catch [System.Exception] {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath $config.LogFilePath 
    }

}

function Show-Banner {
    Write-Host @'

   __powershell___________/\\\___/\\\________        
    ___voytas75___________\/\\\__\/\\\________       
     _____/\\\_____________\/\\\__\/\\\________      
      __/\\\\\\\\\\\________\/\\\__\/\\\________     
       _\////\\\////____/\\\\\\\\\__\/\\\\\\\\\__    
        ____\/\\\_______/\\\////\\\__\/\\\////\\\_   
         ____\/\\\_/\\__\/\\\__\/\\\__\/\\\__\/\\\_  
          ____\//\\\\\___\//\\\\\\\/\\_\/\\\\\\\\\__ 
           _____\/////_____\///////\//__\/////////___
   
           powershell [t]ext [d]ata[b]ase
           https://github.com/voytas75/tdb


'@
}

# Logging function
function Write-tdbLog {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logDir = Split-Path -Path $config.LogFilePath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force
    }
    "$timestamp [$Level] - $Message" | Out-File -FilePath $config.LogFilePath -Append -Force
}

# Error handling function
function Handle-tdbError {
    param (
        [string]$ErrorMessage
    )
    Write-tdbLog -Message $ErrorMessage -Level "ERROR"
    throw $ErrorMessage
}

function Update-ErrorHandling {
    param (
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,

        [string]$ErrorContext,

        [string]$LogFilePath
    )

    # Capture detailed error information
    $errorDetails = [ordered]@{
        Timestamp         = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ErrorMessage      = $ErrorRecord.Exception.Message
        ExceptionType     = $ErrorRecord.Exception.GetType().FullName
        ErrorContext      = $ErrorContext
        ScriptFullName    = $MyInvocation.ScriptName
        LineNumber        = $MyInvocation.ScriptLineNumber
        StackTrace        = $ErrorRecord.ScriptStackTrace
        UserName          = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        MachineName       = $env:COMPUTERNAME
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()

    } | ConvertTo-Json

    # Provide suggestions based on the error type
    $suggestions = switch -Regex ($ErrorMessage) {
        "Get-tdbRecord" {
            "Check the table name and ensure it exists. Verify the filter and logical operator parameters."
        }
        "New-tdbTable" {
            "Ensure the table name is unique and follows the naming conventions. Verify the columns provided."
        }
        "Insert-tdbRecord" {
            "Check if the table exists and the record format is correct. Ensure the ID field is not manually set."
        }
        "Update-tdbRecords" {
            "Verify the table name, filter criteria, and new values. Ensure the table exists and the filter matches records."
        }
        "Remove-tdbRecords" {
            "Ensure the table exists and the filter criteria are correct. Verify that matching records exist."
        }
        "New-tdbIndex" {
            "Check if the index name is unique and the table and column names are correct. Ensure the table exists."
        }
        "Reindex-tdbIndex" {
            "Verify the index name and ensure it exists. Check the table and column names in the index metadata."
        }
        "UnauthorizedAccessException" {
            "Check the file permissions and ensure you have the necessary access rights to the file or directory."
        }
        "IOException" {
            "Ensure the file path is correct and the file is not being used by another process."
        }
        default {
            "Refer to the error message and stack trace for more details. Consult the official documentation or seek help from the community."
        }
    }

    # Display the error details and suggestions
    #Write-Host "-- Error: $($ErrorRecord.Exception.Message)"
    Write-Host "-- Error: $($ErrorRecord.Exception.Message)"
    Write-Host "-- Context: $ErrorContext"
    Write-Host "-- Suggestions: $suggestions"

    # Log the error details if LogFilePath is provided
    if ($LogFilePath) {
        $errorDetails | Out-File -FilePath $LogFilePath -Append -Force
        if (Test-Path -Path $LogFilePath) {
            Write-Host ">> Error details have been saved to the file: $LogFilePath" -ForegroundColor Yellow
        }
        else {
            Write-Host "-- The specified log file path does not exist: $LogFilePath" -ForegroundColor Red
        }
    }        
}

# Function to create a new table
function New-tdbTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern("^[a-zA-Z0-9_]+$")]  # Only allow alphanumeric and underscore
        [string]$TableName,
        [Parameter(Mandatory)]
        [string[]]$Columns
    )
    try {
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$TableName.csv"
        
        # Check if the table already exists
        if (Test-Path -Path $tablePath) {
            Handle-tdbError -ErrorMessage "Table '$TableName' already exists."
        }

        # Combine default columns with user-defined columns, ensuring no duplicates
        $allColumns = $DefaultColumns + ($Columns | Where-Object { $DefaultColumns -notcontains $_ })
        $header = $allColumns -join ","
        
        # Ensure the directory exists
        $dbDir = Split-Path -Path $tablePath -Parent
        if (-not (Test-Path -Path $dbDir)) {
            New-Item -Path $dbDir -ItemType Directory -Force
        }
        
        $header | Out-File -FilePath $tablePath -Force
        Write-tdbLog -Message "Table '$TableName' created with columns: $allColumns"
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Error creating table '$TableName'" -LogFilePath $config.LogFilePath  
    }
}

# Function to list all tables in the current database or show info for a specific table
function Get-tdbTable {
    [CmdletBinding()]
    param (
        [string]$TableName
    )
    try {
        Write-Verbose "Retrieving database directory from configuration."
        # Get the database directory from the configuration
        $dbDir = $config.DBDirectory
        
        Write-Verbose "Checking if the database directory exists."
        # Check if the database directory exists
        if (-not (Test-Path -Path $dbDir)) {
            Handle-tdbError -ErrorMessage "Database directory '$dbDir' does not exist."
        }

        if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('TableName')) {
            Write-Verbose "Retrieving information for table '$TableName'."
            # Show info for the provided table
            $tablePath = Join-Path -Path $dbDir -ChildPath "$TableName.csv"
            if (-not (Test-Path -Path $tablePath)) {
                Write-Output "Table '$TableName' does not exist."
                #Handle-tdbError -ErrorMessage "Table '$TableName' does not exist."
                return
            }
            $tableSize = (Get-Item $tablePath).Length
            $tableInfo = [PSCustomObject]@{
                TableName   = $TableName
                CreatedOn   = (Get-Item $tablePath).CreationTime
                ModifiedOn  = (Get-Item $tablePath).LastWriteTime
                SizeInBytes = $tableSize
            }
            Write-Output "Table: $($tableInfo.TableName), Created On: $($tableInfo.CreatedOn), Last Modified On: $($tableInfo.ModifiedOn), Size: $($tableInfo.SizeInBytes) bytes"
        }
        else {
            Write-Verbose "Retrieving list of all tables in the database."
            # Get all CSV files in the database directory, which represent tables
            $tables = Get-ChildItem -Path $dbDir -Filter *.csv | ForEach-Object {
                $tablePath = $_.FullName
                $tableSize = (Get-Item $tablePath).Length
                [PSCustomObject]@{
                    TableName   = $_.BaseName
                    CreatedOn   = $_.CreationTime
                    ModifiedOn  = $_.LastWriteTime
                    SizeInBytes = $tableSize
                }
            }

            # Output the list of tables or a message if no tables are found
            if ($tables.Count -eq 0) {
                Write-Output "No tables found in the database."
            }
            else {
                Write-Output "Tables in the database:"
                $tables | ForEach-Object { 
                    Write-Output "Table: $($_.TableName), Created On: $($_.CreatedOn), Last Modified On: $($_.ModifiedOn), Size: $($_.SizeInBytes) bytes"
                }
            }
        }

        Write-Verbose "Showing context."
        # Show context of config file path
        Write-Output "Configuration file path: $configFilePath"
    }
    catch {
        # Handle any errors that occur during the process
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Error retrieving tables from database" -LogFilePath $config.LogFilePath  
    }
}



# Function to insert a new record
function Insert-tdbRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TableName,
        [Parameter(Mandatory)]
        [hashtable]$Record
    )
    try {
        Write-Verbose "Starting to insert record into table '$TableName'."
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$TableName.csv"
        if (-not (Test-Path -Path $tablePath)) {
            $errorMessage = "Table '$TableName' does not exist. Please ensure the table name is correct and the table has been created."
            Write-Output $errorMessage
            #Handle-tdbError -ErrorMessage $errorMessage
            return
        }

        Write-Verbose "Reading columns from table '$TableName'."
        $columns = (Get-Content -Path $tablePath -First 1) -split ","
        
        # Get the current max ID and increment it
        Write-Verbose "Importing data from table '$TableName'."
        $data = Import-Csv -Path $tablePath
        $maxId = if ($data) { [int]($data | Measure-Object -Property ID -Maximum).Maximum } else { 0 }
        $newId = $maxId + 1
        Write-Verbose "New ID for the record will be $newId."

        # Check if user provided ID and show info that ID is auto-incrementing
        if ($Record.ContainsKey("ID")) {
            Write-Warning "The 'ID' field is auto-incrementing and will be $newId."
        }

        # Add auto-increment ID and CreationTime to the record
        $Record["ID"] = $newId
        $Record["CreationTime"] = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")

        Write-Verbose "Preparing values for the new record."
        $values = foreach ($col in $columns) { 
            if ($Record.ContainsKey($col)) { $Record[$col] } else { $null } 
        }

        $line = ($values -join ",")
        Write-Verbose "Appending new record to table '$TableName'."
        Add-Content -Path $tablePath -Value $line
        Write-tdbLog -Message "Inserted record into '$TableName': $Record"

        # Update indexes if they exist
        $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
        $indexFiles = Get-ChildItem -Path $indexDir -Filter "*.index"

        foreach ($indexFile in $indexFiles) {
            Write-Verbose "Checking index file: $($indexFile.Name)"
            $indexData = Import-Clixml -Path $indexFile.FullName
            if ($indexData.TableName -eq $TableName) {
                Write-Verbose "Index file $($indexFile.Name) matches table $TableName. Updating index."
                
                # Check if the Records property exists and is an array
                if (-not $indexData.PSObject.Properties['Records']) {
                    $indexData | Add-Member -MemberType NoteProperty -Name 'Records' -Value @()
                }
                elseif (-not ($indexData.Records -is [System.Collections.ArrayList])) {
                    $indexData.Records = [System.Collections.ArrayList]::new($indexData.Records)
                }

                # Ensure the Records property is an ArrayList to allow adding new items
                if ($indexData.Records -is [System.Collections.ArrayList]) {
                    $indexData.Records.Add($Record)
                }
                else {
                    $tempArrayList = [System.Collections.ArrayList]::new()
                    $tempArrayList.AddRange($indexData.Records)
                    $tempArrayList.Add($Record)
                    $indexData.Records = $tempArrayList
                }

                Write-Verbose "Exporting updated index data to file $($indexFile.FullName)."
                $indexData | Export-Clixml -Path $indexFile.FullName -Force
                Write-tdbLog -Message "Index '$($indexFile.BaseName)' updated with new record."
            }
            else {
                Write-Verbose "Index file $($indexFile.Name) does not match table $TableName. Skipping."
            }
        }
        Write-Verbose "Finished inserting record into table '$TableName'."
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Error inserting record into '$TableName'" -LogFilePath $config.LogFilePath  
    }
}

# Function to read records
function Get-tdbRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]

        [string]$TableName,

        [hashtable]$Filter,

        [string]$LogicalOperator = 'AND',

        [ValidateSet("equals", "contains", "starts with", "ends with")]
        [string]$ComparisonOperator = 'equals'
    )
    try {
        Write-Verbose "Starting Get-tdbRecord for table '$TableName' with filter and logical operator '$LogicalOperator'."
        Write-Debug "Parameters: TableName=$TableName, Filter=$($Filter | Out-String), LogicalOperator=$LogicalOperator, ComparisonOperator=$ComparisonOperator"
        
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$TableName.csv"
        Write-Debug "Table path: $tablePath"
        
        if (-not (Test-Path -Path $tablePath)) {
            Handle-tdbError -ErrorMessage "Table '$TableName' does not exist."
        }

        $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
        Write-Debug "Index directory: $indexDir"
        
        $indexFiles = Get-ChildItem -Path $indexDir -Filter "*.index"
        Write-Debug "Index files found: $($indexFiles | Out-String)"
        
        $indexUsed = $false

        foreach ($indexFile in $indexFiles) {
            $indexData = Import-Clixml -Path $indexFile.FullName
            Write-Debug "Checking index file: $($indexFile.FullName)"
            Write-Debug "Checking if index file matches table and filter keys: TableName=$($indexData.TableName), FilterKeys=$($Filter.Keys)"
            Write-Debug "Index data: $($indexData | Out-String)"
            $indexData.TableName -eq $TableName -and $Filter.Keys -contains $indexData.ColumnName
            if ($indexData.TableName -eq $TableName -and $Filter.Keys -contains $indexData.ColumnName) {
                $indexPath = $indexFile.FullName
                $indexUsed = $true
                Write-Debug "Index file $($indexFile.FullName) matches table $TableName and filter keys. Using this index."
                break
            }
        }

        if (Test-Path -Path $indexPath) {
            Write-Verbose "Using index file: $indexPath"
            $indexData = Import-Clixml -Path $indexPath
            Write-Debug "Index data imported: $($indexData | Out-String)"
            
            $data = $indexData.Records | Where-Object {
                $result = $true
                $record = $_
                Write-Debug "Evaluating record: $($record | Out-String)"
                
                foreach ($key in $Filter.Keys) {
                    if (-not $record.PSObject.Properties.Match($key)) {
                        Write-Warning "The property '$key' cannot be found in index. Skipping this filter."
                        continue
                    }
                    $value = $Filter[$key]
                    Write-Debug "Filtering with key: $key, value: $value"
                    
                    $conditionMet = switch ($ComparisonOperator) {
                        "equals" { $record.$key -eq $value }
                        "contains" { $record.$key -like "*$value*" }
                        "starts with" { $record.$key -like "$value*" }
                        "ends with" { $record.$key -like "*$value" }
                        default { throw "Unsupported comparison operator: $ComparisonOperator" }
                    }
                    Write-Debug "Condition met: $conditionMet"
                    
                    if ($LogicalOperator -eq 'OR') {
                        $result = $result -or $conditionMet
                        if ($result) { break }
                    }
                    else {
                        $result = $result -and $conditionMet
                    }
                }
                Write-Debug "Result for record: $result"
                return $result
            }
            $indexUsed = $true
        }

        if (-not $indexUsed) {
            Write-Verbose "No suitable index found. Performing full table scan."
            $data = Import-Csv -Path $tablePath
            Write-Verbose "Data imported from $tablePath"
            Write-Debug "Imported data: $($data | Out-String)"

            if ($Filter) {
                $data = $data | Where-Object {
                    $result = $true
                    $record = $_
                    Write-Debug "Evaluating record: $($record | Out-String)"
                    
                    foreach ($key in $Filter.Keys) {
                        if (-not $record.PSObject.Properties.Match($key)) {
                            Write-Warning "The property '$key' cannot be found on table '$tablePath'. Skipping this filter."
                            continue
                        }
                        $value = $Filter[$key]
                        Write-Debug "Filtering with key: $key, value: $value"
                        
                        $conditionMet = switch ($ComparisonOperator) {
                            "equals" { 
                                if ($record.PSObject.Properties.Match($key)) {
                                    Write-Verbose "Comparing property '$key' '$record' with value '$value'"
                                    $record.$key -eq $value
                                }
                                else {
                                    Write-Verbose "Property '$key' not found in the data"
                                    $false
                                }
                            }
                            "contains" { $_.$key -like "*$value*" }
                            "starts with" { $_.$key -like "$value*" }
                            "ends with" { $_.$key -like "*$value" }
                            default { throw "Unsupported comparison operator: $ComparisonOperator" }
                        }
                        Write-Debug "Condition met: $conditionMet"
                        
                        if ($LogicalOperator -eq 'OR') {
                            $result = $result -or $conditionMet
                            if ($result) { break }
                        }
                        else {
                            $result = $result -and $conditionMet
                        }
                    }
                    Write-Debug "Result for record: $result"
                    return $result
                }
            }
        }
        Write-Verbose "Finished Get-tdbRecord for table '$TableName'."
        Write-Debug "Final data: $($data | Out-String)"
        return $data
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Error reading records from '$TableName' '$tablePath'" -LogFilePath $config.LogFilePath  
    }
}
# Function to update records
function Update-tdbRecords {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TableName,
        [Parameter(Mandatory)]
        [hashtable]$Filter,
        [Parameter(Mandatory)]
        [hashtable]$NewValues
    )
    try {
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$TableName.csv"
        if (-not (Test-Path -Path $tablePath)) {
            Handle-tdbError -ErrorMessage "Table '$TableName' does not exist."
        }

        $data = Import-Csv -Path $tablePath
        $updated = $false

        foreach ($row in $data) {
            $match = $true
            foreach ($key in $Filter.Keys) {
                if ($row.$key -ne $Filter[$key]) {
                    $match = $false
                    break
                }
            }

            if ($match) {
                foreach ($key in $NewValues.Keys) {
                    $row.$key = $NewValues[$key]
                }
                $updated = $true
            }
        }

        if ($updated) {
            $data | Export-Csv -Path $tablePath -NoTypeInformation
            Write-tdbLog -Message "Updated records in '$TableName' where $Filter with $NewValues"
        }
        else {
            Handle-tdbError -ErrorMessage "No matching records found to update in '$TableName'."
        }
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Error updating records in '$TableName'" -LogFilePath $config.LogFilePath  
    }
}

# Function to delete records
function Remove-tdbRecords {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TableName,
        [Parameter(Mandatory)]
        [hashtable]$Filter
    )
    try {
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$TableName.csv"
        if (-not (Test-Path -Path $tablePath)) {
            Handle-tdbError -ErrorMessage "Table '$TableName' does not exist."
        }

        $data = Import-Csv -Path $tablePath
        $originalCount = $data.Count

        $data = $data | Where-Object {
            $match = $true
            foreach ($key in $Filter.Keys) {
                if ($_.($key) -ne $Filter[$key]) {
                    $match = $false
                    break
                }
            }
            -not $match
        }

        if ($data.Count -lt $originalCount) {
            $data | Export-Csv -Path $tablePath -NoTypeInformation
            Write-tdbLog -Message "Deleted records from '$TableName' where $Filter"
        }
        else {
            Handle-tdbError -ErrorMessage "No matching records found to delete in '$TableName'."
        }
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Error deleting records from '$TableName'" -LogFilePath $config.LogFilePath  
    }
}

# Function to create an index
function New-tdbIndex {
    param (
        [string]$TableName,
        [string]$ColumnName,
        [string]$IndexName
    )

    Write-Warning "The indexing feature is experimental and may not work as expected."

    # Ensure the index directory exists
    $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
    if (-not (Test-Path -Path $indexDir)) {
        New-Item -Path $indexDir -ItemType Directory -Force
    }

    # Check if index already exists
    $indexPath = Join-Path -Path $indexDir -ChildPath "$IndexName.index"
    if (Test-Path $indexPath) {
        Handle-tdbError -ErrorMessage "Index '$IndexName' already exists."
    }

    # Create index file and write metadata
    New-Item -Path $indexPath -ItemType File -Force
    $metadata = @{
        TableName  = $TableName
        ColumnName = $ColumnName
        CreatedOn  = (Get-Date)
    }
    $metadata | Export-Clixml -Path $indexPath

    Write-tdbLog -Message "Index '$IndexName' created successfully."
}

# Function to list all indexes
function Get-tdbIndexes {

    Write-Warning "The indexing feature is experimental and may not work as expected."

    $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
    Get-ChildItem -Path $indexDir -Filter *.index | ForEach-Object {
        [PSCustomObject]@{
            IndexName = $_.BaseName
            Metadata  = Import-Clixml -Path $_.FullName
        }
    }
}

# Function to delete an index
function Remove-tdbIndex {
    param (
        [string]$IndexName
    )

    Write-Warning "The indexing feature is experimental and may not work as expected."

    $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
    $indexPath = Join-Path -Path $indexDir -ChildPath "$IndexName.index"
    
    if (Test-Path $indexPath) {
        Remove-Item -Path $indexPath -Force
        Write-tdbLog -Message "Index '$IndexName' deleted successfully."
    }
    else {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Index '$IndexName' does not exist." -LogFilePath $config.LogFilePath  
    }
}

function Reindex-tdbIndex {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IndexName
    )

    Write-Warning "The indexing feature is experimental and may not work as expected."

    try {
        Write-Verbose "Starting reindexing process for index '$IndexName'."
        Write-Debug "Parameters: IndexName=$IndexName"

        $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
        $indexPath = Join-Path -Path $indexDir -ChildPath "$IndexName.index"
        Write-Debug "Index path: $indexPath"
        
        if (-not (Test-Path $indexPath)) {
            Handle-tdbError -ErrorMessage "Index '$IndexName' does not exist."
            return
        }

        # Load existing metadata
        Write-Verbose "Loading existing metadata for index '$IndexName'."
        $metadata = Import-Clixml -Path $indexPath
        Write-Debug "Metadata loaded: $($metadata | Out-String)"

        # Validate metadata
        if (-not $metadata.TableName -or -not $metadata.ColumnName) {
            Handle-tdbError -ErrorMessage "Invalid metadata for index '$IndexName'."
            return
        }

        # Load table data
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$($metadata.TableName).csv"
        Write-Debug "Table path: $tablePath"
        if (-not (Test-Path $tablePath)) {
            Handle-tdbError -ErrorMessage "Table '$($metadata.TableName)' does not exist."
            return
        }
        Write-Verbose "Loading table data from '$tablePath'."
        $tableData = Import-Csv -Path $tablePath
        Write-Debug "Table data loaded: $($tableData | Out-String)"

        # Recreate index based on table data
        Write-Verbose "Recreating index based on table data."
        $indexData = [PSCustomObject]@{
            TableName  = $metadata.TableName
            ColumnName = $metadata.ColumnName
            CreatedOn  = (Get-Date)
            Records    = @()
        }

        foreach ($record in $tableData) {
            Write-Debug "Adding record to index: $($record | Out-String)"
            $indexData.Records += $record
        }

        # Save the new index
        Write-Verbose "Saving the new index to '$indexPath'."
        $indexData | Export-Clixml -Path $indexPath -Force

        Write-tdbLog -Message "Index '$IndexName' reindexed successfully based on table data."
        Write-Verbose "Reindexing process for index '$IndexName' completed successfully."
    }
    catch {
        $functionName = $MyInvocation.MyCommand.Name
        Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function; Error reindexing '$IndexName'" -LogFilePath $config.LogFilePath  
    }
}


# Function to validate data types
function Validate-tdbDataType {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Record,
        [Parameter(Mandatory = $true)]
        [hashtable] $Schema
    )
    foreach ($key in $Schema.Keys) {
        if ($Record.PSObject.Properties[$key]) {
            $expectedType = $Schema[$key]
            $actualType = $Record.$key.GetType().Name
            if ($actualType -ne $expectedType) {
                throw "Invalid data type for field '$key'. Expected: $expectedType, Found: $actualType"
            }
        }
    }
}

# Function to validate required fields
function Validate-tdbRequiredFields {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Record,
        [Parameter(Mandatory = $true)]
        [string[]] $RequiredFields
    )
    foreach ($field in $RequiredFields) {
        if (-not $Record.PSObject.Properties[$field] -or [string]::IsNullOrEmpty($Record.$field)) {
            throw "Required field '$field' is missing or empty."
        }
    }
}

# Function to validate unique constraints
function Validate-tdbUniqueConstraints {
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject] $Record,
        [Parameter(Mandatory = $true)]
        [string[]] $UniqueFields,
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList] $ExistingRecords
    )
    foreach ($field in $UniqueFields) {
        foreach ($existingRecord in $ExistingRecords) {
            if ($existingRecord.$field -eq $Record.$field) {
                throw "Duplicate value found for unique field '$field'. Value: $($Record.$field)"
            }
        }
    }
}

# Sample usage guide
function Show-tdbUsage {
    Write-Output "Usage Guide for Miniature Text Relational DBMS (tdb)"
    Write-Output "---------------------------------------------"
    Write-Output "1. Creating a new table: New-tdbTable -TableName 'Users' -Columns @('Name', 'Email')"
    Write-Output "2. Inserting a record: Insert-tdbRecord -TableName 'Users' -Record @{Name='John Doe'; Email='john@example.com'}"
    Write-Output "3. Reading records: Get-tdbRecord -TableName 'Users' -Filter @{Name='John Doe'} -LogicalOperator equals"
    Write-Output "4. Getting table information: Get-tdbTable -TableName 'Users'"
    Write-Output "5. Updating records: Update-tdbRecords -TableName 'Users' -Filter @{ID=1} -NewValues @{Email='john.doe@example.com'}"
    Write-Output "6. Deleting records: Remove-tdbRecords -TableName 'Users' -Filter @{ID=1}"
    Write-Output "7. Troubleshooting Tips: Check the log file at `$config.LogFilePath for detailed error messages if any operation fails."
}
#endregion Functions


#region Entry Point
# Display the banner
Show-Banner
    
# Inform the user how to display the usage guide
Write-Output "To display the usage guide at any time, run the cmdlet: Show-tdbUsage"
    
try {
    # Configuration Section
    if ($PSCmdlet.MyInvocation.BoundParameters.ContainsKey('configFilePath') -and (Test-Path -Path $configFilePath -PathType Leaf)) {
        Write-Verbose "User provided configuration file path: $configFilePath. Loading configuration."
        # Load the configuration from the provided file
        $configFilePath = (Resolve-Path -Path $configFilePath).Path
        $config = Get-Content -Path $configFilePath | ConvertFrom-Json
        Write-Host "Configuration loaded successfully from user-provided path: $configFilePath"
    }
    else {
        # Determine the path to the default configuration file
        $Invocation = (Get-Variable MyInvocation).Value
        Write-Verbose "Determining the parent path of the current script."
        $parentPath = Split-Path -Parent $Invocation.MyCommand.Path
        Write-Verbose "Parent path determined: $parentPath"
        Write-Verbose "Joining the parent path with the default configuration file name."
        $ConfigFilePath = Join-Path -Path $parentPath -ChildPath ".tdb_default.config"
        Write-Host "Default configuration loaded successfully from path: $ConfigFilePath"
        
        if (-not (Test-Path -Path $ConfigFilePath -PathType Leaf)) {
            Write-Verbose "Default configuration file not found. Creating default configuration."
            # If the default config file does not exist, create a default configuration
            $config = @{
                LogFilePath    = "$env:USERPROFILE\Documents\$scriptname\Logs\tdb.Log"  # Path to the log file
                DBDirectory    = "$env:USERPROFILE\Documents\$scriptname\DB"            # Path to the database directory
                IndexDirectory = "$env:USERPROFILE\Documents\$scriptname\DB\Indexes"    # Path to the index directory
            }
            # Create default config file with default settings
            $config | ConvertTo-Json | Set-Content -Path $defaultConfigFilePath
            Write-Verbose "Default configuration file created at: $defaultConfigFilePath"
        }
        else {
            Write-Verbose "Default configuration file found. Loading configuration."
            # If the default config file exists, load the configuration from the file
            $config = Get-Content -Path $defaultConfigFilePath | ConvertFrom-Json
            Write-Verbose "Configuration loaded successfully from default path."
        }
    }
    # Check for script updates
    Get-CheckForScriptUpdate -currentScriptVersion $tdbVersion -scriptName $scriptname

}
catch [System.Exception] {
    # Handle any exceptions that occur during the configuration process
    $functionName = $MyInvocation.MyCommand.Name
    Update-ErrorHandling -ErrorRecord $_ -ErrorContext "$functionName function" -LogFilePath $config.LogFilePath  
}
#endregion Entry Point
