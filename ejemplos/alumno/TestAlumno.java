
package com.mycompany.alumno;

import java.util.ArrayList;

public class TestAlumno {

    public static void main(String[] args) {

        Alumno a1 = new Alumno(101, "Carlos", "Perez");
        Alumno a2 = new Alumno(102, "Maria", "Lopez");

        Curso c1 = new Curso(201, "Programacion Java", 4);
        Curso c2 = new Curso(202, "Matematica", 4);
        Curso c3 = new Curso(203, "Base de Datos", 3);

        Matricula m1 = new Matricula(1, "13/11/2026", a1);
        Matricula m2 = new Matricula(2, "13/11/2026", a2);

        m1.agregarCurso(c1);
        m1.agregarCurso(c2);
        m1.agregarCurso(c3);

        m2.agregarCurso(c1);
        m2.agregarCurso(c3);

        ArrayList<Matricula> lista = new ArrayList<>();

        lista.add(m1);
        lista.add(m2);

        for (int i = 0; i < lista.size(); i++) {
            lista.get(i).mostrarDatos();
        }

        m1.setFecha("14/11/2026");
        a1.setApellido("Ramirez");

        System.out.println("Matricula actualizada");
        m1.mostrarDatos();
    }
}
