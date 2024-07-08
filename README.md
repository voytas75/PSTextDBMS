# Miniature Powershell Text Relational Database Management System (tdb)

![tdb](https://raw.githubusercontent.com/voytas75/tdb/master/images/tdb128x128.png "tdb")

[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/tdb)](https://www.powershellgallery.com/packages/tdb)

## Table of Contents

- [Miniature Powershell Text Relational Database Management System (tdb)](#miniature-powershell-text-relational-database-management-system-tdb)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Installation](#installation)
  - [Configuration](#configuration)
    - [Custom Configuration](#custom-configuration)
  - [Usage Guide](#usage-guide)
    - [Creating a New Table](#creating-a-new-table)
    - [Inserting a Record](#inserting-a-record)
    - [Reading Records](#reading-records)
    - [Updating Records](#updating-records)
    - [Deleting Records](#deleting-records)
    - [Listing Tables](#listing-tables)
  - [Support Us on Ko-fi](#support-us-on-ko-fi)

## Introduction

The Miniature PowerShell Text Relational Database Management System (tdb) is a lightweight, file-based relational database management system developed using PowerShell. It provides CRUD operations for data storage, retrieval, update, and deletion operations without the need for complex database software.

## Installation

1. **Install the Script:**
   Install the PowerShell script file from PowerShell Gallery.

   ```powershell
   Install-Script -Name tdb
   ```

2. **Run the Script:**

   ```powershell
   tdb.ps1
   ```

   or

   ```powershell
   tdb
   ```

3. **Show usage guide**

   ```powershell
   show-tdbUsage
   ```

   When you run the script for the first time, it will automatically create a configuration file named `.tdb_default.config` with default settings. **This file will be located in the same directory where the script is**. The default settings include paths for the database directory and the log file. You can modify these settings as needed.

   Example of default settings in `.tdb_default.config`:

   ```json
   {
    "DBDirectory":  "C:\\Users\\voytas75\\Documents\\tdb\\DB",
    "LogFilePath":  "C:\\Users\\voytas75\\Documents\\tdb\\Logs\\tdb.Log",
   }
   ```

## Configuration

The script uses a configuration file for settings. These settings can be modified in the `.tdb_default.config` file.

- **Database Path:**

  ```json
  "DBDirectory": ".\\Database"
  ```

- **Log File Path:**
  
  ```json
  "LogFilePath": ".\\Database\\log.txt"
  ```

Ensure that the paths are correctly set according to your environment.

### Custom Configuration

You can also create your own configuration file and start the program with the `-configFilePath` parameter to specify the path to your custom configuration file.

1. **Create a Custom Configuration File:**

   Create a JSON file with your desired settings. For example, create a file named `my_custom_config.json` with the following content:

   ```json
   {
    "DBDirectory":  "D:\\MyCustomDB\\DB",
    "LogFilePath":  "D:\\MyCustomDB\\Logs\\tdb.Log"
   }
   ```

2. **Run the Script with Custom Configuration:**

   Use the `-configFilePath` parameter to specify the path to your custom configuration file when running the script.

   ```powershell
   tdb.ps1 -configFilePath "D:\\MyCustomDB\\my_custom_config.json"
   ```

   or

   ```powershell
   tdb -configFilePath "D:\\MyCustomDB\\my_custom_config.json"
   ```

This allows you to have multiple configurations and switch between them as needed.

## Usage Guide

### Creating a New Table

To create a new table, use the `New-tdbTable` function. This function requires the table name and the columns you want to include in the table. The table name should only contain alphanumeric characters and underscores.

```powershell
New-tdbTable -TableName 'Users' -Columns @('Name', 'Email')
```

### Inserting a Record

To insert a new record into a table, use the `Insert-tdbRecord` function. This function requires the table name and a hashtable representing the record.

```powershell
Insert-tdbRecord -TableName 'Users' -Record @{Name='John Doe'; Email='john@example.com'}
```

### Reading Records

To read records from a table, use the `Get-tdbRecord` function. This function requires the table name and a hashtable representing the filter criteria.

```powershell
get-tdbRecord -TableName "groups1" -ComparisonOperator contains
```

### Updating Records

To update existing records in a table, use the `Update-tdbRecords` function. This function requires the table name, a hashtable representing the filter criteria, and a hashtable representing the new values.

```powershell
Update-tdbRecord -TableName 'Users' -Filter @{ID=1} -NewValues @{Email='john.doe@example.com'}
```

### Deleting Records

To delete records from a table, use the `Remove-tdbRecords` function. This function requires the table name and a hashtable representing the filter criteria.

```powershell
Remove-tdbRecord -TableName 'Users' -Filter @{ID=1}
```

### Listing Tables

To list all tables in the current database or show info for a specific table, use the `Get-tdbTable` function.

```powershell
Get-tdbTable
```

## Support Us on Ko-fi

If you find the Miniature Powershell Text Relational Database Management System (tdb) useful, consider supporting us on [Ko-fi](https://ko-fi.com/A0A6KYBUS). Your support helps us maintain and improve the project. Thank you!

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6KYBUS)

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">🚀 A lightweight, file-based <a href="https://twitter.com/hashtag/RelationalDatabase?src=hash&amp;ref_src=twsrc%5Etfw">#RelationalDatabase</a> using <a href="https://twitter.com/hashtag/PowerShell?src=hash&amp;ref_src=twsrc%5Etfw">#PowerShell</a>. CRUD operations. No complex software! 💾 <a href="https://t.co/43YFxn8hvw">https://t.co/43YFxn8hvw</a><br><br>𝙸𝚗𝚜𝚝𝚊𝚕𝚕-𝚂𝚌𝚛𝚒𝚙𝚝 -𝙽𝚊𝚖𝚎 𝚝𝚍𝚋<a href="https://twitter.com/hashtag/PowerShell?src=hash&amp;ref_src=twsrc%5Etfw">#PowerShell</a> <a href="https://twitter.com/hashtag/Database?src=hash&amp;ref_src=twsrc%5Etfw">#Database</a> <a href="https://twitter.com/hashtag/TextDB?src=hash&amp;ref_src=twsrc%5Etfw">#TextDB</a> <a href="https://twitter.com/hashtag/tdb?src=hash&amp;ref_src=twsrc%5Etfw">#tdb</a></p>&mdash; Script Savvy Ninja (@CodeSavvySensei) <a href="https://twitter.com/CodeSavvySensei/status/1810273903949820167?ref_src=twsrc%5Etfw">July 8, 2024</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>