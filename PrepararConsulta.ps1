param(
    [Parameter(Mandatory)][ValidateSet('resolver','revisar','practicar')][string]$Modo,
    [Parameter(Mandatory)][string]$Enunciado,
    [string[]]$Codigo = @(),
    [ValidateSet('empleado','alumno','curso')][string]$Referencia = 'empleado'
)

$ErrorActionPreference = 'Stop'
if ($Modo -eq 'revisar' -and $Codigo.Count -eq 0) {
    throw 'Indica al menos un archivo Java con -Codigo.'
}
$instruccion = switch ($Modo) {
    resolver { 'Entrega el codigo Java completo por archivo. Respeta el enunciado. Si puedes ejecutar comandos, verifica con javac.' }
    revisar { 'Compara el codigo con el enunciado y la guia. Enumera requisitos cumplidos y faltantes y senala los archivos y metodos correspondientes.' }
    practicar { 'Da una sola pista y formula una pregunta para que el estudiante avance. Reserva la solucion completa hasta que la pida.' }
}
$ejemplo = Join-Path $PSScriptRoot ('ejemplos/' + $Referencia)
$estilo = Get-Content (Join-Path $PSScriptRoot 'estilo.txt') -Raw -Encoding UTF8
$problema = Get-Content -LiteralPath $Enunciado -Raw -Encoding UTF8
$archivosEjemplo = Get-ChildItem -LiteralPath $ejemplo -Filter "*.java" | Sort-Object Name
$material = @(
    Get-Content (Join-Path $ejemplo "enunciado.txt") -Raw -Encoding UTF8
    foreach ($archivo in $archivosEjemplo) {
        "Archivo: $($archivo.Name)"
        Get-Content -LiteralPath $archivo.FullName -Raw -Encoding UTF8
    }
)
$entrega = foreach ($archivo in $Codigo) {
    "Archivo: $archivo"
    Get-Content -LiteralPath $archivo -Raw -Encoding UTF8
}
@"
$instruccion

Guia de estilo:
$estilo

Ejemplo de referencia:
$($material -join "`n")

Ejercicio:
$problema

Codigo del estudiante:
$($entrega -join "`n")
"@

