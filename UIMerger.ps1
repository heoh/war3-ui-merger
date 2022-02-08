param (
    [string] $InputDir,
    [string] $OutputDir,
    [string] $Encoding='UTF8'
)

$NEWLINE = "`r`n"
$LINE_TYPE_EMPTY = 1
$LINE_TYPE_CATEGORY = 2
$LINE_TYPE_TEXT = 3
$LINE_TYPE_COMMENT= 4

function Get-LineType(
    [string] $line
) {
    if ($line -eq '') {
        return $LINE_TYPE_EMPTY
    }
    if ($line.StartsWith('[') -and $line.Contains(']')) {
        return $LINE_TYPE_CATEGORY
    }
    if ($line.StartsWith('//')) {
        return $LINE_TYPE_COMMENT
    }
    return $LINE_TYPE_TEXT
}

function Read-UIFile(
    [string] $filePath
) {
    $text = Get-Content -Path $filePath -Encoding $Encoding

    $table = [ordered]@{}
    $table[''] = [ordered]@{}
    $currentCategory = ''
    $currentSubTable = $table[$currentCategory]
    $prevName = $null

    foreach ($line in $text) {
        $lineType = Get-LineType $line
        if ($lineType -eq $LINE_TYPE_CATEGORY) {
            if (-not $($line -match '\[.*\]')) {
                Write-Warning -Message "Unknown line: $line"
                continue
            }

            $currentCategory = $Matches[0]
            if (-not $table.Contains($currentCategory)) {
                $table[$currentCategory] = [ordered]@{}
            }
            $currentSubTable = $table[$currentCategory]
            $prevName = $null
        }
        elseif ($lineType -eq $LINE_TYPE_TEXT) {
            if (-not $($line -match "(.+?)=(.*)")) {
                Write-Warning -Message "Unknown line: $line"
                continue
            }

            $lhs = $Matches[1]
            if (-not $lhs.StartsWith('_')) {
                $name = $lhs
                if ($name -eq "${prevName}Hint") {
                    $currentSubTable[$prevName] += $NEWLINE + $line
                    continue
                }

                if (-not $currentSubTable.Contains($name)) {
                    $currentSubTable[$name] = $line
                }
                else {
                    $currentSubTable[$name] += $NEWLINE + $line
                }
                $prevName = $name
            }
            elseif ($lhs -match "_(.+)_.+?") {
                $name = $Matches[1]
                if (-not $currentSubTable.Contains($name)) {
                    Write-Warning -Message "Unknown name '$name': $line"
                    continue
                }

                $currentSubTable[$name] += $NEWLINE + $line
                $prevName = $name
            }
            else {
                Write-Warning -Message "Unknown line: $line"
                continue
            }
        }
    }

    return $table
}

function Merge-UITable(
    [System.Collections.Specialized.OrderedDictionary] $mainTable,
    [System.Collections.Specialized.OrderedDictionary] $otherTable
) {
    foreach ($category in $otherTable.Keys) {
        if (-not $mainTable.Contains($category)) {
            $mainTable[$category] = [ordered]@{}
        }
        $mainSubTable = $mainTable[$category]
        $otherSubTable = $otherTable[$category]
        foreach ($name in $otherSubTable.Keys) {
            $mainSubTable[$name] = $otherSubTable[$name]
        }
    }
}

function Write-UITable(
    [string] $filePath,
    [System.Collections.Specialized.OrderedDictionary] $table
) {
    $text = ""

    foreach ($category in $table.Keys) {
        $subTable = $table[$category]
        if (($category -eq '') -and ($subTable.Count -eq 0)) {
            continue
        }

        $text += $category + $NEWLINE

        foreach ($name in $subTable.Keys) {
            $text += $subTable[$name] + $NEWLINE
        }
        
        $text += $NEWLINE
    }

    $text | Out-File -FilePath $filePath -Encoding $Encoding
}

function Merge-UIFile(
    [string] $mainFilePath,
    [string] $otherFilePath
) {
    $mainTable = Read-UIFile $mainFilePath
    $otherTable = Read-UIFile $otherFilePath

    Merge-UITable ([ref] $mainTable) $otherTable
    Write-UITable $mainFilePath $mainTable
}


$outputTables = @{}

$inputs = Get-ChildItem -Directory -Path $InputDir | Sort-Object

foreach ($input in $inputs) {
    $files = Get-ChildItem -File -Filter *.txt -Path $input.FullName
    if ($files.Length -gt 0) {
        Write-Host "Processing: $($input.Name)"
    }

    foreach ($file in $files) {
        $inputFilePath = $file.FullName
        $outputFilePath = "${OutputDir}\$($file.Name)"

        $inputTable = Read-UIFile $inputFilePath

        if ($outputTables.Contains($file.Name)) {
            $outputTable = $outputTables[$file.Name]
            Merge-UITable ([ref] $outputTable) $inputTable
        }
        else {
            $outputTables[$file.Name] = $inputTable
        }
    }
}

foreach ($fileName in $outputTables.Keys) {
    Write-Host "Writing: $fileName"
    $outputTable = $outputTables[$fileName]
    $outputFilePath = "${OutputDir}\${fileName}"
    
    Write-UITable $outputFilePath $outputTable
}
