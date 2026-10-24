$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$culture = [System.Globalization.CultureInfo]::InvariantCulture

function Read-TotalSeconds {
    param([string]$Text)

    $pattern = '(?m)^time elapsed:\s*([0-9]+(?:\.[0-9]+)?)\s+seconds\s*$'
    $match = [regex]::Match($Text, $pattern)

    if (-not $match.Success) {
        throw "Missing total elapsed time."
    }

    return [double]::Parse($match.Groups[1].Value, $culture)
}

function Read-PhaseSeconds {
    param(
        [string]$Text,
        [string]$Label
    )

    $pattern = '(?m)^' + [regex]::Escape($Label) +
               ':\s*([0-9]+(?:\.[0-9]+)?)\s+seconds\s*$'

    $match = [regex]::Match($Text, $pattern)

    if (-not $match.Success) {
        return $null
    }

    return [double]::Parse($match.Groups[1].Value, $culture)
}

function Median {
    param([double[]]$Values)

    $sorted = @($Values | Sort-Object)
    return $sorted[[int][math]::Floor($sorted.Count / 2)]
}

$configurations = @(
    "before",
    "serial",
    "1", "2", "3", "4",
    "5", "6", "7", "8"
)

$raw = @(
    foreach ($config in $configurations) {
        foreach ($trial in 1..5) {

            $path = "results\final_${config}_${trial}.txt"
            $text = Get-Content -Raw $path

            [pscustomobject]@{
                Configuration = $config
                Trial = $trial
                PreparationSeconds = Read-PhaseSeconds $text "vector preparation"
                ComparisonSeconds = Read-PhaseSeconds $text "pair comparisons"
                TotalSeconds = Read-TotalSeconds $text
            }
        }
    }
)

$raw | Export-Csv "results\final_raw.csv" -NoTypeInformation

$beforeMedian = Median @(
    $raw |
        Where-Object Configuration -eq "before" |
        ForEach-Object TotalSeconds
)

$serialMedian = Median @(
    $raw |
        Where-Object Configuration -eq "serial" |
        ForEach-Object TotalSeconds
)

if ($serialMedian -le $beforeMedian) {
    $baseline = $serialMedian
    $baselineConfiguration = "serial"
}
else {
    $baseline = $beforeMedian
    $baselineConfiguration = "before"
}

$summary = @(
    foreach ($config in $configurations) {

        $runs = @(
            $raw |
                Where-Object Configuration -eq $config
        )

        $total = Median @($runs.TotalSeconds)

        if ($config -eq "before") {
            $prep = $null
            $comparison = $null
        }
        else {
            $prep = Median @($runs.PreparationSeconds)
            $comparison = Median @($runs.ComparisonSeconds)
        }

        if ($config -match '^\d+$') {
            $threadCount = [int]$config
            $speedup = $baseline / $total
            $efficiency = 100 * $speedup / $threadCount
        }
        else {
            $speedup = $null
            $efficiency = $null
        }

        [pscustomobject]@{
            Configuration = $config
            MedianPreparationSeconds =
                if ($null -eq $prep) {
                    $null
                }
                else {
                    [math]::Round($prep, 6)
                }

            MedianComparisonSeconds =
                if ($null -eq $comparison) {
                    $null
                }
                else {
                    [math]::Round($comparison, 6)
                }

            MedianTotalSeconds =
                [math]::Round($total, 6)

            MinimumTotalSeconds =
                ($runs.TotalSeconds | Measure-Object -Minimum).Minimum

            MaximumTotalSeconds =
                ($runs.TotalSeconds | Measure-Object -Maximum).Maximum

            Speedup =
                if ($null -eq $speedup) {
                    $null
                }
                else {
                    [math]::Round($speedup, 4)
                }

            EfficiencyPercent =
                if ($null -eq $efficiency) {
                    $null
                }
                else {
                    [math]::Round($efficiency, 2)
                }
        }
    }
)

$summary | Export-Csv "results\final_summary.csv" -NoTypeInformation

Write-Host ""
Write-Host "Best sequential baseline:"
Write-Host "$baselineConfiguration = $([math]::Round($baseline, 6)) seconds"
Write-Host ""

$summary | Format-Table -AutoSize