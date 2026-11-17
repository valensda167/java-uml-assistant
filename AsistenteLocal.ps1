[CmdletBinding(DefaultParameterSetName='Archivo')]
param(
 [ValidateSet('resolver','revisar','practicar')][string]$Modo='resolver',
 [Parameter(Mandatory,ParameterSetName='Archivo')][string]$Enunciado,
 [Parameter(Mandatory,ParameterSetName='Directo')][string]$Texto,
 [string[]]$Codigo=@(), [string]$Modelo, [string]$Salida, [switch]$SinTest,
 [string]$Requisitos, [string]$UrlOllama='http://127.0.0.1:11434', [switch]$SinFormatoJson
)
$ErrorActionPreference='Stop'
if ($PSCmdlet.ParameterSetName -eq 'Archivo') { $Texto=Get-Content -LiteralPath $Enunciado -Raw -Encoding UTF8 }
$r = & (Join-Path $PSScriptRoot 'Flujo.ps1') -Texto $Texto -Modo $Modo -Codigo $Codigo -Modelo $Modelo -Salida $Salida -SinTest:$SinTest -Requisitos $Requisitos -UrlOllama $UrlOllama -SinFormatoJson:$SinFormatoJson
if (!$r.Exito) { throw "$($r.Mensaje)`nArchivos y diagnostico: $($r.Carpeta)" }
$r.Mensaje
"Resultados: $($r.Carpeta)"
foreach ($archivo in $r.Archivos) {
 [IO.Path]::GetFileName($archivo)
 Get-Content -LiteralPath $archivo -Raw -Encoding UTF8
}
if ($Modo -eq 'resolver') { Get-Content -LiteralPath (Join-Path $r.Carpeta 'UML.md') -Raw -Encoding UTF8 }
