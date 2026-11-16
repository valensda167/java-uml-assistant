
package com.mycompany.testcurso;




public class Curso {

    public String nombreCurso;
    public int duracion;
    public double costo;
    public Instructor instructor;

    public Curso(String nombreCurso, int duracion, double costo,
            Instructor instructor) {
        this.nombreCurso = nombreCurso;
        this.duracion = duracion;
        this.costo = costo;
        this.instructor = instructor;
    }

    public void mostrarDatos() {
        System.out.println("Curso: " + nombreCurso);
        System.out.println("Duracion: " + duracion);
        System.out.println("Costo: " + costo);
        System.out.println("Instructor: " + instructor.nombre);
    }
}

class Persona {

    public String nombre;

    public Persona(String nombre) {
        this.nombre = nombre;
    }
}

class Instructor extends Persona {

    public String especialidad;

    public Instructor(String nombre, String especialidad) {
        super(nombre);
        this.especialidad = especialidad;
    }
}

class Inscripcion {

    public Persona estudiante;
    public Curso curso;

    public Inscripcion(Persona estudiante, Curso curso) {
        this.estudiante = estudiante;
        this.curso = curso;
    }

    public void mostrarDatos() {
        System.out.println("Estudiante: " + estudiante.nombre);
        System.out.println("Curso: " + curso.nombreCurso);
    }
}
