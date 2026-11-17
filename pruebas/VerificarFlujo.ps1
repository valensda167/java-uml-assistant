param([switch]$SoloReparacion)
$ErrorActionPreference='Stop'
$raiz=Split-Path $PSScriptRoot -Parent
. (Join-Path $raiz 'Procesos.ps1')
$salida=Join-Path $raiz ('soluciones/pruebas-'+[guid]::NewGuid())
$null=New-Item -ItemType Directory -Path $salida -Force
$contrato=Join-Path $raiz 'ejemplos/cuenta/requisitos.json'
$modelo=[IO.File]::ReadAllText((Join-Path $raiz 'ejemplos/cuenta/CuentaBancaria.java'))
$test=[IO.File]::ReadAllText((Join-Path $raiz 'ejemplos/cuenta/TestCuentaBancaria.java'))
function Check([bool]$Condicion,[string]$Mensaje) {
 if (!$Condicion) {throw "FALLO: $Mensaje"}
 Write-Host "OK: $Mensaje"
}
function Payload([string]$Codigo) {
 @{archivos=@(@{nombre='CuentaBancaria.java';contenido=$Codigo},@{nombre='TestCuentaBancaria.java';contenido=$test})} | ConvertTo-Json -Depth 8 -Compress
}
function Mock([object[]]$Respuestas) {
 $socket=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,0)
 $socket.Start(); $port=$socket.LocalEndpoint.Port; $socket.Stop()
 $job=Start-Job -ArgumentList $port,($Respuestas | ConvertTo-Json -Depth 10 -Compress) -ScriptBlock {
  param($port,$json)
  $responses=$json | ConvertFrom-Json
  $listener=New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback,$port); $listener.Start()
  $index=0
  try {
   while ($true) {
    while (!$listener.Pending()) {Start-Sleep -Milliseconds 50}
    $client=$listener.AcceptTcpClient(); $stream=$client.GetStream(); $stream.ReadTimeout=10000
    $header=''
    while (!$header.EndsWith("`r`n`r`n")) {$byte=$stream.ReadByte(); if ($byte -lt 0) {break}; $header += [char]$byte}
    if (!$header.EndsWith("`r`n`r`n")) {$client.Close(); continue}
    if ($header.StartsWith('GET /api/tags ')) {$body='{"models":[{"name":"qwen2.5-coder:1.5b"}]}'}
    else {
     if ($header -match 'Expect: 100-continue') {$continue=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 100 Continue`r`n`r`n"); $stream.Write($continue,0,$continue.Length)}
     $length=[int][regex]::Match($header,'(?i)Content-Length: (\d+)').Groups[1].Value
     $buffer=New-Object byte[] $length; $read=0
     while ($read -lt $length) {$n=$stream.Read($buffer,$read,$length-$read); if (!$n) {throw 'Cuerpo incompleto'}; $read += $n}
     $request=[Text.Encoding]::UTF8.GetString($buffer) | ConvertFrom-Json
     if (!$request.messages -or !$request.options) {throw 'Solicitud invalida'}
     $entry=$responses[[Math]::Min($index,$responses.Count-1)]; $index++
     $body=@{message=@{content=$entry.Texto}; done_reason=$entry.Razon} | ConvertTo-Json -Depth 8 -Compress
    }
    $bytes=[Text.Encoding]::UTF8.GetBytes($body)
    $head=[Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: application/json; charset=utf-8`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n")
    $stream.Write($head,0,$head.Length); $stream.Write($bytes,0,$bytes.Length); $client.Close()
   }
  } finally {$listener.Stop()}
 }
 for ($i=0;$i -lt 30;$i++) {
  try {$null=Invoke-RestMethod "http://127.0.0.1:$port/api/tags" -TimeoutSec 1; break} catch {
   if ($job.State -eq 'Failed') {Receive-Job $job; throw 'El servidor simulado no pudo iniciar.'}
   Start-Sleep -Milliseconds 100
  }
 }
 [pscustomobject]@{Job=$job;Url="http://127.0.0.1:$port"}
}
function Caso([string]$Nombre,[object[]]$Respuestas,[bool]$Exito,[int]$Intentos,[bool]$ConContrato=$true) {
 $mock=Mock $Respuestas
 try {
  $params=@{Texto='Crea CuentaBancaria y TestCuentaBancaria.'; Salida=$salida;UrlOllama=$mock.Url}
  if ($ConContrato) {$params.Requisitos=$contrato}
  $r=& (Join-Path $raiz 'Flujo.ps1') @params
  Check ($r.Exito -eq $Exito) "$Nombre - exito=$Exito ($($r.Mensaje))"
  Check ($r.Intentos -eq $Intentos) "$Nombre - intentos=$Intentos"
  Check (Test-Path (Join-Path $r.Carpeta 'resultado.json')) "$Nombre - resultado persistido"
  return $r
 } finally {Stop-Job $mock.Job; Remove-Job $mock.Job}
}
$correcta=@{Texto=(Payload $modelo);Razon='stop'}
if ($SoloReparacion) {
 $retorno=$modelo.Replace('public void depositar(double monto)', 'public boolean depositar(double monto)').Replace('if (monto > 0) saldo += monto;', 'if (monto > 0) saldo += monto; return true;')
 $r=Caso 'retorno incorrecto' @(@{Texto=(Payload $retorno);Razon='stop'},$correcta) $true 2
 $diagnostico=Get-Content (Join-Path $r.Carpeta 'Diagnostico-1.txt') -Raw -Encoding UTF8
 Check ($diagnostico.Contains('Firma requerida: public void depositar(double)')) 'diagnostico indica la firma requerida'
 Check ($diagnostico.Contains('Encontrado: public boolean depositar(double)')) 'diagnostico indica la firma encontrada'
 Write-Host 'Reparacion especifica verificada.'
 return
}
$r=Caso 'correcta' @($correcta) $true 1
Check ($r.Verificacion.Correctos -eq $r.Verificacion.Total) 'contrato y casos pasan'
& (Join-Path $raiz 'EjecutarSolucion.ps1') -Carpeta $r.Carpeta
$bug=$modelo.Replace('monto <= 0 || monto > saldo','monto <= 0')
$r=Caso 'bug saldo' @(@{Texto=(Payload $bug);Razon='stop'}) $false 2
Check ([bool]($r.Verificacion.Comprobaciones | Where-Object {$_.Nombre -eq 'Caso: saldo insuficiente' -and !$_.Pasa})) 'detecta bug logico'
$bugNombre=$modelo.Replace('retirar(', 'retiro(')
$r=Caso 'bug firma' @(@{Texto=(Payload $bugNombre);Razon='stop'},$correcta) $true 2
$r=Caso 'truncada' @(@{Texto='incompleta';Razon='length'},$correcta) $true 2
$r=Caso 'vacia' @(@{Texto='';Razon='stop'},$correcta) $true 2
$markdown='```java'+"`n"+$modelo+"`n"+$test+"`n"+'```'
$r=Caso 'markdown varias clases' @(@{Texto=$markdown;Razon='stop'}) $true 1
$imports=$modelo.Replace('public class CuentaBancaria', 'import java.util.TestCuentaBancaria;'+"`n"+'public class CuentaBancaria').Replace('private double saldo;','private double saldo; private List<String> notas = new ArrayList<>();')
$r=Caso 'imports' @(@{Texto=(Payload $imports);Razon='stop'}) $true 1
$r=Caso 'sin Test' @(@{Texto=(@{archivos=@(@{nombre='CuentaBancaria.java';contenido=$modelo})}|ConvertTo-Json -Depth 8);Razon='stop'},$correcta) $true 2
$r=Caso 'sin contrato' @($correcta) $true 1 $false
Check (!$r.Verificacion.TieneContrato -and $r.Mensaje.Contains('pendiente')) 'no inventa cumplimiento'
$r=& (Join-Path $raiz 'Flujo.ps1') -Texto 'prueba' -Salida $salida -UrlOllama 'http://127.0.0.1:1'
Check (!$r.Exito -and $r.Mensaje.Contains('no responde')) 'conexion rechazada explicada'
$fixture=Join-Path $salida 'Tipos.java'
$code=@'
import java.util.*;
/** Una clase con documentacion. */
abstract class Catalogo {
    private Map<String,Libro> libros;
    private Optional<Libro> seleccionado;
    private String descripción;
    public abstract void listar();
}
class Libro {}
interface Prestamo { void prestar(); }
enum Estado { LIBRE, OCUPADO }
'@
[IO.File]::WriteAllText($fixture,$code,[Text.UTF8Encoding]::new($false))
$out=Join-Path $salida 'tipos.md'
$x=Invoke-Herramienta java @((Join-Path $raiz 'JavaUml.java'),'--salida',$out,$fixture)
Check ($x.Codigo -eq 0) 'genera UML avanzado'
$uml=Get-Content $out -Raw -Encoding UTF8
foreach ($fragmento in @('<<abstract>>','<<interface>>','<<enumeration>>','"0..*" Libro','"0..1" Libro','descripción','%% fuente:','listar() void*')) {Check ($uml.Contains($fragmento)) "UML contiene $fragmento"}
$split=Join-Path $salida 'split'; $null=New-Item -ItemType Directory $split
$x=Invoke-Herramienta java @((Join-Path $raiz 'JavaUml.java'),'--split',$split,$fixture,$fixture)
Check ($x.Codigo -eq 0) 'deduplica tipos identicos'
Check ((Get-Content (Join-Path $split 'Catalogo.java') -Raw -Encoding UTF8).Contains('/** Una clase')) 'conserva Javadoc'
$loop=Join-Path $salida 'Loop.java'
[IO.File]::WriteAllText($loop,'class Loop { public static void main(String[] a) { while(true) {} } }')
$agotado=$false
try {$null=Invoke-Herramienta java @($loop) 3} catch {$agotado=$_.Exception.Message.Contains('Tiempo agotado')}
Check $agotado 'limita ejecucion infinita'
@{Exito=$true; Fecha=[DateTime]::UtcNow.ToString('o'); Escenarios=10; JavaUml=(Get-FileHash (Join-Path $raiz 'JavaUml.java')).Hash} | ConvertTo-Json | Set-Content (Join-Path $salida 'pruebas-completadas.json') -Encoding UTF8
Write-Host "Todas las pruebas pasaron. Evidencia: $salida"
