
package com.mycompany.alumno;


import java.util.ArrayList;

public class Alumno {

    private int codigo;
    private String nombre;
    private String apellido;

    public Alumno(int codigo, String nombre, String apellido) {
        this.codigo = codigo;
        this.nombre = nombre;
        this.apellido = apellido;
    }

    public int getCodigo() {
        return codigo;
    }

    public void setCodigo(int codigo) {
        this.codigo = codigo;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public String getApellido() {
        return apellido;
    }

    public void setApellido(String apellido) {
        this.apellido = apellido;
    }
}

class Curso {

    private int codigo;
    private String nombre;
    private int creditos;

    public Curso(int codigo, String nombre, int creditos) {
        this.codigo = codigo;
        this.nombre = nombre;
        this.creditos = creditos;
    }

    public int getCodigo() {
        return codigo;
    }

    public void setCodigo(int codigo) {
        this.codigo = codigo;
    }

    public String getNombre() {
        return nombre;
    }

    public void setNombre(String nombre) {
        this.nombre = nombre;
    }

    public int getCreditos() {
        return creditos;
    }

    public void setCreditos(int creditos) {
        this.creditos = creditos;
    }
}

class Matricula {

    private int numero;
    private String fecha;
    private Alumno alumno;
    private ArrayList<Curso> cursos;

    public Matricula(int numero, String fecha, Alumno alumno) {
        this.numero = numero;
        this.fecha = fecha;
        this.alumno = alumno;
        this.cursos = new ArrayList<>();
    }

    public int getNumero() {
        return numero;
    }

    public void setNumero(int numero) {
        this.numero = numero;
    }

    public String getFecha() {
        return fecha;
    }

    public void setFecha(String fecha) {
        this.fecha = fecha;
    }

    public Alumno getAlumno() {
        return alumno;
    }

    public void setAlumno(Alumno alumno) {
        this.alumno = alumno;
    }

    public ArrayList<Curso> getCursos() {
        return cursos;
    }

    public void agregarCurso(Curso curso) {
        cursos.add(curso);
    }

    public void mostrarDatos() {
        System.out.println("Numero de matricula: " + numero);
        System.out.println("Fecha: " + fecha);
        System.out.println("Codigo: " + alumno.getCodigo());
        System.out.println("Alumno: " + alumno.getNombre() + " " + alumno.getApellido());

        System.out.println("Cursos matriculados:");

        for (int i = 0; i < cursos.size(); i++) {
            System.out.println("Codigo: " + cursos.get(i).getCodigo());
            System.out.println("Curso: " + cursos.get(i).getNombre());
            System.out.println("Creditos: " + cursos.get(i).getCreditos());
        }
    }
}
