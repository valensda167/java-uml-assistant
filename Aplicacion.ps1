$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = 'Java UML Assistant'
$form.Size = New-Object Drawing.Size(880, 690)
$form.MinimumSize = New-Object Drawing.Size(650, 500)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.Padding = New-Object Windows.Forms.Padding(20)
$layout.ColumnCount = 1
$layout.RowCount = 5
foreach ($row in @('AutoSize','Percent','AutoSize','AutoSize','Percent')) {
    $style = New-Object Windows.Forms.RowStyle
    $style.SizeType = $row
    if ($row -eq 'Percent') { $style.Height = 50 }
    $null = $layout.RowStyles.Add($style)
}
$form.Controls.Add($layout)
$titulo = New-Object Windows.Forms.Label
$titulo.Text = 'Enunciado del ejercicio'
$titulo.AutoSize = $true
$layout.Controls.Add($titulo, 0, 0)
$entrada = New-Object Windows.Forms.TextBox
$entrada.Multiline = $true
$entrada.ScrollBars = 'Vertical'
$entrada.Dock = 'Fill'
$layout.Controls.Add($entrada, 0, 1)
$acciones = New-Object Windows.Forms.FlowLayoutPanel
$acciones.AutoSize = $true
$acciones.Dock = 'Fill'
$layout.Controls.Add($acciones, 0, 2)
$estado = New-Object Windows.Forms.Label
$estado.AutoSize = $true
$estado.Text = 'Listo. Las consultas se envian a Ollama en esta PC.'
$layout.Controls.Add($estado, 0, 3)
$resultado = New-Object Windows.Forms.TextBox
$resultado.Multiline = $true
$resultado.ReadOnly = $true
$resultado.ScrollBars = 'Both'
$resultado.WordWrap = $true
$resultado.Dock = 'Fill'
$resultado.Font = New-Object Drawing.Font('Consolas', 10)
$layout.Controls.Add($resultado, 0, 4)
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 250
$script:worker = $null
$script:pendiente = $null
$motor = Join-Path $PSScriptRoot 'AsistenteLocal.ps1'
$salidas = Join-Path $PSScriptRoot 'soluciones'
foreach ($opcion in @{resolver='Generar Java y UML'; revisar='Revisar Java'; practicar='Pedir una pista'}.GetEnumerator() | Sort-Object { @('resolver','revisar','practicar').IndexOf($_.Key) }) {
    $boton = New-Object Windows.Forms.Button
    $boton.Text = $opcion.Value
    $boton.Tag = $opcion.Key
    $boton.AutoSize = $true
    $boton.Add_Click({
        param($sender, $eventArgs)
        if ([string]::IsNullOrWhiteSpace($entrada.Text)) {
            $estado.Text = 'Escribe el enunciado primero.'
            return
        }
        $archivos = @()
        if ($sender.Tag -eq 'revisar') {
            $selector = New-Object Windows.Forms.OpenFileDialog
            $selector.Filter = 'Archivos Java (*.java)|*.java'
            $selector.Multiselect = $true
            try {
                if ($selector.ShowDialog($form) -ne 'OK') { return }
                $archivos = @($selector.FileNames)
            } finally { $selector.Dispose() }
        }
        $resultado.Clear()
        $verUml.Enabled = $false
        $estado.Text = 'Ollama esta trabajando. Puede tardar varios minutos si hace falta corregir el codigo.'
        $acciones.Enabled = $false
        $script:worker = [PowerShell]::Create()
        [void]$script:worker.AddScript({
            param($motor, $modo, $texto, $archivos, $salidas)
            & $motor -Modo $modo -Texto $texto -Codigo $archivos -Salida $salidas
        }).AddArgument($motor).AddArgument([string]$sender.Tag).AddArgument($entrada.Text).AddArgument($archivos).AddArgument($salidas)
        $script:pendiente = $script:worker.BeginInvoke()
        $timer.Start()
    })
    $acciones.Controls.Add($boton)
}
$abrir = New-Object Windows.Forms.Button
$abrir.Text = 'Abrir soluciones'
$abrir.AutoSize = $true
$abrir.Add_Click({
    $null = New-Item -ItemType Directory -Force -Path $salidas
    Invoke-Item -LiteralPath $salidas
})
$acciones.Controls.Add($abrir)
$verUml = New-Object Windows.Forms.Button
$verUml.Text = 'Ver diagrama'
$verUml.AutoSize = $true
$verUml.Enabled = $false
$verUml.Add_Click({ Invoke-Item -LiteralPath ([string]$verUml.Tag) })
$acciones.Controls.Add($verUml)
$timer.Add_Tick({
    if (!$script:pendiente.IsCompleted) { return }
    $timer.Stop()
    try {
        $datos = $script:worker.EndInvoke($script:pendiente)
        $resultado.Text = ($datos | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        $generado = $datos | Where-Object { $_.ToString().StartsWith('Java compilado y UML generado en ') } | Select-Object -First 1
        if ($generado) {
            $verUml.Tag = Join-Path ($generado.ToString().Substring('Java compilado y UML generado en '.Length)) 'UML.html'
            $verUml.Enabled = Test-Path -LiteralPath ([string]$verUml.Tag)
        }
        $estado.Text = 'Terminado.'
    } catch {
        $errorMotor = $script:worker.Streams.Error | Select-Object -Last 1
        $resultado.Text = if ($errorMotor) { $errorMotor.Exception.Message } else { $_.Exception.GetBaseException().Message }
        $estado.Text = 'La consulta termino con un error.'
    } finally {
        $script:worker.Dispose()
        $script:worker = $null
        $acciones.Enabled = $true
    }
})
$form.Add_FormClosing({
    param($sender, $eventArgs)
    if ($script:worker) {
        $eventArgs.Cancel = $true
        $estado.Text = 'Espera a que termine la consulta antes de cerrar.'
    }
})
try { [void]$form.ShowDialog() } finally { $timer.Dispose(); $form.Dispose() }




