# Ejecuta herramientas sin bloquear la ventana y limita el tiempo de ejecucion.
function Invoke-Herramienta {
    param([string]$Programa, [string[]]$Argumentos, [int]$Segundos = 40)
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Programa
    $info.Arguments = ($Argumentos | ForEach-Object {
        '"' + ([regex]::Replace(([regex]::Replace($_, '(\\*)"', '$1$1\"')), '(\\+)$', '$1$1')) + '"'
    }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [Text.Encoding]::UTF8
    $proceso = New-Object Diagnostics.Process
    $proceso.StartInfo = $info
    try {
        $null = $proceso.Start()
        $stdout = $proceso.StandardOutput.ReadToEndAsync()
        $stderr = $proceso.StandardError.ReadToEndAsync()
        if (!$proceso.WaitForExit($Segundos * 1000)) {
            # Algunos lanzadores de Java crean otro proceso: detener solo el padre deja el programa activo.
            if ($env:OS -eq 'Windows_NT') {
                $null = & "$env:SystemRoot\System32\taskkill.exe" /PID $proceso.Id /T /F 2>&1
            } else { $proceso.Kill() }
            throw "Tiempo agotado al ejecutar $Programa ($Segundos segundos)."
        }
        [pscustomobject]@{ Codigo = $proceso.ExitCode; Texto = $stdout.Result + $stderr.Result }
    } finally { $proceso.Dispose() }
}
function Invoke-JavaUml {
    param([string[]]$Argumentos)
    $fuente = Join-Path $PSScriptRoot 'JavaUml.java'
    $hash = (Get-FileHash -LiteralPath $fuente -Algorithm SHA256).Hash.Substring(0,12)
    $cache = Join-Path $PSScriptRoot "build/uml-$hash"
    if (!(Test-Path -LiteralPath (Join-Path $cache 'JavaUml.class'))) {
        $null = New-Item -ItemType Directory -Path $cache -Force
        $compilacion = Invoke-Herramienta javac @('-proc:none','-encoding','UTF-8','-d',$cache,$fuente)
        if ($compilacion.Codigo -ne 0) { throw $compilacion.Texto }
    }
    Invoke-Herramienta java (@('-Dfile.encoding=UTF-8','-cp',$cache,'JavaUml') + $Argumentos)
}
