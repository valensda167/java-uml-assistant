import java.util.Arrays;

class VerificarDosSuma {
    static void verificar(int[] numeros, int objetivo, int... esperado) {
        if (!Arrays.equals(Solution.twoSum(numeros, objetivo), esperado)) {
            throw new AssertionError("Indices incorrectos");
        }
    }

    public static void main(String[] args) {
        verificar(new int[]{2, 7, 11, 15}, 9, 0, 1);
        verificar(new int[]{3, 3}, 6, 0, 1);
        verificar(new int[]{-3, 4, 3, 90}, 0, 0, 2);
        verificar(new int[]{Integer.MAX_VALUE, 1, Integer.MIN_VALUE, 0}, Integer.MIN_VALUE, 2, 3);
        System.out.println("Cuatro casos correctos");
    }
}
