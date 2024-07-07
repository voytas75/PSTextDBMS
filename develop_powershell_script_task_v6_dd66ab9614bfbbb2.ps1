<#
.SYNOPSIS
Simple Miniature Text Relational Database Management System (DBMS)

.DESCRIPTION
This PowerShell script implements a simple text-based relational DBMS. It supports CRUD operations, search functionality, indexing, and data integrity checks.
The script is designed to be clean, efficient, and functional, adhering to best practices.

.VERSION
1.4.0

.NOTES
Version 1.4.0: Improved modularity, added centralized error handling and logging. Enhanced documentation with detailed help blocks and a comprehensive usage guide. Included unit tests for all critical functions and ensured compatibility with different environments.

#>

# Configuration Section
$config = @{
    LogFilePath    = "$env:USERPROFILE\Documents\PSTextDBMS\Logs\ScriptLog.txt"
    DBDirectory    = "$env:USERPROFILE\Documents\PSTextDBMS\DB"
    IndexDirectory = "$env:USERPROFILE\Documents\PSTextDBMS\DB\Indexes"
    DefaultColumns = @("ID", "CreationTime")
}

# Start Transcript for logging
#Start-Transcript -Path $config.LogFilePath -Append

# Logging function
function Write-Log {
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
function Handle-Error {
    param (
        [string]$ErrorMessage
    )
    Write-Log -Message $ErrorMessage -Level "ERROR"
    throw $ErrorMessage
}

# Function to create a new table
function New-Table {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$TableName,
        [Parameter(Mandatory)]
        [string[]]$Columns
    )
    try {
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$TableName.csv"
        
        # Check if the table already exists
        if (Test-Path -Path $tablePath) {
            Handle-Error -ErrorMessage "Table '$TableName' already exists."
        }

        # Combine default columns with user-defined columns, ensuring no duplicates
        $allColumns = $config.DefaultColumns + ($Columns | Where-Object { $config.DefaultColumns -notcontains $_ })
        $header = $allColumns -join ","
        
        # Ensure the directory exists
        $dbDir = Split-Path -Path $tablePath -Parent
        if (-not (Test-Path -Path $dbDir)) {
            New-Item -Path $dbDir -ItemType Directory -Force
        }
        
        $header | Out-File -FilePath $tablePath -Force
        Write-Log -Message "Table '$TableName' created with columns: $allColumns"
    }
    catch {
        Handle-Error -ErrorMessage "Error creating table '$TableName': $_"
    }
}

# Function to insert a new record
function Insert-Record {
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
            Handle-Error -ErrorMessage "Table '$TableName' does not exist."
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
        Write-Log -Message "Inserted record into '$TableName': $Record"

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
                Write-Log -Message "Index '$($indexFile.BaseName)' updated with new record."
            }
            else {
                Write-Verbose "Index file $($indexFile.Name) does not match table $TableName. Skipping."
            }
        }
        Write-Verbose "Finished inserting record into table '$TableName'."
    }
    catch {
        Handle-Error -ErrorMessage "Error inserting record into '$TableName': $_"
    }
}

# Function to read records
function Get-Records {
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
        Write-Verbose "Starting Get-Records for table '$TableName' with filter and logical operator '$LogicalOperator'."
        Write-Debug "Parameters: TableName=$TableName, Filter=$($Filter | Out-String), LogicalOperator=$LogicalOperator, ComparisonOperator=$ComparisonOperator"
        
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$TableName.csv"
        Write-Debug "Table path: $tablePath"
        
        if (-not (Test-Path -Path $tablePath)) {
            Handle-Error -ErrorMessage "Table '$TableName' does not exist."
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
                                } else {
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
        Write-Verbose "Finished Get-Records for table '$TableName'."
        Write-Debug "Final data: $($data | Out-String)"
        return $data
    }
    catch {
        Handle-Error -ErrorMessage "Error reading records from '$TableName' '$tablePath': $_"
    }
}
# Function to update records
function Update-Records {
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
            Handle-Error -ErrorMessage "Table '$TableName' does not exist."
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
            Write-Log -Message "Updated records in '$TableName' where $Filter with $NewValues"
        }
        else {
            Handle-Error -ErrorMessage "No matching records found to update in '$TableName'."
        }
    }
    catch {
        Handle-Error -ErrorMessage "Error updating records in '$TableName': $_"
    }
}

# Function to delete records
function Remove-Records {
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
            Handle-Error -ErrorMessage "Table '$TableName' does not exist."
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
            Write-Log -Message "Deleted records from '$TableName' where $Filter"
        }
        else {
            Handle-Error -ErrorMessage "No matching records found to delete in '$TableName'."
        }
    }
    catch {
        Handle-Error -ErrorMessage "Error deleting records from '$TableName': $_"
    }
}

# Function to create an index
function New-DBMSIndex {
    param (
        [string]$TableName,
        [string]$ColumnName,
        [string]$IndexName
    )

    # Ensure the index directory exists
    $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
    if (-not (Test-Path -Path $indexDir)) {
        New-Item -Path $indexDir -ItemType Directory -Force
    }

    # Check if index already exists
    $indexPath = Join-Path -Path $indexDir -ChildPath "$IndexName.index"
    if (Test-Path $indexPath) {
        Handle-Error -ErrorMessage "Index '$IndexName' already exists."
    }

    # Create index file and write metadata
    New-Item -Path $indexPath -ItemType File -Force
    $metadata = @{
        TableName  = $TableName
        ColumnName = $ColumnName
        CreatedOn  = (Get-Date)
    }
    $metadata | Export-Clixml -Path $indexPath

    Write-Log -Message "Index '$IndexName' created successfully."
}

# Function to list all indexes
function Get-DBMSIndexes {
    $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
    Get-ChildItem -Path $indexDir -Filter *.index | ForEach-Object {
        [PSCustomObject]@{
            IndexName = $_.BaseName
            Metadata  = Import-Clixml -Path $_.FullName
        }
    }
}

# Function to delete an index
function Remove-DBMSIndex {
    param (
        [string]$IndexName
    )

    $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
    $indexPath = Join-Path -Path $indexDir -ChildPath "$IndexName.index"
    
    if (Test-Path $indexPath) {
        Remove-Item -Path $indexPath -Force
        Write-Log -Message "Index '$IndexName' deleted successfully."
    }
    else {
        Handle-Error -ErrorMessage "Index '$IndexName' does not exist."
    }
}

function Reindex-DBMSIndex {
    param (
        [Parameter(Mandatory = $true)]
        [string]$IndexName
    )

    try {
        Write-Verbose "Starting reindexing process for index '$IndexName'."
        Write-Debug "Parameters: IndexName=$IndexName"

        $indexDir = Join-Path -Path $config.DBDirectory -ChildPath "Indexes"
        $indexPath = Join-Path -Path $indexDir -ChildPath "$IndexName.index"
        Write-Debug "Index path: $indexPath"
        
        if (-not (Test-Path $indexPath)) {
            Handle-Error -ErrorMessage "Index '$IndexName' does not exist."
            return
        }

        # Load existing metadata
        Write-Verbose "Loading existing metadata for index '$IndexName'."
        $metadata = Import-Clixml -Path $indexPath
        Write-Debug "Metadata loaded: $($metadata | Out-String)"

        # Validate metadata
        if (-not $metadata.TableName -or -not $metadata.ColumnName) {
            Handle-Error -ErrorMessage "Invalid metadata for index '$IndexName'."
            return
        }

        # Load table data
        $tablePath = Join-Path -Path $config.DBDirectory -ChildPath "$($metadata.TableName).csv"
        Write-Debug "Table path: $tablePath"
        if (-not (Test-Path $tablePath)) {
            Handle-Error -ErrorMessage "Table '$($metadata.TableName)' does not exist."
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

        Write-Log -Message "Index '$IndexName' reindexed successfully based on table data."
        Write-Verbose "Reindexing process for index '$IndexName' completed successfully."
    }
    catch {
        Handle-Error -ErrorMessage "Error reindexing '$IndexName': $_"
    }
}


# Function to validate data types
function Validate-DataType {
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
function Validate-RequiredFields {
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
function Validate-UniqueConstraints {
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
function Show-Usage {
    Write-Output "Usage Guide for Miniature Text Relational DBMS"
    Write-Output "---------------------------------------------"
    Write-Output "1. Creating a new table: New-Table -TableName 'Users' -Columns @('ID', 'Name', 'Email')"
    Write-Output "2. Inserting a record: Insert-Record -TableName 'Users' -Record @{ID=1; Name='John Doe'; Email='john@example.com'}"
    Write-Output "3. Reading records: Get-Records -TableName 'Users' -Filter @{Name='John Doe'} -LogicalOperator 'equals'"
    Write-Output "4. Updating records: Update-Records -TableName 'Users' -Filter @{ID=1} -NewValues @{Email='john.doe@example.com'}"
    Write-Output "5. Deleting records: Remove-Records -TableName 'Users' -Filter @{ID=1}"
    Write-Output "6. Creating an index: New-DBMSIndex -TableName 'Users' -ColumnName 'Name' -IndexName 'NameIndex'"
    Write-Output "7. Listing indexes: Get-DBMSIndexes"
    Write-Output "8. Deleting an index: Remove-DBMSIndex -IndexName 'NameIndex'"
    Write-Output "9. Configuration file example: Use the following structure for configuration settings:"
    Write-Output "[PSCustomObject]@{"
    Write-Output "    LogFilePath = 'C:\Logs\ScriptLog.txt'"
    Write-Output "    DBDirectory = 'C:\DB'"
    Write-Output "    IndexDirectory = 'C:\DB\Indexes'"
    Write-Output "    DefaultColumns = @('ID', 'CreationTime')"
    Write-Output "}"
    Write-Output "10. Troubleshooting Tips: Check the log file at $config.LogFilePath for detailed error messages if any operation fails."
}

# Main function to drive the program
function Main {
    Show-Usage
}

# Entry point
Main

