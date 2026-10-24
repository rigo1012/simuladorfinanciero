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

Write-Output "TOTAL PARAGRAPHS: ${count}"

$doc.Close()
$word.Quit()