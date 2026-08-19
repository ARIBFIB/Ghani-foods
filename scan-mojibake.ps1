# ============================================================
# MOJIBAKE SCANNER - SAFE ASCII VERSION
# ============================================================

$ErrorActionPreference = "Continue"

$ProjectRoot = (Get-Location).Path
$ReportFile = Join-Path $ProjectRoot "mojibake-scan-report.txt"

# ------------------------------------------------------------
# Source/text file extensions
# ------------------------------------------------------------

$TextExtensions = @(
    ".ts",
    ".tsx",
    ".js",
    ".jsx",
    ".mjs",
    ".cjs",
    ".json",
    ".css",
    ".scss",
    ".sass",
    ".less",
    ".html",
    ".htm",
    ".md",
    ".mdx",
    ".txt",
    ".xml",
    ".yml",
    ".yaml",
    ".toml",
    ".env",
    ".prisma",
    ".sql",
    ".graphql",
    ".gql",
    ".svg",
    ".vue",
    ".svelte",
    ".astro",
    ".php",
    ".py",
    ".java",
    ".cs",
    ".cpp",
    ".c",
    ".h",
    ".hpp",
    ".dart",
    ".kt",
    ".swift",
    ".rs",
    ".go"
)

# ------------------------------------------------------------
# Directories to skip
# ------------------------------------------------------------

$ExcludedDirectories = @(
    "node_modules",
    ".next",
    ".git",
    ".vercel",
    "dist",
    "build",
    "out",
    "coverage",
    ".turbo",
    ".cache",
    "vendor",
    "target",
    "__pycache__"
)

# ------------------------------------------------------------
# Mojibake detection patterns
#
# IMPORTANT:
# These are constructed using Unicode code points.
# No corrupted characters are directly stored in this script.
# ------------------------------------------------------------

$U0080 = [char]0x0080
$U00FF = [char]0x00FF
$UFFFF = [char]0xFFFF

$HighByteRange = "[\u0080-\u00FF\u2000-\uFFFF]"

$MojibakePatterns = @(
    [PSCustomObject]@{
        Name    = "Replacement Character"
        Pattern = [string][char]0xFFFD
    },

    [PSCustomObject]@{
        Name    = "UTF-8 replacement sequence"
        Pattern = ([char]0x00EF).ToString() +
                  ([char]0x00BF).ToString() +
                  ([char]0x00BD).ToString()
    },

    [PSCustomObject]@{
        Name    = "Latin mojibake - A with tilde"
        Pattern = ([char]0x00C3).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "Latin mojibake - A with circumflex"
        Pattern = ([char]0x00C2).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "Latin mojibake - E with grave"
        Pattern = ([char]0x00C8).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "Latin mojibake - I with grave"
        Pattern = ([char]0x00CC).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "Latin mojibake - O with grave"
        Pattern = ([char]0x00D2).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "Latin mojibake - U with grave"
        Pattern = ([char]0x00D9).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "Latin mojibake - Y with acute"
        Pattern = ([char]0x00DD).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "UTF-8 punctuation mojibake"
        Pattern = ([char]0x00E2).ToString() + $HighByteRange + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "UTF-8 emoji mojibake"
        Pattern = ([char]0x00F0).ToString() + $HighByteRange + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "UTF-8 mojibake - I diaeresis"
        Pattern = ([char]0x00EF).ToString() + $HighByteRange + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "UTF-8 mojibake - AE"
        Pattern = ([char]0x00E6).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "UTF-8 mojibake - C cedilla"
        Pattern = ([char]0x00E7).ToString() + $HighByteRange
    },

    [PSCustomObject]@{
        Name    = "UTF-8 mojibake - A ring"
        Pattern = ([char]0x00E5).ToString() + $HighByteRange
    }
)

# ------------------------------------------------------------
# Exact common mojibake sequences
# Constructed safely from Unicode code points.
# ------------------------------------------------------------

$ExactPatterns = @(
    [PSCustomObject]@{
        Name = "UTF-8 apostrophe sequence"
        Text = (
            ([char]0x00E2).ToString() +
            ([char]0x20AC).ToString() +
            ([char]0x0099).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "UTF-8 opening quote sequence"
        Text = (
            ([char]0x00E2).ToString() +
            ([char]0x20AC).ToString() +
            ([char]0x009C).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "UTF-8 closing quote sequence"
        Text = (
            ([char]0x00E2).ToString() +
            ([char]0x20AC).ToString() +
            ([char]0x009D).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "UTF-8 en dash sequence"
        Text = (
            ([char]0x00E2).ToString() +
            ([char]0x20AC).ToString() +
            ([char]0x0093).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "UTF-8 em dash sequence"
        Text = (
            ([char]0x00E2).ToString() +
            ([char]0x20AC).ToString() +
            ([char]0x0094).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "UTF-8 ellipsis sequence"
        Text = (
            ([char]0x00E2).ToString() +
            ([char]0x20AC).ToString() +
            ([char]0x00A6).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "Copyright mojibake"
        Text = (
            ([char]0x00C2).ToString() +
            ([char]0x00A9).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "Registered trademark mojibake"
        Text = (
            ([char]0x00C2).ToString() +
            ([char]0x00AE).ToString()
        )
    },

    [PSCustomObject]@{
        Name = "Degree mojibake"
        Text = (
            ([char]0x00C2).ToString() +
            ([char]0x00B0).ToString()
        )
    }
)

# ------------------------------------------------------------
# Helper: excluded path
# ------------------------------------------------------------

function Test-IsExcludedPath {
    param(
        [string]$Path
    )

    foreach ($Dir in $ExcludedDirectories) {

        $Pattern = "(^|[\\/])" +
                   [regex]::Escape($Dir) +
                   "([\\/]|$)"

        if ($Path -match $Pattern) {
            return $true
        }
    }

    return $false
}

# ------------------------------------------------------------
# Helper: text file
# ------------------------------------------------------------

function Test-IsTextFile {
    param(
        [System.IO.FileInfo]$File
    )

    if ($File.Name -in @(
        ".env",
        ".env.local",
        ".env.development",
        ".env.production",
        ".gitignore",
        ".npmrc",
        ".prettierrc",
        ".editorconfig"
    )) {
        return $true
    }

    return ($TextExtensions -contains $File.Extension.ToLowerInvariant())
}

# ------------------------------------------------------------
# Report
# ------------------------------------------------------------

$Report = New-Object System.Collections.Generic.List[string]

$Report.Add("============================================================")
$Report.Add("MOJIBAKE SCAN REPORT")
$Report.Add("============================================================")
$Report.Add("")
$Report.Add("Project Root:")
$Report.Add($ProjectRoot)
$Report.Add("")
$Report.Add("Scan Date:")
$Report.Add((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
$Report.Add("")
$Report.Add("Excluded directories:")
$Report.Add(($ExcludedDirectories -join ", "))
$Report.Add("")
$Report.Add("============================================================")
$Report.Add("")

$FilesScanned = 0
$FilesWithMojibake = 0
$TotalOccurrences = 0

$Results = New-Object System.Collections.Generic.List[object]

# ------------------------------------------------------------
# Get all files
# ------------------------------------------------------------

$AllFiles = Get-ChildItem `
    -Path $ProjectRoot `
    -Recurse `
    -File `
    -Force `
    -ErrorAction SilentlyContinue

foreach ($File in $AllFiles) {

    if ($File.FullName -eq $ReportFile) {
        continue
    }

    if (Test-IsExcludedPath $File.FullName) {
        continue
    }

    if (-not (Test-IsTextFile $File)) {
        continue
    }

    $FilesScanned++

    try {

        $Content = [System.IO.File]::ReadAllText(
            $File.FullName,
            [System.Text.UTF8Encoding]::new($false, $false)
        )

    }
    catch {

        Write-Host "Could not read: $($File.FullName)" -ForegroundColor Yellow
        continue
    }

    if ([string]::IsNullOrEmpty($Content)) {
        continue
    }

    $Lines = $Content -split "`r?`n"

    $FileMatches = New-Object System.Collections.Generic.List[object]

    for ($LineIndex = 0; $LineIndex -lt $Lines.Count; $LineIndex++) {

        $Line = $Lines[$LineIndex]

        if ([string]::IsNullOrEmpty($Line)) {
            continue
        }

        $FoundPatterns = New-Object System.Collections.Generic.List[string]
        $FoundText = New-Object System.Collections.Generic.List[string]

        # ----------------------------------------------------
        # Exact patterns
        # ----------------------------------------------------

        foreach ($Item in $ExactPatterns) {

            $ExactText = $Item.Text

            if ($Line.Contains($ExactText)) {

                if (-not $FoundPatterns.Contains($Item.Name)) {
                    $FoundPatterns.Add($Item.Name)
                }

                $StartIndex = 0

                while ($true) {

                    $Index = $Line.IndexOf(
                        $ExactText,
                        $StartIndex,
                        [System.StringComparison]::Ordinal
                    )

                    if ($Index -lt 0) {
                        break
                    }

                    $FoundText.Add($ExactText)

                    $StartIndex = $Index + $ExactText.Length
                }
            }
        }

        # ----------------------------------------------------
        # Regex patterns
        # ----------------------------------------------------

        foreach ($Item in $MojibakePatterns) {

            try {

                $Matches = [regex]::Matches(
                    $Line,
                    $Item.Pattern
                )

                if ($Matches.Count -gt 0) {

                    if (-not $FoundPatterns.Contains($Item.Name)) {
                        $FoundPatterns.Add($Item.Name)
                    }

                    foreach ($Match in $Matches) {

                        if (-not [string]::IsNullOrWhiteSpace($Match.Value)) {
                            $FoundText.Add($Match.Value)
                        }
                    }
                }

            }
            catch {
                continue
            }
        }

        # ----------------------------------------------------
        # Store result
        # ----------------------------------------------------

        if ($FoundPatterns.Count -gt 0) {

            $UniqueFoundText = @(
                $FoundText | Sort-Object -Unique
            )

            $UniquePatterns = @(
                $FoundPatterns | Sort-Object -Unique
            )

            $RelativePath = $File.FullName.Substring(
                $ProjectRoot.Length
            ).TrimStart("\", "/")

            $Results.Add(
                [PSCustomObject]@{
                    FilePath     = $File.FullName
                    RelativePath = $RelativePath
                    LineNumber   = $LineIndex + 1
                    Mojibake     = ($UniqueFoundText -join " | ")
                    Pattern      = ($UniquePatterns -join " | ")
                    CodeLine     = $Line.Trim()
                }
            )
        }
    }

    if ($FileMatches.Count -gt 0) {
        $FilesWithMojibake++
    }
}

# Recalculate based on actual results
$FilesWithMojibake = @(
    $Results |
    Select-Object -ExpandProperty RelativePath -Unique
).Count

$TotalOccurrences = $Results.Count

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

$Report.Add("SCAN SUMMARY")
$Report.Add("------------------------------------------------------------")
$Report.Add("Files scanned              : $FilesScanned")
$Report.Add("Files containing mojibake : $FilesWithMojibake")
$Report.Add("Affected lines             : $TotalOccurrences")
$Report.Add("")

# ------------------------------------------------------------
# Findings
# ------------------------------------------------------------

if ($Results.Count -eq 0) {

    $Report.Add("============================================================")
    $Report.Add("RESULT: NO MOJIBAKE DETECTED")
    $Report.Add("============================================================")
    $Report.Add("")
    $Report.Add(
        "No known mojibake patterns were found in the scanned files."
    )
    $Report.Add("")

}
else {

    $Report.Add("============================================================")
    $Report.Add("DETAILED FINDINGS")
    $Report.Add("============================================================")
    $Report.Add("")

    $Groups = $Results |
        Group-Object RelativePath |
        Sort-Object Name

    foreach ($Group in $Groups) {

        $Report.Add("")
        $Report.Add("############################################################")
        $Report.Add("FILE: $($Group.Name)")
        $Report.Add("############################################################")
        $Report.Add("")

        foreach ($Result in (
            $Group.Group | Sort-Object LineNumber
        )) {

            $Report.Add("------------------------------------------------------------")
            $Report.Add("FULL PATH:")
            $Report.Add($Result.FilePath)
            $Report.Add("")
            $Report.Add("LINE NUMBER:")
            $Report.Add([string]$Result.LineNumber)
            $Report.Add("")
            $Report.Add("DETECTED MOJIBAKE:")
            $Report.Add($Result.Mojibake)
            $Report.Add("")
            $Report.Add("DETECTION PATTERN:")
            $Report.Add($Result.Pattern)
            $Report.Add("")
            $Report.Add("CODE:")
            $Report.Add($Result.CodeLine)
            $Report.Add("")
        }
    }

    # --------------------------------------------------------
    # File summary
    # --------------------------------------------------------

    $Report.Add("")
    $Report.Add("============================================================")
    $Report.Add("FILE SUMMARY")
    $Report.Add("============================================================")
    $Report.Add("")

    foreach ($Group in $Groups) {

        $Report.Add(
            ("{0} --> {1} affected line(s)" -f
                $Group.Name,
                $Group.Count)
        )
    }
}

# ------------------------------------------------------------
# Write report
# ------------------------------------------------------------

[System.IO.File]::WriteAllLines(
    $ReportFile,
    $Report,
    [System.Text.UTF8Encoding]::new($false)
)

# ------------------------------------------------------------
# Console result
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "MOJIBAKE SCAN COMPLETE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Files scanned              : $FilesScanned"
Write-Host "Files containing mojibake : $FilesWithMojibake"
Write-Host "Affected lines             : $TotalOccurrences"
Write-Host ""

Write-Host "Report:" -ForegroundColor Green
Write-Host $ReportFile -ForegroundColor Green
Write-Host ""

if ($Results.Count -eq 0) {

    Write-Host "NO MOJIBAKE DETECTED." -ForegroundColor Green

}
else {

    Write-Host "MOJIBAKE FOUND." -ForegroundColor Yellow
    Write-Host "Open mojibake-scan-report.txt for details." -ForegroundColor Yellow
}

Write-Host ""