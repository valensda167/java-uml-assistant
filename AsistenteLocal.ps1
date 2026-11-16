[CmdletBinding(DefaultParameterSetName='Archivo')]
param(
    [ValidateSet('resolver','revisar','practicar')][string]$Modo = 'resolver',
    [Parameter(Mandatory,ParameterSetName='Archivo')][string]$Enunciado,
    [Parameter(Mandatory,ParameterSetName='Directo')][string]$Texto,
    [string[]]$Codigo = @(),
    [string]$Modelo = 'qwen2.5-coder:0.5b',
    [string]$Salida = (Join-Path $PSScriptRoot 'soluciones')
)
$ErrorActionPreference = 'Stop'
$problema = if ($PSCmdlet.ParameterSetName -eq 'Directo') { $Texto } else { Get-Content -LiteralPath $Enunciado -Raw -Encoding UTF8 }
$palabras = @([regex]::Matches($problema.ToLowerInvariant(), '[\p{L}]{4,}') |
    ForEach-Object Value | Sort-Object -Unique)
$referencia = Get-ChildItem (Join-Path $PSScriptRoot 'ejemplos/netbeans') -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
        $archivos = @(Get-ChildItem $_.FullName -Recurse -Filter '*.java')
        $nombres = $archivos.BaseName -join ' '
        $puntos = @($palabras | Where-Object { $nombres -match [regex]::Escape($_) }).Count
        [pscustomobject]@{ Proyecto = $_.Name; Puntos = $puntos; Archivos = $archivos }
    } | Sort-Object -Property @{Expression='Puntos';Descending=$true}, Proyecto | Select-Object -First 1

if ($Modo -eq 'revisar' -and !$Codigo.Count) { throw 'Indica los archivos con -Codigo.' }
$accion = switch ($Modo) {
    resolver { 'Entrega cada archivo Java completo dentro de su propio bloque Markdown con etiqueta java. Incluye una clase publica por archivo.' }
    revisar { 'Indica requisitos cumplidos y faltantes. Cita clases y metodos.' }
    practicar { 'Da una pista breve y haz una pregunta. Reserva la solucion.' }
}
$consulta = "$accion Estilo: Java 17, POO sencilla, nombres en espanol, atributos privados cuando corresponda, modelo separado de Test con main, calculo separado de mostrarDatos(). El enunciado tiene prioridad sobre el estilo y los ejemplos. Si solicita solo una clase, omite main, comentarios y metodos adicionales.`nEjercicio:`n$problema"
foreach ($archivo in $Codigo) {
    $consulta += "`nArchivo: $archivo`n" + (Get-Content -LiteralPath $archivo -Raw -Encoding UTF8)
}
if ($referencia.Puntos -gt 0 -and $Modo -ne 'practicar') {
    Write-Host "Referencia de NetBeans: $($referencia.Proyecto)"
    $archivos = $referencia.Archivos | ForEach-Object {
        "Archivo: $($_.Name)"
        Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    }
    $consulta += "`nReferencia adicional de NetBeans:`n" + ($archivos -join "`n")
}
$limite = if ($Modo -eq 'practicar') { 120 } else { 900 }
$cuerpo = @{
    model = $Modelo
    stream = $false
    options = @{ num_ctx = 8192; num_predict = $limite }
    messages = @(@{ role='system'; content=$accion }, @{ role='user'; content=$consulta })
} | ConvertTo-Json -Depth 6
try {
    $respuesta = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/chat' -Method Post -TimeoutSec 120 `
        -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($cuerpo))
} catch {
    throw "Fallo Ollama local: $($_.Exception.Message)"
}
if ([string]::IsNullOrWhiteSpace($respuesta.message.content)) { throw 'Ollama devolvio una respuesta vacia.' }
if ($respuesta.done_reason -eq 'length') { Write-Warning 'La respuesta alcanzo el limite de longitud.' }
if ($Modo -ne 'resolver') {
    $respuesta.message.content
    return
}

$destino = Join-Path $Salida ([guid]::NewGuid().ToString('N').Substring(0,12))
$null = New-Item -ItemType Directory -Path $destino -Force
$respuesta.message.content | Set-Content -LiteralPath (Join-Path $destino 'Respuesta.md') -Encoding UTF8
$problema | Set-Content -LiteralPath (Join-Path $destino 'Enunciado.txt') -Encoding UTF8
if ($respuesta.done_reason -eq 'length') { throw "Respuesta incompleta. Revisa $destino o prueba con otro modelo." }

$bloques = [regex]::Matches($respuesta.message.content, '(?ims)^[ \t]*```java[ \t]*\r?\n(?<java>.*?)^[ \t]*```[ \t]*\r?$')
if (!$bloques.Count) { throw "No se encontraron bloques Java completos. Revisa $destino." }
$archivos = @(foreach ($bloque in $bloques) {
    $java = $bloque.Groups['java'].Value
    $tipo = [regex]::Match($java, '(?m)^\s*public\s+(?:(?:abstract|final|sealed|non-sealed)\s+)*(?:class|interface|record|enum)\s+([\p{L}_$][\p{L}\p{N}_$]*)')
    if (!$tipo.Success) { throw "Falta un tipo publico en un bloque Java. Revisa $destino." }
    $archivo = Join-Path $destino ($tipo.Groups[1].Value + '.java')
    if (Test-Path -LiteralPath $archivo) { throw "Nombre Java duplicado: $archivo" }
    $ruta = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($archivo)
    [IO.File]::WriteAllText($ruta, $java, [Text.UTF8Encoding]::new($false))
    $ruta
})
$build = New-Item -ItemType Directory -Path (Join-Path $destino 'build')
& javac -proc:none -encoding UTF-8 -d $build.FullName @archivos
if ($LASTEXITCODE -ne 0) { throw "El Java generado no compila. Los archivos quedaron en $destino." }
$uml = & java (Join-Path $PSScriptRoot 'JavaUml.java') @archivos
if ($LASTEXITCODE -ne 0 -or $uml -notcontains 'classDiagram') { throw "No se pudo generar el UML. Revisa $destino." }
$uml | Set-Content -LiteralPath (Join-Path $destino 'UML.md') -Encoding UTF8
Write-Host "Java compilado y UML generado en $destino"
$archivos
$uml

