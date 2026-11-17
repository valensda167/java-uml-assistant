# Java UML Assistant

Aplicacion de escritorio para convertir un enunciado en Java y UML Mermaid siguiendo `estilo.txt` y ejemplos personales. Funciona en Windows con **JDK 17+**, Windows PowerShell 5.1 o PowerShell 7 y **Ollama**. El modelo preferido es `qwen2.5-coder:1.5b`; si falta utiliza `qwen2.5-coder:0.5b` cuando esta instalado.

## Abrir y resolver

1. Abre `Abrir-Java-UML.cmd` o el acceso directo existente.
2. Pega el enunciado completo, incluidos nombres y condiciones.
3. Opcionalmente carga un contrato JSON con **Cargar requisitos**. Hay uno en `ejemplos/cuenta/requisitos.json`. Revisa sus casos antes de usarlos.
4. Pulsa **Generar Java y UML**. El estado indica generacion, compilacion, reparacion y verificacion.
5. En **Java** selecciona el archivo del objeto o su `TestObjeto`; en **UML Mermaid** copia el diagrama. **Ver diagrama** abre la representacion grafica local.
6. **Ejecutar Test** compila y ejecuta los programas `Test*.java` en otra ventana. Cada ejecucion tiene un limite de 15 segundos y no admite entrada interactiva con Scanner.

**Copiar pestana**, **Guardar pestana** y **Abrir soluciones** permiten reutilizar los resultados. La pestana **Registro** muestra errores y la carpeta con todos los intentos. La ventana espera a que termine la consulta para cerrarse; cada llamada a Ollama tiene un limite de 240 segundos.

El lanzador aplica `ExecutionPolicy Bypass` solo al proceso que abre esta aplicacion; no cambia la politica de Windows de forma permanente.

## Que se comprueba

- Java compilable, separado en archivos por clase.
- Pareja `Objeto.java` y `TestObjeto.java` con `main(String[])` publico y estatico que crea el objeto. `-SinTest` permite ejercicios cuya organizacion sea distinta.
- Con un contrato: clases, atributos, visibilidad, firmas, constructores, herencia, interfaces y los casos Java que proporciona el usuario.
- Sin contrato: se indica explicitamente que **el cumplimiento del enunciado esta pendiente**.

Compilar no demuestra que el ejercicio este resuelto. Un contrato tampoco demuestra comportamientos no incluidos en sus casos. El modelo no genera automaticamente expectativas que luego presente como verdad. El contrato puede editarse en la pestana **Requisitos**; el ejemplo de CuentaBancaria explica su formato. Para clases dentro de un paquete agrega `"paquete":"nombre.del.paquete"` al contrato.

Los casos y programas generados se ejecutan en tu equipo con tu usuario. El limite de tiempo y memoria no es un aislamiento de seguridad. Revisa codigo y contratos de fuentes desconocidas antes de ejecutarlos. No se envian datos a servicios externos en la configuracion local predeterminada.

## Consola PowerShell

Desde la carpeta del proyecto:

```powershell
.\AsistenteLocal.ps1 -Texto 'Crea Rectangulo con base, altura, calcularArea y TestRectangulo.'
.\AsistenteLocal.ps1 -Enunciado ejemplos/cuenta/enunciado.txt -Requisitos ejemplos/cuenta/requisitos.json
.\AsistenteLocal.ps1 -Modo practicar -Texto 'Como separo el modelo y el main?'
.\AsistenteLocal.ps1 -Modo revisar -Texto 'Revisa este ejercicio' -Codigo .\Objeto.java
.\EjecutarSolucion.ps1 -Carpeta .\soluciones\ID
```

`-Modelo` selecciona un modelo instalado. `-SinFormatoJson` admite proveedores o modelos que no soporten el esquema JSON; el parser tambien reconoce bloques Markdown Java. `-UrlOllama` permite un servidor alternativo o uno simulado para pruebas. Cambiar esta direccion puede enviar enunciado, guia y ejemplos al servidor indicado.

## Arquitectura

- `Aplicacion.ps1`: ventana y trabajo en segundo plano.
- `Flujo.ps1`: devuelve un objeto y guarda `resultado.json`, sin depender de la ventana.
- `AsistenteLocal.ps1`: entrada de consola compatible con `-Texto` y `-Enunciado`.
- `Verificar.ps1`: compara la estructura con el contrato y ejecuta casos acotados.
- `Procesos.ps1`: captura salidas de Java/javac y limita tiempos.
- `JavaUml.java`: parser con el AST de javac; separacion, inspeccion JSON y UML.
- `PrepararConsulta.ps1`: preparacion manual de consultas para otros asistentes; no integra ni paga una API.

Para reducir el consumo de memoria se utiliza una ventana de contexto de 4096 tokens y se pide a Ollama descargar el modelo de memoria tras cada respuesta. Esto puede aumentar el tiempo de inicio de la siguiente consulta, pero deja memoria disponible para Java y la ventana. El conversor UML se compila una vez por version de su fuente y se reutiliza desde build/.

El flujo pide JSON `{archivos:[{nombre,contenido}]}`, conserva la respuesta original, separa clases, compila con `-proc:none`, genera UML y verifica. Conserva cada intento en su propia carpeta. Repara hasta tres veces como maximo y se detiene si se repite el diagnostico. Para errores de compilacion con archivo identificable solicita solo los archivos afectados y conserva los demas; para errores estructurales o de requisitos solicita una solucion completa. Se registra el intento con mas comprobaciones aprobadas. Respuestas vacias, truncadas y problemas de conexion tienen diagnosticos propios.

La guia se incluye de forma acotada para reservar contexto al enunciado y la respuesta. Se adjunta teoria y hasta dos ejemplos pertinentes de `ejemplos/netbeans`; si no hay coincidencias se utiliza Empleado. Esto **no entrena ni modifica los pesos** del modelo. Un modelo de 1.5B puede fallar con problemas largos; no hay promesa de resolver cualquier ejercicio.

## UML

Cada solucion correcta incluye:

- `UML.md`: clases y dependencias de pruebas.
- `UML-modelo.md`: excluye clases con prefijo Test.
- `UML-resumen.md`: modelo sin miembros.
- `UML-pruebas.md`: cajas y dependencias de creacion desde los Test.
- `UML.html` y `mermaid.min.js`: visualizacion sin conexion.

Incluye herencia, interfaces, visibilidad, marcadores abstract/interface/enumeration y static/abstract. Detecta asociaciones directas, arreglos, colecciones, valores de Map y Optional. Usa `0..*` para colecciones y `0..1` para Optional; **no infiere composicion ni obligatoriedad del dominio**. Incluye hash SHA-256 de las fuentes. Java escribe UTF-8 directamente para conservar nombres con tildes.

```powershell
java JavaUml.java --modelo --salida UML.md Objeto.java TestObjeto.java
java JavaUml.java --inspeccionar --salida Estructura.json Objeto.java TestObjeto.java
```

Limitaciones: analisis de tipos de nivel superior, reconocimiento de relaciones por nombres simples y comprobacion exacta de firmas en los contratos. No es un analizador semantico completo. La deduccion automatica de imports cubre tipos habituales del JDK; otros errores se devuelven al modelo.

## Pruebas

```powershell
.\VerificarEjemplo.ps1
.\EjecutarDosSuma.ps1
.\pruebas\VerificarFlujo.ps1
```

Las primeras comprueban Empleado (dos sueldos), Alumno, Curso con herencia y cuatro casos de Two Sum. La ultima usa un servidor Ollama simulado local: no descarga modelos ni requiere IA. Comprueba contrato correcto, bugs de logica y firmas, truncamiento, respuesta vacia, bloques con varias clases, imports, ausencia de Test, falta de contrato, conexion fallida, UML y tiempo limite. Conserva evidencia bajo `soluciones/pruebas-*`.

`soluciones/`, `build/`, `.class` y `ejemplos/netbeans/` quedan fuera de Git. No guardes claves de API en el repositorio publico.

## Referencias

[MagicUML](https://github.com/xukmin/magicuml) inspira la conversion de declaraciones a diagramas. [JADX](https://github.com/skylot/jadx) es una referencia de decompilacion Android; no es una dependencia ni un entrenador. Este proyecto analiza fuentes Java con javac y utiliza Mermaid distribuido en `vendor/` con su licencia.
