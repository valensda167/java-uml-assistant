import java.util.HashMap;
import java.util.Map;

public class Solution {
    public static int[] twoSum(int[] nums, int target) {
        Map<Long, Integer> indices = new HashMap<>();

        for (int i = 0; i < nums.length; i++) {
            long complemento = (long) target - nums[i];
            Integer indiceAnterior = indices.get(complemento);
            if (indiceAnterior != null) {
                return new int[]{indiceAnterior, i};
            }
            indices.put((long) nums[i], i);
        }

        throw new IllegalArgumentException("No hay dos elementos que sumen el objetivo.");
    }
}
