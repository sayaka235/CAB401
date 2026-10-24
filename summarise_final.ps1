$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$culture = [System.Globalization.CultureInfo]::InvariantCulture

function Read-Seconds {
    param([string]$Text, [string]$Label)

    $pattern = '(?m)^' + [regex]::Escape($Label) +
               ':\s*([0-9]+(?:\.[0-9]+)?)\s+seconds\s*$'

    $match = [regex]::Match($Text, $pattern)

    if (-not $match.Success) {
        throw "Missing timing: $Label"
    }

    return [double]::Parse($match.Groups[1].Value, $culture)
}

function Median {
    param([double[]]$Values)

    $sorted = @($Values | Sort-Object)
    return $sorted[[int][math]::Floor($sorted.Count / 2)]
}

$configurations = @("serial", "1", "2", "3", "4", "5", "6", "7", "8")

$raw = @(
    foreach ($config in $configurations) {
        foreach ($trial in 1..5) {
            $path = "results\final_${config}_${trial}.txt"
            $text = Get-Content -Raw $path

            [pscustomobject]@{
                Configuration = $config
                Trial = $trial
                PreparationSeconds = Read-Seconds $text "vector preparation"
                ComparisonSeconds = Read-Seconds $text "pair comparisons"
                TotalSeconds = Read-Seconds $text "time elapsed"
            }
        }
    }
)

$raw | Export-Csv "results\final_raw.csv" -NoTypeInformation

$baseline = Median @(
    $raw |
        Where-Object Configuration -eq "serial" |
        ForEach-Object TotalSeconds
)

$summary = @(
    foreach ($config in $configurations) {
        $runs = @($raw | Where-Object Configuration -eq $config)

        $prep = Median @($runs.PreparationSeconds)
        $comparison = Median @($runs.ComparisonSeconds)
        $total = Median @($runs.TotalSeconds)
        $speedup = $baseline / $total

        $efficiency = if ($config -eq "serial") {
            $null
        } else {
            [math]::Round(100 * $speedup / [int]$config, 2)
        }

        [pscustomobject]@{
            Configuration = $config
            MedianPreparationSeconds = [math]::Round($prep, 6)
            MedianComparisonSeconds = [math]::Round($comparison, 6)
            MedianTotalSeconds = [math]::Round($total, 6)
            MinimumTotalSeconds = ($runs.TotalSeconds |
                Measure-Object -Minimum).Minimum
            MaximumTotalSeconds = ($runs.TotalSeconds |
                Measure-Object -Maximum).Maximum
            Speedup = [math]::Round($speedup, 4)
            EfficiencyPercent = $efficiency
        }
    }
)

$summary | Export-Csv "results\final_summary.csv" -NoTypeInformation
$summary | Format-Table -AutoSize