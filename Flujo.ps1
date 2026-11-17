[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Texto,
    [ValidateSet('resolver','revisar','practicar')][string]$Modo = 'resolver',
    [string[]]$Codigo = @(), [string]$Modelo, [string]$Salida,
    [string]$Requisitos, [switch]$SinTest,
    [string]$UrlOllama = 'http://127.0.0.1:11434',
    [ValidateRange(1,3)][int]$MaxIntentos = 3,
    [string]$EstadoArchivo,
    [switch]$SinFormatoJson
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Procesos.ps1')
if (!$Salida) { $Salida = Join-Path $PSScriptRoot 'soluciones' }
$destino = Join-Path $Salida ([guid]::NewGuid().ToString('N').Substring(0,12))
$null = New-Item -ItemType Directory -Path $destino -Force
$destino = (Get-Item -LiteralPath $destino).FullName
$resultado = [ordered]@{ Exito=$false; Carpeta=$destino; Etapa='Preparando'; Mensaje=''; Intentos=0; Modelo=''; Archivos=@(); Verificacion=$null; MejorIntento=$null }
$mejorPuntaje = -1
function Etapa([string]$Nombre) {
    $resultado.Etapa = $Nombre
    if ($EstadoArchivo) { $Nombre | Set-Content -LiteralPath $EstadoArchivo -Encoding UTF8 }
}
function Herramienta([string]$Exe, [string[]]$Argumentos) {
    $r = Invoke-Herramienta $Exe $Argumentos
    if ($r.Codigo -ne 0) { throw $r.Texto }
    $r.Texto
}
try {
    $Texto | Set-Content -LiteralPath (Join-Path $destino 'Enunciado.txt') -Encoding UTF8
    if ($Requisitos) {
        $null = Get-Content -LiteralPath $Requisitos -Raw -Encoding UTF8 | ConvertFrom-Json
        Copy-Item -LiteralPath $Requisitos -Destination (Join-Path $destino 'Requisitos.json')
        $Requisitos = Join-Path $destino 'Requisitos.json'
    }
    if ($Modo -eq 'revisar' -and !$Codigo.Count) { throw 'Selecciona los archivos Java que deseas revisar.' }
    Etapa 'Conectando con Ollama'
    $url = $UrlOllama.TrimEnd('/')
    try { $modelos = Invoke-RestMethod "$url/api/tags" -TimeoutSec 3 }
    catch {
        if ($url -ne 'http://127.0.0.1:11434') { throw 'Ollama no responde en la direccion configurada.' }
        $ollama = Get-Command ollama.exe -ErrorAction SilentlyContinue
        $ruta = if ($ollama) { $ollama.Source } else { Join-Path $env:LOCALAPPDATA 'Programs/Ollama/ollama.exe' }
        if (!(Test-Path -LiteralPath $ruta)) { throw 'No se encontro Ollama. Instala o abre Ollama y vuelve a intentar.' }
        Start-Process -FilePath $ruta -ArgumentList 'serve' -WindowStyle Hidden
        $modelos = $null
        for ($i=0; $i -lt 10 -and !$modelos; $i++) {
            Start-Sleep -Milliseconds 500
            try { $modelos = Invoke-RestMethod "$url/api/tags" -TimeoutSec 2 } catch {}
        }
        if (!$modelos) { throw 'Ollama no inicio. Abre Ollama y vuelve a intentar.' }
    }
    if (!$Modelo) { $Modelo = if ('qwen2.5-coder:1.5b' -in $modelos.models.name) { 'qwen2.5-coder:1.5b' } else { 'qwen2.5-coder:0.5b' } }
    if ($Modelo -notin $modelos.models.name) { throw "Modelo no instalado: $Modelo. Ejecuta: ollama pull $Modelo" }
    $resultado.Modelo = $Modelo
    $estilo = Get-Content (Join-Path $PSScriptRoot 'estilo.txt') -Raw -Encoding UTF8
    $teoria = Get-Content (Join-Path $PSScriptRoot 'Teoria.txt') -Raw -Encoding UTF8
    # Seleccion explicita y acotada de la guia; deja espacio para enunciado y respuesta.
    $guia = $estilo.Substring(0, [Math]::Min(4000, $estilo.Length))
    $consultaBase = "Java 17, solo JDK. El enunciado tiene prioridad. Usa nombres solicitados, POO sencilla y separa calculos de mostrarDatos. No inventes funciones. Entrega todas las clases necesarias. No uses JUnit.`nGUIA PERSONAL:`n$guia`nTEORIA:`n$teoria`nENUNCIADO:`n$Texto"
    if (!$SinTest) { $consultaBase += "`nEntrega Objeto.java y TestObjeto.java (usa el nombre real). TestObjeto debe tener public static void main(String[] args), crear new Objeto(...) y llamar sus metodos." }
    if ($Requisitos) { $consultaBase += "`nCONTRATO REVISADO POR EL USUARIO:`n" + (Get-Content $Requisitos -Raw -Encoding UTF8) }
    $palabras = @([regex]::Matches($Texto.ToLowerInvariant(), '[\p{L}]{4,}') | ForEach-Object Value | Sort-Object -Unique)
    $candidatos = @(Get-ChildItem (Join-Path $PSScriptRoot 'ejemplos/netbeans') -Filter '*.java' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $nombre = $_.BaseName.ToLowerInvariant(); @($palabras | Where-Object { $nombre.Contains($_) }).Count -gt 0 } | Select-Object -First 2)
    if (!$candidatos.Count) { $candidatos = @(Get-ChildItem (Join-Path $PSScriptRoot 'ejemplos/empleado') -Filter '*.java') }
    $ejemplos = ($candidatos | ForEach-Object { Get-Content $_.FullName -Raw -Encoding UTF8 }) -join "`n"
    $consultaBase += "`nEJEMPLOS DE ESTILO (no copies el problema):`n" + $ejemplos.Substring(0, [Math]::Min(1600, $ejemplos.Length))
    $consultaBase += "`nRESUELVE ESTE ENUNCIADO, NO EL EJEMPLO:`n$Texto"
    if ($Requisitos) {
        $contrato = Get-Content $Requisitos -Raw -Encoding UTF8 | ConvertFrom-Json
        $firmas = foreach ($clase in $contrato.clases) {
            foreach ($metodo in $clase.metodos) { "$($clase.nombre): $($metodo.visibilidad) $($metodo.retorno) $($metodo.nombre)($($metodo.params -join ', '))" }
        }
        $consultaBase += "`nFIRMAS OBLIGATORIAS: respeta exactamente el retorno de cada metodo, incluido void.`n" + ($firmas -join "`n")
    }
    foreach ($archivo in $Codigo) { $consultaBase += "`nARCHIVO $([IO.Path]::GetFileName($archivo)):`n" + (Get-Content $archivo -Raw -Encoding UTF8) }
    $accion = switch ($Modo) {
        resolver { 'Resuelve el ENUNCIADO respetando sus nombres reales. Genera TODAS las clases, incluido TestNombre con main que crea el objeto. Objeto y Modelo son solo marcadores: reemplazalos por el nombre pedido. Responde un objeto JSON con la propiedad archivos, una lista de objetos con nombre (nombre real del archivo .java) y contenido (codigo Java completo). Sin explicaciones.' }
        revisar { 'Revisa requisitos y logica del codigo. Distingue observaciones de hechos verificados. No afirmes haber ejecutado pruebas.' }
        practicar { 'Da una pista corta y una pregunta, sin resolver todo el ejercicio.' }
    }
    $schema = @{ type='object'; required=@('archivos'); properties=@{ archivos=@{ type='array'; minItems=1; items=@{ type='object'; required=@('nombre','contenido'); properties=@{ nombre=@{type='string'}; contenido=@{type='string'} } } } } }
    $consulta = $consultaBase
    $limite = if ($Modo -eq 'practicar') { 300 } else { 2400 }
    $falloAnterior = ''
    for ($intento=1; $intento -le $MaxIntentos; $intento++) {
        $resultado.Intentos = $intento
        Etapa "Generando: intento $intento de $MaxIntentos"
        $cuerpo = @{ model=$Modelo; stream=$false; keep_alive=0; options=@{ num_ctx=4096; num_predict=$limite; temperature=0; seed=42 }; messages=@(@{role='system';content=$accion}, @{role='user';content=$consulta}) }
        if ($Modo -eq 'resolver' -and !$SinFormatoJson) { $cuerpo.format = $schema }
        try {
            $respuesta = Invoke-RestMethod "$url/api/chat" -Method Post -TimeoutSec 240 -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes(($cuerpo | ConvertTo-Json -Depth 15)))
        } catch { throw "No se pudo completar la consulta a Ollama. Comprueba el modelo y la conexion. $($_.Exception.Message)" }
        $raw = [string]$respuesta.message.content
        $raw | Set-Content -LiteralPath (Join-Path $destino "Respuesta-$intento.txt") -Encoding UTF8
        if ($Modo -ne 'resolver') {
            if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Ollama devolvio una respuesta vacia.' }
            $resultado.Mensaje = $raw
            $resultado.Exito = $true
            break
        }
        try {
            if ([string]::IsNullOrWhiteSpace($raw)) { throw 'Respuesta vacia: entrega los archivos Java.' }
            if ($respuesta.done_reason -eq 'length') { $limite = 3200; throw 'Respuesta truncada: entrega una solucion mas breve y completa.' }
            Etapa 'Separando los archivos Java'
            $bloques = @()
            try {
                $json = $raw | ConvertFrom-Json
                foreach ($archivo in $json.archivos) {
                    if ($archivo.nombre -notmatch '^[\p{L}_$][\p{L}\p{N}_$]*\.java$') { throw 'Nombre de archivo Java no valido.' }
                    if ([string]::IsNullOrWhiteSpace($archivo.contenido)) { throw 'Archivo vacio.' }
                    $bloques += [string]$archivo.contenido
                }
            } catch { $bloques = @() }
            if (!$bloques.Count) {
                $bloques = @([regex]::Matches($raw, '(?ims)^[ \t]*```java[^\r\n]*\r?\n(.*?)^[ \t]*```') | ForEach-Object { $_.Groups[1].Value })
            }
            if (!$bloques.Count) { throw 'No se encontraron archivos Java completos en la respuesta.' }
            $entrada = Join-Path $destino "intento-$intento"
            $null = New-Item -ItemType Directory -Path $entrada
            $paths = @(for ($b=0; $b -lt $bloques.Count; $b++) {
                $p = Join-Path $entrada "Bloque$b.java"
                [IO.File]::WriteAllText($p, $bloques[$b], [Text.UTF8Encoding]::new($false)); $p
            })
            # Cada intento queda aislado; un intento peor no pisa los anteriores.
            $carpeta = Join-Path $entrada 'java'
            $null = New-Item -ItemType Directory -Path $carpeta
            if ($reparacionParcial) { Copy-Item -Path (Join-Path $reparacionParcial '*.java') -Destination $carpeta }
            $separacion = Invoke-JavaUml (@('--split', $carpeta) + $paths)
            if ($separacion.Codigo -ne 0) { throw $separacion.Texto }
            $fuentes = @(Get-ChildItem $carpeta -Filter '*.java' -File | ForEach-Object FullName)
            Etapa 'Compilando Java'
            $build = Join-Path $carpeta 'build'
            $null = New-Item -ItemType Directory -Path $build
            $null = Herramienta javac (@('-proc:none','-encoding','UTF-8','-d',$build) + $fuentes)
            Etapa 'Generando UML desde el codigo'
            foreach ($vista in @(@{Nombre='UML.md'; Args=@()}, @{Nombre='UML-modelo.md';Args=@('--modelo')}, @{Nombre='UML-resumen.md';Args=@('--modelo','--resumen')}, @{Nombre='UML-pruebas.md';Args=@('--pruebas')})) {
                $diagrama = Invoke-JavaUml (@('--salida',(Join-Path $carpeta $vista.Nombre)) + $vista.Args + $fuentes)
                if ($diagrama.Codigo -ne 0) { throw $diagrama.Texto }
            }
            Etapa 'Verificando estructura y casos'
            $verificacion = & (Join-Path $PSScriptRoot 'Verificar.ps1') -Carpeta $carpeta -Requisitos $Requisitos -SinTest:$SinTest
            if ($verificacion.Correctos -gt $mejorPuntaje) {
                $mejorPuntaje = $verificacion.Correctos
                $resultado.Verificacion = $verificacion
                $resultado.MejorIntento = $carpeta
                $resultado.Archivos = $fuentes
            }
            if (!$verificacion.Pasa) { throw ('Requisitos pendientes: ' + (($verificacion.Comprobaciones | Where-Object { !$_.Pasa } | ForEach-Object { "$($_.Nombre). $($_.Detalle)" }) -join '; ')) }
            foreach ($f in Get-ChildItem $carpeta -File) { Copy-Item -LiteralPath $f.FullName -Destination $destino }
            $resultado.Archivos = @(Get-ChildItem $destino -Filter '*.java' -File | ForEach-Object FullName)
            $resultado.Exito = $true
            $resultado.Mensaje = if ($Requisitos) { "Compila. Verificaciones: $($verificacion.Correctos)/$($verificacion.Total)." } else { 'Compila y respeta la pareja Objeto/Test. Cumplimiento del enunciado pendiente: agrega requisitos y casos para comprobarlo.' }
            if ($SinTest -and !$Requisitos) { $resultado.Mensaje = 'Compila. No se comprobo la pareja Objeto/Test ni requisitos del enunciado.' }
            break
        } catch {
            $fallo = $_.Exception.Message.Replace($destino, '[solucion]')
            $fallo | Set-Content (Join-Path $destino "Diagnostico-$intento.txt") -Encoding UTF8
            if ($intento -eq $MaxIntentos -or $fallo -ceq $falloAnterior) { throw $fallo }
            $falloAnterior = $fallo
            Etapa 'Preparando reparacion'
            $reparacionParcial = $null
            $afectados = @([regex]::Matches($fallo, '([\p{L}_$][\p{L}\p{N}_$]*\.java):\d+:') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
            if ($afectados.Count -and $carpeta -and (Test-Path $carpeta)) {
                $reparacionParcial = $carpeta
                $contexto = (Get-ChildItem $carpeta -Filter '*.java' | ForEach-Object {
                    $contenido = Get-Content $_.FullName -Raw -Encoding UTF8
                    if ($_.Name -in $afectados) { "ARCHIVO A CORREGIR $($_.Name):`n$contenido" }
                    else { "FIRMAS DE $($_.Name):`n" + (([regex]::Matches($contenido, '(?m)^\s*(public|protected|private).*$') | ForEach-Object Value) -join "`n") }
                }) -join "`n"
                $consulta = "$consultaBase`nCorrige SOLO estos archivos: $($afectados -join ', '). Diagnostico:`n$fallo`n$contexto"
            } else {
                $consulta = "Corrige Java 17 con estilo POO sencillo. Devuelve TODOS los archivos, modelo y Test con main, en el mismo JSON de archivos.`nENUNCIADO:`n$Texto`nRESPUESTA A CORREGIR:`n$raw`nCAMBIOS OBLIGATORIOS: $fallo`nNo repitas la respuesta con estos errores. Conserva los metodos y archivos correctos."
            }
        }
    }
    if ($resultado.Exito -and $Modo -eq 'resolver') {
        $mermaid = Join-Path $PSScriptRoot 'vendor/mermaid.min.js'
        Copy-Item -LiteralPath $mermaid -Destination (Join-Path $destino 'mermaid.min.js')
        $uml = Get-Content (Join-Path $destino 'UML.md') -Raw -Encoding UTF8
        $diagrama = [Net.WebUtility]::HtmlEncode(($uml -replace '^```mermaid\s*','' -replace '\s*```\s*$',''))
        $html = '<!doctype html><html lang="es"><meta charset="utf-8"><title>UML</title><style>body{font:16px system-ui;background:#f4f6fb;padding:24px}pre{background:white;padding:24px}</style><h1>Diagrama desde el codigo Java</h1><pre class="mermaid">' + $diagrama + '</pre><script src="mermaid.min.js"></script><script>mermaid.initialize({startOnLoad:true,securityLevel:"strict"});</script></html>'
        [IO.File]::WriteAllText((Join-Path $destino 'UML.html'), $html, [Text.UTF8Encoding]::new($false))
    }
    Etapa 'Terminado'
} catch {
    $resultado.Exito = $false
    $resultado.Mensaje = $_.Exception.Message
    Etapa 'Requiere atencion'
} finally {
    $resultado | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath (Join-Path $destino 'resultado.json') -Encoding UTF8
}
[pscustomobject]$resultado
