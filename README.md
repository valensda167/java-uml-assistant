# Java UML Assistant

Herramientas para practicar POO en Java con la guía de estilo de este repositorio. Requiere JDK 17 o posterior. Los modos de IA preparan una consulta para pegar en Codex. El conversor Java a Mermaid funciona localmente.

## Probar el ejemplo

```powershell
javac -d build ejemplos/empleado/Empleado.java ejemplos/empleado/TestEmpleado.java
java -cp build TestEmpleado
java JavaUml.java ejemplos/empleado/Empleado.java ejemplos/empleado/TestEmpleado.java |
    Set-Content ejemplos/empleado/UML.md -Encoding UTF8
```

Consulta el [diagrama del ejemplo](ejemplos/empleado/UML.md). El conversor lee clases de nivel superior, atributos, constructores, métodos, herencia e interfaces declaradas. Las asociaciones y multiplicidades quedan para una siguiente versión.

## Resolver, revisar y practicar

Desde la carpeta principal, genera una consulta y pégala en Codex usando el comando `asistente` de WezTerm.

```powershell
.\PrepararConsulta.ps1 -Modo resolver -Enunciado ejemplos/empleado/enunciado.txt
.\PrepararConsulta.ps1 -Modo revisar -Enunciado ejemplos/empleado/enunciado.txt -Codigo ejemplos/empleado/Empleado.java
.\PrepararConsulta.ps1 -Modo practicar -Enunciado ejemplos/empleado/enunciado.txt
```

Si PowerShell restringe la ejecución de scripts, abre el repositorio en Codex y pídele que use `estilo.txt` y el ejemplo de `ejemplos/empleado` como referencia para el modo elegido.

## Cómo funciona

`estilo.txt` guarda la guía. `PrepararConsulta.ps1` combina esa guía, el enunciado, el ejemplo elegido y la instrucción del modo. En modo revisar también incluye los archivos que indiques con `-Codigo`. Pega el resultado en Codex para obtener código, una revisión o una pista.

Elige la referencia con `-Referencia empleado`, `-Referencia alumno` o `-Referencia curso`. Por ejemplo:

```powershell
.\PrepararConsulta.ps1 -Modo resolver -Enunciado ejercicio.txt -Referencia curso
```

Los ejemplos Alumno y TestCurso son copias de los proyectos de NetBeans. Sus enunciados son resúmenes del código existente. Alumno muestra encapsulamiento y matrícula. TestCurso muestra herencia de Persona a Instructor. El conversor genera Mermaid desde las declaraciones Java, de modo que puedes regenerar el diagrama después de editar el código.


## IA local con Ollama

Con Ollama abierto y el modelo descargado, ejecuta desde esta carpeta:

```powershell
.\AsistenteLocal.ps1 -Modo practicar -Enunciado ejemplos/empleado/enunciado.txt
```

También puedes usar `resolver` o `revisar`. Para revisar agrega `-Codigo ruta/Archivo.java`. Usa `-Modelo` para elegir otro modelo instalado. La consulta se envía a Ollama en 127.0.0.1 y la respuesta se muestra como texto. Revisa y compila cualquier código generado antes de usarlo.

La carpeta local `ejemplos/netbeans` admite una subcarpeta por proyecto con sus archivos Java. El asistente elige una referencia adicional por coincidencias entre el enunciado y los nombres de clases. Puedes usar los ejemplos incluidos aunque esa carpeta no exista. Las copias privadas quedan fuera de Git.

## Verificación reproducible

Ejecuta `./VerificarEjemplo.ps1` desde PowerShell. Compila el ejemplo incluido, comprueba el resultado de un empleado con diez horas extras y regenera el diagrama Mermaid si la prueba pasa.

## Inicio rápido en Windows

Desde PowerShell con JDK 17 o posterior:

```powershell
git clone https://github.com/valensda167/java-uml-assistant.git
cd java-uml-assistant
.\VerificarEjemplo.ps1
```

La verificación compila los tres ejemplos, comprueba dos resultados del sueldo
y valida el UML de herencia de Instructor. Ollama solo se necesita para
`AsistenteLocal.ps1`.

## Del enunciado a Java y Mermaid

```powershell
.\AsistenteLocal.ps1 -Texto 'Crea una clase Rectangulo con base, altura y un metodo calcularArea.'
```

También puedes usar `-Enunciado .\ejercicio.txt`. El modo resolver guarda el
enunciado, la respuesta original y los archivos Java en una carpeta nueva bajo
`soluciones/`. Genera `UML.md` a partir del Java si la compilación pasa.
La compilación verifica la estructura del código. Revisa que la solución cumpla
el ejercicio y prueba los resultados antes de entregarla.

## Demo de Two Sum

```powershell
.\EjecutarDosSuma.ps1
```

Compila la solución y ejecuta cuatro pruebas de índices, con duplicados,
negativos y valores extremos. Al terminar, muestra el diagrama Mermaid.
La demo funciona con el JDK y usa código incluido en el repositorio.

## Aplicación de escritorio

Abre `Abrir-Java-UML.cmd` en Windows. Pega el enunciado y elige **Generar Java y UML**, **Revisar Java** o **Pedir una pista**. Los ejercicios generados quedan en `soluciones/`. La app usa Ollama local, las reglas de estilo, una síntesis de teoría y ejemplos seleccionados. Estas referencias se incluyen en la consulta. El modelo conserva sus pesos originales.

## Referencias de diseño

- [MagicUML](https://github.com/xukmin/magicuml) inspira la generación de diagramas desde declaraciones Java. El conversor de este proyecto usa el árbol sintáctico de javac y produce Mermaid.
- [JADX](https://github.com/skylot/jadx) sirve como referencia para distinguir la decompilación de Android del análisis de código fuente Java. El flujo de ejercicios trabaja con los archivos fuente generados localmente.
