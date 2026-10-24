$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open('C:\Users\rodri\OneDrive\PROYECTO\SIMULADOR FINANCIERO.docx')
$text = $doc.Content.Text
$doc.Close()
$word.Quit()
Write-Output $text