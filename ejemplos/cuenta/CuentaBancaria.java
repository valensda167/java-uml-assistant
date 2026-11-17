public class CuentaBancaria {
    private String titular;
    private double saldo;
    public CuentaBancaria(String titular, double saldo) {
        this.titular = titular;
        this.saldo = saldo;
    }
    public void depositar(double monto) {
        if (monto > 0) saldo += monto;
    }
    public boolean retirar(double monto) {
        if (monto <= 0 || monto > saldo) return false;
        saldo -= monto;
        return true;
    }
    public double getSaldo() { return saldo; }
    public void mostrarDatos() { System.out.println(titular + ": " + saldo); }
}
