param(
    [Parameter(Mandatory)][ValidateSet('resolver','revisar','practicar')][string]$Modo,
    [Parameter(Mandatory)][string]$Enunciado,
    [string[]]$Codigo = @(),
    [string]$Modelo = 'qwen2.5-coder:0.5b'
)

$ErrorActionPreference = 'Stop'
$problema = Get-Content -LiteralPath $Enunciado -Raw -Encoding UTF8
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
    resolver { 'Entrega Java completo, con un bloque por archivo.' }
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
$respuesta.message.content




