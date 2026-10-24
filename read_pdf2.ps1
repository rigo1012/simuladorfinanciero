# Try to read PDF using iTextSharp if available, or just try to extract raw text
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Try using a simple approach - check if it's a text-based PDF
$bytes = [System.IO.File]::ReadAllBytes('C:\Users\rodri\OneDrive\PROYECTO\SISTEMA DE RIEGO.pdf')
$text = [System.Text.Encoding]::UTF8.GetString($bytes)
# Look for readable text chunks
$text -split '[\x00-\x1F\x7F-\xFF]' | Where-Object { $_.Length -gt 20 } | Select-Object -First 50