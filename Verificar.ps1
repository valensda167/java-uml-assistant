param([Parameter(Mandatory)][string]$Carpeta, [string]$Requisitos, [switch]$SinTest)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Procesos.ps1')
$fuentes = @(Get-ChildItem -LiteralPath $Carpeta -Filter '*.java' -File | ForEach-Object FullName)
$inspeccion = Join-Path $Carpeta 'Estructura.json'
$r = Invoke-JavaUml (@('--inspeccionar', '--salida', $inspeccion) + $fuentes)
if ($r.Codigo -ne 0) { throw "No se pudo inspeccionar Java: $($r.Texto)" }
$estructura = Get-Content -LiteralPath $inspeccion -Raw -Encoding UTF8 | ConvertFrom-Json
$comprobaciones = New-Object Collections.Generic.List[object]
function Agregar([string]$Nombre, [bool]$Pasa, [string]$Detalle = '') {
    $comprobaciones.Add([pscustomobject]@{ Nombre = $Nombre; Pasa = $Pasa; Detalle = $Detalle })
}
if (!$SinTest) {
    $uml = Get-Content -LiteralPath (Join-Path $Carpeta 'UML.md') -Raw -Encoding UTF8
    Agregar 'Modelo y TestModelo con main que crea el objeto' ([bool]($uml -cmatch '(?m)^    Test(\w+) \.\.> \1 : crea\s*$'))
}
if ($Requisitos) {
    $contrato = Get-Content -LiteralPath $Requisitos -Raw -Encoding UTF8 | ConvertFrom-Json
    if (!$contrato.clases -and !$contrato.casos) { throw 'El contrato necesita clases o casos; revisa el ejemplo de requisitos.' }
    foreach ($esperada in $contrato.clases) {
        $actual = $estructura.clases | Where-Object nombre -CEQ $esperada.nombre | Select-Object -First 1
        Agregar "Clase $($esperada.nombre)" ([bool]$actual)
        if (!$actual) { continue }
        if ($esperada.hereda) { Agregar "$($esperada.nombre) hereda $($esperada.hereda)" ($actual.hereda -ceq $esperada.hereda) }
        foreach ($interfaz in $esperada.interfaces) { Agregar "Interfaz $interfaz" ($interfaz -cin $actual.interfaces) }
        foreach ($campo in $esperada.atributos) {
            $encontrado = @($actual.atributos | Where-Object {
                $_.nombre -ceq $campo.nombre -and $_.tipo -ceq $campo.tipo -and
                (!$campo.visibilidad -or $campo.visibilidad -cin $_.modificadores)
            })
            Agregar "$($esperada.nombre).$($campo.nombre): $($campo.tipo) $($campo.visibilidad)" ($encontrado.Count -gt 0)
        }
        foreach ($metodo in $esperada.metodos) {
            $encontrado = @($actual.metodos | Where-Object {
                $_.nombre -ceq $metodo.nombre -and $_.retorno -ceq $metodo.retorno -and
                ($_.params -join '|') -ceq ($metodo.params -join '|') -and
                (!$metodo.visibilidad -or $metodo.visibilidad -cin $_.modificadores)
            })
            $observados = @($actual.metodos | Where-Object nombre -CEQ $metodo.nombre | ForEach-Object { "$($_.modificadores -join ' ') $($_.retorno) $($_.nombre)($($_.params -join ', '))" })
            $detalle = "Firma requerida: $($metodo.visibilidad) $($metodo.retorno) $($metodo.nombre)($($metodo.params -join ', ')). Encontrado: $($observados -join '; ')."
            Agregar "$($esperada.nombre).$($metodo.nombre)($($metodo.params -join ', ')): $($metodo.retorno)" ($encontrado.Count -gt 0) $detalle
        }
        foreach ($constructor in $esperada.constructores) {
            Agregar "Constructor $($esperada.nombre)($($constructor -join ', '))" ([bool]@($actual.metodos | Where-Object {
                $_.nombre -ceq $esperada.nombre -and $_.retorno -eq '' -and ($_.params -join '|') -ceq ($constructor -join '|')
            }).Count)
        }
    }
    foreach ($pareja in $contrato.pares_test) {
        $clase = $estructura.clases | Where-Object nombre -CEQ $pareja
        Agregar "Programa $pareja.main(String[])" ([bool]@($clase.metodos | Where-Object {
            $_.nombre -ceq 'main' -and $_.retorno -ceq 'void' -and ($_.params -join '|') -ceq 'String[]' -and
            'public' -in $_.modificadores -and 'static' -in $_.modificadores
        }).Count)
    }
    # Los casos son codigo proporcionado por el usuario, nunca expectativas inventadas por el generador.
    $indice = 0
    foreach ($caso in $contrato.casos) {
        $indice++
        if (!@($caso.afirmaciones).Count) { throw "El caso $($caso.nombre) no contiene afirmaciones." }
        $dir = Join-Path $Carpeta "verificacion/caso$indice"
        $null = New-Item -ItemType Directory -Path $dir -Force
        $nombre = "VerificarCaso$indice"
        $paquete = if ($contrato.paquete) { "package $($contrato.paquete);" } else { '' }
        $asserts = ($caso.afirmaciones | ForEach-Object { "if (!($_)) throw new AssertionError();" }) -join "`n"
        $codigo = "$paquete`npublic class $nombre { public static void main(String[] args) { $($caso.codigo)`n$asserts } }"
        $archivo = Join-Path $dir "$nombre.java"
        [IO.File]::WriteAllText($archivo, $codigo, [Text.UTF8Encoding]::new($false))
        $build = Join-Path $Carpeta 'build'
        $compilar = Invoke-Herramienta javac (@('-proc:none', '-encoding', 'UTF-8', '-d', $dir, $archivo) + $fuentes)
        $bien = $false
        $detalle = $compilar.Texto
        if ($compilar.Codigo -eq 0) {
            $clase = if ($contrato.paquete) { "$($contrato.paquete).$nombre" } else { $nombre }
            try {
                $ejecutar = Invoke-Herramienta java @('-Dfile.encoding=UTF-8', '-Xmx128m', '-cp', $dir, $clase) 15
                $bien = $ejecutar.Codigo -eq 0
                $detalle = $ejecutar.Texto
            } catch { $detalle = $_.Exception.Message }
        }
        $detalle | Set-Content -LiteralPath (Join-Path $dir 'Registro.txt') -Encoding UTF8
        Agregar "Caso: $($caso.nombre)" $bien
    }
}
$informe = [pscustomobject]@{
    TieneContrato = [bool]$Requisitos
    Total = $comprobaciones.Count
    Correctos = @($comprobaciones | Where-Object Pasa).Count
    Pasa = @($comprobaciones | Where-Object { !$_.Pasa }).Count -eq 0
    Comprobaciones = @($comprobaciones.ToArray())
    Nota = 'Solo se comprueban los requisitos y casos indicados; no garantiza todos los comportamientos del enunciado.'
}
$informe | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $Carpeta 'Verificacion.json') -Encoding UTF8
$informe
