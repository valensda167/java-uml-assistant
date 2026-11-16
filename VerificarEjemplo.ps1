$ErrorActionPreference = 'Stop'
$ejemplo = Join-Path $PSScriptRoot 'ejemplos/empleado'
$archivos = @('Empleado.java','TestEmpleado.java') | ForEach-Object { Join-Path $ejemplo $_ }
$temporal = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ('java-uml-' + [guid]::NewGuid()))
try {
    & javac -encoding UTF-8 -d $temporal.FullName @archivos
    if ($LASTEXITCODE -ne 0) { throw 'El ejemplo no compila.' }
    $salida = & java -cp $temporal.FullName TestEmpleado
    if ($LASTEXITCODE -ne 0 -or ($salida -join "`n") -cne ("Carlos - S/ 1700.0
Ana - S/ 1500.0")) {
        throw "Salida inesperada: $salida"
    }
    $uml = & java (Join-Path $PSScriptRoot 'JavaUml.java') @archivos
    if ($LASTEXITCODE -ne 0 -or $uml -notcontains 'classDiagram') { throw 'No se pudo generar Mermaid.' }
    $uml | Set-Content -LiteralPath (Join-Path $ejemplo 'UML.md') -Encoding UTF8
    Write-Host "Prueba correcta: $salida. UML.md actualizado."
} finally {
    Get-ChildItem -LiteralPath $temporal.FullName -Filter '*.class' -File | Remove-Item
    Remove-Item -LiteralPath $temporal.FullName
}

