$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open('C:\Users\rodri\OneDrive\PROYECTO\SIMULADOR FINANCIERO.docx')

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

Write-Output "TOTAL TABLES: ${tcount}"

$doc.Close()
$word.Quit()