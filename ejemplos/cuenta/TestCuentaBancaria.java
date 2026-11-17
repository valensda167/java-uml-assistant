public class TestCuentaBancaria {
    public static void main(String[] args) {
        CuentaBancaria c1 = new CuentaBancaria("Ana", 100);
        c1.depositar(50);
        c1.mostrarDatos();
    }
}
