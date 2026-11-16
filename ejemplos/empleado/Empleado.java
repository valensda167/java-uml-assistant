public class Empleado {
    private String nombre;
    private double sueldoBase;
    private int horasExtras;

    public Empleado(String nombre, double sueldoBase, int horasExtras) {
        this.nombre = nombre;
        this.sueldoBase = sueldoBase;
        this.horasExtras = horasExtras;
    }

    public double calcularPagoExtras() {
        return horasExtras * 20.0;
    }

    public double calcularSueldoTotal() {
        return sueldoBase + calcularPagoExtras();
    }

    public void mostrarDatos() {
        System.out.println(nombre + " - S/ " + calcularSueldoTotal());
    }
}
