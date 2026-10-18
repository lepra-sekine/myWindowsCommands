# ------------------------------------------------
# DUSK_N_THGILIWT
#     DuskNThgiliwt -filePath 'TwilightFile.txt'
#     DuskNThgiliwt -filePath 'TwilightFile.txt' -forOdd
#     DuskNThgiliwt -filePath 'TwilightFile.txt' -Force
# ------------------------------------------------
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$filePath,
    [switch]$forOdd,
    [switch]$Force,
    [switch]$Help
)

if ($Help -or [string]::IsNullOrWhiteSpace($filePath)) {
    Write-Host "使用方法: DuskNThgiliwt -filePath <変換元ファイル> [-forOdd]"
    exit
}

# 奇数行を逆順に変換するモードかどうかを判定する
$shouldReverseOddLines = $forOdd.IsPresent

try {
    # 変換元ファイルを確認し、ファイルではなくディレクトリなら停止する
    $sourceFile = Get-Item -LiteralPath $filePath -ErrorAction Stop
    if ($sourceFile.PSIsContainer) {
        throw "ファイルではなくフォルダが指定されました: $($sourceFile.FullName)"
    }

    # 変換先ファイル名は元ファイル名を文字要素ごとに逆順にしたものにする
    # これにより補助文字のサロゲートペアが分離されず、絵文字を含むファイル名でも保持される
    $sourceTextElements = @()
    $textElementEnumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($sourceFile.Name)
    while ($textElementEnumerator.MoveNext()) {
        $sourceTextElements += $textElementEnumerator.GetTextElement()
    }

    [Array]::Reverse($sourceTextElements)
    $outputFileName = -join $sourceTextElements

    # カレントディレクトリに出力する
    $outputPath = Join-Path -Path (Get-Location) -ChildPath $outputFileName
    # 変換元 = 出力先の場合はエラーとする。（例：abc.cba -> abc.cba）
    # このチェックは -Force 時でも実行し、FileMode.Create による切り詰めを防ぐ
    $outputPathFull = [System.IO.Path]::GetFullPath($outputPath)
    $sourceFull = [System.IO.Path]::GetFullPath($sourceFile.FullName)
    if ($outputPathFull -ieq $sourceFull) {
        throw "出力先が変換元と同じファイルです: $outputPath"
    }
    if ((Test-Path -LiteralPath $outputPathFull -PathType Leaf) -and (Get-Item -LiteralPath $outputPathFull).LinkType -ne $null) {
        if ((Get-Item -LiteralPath $sourceFull).LinkType -ne $null) {
            $outputIdentity = (Get-Item -LiteralPath $outputPathFull).Target
            $sourceIdentity = (Get-Item -LiteralPath $sourceFull).Target
            if ($outputIdentity -and $sourceIdentity -and ($outputIdentity -ieq $sourceIdentity)) {
                throw "出力先が変換元と同じファイルです: $outputPath"
            }
        }
    }
    # 出力先ファイルの上書きを許可しない。
    if (!$Force -and (Test-Path -LiteralPath $outputPath)) {
        throw "出力先ファイルがすでに存在します: $outputPath"
    }

    # 変換元の改行スタイルを保存し、変換後のファイルも同じ改行コードを使う
    $sourceText = [System.IO.File]::ReadAllText($sourceFile.FullName)
    $outputNewLine = if ($sourceText.Contains("`r`n")) {
        "`r`n"
    } elseif ($sourceText.Contains("`n")) {
        "`n"
    } else {
        [System.Environment]::NewLine
    }

    # ファイル全体を行単位で読み込み、加工後の内容を保持する
    $lines = @(Get-Content -LiteralPath $sourceFile.FullName -Encoding UTF8 -ErrorAction Stop)
    $resultLines = @()

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = [string]$lines[$index]

        # 偶数行か奇数行かを判定し、対象行だけ逆順変換を行う
        $shouldReverse = if ($shouldReverseOddLines) {
            ($index % 2) -eq 0
        } else {
            ($index % 2) -eq 1
        }

        # 対象外の行はそのまま保持する
        if (-not $shouldReverse) {
            $resultLines += $line
            continue
        }

        # 文字を UTF-16 コード単位ではなく、Unicode の文字要素ごとに逆順に並べ替える
        # これにより補助文字のサロゲートペアが分離されずに保持される
        $reversedChars = @()
        $textElementEnumerator = [System.Globalization.StringInfo]::GetTextElementEnumerator($line)
        while ($textElementEnumerator.MoveNext()) {
            $reversedChars += $textElementEnumerator.GetTextElement()
        }

        [Array]::Reverse($reversedChars)
        $reversedLine = -join $reversedChars

        # 先頭の句点があれば削除し、あとで文末に戻す
        $leadingPunctuation = $null
        $hadLeadingPunctuation = $false
        if ($reversedLine.StartsWith('.')) {
            $leadingPunctuation = '.'
            $hadLeadingPunctuation = $true
        } elseif ($reversedLine.StartsWith('。')) {
            $leadingPunctuation = '。'
            $hadLeadingPunctuation = $true
        }

        if ($hadLeadingPunctuation) {
            $reversedLine = $reversedLine.Substring(1)
        }

        # 先頭文字を大文字にし、最後の英字を小文字にする
        if ($reversedLine.Length -gt 0) {
            $reversedLine = [char]::ToUpperInvariant($reversedLine[0]) + $reversedLine.Substring(1)
            $lastAlphaIndex = -1

            for ($charIndex = $reversedLine.Length - 1; $charIndex -ge 0; $charIndex--) {
                if ($reversedLine[$charIndex] -match '[A-Za-z]') {
                    $lastAlphaIndex = $charIndex
                    break
                }
            }

            if ($lastAlphaIndex -ge 0) {
                $reversedLine = $reversedLine.Substring(0, $lastAlphaIndex) + [char]::ToLowerInvariant($reversedLine[$lastAlphaIndex]) + $reversedLine.Substring($lastAlphaIndex + 1)
            }
        }

        # 先頭に句点があった場合は、文末に戻す
        if ($hadLeadingPunctuation) {
            $reversedLine += $leadingPunctuation
        }

        $resultLines += $reversedLine
    }

    # 変換結果を出力先ファイルに保存する
    # 事前の Test-Path だけでは競合に弱いので、保存時に FileMode で排他作成を行う
    # -Force が指定されていない場合は新規作成のみ許可し、既存ファイルの上書きは失敗させる
    $fileMode = if ($Force) { [System.IO.FileMode]::Create } else { [System.IO.FileMode]::CreateNew }

    $outputStream = [System.IO.File]::Open($outputPath, $fileMode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    try {
        $writer = New-Object System.IO.StreamWriter($outputStream, [System.Text.UTF8Encoding]::new($false))
        $writer.NewLine = $outputNewLine
        try {
            foreach ($line in $resultLines) {
                $writer.WriteLine($line)
            }
        } finally {
            $writer.Dispose()
        }
    } finally {
        $outputStream.Dispose()
    }

    Write-Host "$outputFileName <- $($sourceFile.Name) : 了完換変"
}
catch {
    # 例外が起きた場合は、原因を表示して終了する
    Write-Error "DuskNThgiliwt の実行中にエラーが発生しました: $($_.Exception.Message)"
    exit 1
}

