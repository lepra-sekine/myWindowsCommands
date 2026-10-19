# テストの作業ディレクトリを、このスクリプトのある場所に固定する
Set-Location $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot "..\DuskNThgiliwt.ps1"

$failedTests = @()

# ----------------------------------------
# Compare-Files
# 差分比較関数
# ----------------------------------------
function Compare-Files {
    param(
        [Parameter(Mandatory = $true)]
        [int]$testNo,

        [Parameter(Mandatory = $true)]
        [string]$actualFile,

        [Parameter(Mandatory = $true)]
        [string]$expectedFile
    )

    # 出力ファイルと期待結果ファイルが同一であれば、問題なし。
    $actual = (Get-Content -Raw -Encoding UTF8 $actualFile)
    $expected = (Get-Content -Raw -Encoding UTF8 $expectedFile)
    if ($actual -ceq $expected) {
        Write-Host "OK"
        return
    }

    # 出力ファイルと期待結果ファイルの行ごとの差分をチェックする。
    $actualLines = @(Get-Content -Encoding UTF8 $actualFile)
    $expectedLines = @(Get-Content -Encoding UTF8 $expectedFile)
    $before = $script:failedTests.Count

    for ($i = 0; $i -lt [Math]::Max($actualLines.Count, $expectedLines.Count); $i++) {
        $actualValue = if ($i -lt $actualLines.Count) { $actualLines[$i] } else { "<missing>" }
        $expectedValue = if ($i -lt $expectedLines.Count) { $expectedLines[$i] } else { "<missing>" }

        if ($actualValue -cne $expectedValue) {
            $script:failedTests += "#$testNo. 差分 at line $($i + 1). actual: $actualValue expected: $expectedValue"
        }
    }

    if ($script:failedTests.Count -eq $before) {
        $script:failedTests += "#$testNo. 改行コードまたは末尾改行が期待結果と異なります"
    }
}

# ----------------------------------------
# 各テストの実行
# ----------------------------------------

# 出力ファイルが残っていたら削除してから、期待どおりの変換結果を生成する
Remove-Item -Force "txt.nigiro" -ErrorAction SilentlyContinue

# 1. 通常モードのテスト
Write-Host "------"
Write-Host "#1. 通常モードのテスト"
& $scriptPath -filePath "origin.txt"

# 出力されたファイルを期待結果と比較
Compare-Files -testNo 1 -actualFile "txt.nigiro" -expectedFile "expected.txt"

# 出力ファイルを削除
Remove-Item -Force "txt.nigiro" -ErrorAction SilentlyContinue

# 2. 奇数行モードのテスト
Write-Host "------"
Write-Host "#2. 奇数モードのテスト"
& $scriptPath -filePath "origin.txt" -forOdd

# 出力されたファイルを期待結果と比較
Compare-Files -testNo 2 -actualFile "txt.nigiro" -expectedFile "expected2.txt"

# 出力ファイルを削除
Remove-Item -Force "txt.nigiro" -ErrorAction SilentlyContinue

# 3. 日本語のファイルのテスト
Write-Host "------"
Write-Host "#3. 日本語のファイルのテスト"
& $scriptPath -filePath "日本語😎.txt"

# 出力されたファイルを期待結果と比較
Compare-Files -testNo 3 -actualFile "txt.😎語本日" -expectedFile "expected3.txt"

# 出力ファイルを削除
Remove-Item -Force "txt.😎語本日" -ErrorAction SilentlyContinue

# 4. 異常系のテスト
Write-Host "------"
Write-Host "#4. 異常系のテスト"
# 元の意図どおり、出力先が変換元と同一のケースで、
# エラーメッセージに 「出力先が変換元と同じファイルです」 が含まれることを確認する
# エラーになればOK
$abnormalFile = "error.rorre"
$abnormalOutput = & $scriptPath -filePath $abnormalFile 2>&1
if ($abnormalOutput -match "出力先が変換元と同じファイルです") {
    Write-Host "OK"
} else {
    $abnormalOutput | Format-List *
    $failedTests += "#4. 変換元と出力先が同一のケースでエラーが出ていません"
}

if ($failedTests.Count -gt 0) {
    throw "FAIL: $($failedTests -join [Environment]::NewLine)"
}

Write-Host "ALL_TESTS_PASSED"
