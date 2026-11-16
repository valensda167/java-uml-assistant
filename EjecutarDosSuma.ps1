$ErrorActionPreference = 'Stop'
$ejemplo = Join-Path $PSScriptRoot 'ejemplos/dos-suma'
$build = New-Item -ItemType Directory -Force (Join-Path $ejemplo 'build')
$fuentes = @('Solution.java','VerificarDosSuma.java') | ForEach-Object { Join-Path $ejemplo $_ }
& javac -proc:none -encoding UTF-8 -d $build.FullName @fuentes
if ($LASTEXITCODE -ne 0) { throw 'La demo no compila.' }
& java -cp $build.FullName VerificarDosSuma
if ($LASTEXITCODE -ne 0) { throw 'Una prueba devolvio indices incorrectos.' }
Get-Content -LiteralPath (Join-Path $ejemplo 'UML.md')
