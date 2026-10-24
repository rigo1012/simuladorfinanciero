$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open('C:\Users\rodri\OneDrive\PROYECTO\SIMULADOR FINANCIERO.docx')
$paras = $doc.Paragraphs
foreach ($p in $paras) {
    Write-Output $p.Range.Text
}
$doc.Close()
$word.Quit()