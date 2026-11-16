public class TestEmpleado {
    public static void main(String[] args) {
        Empleado e1 = new Empleado("Carlos", 1500, 10);
        e1.mostrarDatos();
        Empleado sinExtras = new Empleado("Ana", 1500, 0);
        sinExtras.mostrarDatos();
    }
}

