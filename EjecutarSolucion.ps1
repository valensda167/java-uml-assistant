param([Parameter(Mandatory)][string]$Carpeta)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Procesos.ps1')
$Carpeta=(Get-Item -LiteralPath $Carpeta).FullName
$fuentes=@(Get-ChildItem $Carpeta -Filter '*.java' -File | ForEach-Object FullName)
$build=Join-Path $Carpeta 'build'
$null=New-Item -ItemType Directory -Path $build -Force
$r=Invoke-Herramienta javac (@('-proc:none','-encoding','UTF-8','-d',$build)+$fuentes)
if ($r.Codigo -ne 0) {throw $r.Texto}
$tests=@(Get-ChildItem $Carpeta -Filter 'Test*.java' -File)
if (!$tests.Count) {throw 'No hay Test*.java para ejecutar.'}
foreach ($test in $tests) {
 $contenido=Get-Content $test.FullName -Raw -Encoding UTF8
 $paquete=[regex]::Match($contenido,'(?m)^\s*package\s+([\w.]+)\s*;')
 $clase=if ($paquete.Success) {$paquete.Groups[1].Value+'.'+$test.BaseName} else {$test.BaseName}
 Write-Host "Ejecutando $clase (limite: 15 segundos, sin entrada interactiva)..."
 $r=Invoke-Herramienta java @('-Dfile.encoding=UTF-8','-Xmx256m','-cp',$build,$clase) 15
 $r.Texto
 if ($r.Codigo -ne 0) {throw "El programa $clase termino con error."}
}
