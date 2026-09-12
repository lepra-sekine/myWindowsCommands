# ------------------------------------------------
# カレントディレクトリ内のファイルに対して、一括リネームを行うスクリプト。
# 使用例：
#     BulkRename -searchPattern '^original_([0-9]{14})\.dat$' -replacePattern 'newname_$1.txt'
# ------------------------------------------------
# [CmdletBinding(SupportsShouldProcess=$true)]
Param(
    [Parameter(Mandatory=$false, Position=0)][string]$searchPattern,
    [Parameter(Mandatory=$false, Position=1)][string]$replacePattern,
    [switch]$Recurse,
    [switch]$Help,
    [switch]$WhatIf
)

if ($Help -or -not $searchPattern) {
    Write-Host "使用方法: BulkRename.ps1 -searchPattern <検索パターン> -replacePattern <置換パターン> [-Recurse] [-WhatIf]"
    Exit
}

# Get-ChildItem パラメータ設定
$gciParams = @{ File = $true }
if ($Recurse) { $gciParams['Recurse'] = $true }

$neverExec = $true

# ディレクトリ内のファイルを取得
Get-ChildItem @gciParams |
    Where-Object { $_.Name -match $searchPattern } |
    ForEach-Object {
        try {
            # 例外時用の置換前フルパス
            $oldPath = $_.FullName

            # 置換後のファイル名を作成
            $newName = $_.Name -replace $searchPattern, $replacePattern
            $newPath = Join-Path -Path $_.DirectoryName -ChildPath $newName

            # 置換後のファイル名のファイルが存在する場合は、スキップする
            if (Test-Path -LiteralPath $newPath) {
                Write-Warning "'$newPath'は既に存在するため、置換をスキップします。"
                return
            }

            if ($WhatIf) {
                # チェックのみ。
                Write-Output "$($oldPath) ---> $($newPath)"
                $neverExec = $false
            } else {
                # ファイル名を書き換える。
                Rename-Item -LiteralPath $oldPath -NewName $newPath -ErrorAction Stop
                Write-Output "置換成功 $($oldPath) ---> $($newPath)"
                $neverExec = $false
            }
        } catch {
            # 例外時は、そこで中断する。
            Write-Error "一括ファイル名置換中に例外が発生した為、処理を中断します。`n対象ファイル:$($oldPath) -> $($newPath)`n$($_.Exception.Message)"
            exit
        }
    }


# 何もしなかった場合。
if ($neverExec) {
    Write-Output "置換対象がありません。"
}