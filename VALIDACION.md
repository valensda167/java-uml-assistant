# Validacion de la mejora (16 de noviembre de 2026)

## Comprobado

- Windows PowerShell 5.1: diez escenarios del flujo con un servidor Ollama simulado, incluidos errores de firma, errores de logica, respuestas vacias/truncadas, imports y ausencia de Test.
- Parser Java: Map, Optional, interfaces, clases abstractas, enumeraciones, modificadores, nombres con tildes, hash de fuentes y conservacion de Javadoc.
- Limite de ejecucion: un bucle infinito compilado fue interrumpido; se comprobo que no quedaron sus procesos Java activos.
- Interfaz: apertura y captura de la ventana en Windows PowerShell; tamano adaptado al escritorio.
- Mermaid: el HTML de CuentaBancaria se renderizo como SVG en Chrome sin error de sintaxis.
- Ollama real con qwen2.5-coder:1.5b: CuentaBancaria y TestCuentaBancaria se generaron en un intento, compilaron y aprobaron las 14 comprobaciones del contrato incluido. El Test tambien se ejecuto desde PowerShell.
- Regresiones existentes: Empleado, Alumno, Curso y los cuatro casos de Two Sum.

## Limites

Estas pruebas no garantizan que el modelo resuelva cualquier enunciado. Durante el desarrollo tambien omitio una clase Test y devolvio un retorno distinto al contrato; ambos errores fueron detectados. El estado final distingue compilacion, verificaciones declaradas y requisitos pendientes.

Los casos ejecutan Java local con limite de tiempo y memoria, sin aislamiento de permisos. La captura de la ventana comprueba su construccion y presentacion; no equivale a una prueba automatizada de todos los clics.

## Repetir

```powershell
.\VerificarEjemplo.ps1
.\EjecutarDosSuma.ps1
.\pruebas\VerificarFlujo.ps1
.\pruebas\VerificarFlujo.ps1 -SoloReparacion
.\AsistenteLocal.ps1 -Enunciado ejemplos/cuenta/enunciado.txt -Requisitos ejemplos/cuenta/requisitos.json
```

Las respuestas, diagnosticos y resultados detallados se conservan en `soluciones/` y no se publican. `pruebas-completadas.json` acredita la finalizacion de la bateria simulada.
