param([string]$Captura)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = 'Java UML Assistant - Codigo, UML y verificacion'
$pantalla = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Size = New-Object Drawing.Size([Math]::Min(1080,$pantalla.Width-30), [Math]::Min(800,$pantalla.Height-30))
$form.MinimumSize = New-Object Drawing.Size(800, 580)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)
$layout = New-Object Windows.Forms.TableLayoutPanel
$layout.Dock='Fill'; $layout.Padding=16; $layout.ColumnCount=1; $layout.RowCount=5
foreach ($height in @(30,25,80,30,75)) {
 $s=New-Object Windows.Forms.RowStyle
 $s.SizeType=if ($height -in @(25,75)) {'Percent'} else {'Absolute'}
 $s.Height=$height; [void]$layout.RowStyles.Add($s)
}
$form.Controls.Add($layout)
$label=New-Object Windows.Forms.Label
$label.Text='Enunciado: pega el problema y conserva los nombres y reglas que pide el profesor.'
$label.Dock='Fill'; $layout.Controls.Add($label,0,0)
function Editor {
 $e=New-Object Windows.Forms.TextBox
 $e.Multiline=$true; $e.AcceptsTab=$true; $e.ScrollBars='Both'; $e.Dock='Fill'
 $e.Font=New-Object Drawing.Font('Consolas',10); return $e
}
$entrada=Editor; $layout.Controls.Add($entrada,0,1)
$acciones=New-Object Windows.Forms.FlowLayoutPanel
$acciones.Dock='Fill'; $layout.Controls.Add($acciones,0,2)
$estado=New-Object Windows.Forms.Label
$estado.Text='Listo. IA local. Los requisitos son opcionales, pero necesarios para verificar el ejercicio.'
$estado.Dock='Fill'; $layout.Controls.Add($estado,0,3)
$tabs=New-Object Windows.Forms.TabControl
$tabs.Dock='Fill'; $layout.Controls.Add($tabs,0,4)
$editores=@{}
foreach ($nombre in @('Java','UML Mermaid','Verificacion','Requisitos','Registro')) {
 $p=New-Object Windows.Forms.TabPage; $p.Text=$nombre
 $e=Editor; $e.ReadOnly=$nombre -ne 'Requisitos'; $p.Controls.Add($e)
 $editores[$nombre]=$e; $tabs.TabPages.Add($p)
}
$archivos=New-Object Windows.Forms.ComboBox
$archivos.Dock='Top'; $archivos.DropDownStyle='DropDownList'
$tabs.TabPages[0].Controls.Add($archivos)
$archivos.Add_SelectedIndexChanged({
 if ($archivos.SelectedItem) { $editores['Java'].Text=Get-Content -LiteralPath ([string]$archivos.SelectedItem) -Raw -Encoding UTF8 }
})
$editores['Requisitos'].Text=''
$editores['Verificacion'].Text='Sin requisitos no se puede afirmar que el codigo resuelva todo el enunciado. Usa Cargar requisitos para abrir un contrato JSON. Los casos del contrato ejecutan Java local con limite de tiempo; carga solo casos que hayas revisado.'
$script:worker=$null; $script:pendiente=$null; $script:ultimo=$null
$salidas=Join-Path $PSScriptRoot 'soluciones'
$motor=Join-Path $PSScriptRoot 'Flujo.ps1'
$timer=New-Object Windows.Forms.Timer; $timer.Interval=350
function Boton([string]$Texto, [scriptblock]$Accion) {
 $b=New-Object Windows.Forms.Button; $b.Text=$Texto; $b.AutoSize=$true
 $b.Add_Click($Accion); $acciones.Controls.Add($b); return $b
}
foreach ($opcion in @(@('resolver','Generar Java y UML'),@('revisar','Revisar Java'),@('practicar','Pedir pista'))) {
 $b=Boton $opcion[1] {
  param($sender,$eventArgs)
  if ([string]::IsNullOrWhiteSpace($entrada.Text)) { $estado.Text='Escribe el enunciado primero.'; return }
  $codigo=@()
  if ($sender.Tag -eq 'revisar') {
   $d=New-Object Windows.Forms.OpenFileDialog; $d.Filter='Java|*.java'; $d.Multiselect=$true
   try { if ($d.ShowDialog() -ne 'OK') { return }; $codigo=@($d.FileNames) } finally {$d.Dispose()}
  }
  $null=New-Item -ItemType Directory -Path $salidas -Force
  $requisitos=$null
  if (![string]::IsNullOrWhiteSpace($editores['Requisitos'].Text)) {
   try { $null=$editores['Requisitos'].Text | ConvertFrom-Json } catch {$estado.Text='El JSON de requisitos no es valido. Corrigelo en la pestana Requisitos.'; return}
   $requisitos=Join-Path $salidas ('contrato-'+[guid]::NewGuid()+'.json')
   $editores['Requisitos'].Text | Set-Content $requisitos -Encoding UTF8
  }
  $script:estadoArchivo=Join-Path $salidas ('estado-'+[guid]::NewGuid()+'.txt')
  $script:ultimo=$null; $verUml.Enabled=$false; $ejecutar.Enabled=$false
  $archivos.Items.Clear(); $editores['Java'].Clear(); $editores['UML Mermaid'].Clear()
  $editores['Verificacion'].Clear(); $editores['Registro'].Clear()
  $acciones.Enabled=$false; $estado.Text='Preparando consulta...'
  $script:worker=[PowerShell]::Create()
  [void]$script:worker.AddScript({param($motor,$modo,$texto,$codigo,$salidas,$requisitos,$estado)
   & $motor -Texto $texto -Modo $modo -Codigo $codigo -Salida $salidas -Requisitos $requisitos -EstadoArchivo $estado
  }).AddArgument($motor).AddArgument([string]$sender.Tag).AddArgument($entrada.Text).AddArgument($codigo).AddArgument($salidas).AddArgument($requisitos).AddArgument($script:estadoArchivo)
  $script:pendiente=$script:worker.BeginInvoke(); $timer.Start()
 }
 $b.Tag=$opcion[0]
}
$null=Boton 'Cargar requisitos' {
 $d=New-Object Windows.Forms.OpenFileDialog; $d.Filter='Contrato JSON|*.json'; $d.InitialDirectory=Join-Path $PSScriptRoot 'ejemplos'
 try {if ($d.ShowDialog() -eq 'OK') {$editores['Requisitos'].Text=Get-Content $d.FileName -Raw -Encoding UTF8; $tabs.SelectedIndex=3}} finally {$d.Dispose()}
}
$null=Boton 'Copiar pestana' {
 $e=$editores[$tabs.SelectedTab.Text]
 if ($e.Text) {[Windows.Forms.Clipboard]::SetText($e.Text)}
}
$null=Boton 'Guardar pestana' {
 $d=New-Object Windows.Forms.SaveFileDialog; $d.Filter='Texto|*.txt|Java|*.java|Mermaid|*.md|JSON|*.json'
 try {if ($d.ShowDialog() -eq 'OK') {[IO.File]::WriteAllText($d.FileName,$editores[$tabs.SelectedTab.Text].Text,[Text.UTF8Encoding]::new($false))}} finally {$d.Dispose()}
}
$null=Boton 'Abrir soluciones' {
 $null=New-Item -ItemType Directory -Path $salidas -Force
 if ($script:ultimo) {Invoke-Item $script:ultimo.Carpeta} else {Invoke-Item $salidas}
}
$verUml=Boton 'Ver diagrama' {Invoke-Item (Join-Path $script:ultimo.Carpeta 'UML.html')}
$verUml.Enabled=$false
$ejecutar=Boton 'Ejecutar Test' {
 $ruta=Join-Path $PSScriptRoot 'EjecutarSolucion.ps1'
 Start-Process powershell.exe -ArgumentList @('-NoProfile','-NoExit','-ExecutionPolicy','Bypass','-File',('"'+$ruta+'"'),'-Carpeta',('"'+$script:ultimo.Carpeta+'"')) -WindowStyle Normal
}
$ejecutar.Enabled=$false
$timer.Add_Tick({
 if (Test-Path $script:estadoArchivo) {try {$estado.Text=Get-Content $script:estadoArchivo -Raw -Encoding UTF8} catch {}}
 if (!$script:pendiente.IsCompleted) {return}
 $timer.Stop()
 try {
  $datos=@($script:worker.EndInvoke($script:pendiente))
  $r=$datos | Where-Object {$_.PSObject.Properties['Exito']} | Select-Object -Last 1
  if (!$r) {throw 'No se recibio resultado del motor.'}
  $script:ultimo=$r; $estado.Text=$r.Mensaje
  foreach ($archivo in $r.Archivos) {[void]$archivos.Items.Add($archivo)}
  if ($archivos.Items.Count) {$archivos.SelectedIndex=0}
  $uml=Join-Path $r.Carpeta 'UML.md'
  if (Test-Path $uml) {$editores['UML Mermaid'].Text=Get-Content $uml -Raw -Encoding UTF8}
  $editores['Verificacion'].Text=$r.Mensaje+"`r`n`r`n"
  if ($r.Verificacion) {
   foreach ($c in $r.Verificacion.Comprobaciones) {
    $editores['Verificacion'].AppendText($(if ($c.Pasa) {'OK  '} else {'FALLO  '})+$c.Nombre+"`r`n")
    if (!$c.Pasa -and $c.Detalle) {$editores['Verificacion'].AppendText('  '+$c.Detalle+"`r`n")}
   }
   $editores['Verificacion'].AppendText("`r`n"+$r.Verificacion.Nota)
  }
  $editores['Registro'].Text=Get-Content (Join-Path $r.Carpeta 'resultado.json') -Raw -Encoding UTF8
  foreach ($f in Get-ChildItem $r.Carpeta -Filter 'Diagnostico-*.txt') {$editores['Registro'].AppendText("`r`n"+$f.Name+"`r`n"+(Get-Content $f.FullName -Raw -Encoding UTF8))}
  $verUml.Enabled=$r.Exito -and (Test-Path (Join-Path $r.Carpeta 'UML.html'))
  $ejecutar.Enabled=$r.Exito -and $r.Archivos.Count -gt 0
  $tabs.SelectedIndex=if ($r.Exito -and $r.Archivos.Count) {0} else {2}
 } catch {
  $estado.Text='Error. Mira la pestana Registro.'
  $editores['Registro'].Text=$_.Exception.GetBaseException().Message+"`r`n"+($script:worker.Streams.Error -join "`r`n")
  $tabs.SelectedIndex=4
 } finally {
  $script:worker.Dispose(); $script:worker=$null; $acciones.Enabled=$true
 }
})
$form.Add_FormClosing({param($sender,$e) if ($script:worker) {$e.Cancel=$true; $estado.Text='La consulta sigue en curso. Espera a que termine (cada llamada tiene limite de tiempo).'}})
try {
 if ($Captura) {
  $form.Show(); [Windows.Forms.Application]::DoEvents()
  $bitmap=New-Object Drawing.Bitmap($form.Width,$form.Height)
  try {$form.DrawToBitmap($bitmap,$form.ClientRectangle); $bitmap.Save($Captura)} finally {$bitmap.Dispose()}
  if ($tabs.TabPages.Count -ne 5 -or $acciones.Controls.Count -lt 8) {throw 'Faltan controles en la ventana.'}
 } else {[void]$form.ShowDialog()}
} finally {$timer.Dispose(); $form.Dispose()}
