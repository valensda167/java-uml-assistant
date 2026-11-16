[CmdletBinding(DefaultParameterSetName='Archivo')]
param(
    [ValidateSet('resolver','revisar','practicar')][string]$Modo = 'resolver',
    [Parameter(Mandatory,ParameterSetName='Archivo')][string]$Enunciado,
    [Parameter(Mandatory,ParameterSetName='Directo')][string]$Texto,
    [string[]]$Codigo = @(),
    [string]$Modelo,
    [string]$Salida,
    [switch]$SinTest
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
    resolver { 'Genera Java 17 que compile con javac. Usa solo el JDK: sin JUnit, anotaciones de prueba ni bibliotecas externas. Incluye todas las clases propias e imports. Devuelve solo bloques Markdown java, uno por archivo, con una clase publica del mismo nombre. Omite package salvo que el enunciado pida uno expresamente.' }
    revisar { 'Indica requisitos cumplidos y faltantes. Cita clases y metodos.' }
    practicar { 'Da una pista breve y haz una pregunta. Reserva la solucion.' }
}
$consulta = "$accion Estilo: Java 17, POO sencilla, nombres en espanol, atributos privados cuando corresponda, modelo separado de Test con main, calculo separado de mostrarDatos(). El enunciado tiene prioridad sobre el estilo y los ejemplos. Evita comentarios y metodos adicionales. En modo resolver, sigue el formato de archivos indicado al final.`nEjercicio:`n$problema"
$teoria = Get-Content (Join-Path $PSScriptRoot 'Teoria.txt') -Raw -Encoding UTF8
$consulta += "`nPrincipios de Java y UML:`n$teoria"
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
try {
    $modelos = Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 -ErrorAction Stop
} catch {
    $ollama = Get-Command ollama.exe -ErrorAction SilentlyContinue
    $rutaOllama = if ($ollama) { $ollama.Source } else {
        Join-Path $env:LOCALAPPDATA 'Programs/Ollama/ollama.exe'
    }
    if (!(Test-Path -LiteralPath $rutaOllama -PathType Leaf)) { throw 'Instala Ollama para usar el asistente local.' }
    Write-Host 'Iniciando Ollama local...'
    Start-Process -FilePath $rutaOllama -ArgumentList 'serve' -WindowStyle Hidden
    for ($intento = 0; $intento -lt 10 -and !$modelos; $intento++) {
        Start-Sleep -Milliseconds 500
        try {
            $modelos = Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2 -ErrorAction Stop
        } catch {}
    }
    if (!$modelos) { throw 'Ollama no inicio en 127.0.0.1:11434. Abre Ollama y vuelve a intentar.' }
}
if (!$Modelo) {
    $Modelo = if ('qwen2.5-coder:1.5b' -in $modelos.models.name) { 'qwen2.5-coder:1.5b' } else { 'qwen2.5-coder:0.5b' }
}
if ($Modelo -notin $modelos.models.name) { throw "Falta el modelo: ejecuta ollama pull $Modelo" }

$limite = if ($Modo -eq 'practicar') { 120 } else { 3200 }
if ($Modo -eq 'resolver' -and !$SinTest) {
    $consulta += "`nFormato obligatorio: entrega Modelo.java y TestModelo.java (reemplaza Modelo por el nombre real). El modelo contiene atributos, constructores y metodos. TestModelo es una clase Java normal: public static void main(String[] args) crea el objeto con new Modelo(...) y llama sus metodos. No uses JUnit. Si agregas clases de apoyo, entrega cada una en un bloque java separado."
}
for ($intentoGeneracion = 1; $intentoGeneracion -le 2; $intentoGeneracion++) {
    try {
        $cuerpo = @{
            model = $Modelo
            stream = $false
            options = @{ num_ctx = 8192; num_predict = $limite; temperature = 0.15 }
            messages = @(@{ role='system'; content=$accion }, @{ role='user'; content=$consulta })
        } | ConvertTo-Json -Depth 6
        try {
            $respuesta = Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/chat' -Method Post -TimeoutSec 240 `
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

        if (!$Salida) { $Salida = Join-Path $PSScriptRoot 'soluciones' }
        $destino = Join-Path $Salida ([guid]::NewGuid().ToString('N').Substring(0,12))
        $null = New-Item -ItemType Directory -Path $destino -Force
        $respuesta.message.content | Set-Content -LiteralPath (Join-Path $destino 'Respuesta.md') -Encoding UTF8
        $problema | Set-Content -LiteralPath (Join-Path $destino 'Enunciado.txt') -Encoding UTF8
        if ($respuesta.done_reason -eq 'length') { throw "Respuesta incompleta. Revisa $destino o prueba con otro modelo." }

        $bloques = [regex]::Matches($respuesta.message.content, '(?ims)^[ \t]*```java[ \t]*\r?\n(?<java>.*?)^[ \t]*```[ \t]*\r?$')
        if (!$bloques.Count) { throw "No se encontraron bloques Java completos. Revisa $destino." }
        $entradaJava = New-Item -ItemType Directory -Path (Join-Path $destino 'respuesta-java')
        $bloquesJava = @(for ($i = 0; $i -lt $bloques.Count; $i++) {
            $ruta = Join-Path $entradaJava.FullName "Bloque$i.java"
            [IO.File]::WriteAllText($ruta, $bloques[$i].Groups['java'].Value, [Text.UTF8Encoding]::new($false))
            $ruta
        })
        $rutaDestino = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($destino)
        & java (Join-Path $PSScriptRoot 'JavaUml.java') --split $rutaDestino @bloquesJava
        if ($LASTEXITCODE -ne 0) { throw "No se pudieron separar las clases Java. Revisa $destino." }
        $archivos = @(Get-ChildItem -LiteralPath $rutaDestino -File -Filter '*.java' | ForEach-Object FullName)
        $build = New-Item -ItemType Directory -Path (Join-Path $destino 'build')
        $preferencia = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $diagnostico = @(& javac -proc:none -encoding UTF-8 -d $build.FullName @archivos 2>&1)
            $codigoSalida = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $preferencia
        }
        if ($codigoSalida -ne 0) {
            $detalle = ($diagnostico | ForEach-Object { $_.ToString() }) -join "`r`n"
            $detalle | Set-Content -LiteralPath (Join-Path $destino 'Compilacion.txt') -Encoding UTF8
            throw "El Java generado no compila.`r`nCarpeta: $destino`r`n`r`n$detalle"
        }
        $uml = & java (Join-Path $PSScriptRoot 'JavaUml.java') @archivos
        if ($LASTEXITCODE -ne 0 -or $uml -notcontains 'classDiagram') {
            throw "No se pudo generar el UML. Revisa $destino."
        }
        if (!$SinTest -and !($uml -cmatch '^    Test(.+) \.\.> \1 : crea$')) {
            throw "Falta la pareja Modelo.java y TestModelo.java con main y new Modelo(). Carpeta: $destino"
        }

        break
    } catch {
        if ($Modo -ne 'resolver' -or $intentoGeneracion -eq 2 -or $_.Exception.Message -like 'Fallo Ollama local:*') { throw }
        $causa = $_.Exception.Message
        if ($destino) {
            $rutaIntento = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($destino)
            $causa = $causa.Replace($rutaIntento, '[carpeta]').Replace($destino, '[carpeta]')
        }
        $consulta += "`nCorrige la respuesta anterior. Devuelve TODOS los archivos, incluso los que no cambien. Los nombres de carpetas del diagnostico no son paquetes Java.`nDiagnostico:`n$causa`nRespuesta anterior:`n$($respuesta.message.content)"
        Write-Warning 'La primera solucion no paso la comprobacion. Reintentando una vez.'
    }
}
$uml | Set-Content -LiteralPath (Join-Path $destino 'UML.md') -Encoding UTF8
$mermaid = Join-Path $PSScriptRoot 'vendor/mermaid.min.js'
if (Test-Path -LiteralPath $mermaid) {
    $src = ([uri](Get-Item -LiteralPath $mermaid).FullName).AbsoluteUri
    $diagrama = [Net.WebUtility]::HtmlEncode(($uml | Select-Object -Skip 1 -Last ($uml.Count - 2)) -join "`n")
    @"
<!doctype html>
<html lang="es"><meta charset="utf-8"><title>Diagrama de clases</title>
<style>body{margin:36px;background:#f4f6fb;color:#242742;font:16px system-ui}pre{background:white;padding:24px;overflow:auto;border-radius:12px}</style>
<h1>Diagrama de clases</h1>
<pre class="mermaid">$diagrama</pre>
<script src="$src"></script>
<script>if(window.mermaid){mermaid.initialize({startOnLoad:true,securityLevel:'strict'});}</script>
</html>
"@ | Set-Content -LiteralPath (Join-Path $destino 'UML.html') -Encoding UTF8
}
"Java compilado y UML generado en $destino"
foreach ($archivo in $archivos) {
    [IO.Path]::GetFileName($archivo)
    Get-Content -LiteralPath $archivo -Raw -Encoding UTF8
}
$uml











