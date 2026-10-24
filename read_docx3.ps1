$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open('C:\Users\rodri\OneDrive\PROYECTO\SIMULADOR FINANCIERO.docx')

# Get all paragraphs
$paras = $doc.Paragraphs
$count = 0
foreach ($p in $paras) {
    $count++
    $txt = $p.Range.Text.Trim()
    if ($txt -ne "") {
        Write-Output "PARA ${count}: ${txt}"
    }
}

# Get all tables
$tables = $doc.Tables
$tcount = 0
foreach ($table in $tables) {
    $tcount++
    Write-Output "=== TABLE ${tcount} ==="
    $rowCount = 0
    foreach ($row in $table.Rows) {
        $rowCount++
        $cells = @()
        foreach ($cell in $row.Cells) {
            $cells += $cell.Range.Text.Trim()
        }
        Write-Output "Row ${rowCount}: $($cells -join ' | ')"
    }
}

$doc.Close()
$word.Quit()