$ErrorActionPreference = 'Stop'
$ejemplo = Join-Path $PSScriptRoot 'ejemplos/empleado'
$archivos = @('Empleado.java','TestEmpleado.java') | ForEach-Object { Join-Path $ejemplo $_ }
$temporal = New-Item -ItemType Directory -Path (Join-Path ([IO.Path]::GetTempPath()) ('java-uml-' + [guid]::NewGuid()))
try {
    & javac -encoding UTF-8 -d $temporal.FullName @archivos
    if ($LASTEXITCODE -ne 0) { throw 'El ejemplo no compila.' }
    $salida = & java -cp $temporal.FullName TestEmpleado
    if ($LASTEXITCODE -ne 0 -or ($salida -join "`n") -cne (@('Carlos - S/ 1700.0', 'Ana - S/ 1500.0') -join "`n")) {
        throw "Salida inesperada: $salida"
    }
    $uml = & java (Join-Path $PSScriptRoot 'JavaUml.java') @archivos
    if ($LASTEXITCODE -ne 0 -or $uml -notcontains 'classDiagram') { throw 'No se pudo generar Mermaid.' }
    $uml | Set-Content -LiteralPath (Join-Path $ejemplo 'UML.md') -Encoding UTF8
    foreach ($caso in 'alumno', 'curso') {
        $carpeta = Join-Path $PSScriptRoot "ejemplos/$caso"
        $fuentes = @(Get-ChildItem -LiteralPath $carpeta -Filter '*.java' -File | ForEach-Object FullName)
        & javac -encoding UTF-8 -d $temporal.FullName @fuentes
        if ($LASTEXITCODE -ne 0) { throw "El ejemplo $caso no compila." }
        $diagrama = & java (Join-Path $PSScriptRoot 'JavaUml.java') @fuentes
        if ($LASTEXITCODE -ne 0 -or $diagrama -notcontains 'classDiagram') {
            throw "No se pudo generar Mermaid para $caso."
        }
        if ($caso -eq 'curso' -and $diagrama -notcontains '    Persona <|-- Instructor') {
            throw 'Falta la herencia de Instructor.'
        }
        Write-Host "$caso compilado y UML verificado."
    }
    Write-Host "Prueba correcta: $salida. UML.md actualizado."
} finally {
    $ruta = [IO.Path]::GetFullPath($temporal.FullName)
    $raiz = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ([IO.Path]::GetDirectoryName($ruta) -eq $raiz.TrimEnd([IO.Path]::DirectorySeparatorChar) -and
        [IO.Path]::GetFileName($ruta) -match '^java-uml-[0-9a-f-]{36}$') {
        [IO.Directory]::Delete($ruta, $true)
    }
}
