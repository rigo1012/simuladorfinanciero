Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead('C:\Users\rodri\OneDrive\PROYECTO\SISTEMA DE RIEGO.pdf')
$zip.Entries | ForEach-Object { Write-Output $_.FullName }
$zip.Dispose()