

package com.mycompany.testcurso;

import java.util.ArrayList;

public class TestCurso {

    public static void main(String[] args) {

        ArrayList<Curso> lista = new ArrayList<>();
       
        Instructor i1 = new Instructor("Juan", "Programacion");
        Instructor i2 = new Instructor("Ana", "Matematicas");

        Curso c1 = new Curso("Java", 40, 250, i1);
        Curso c2 = new Curso("Calculo", 30, 180, i2);
        
        lista.add(c1);
        lista.add(c2);
        
        for (Curso c : lista) {
            c.mostrarDatos();
        }

        Persona p1 = new Persona("Carlos");
        Persona p2 = new Persona("Maria");

        Inscripcion ins1 = new Inscripcion(p1, c1);
        Inscripcion ins2 = new Inscripcion(p2, c2);

        ArrayList<Inscripcion> inscripciones = new ArrayList<>();

        inscripciones.add(ins1);
        inscripciones.add(ins2);

        for (Inscripcion ins : inscripciones) {
            ins.mostrarDatos();
        }
    }
}