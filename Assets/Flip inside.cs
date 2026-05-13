using UnityEngine;

public class FlipInside : MonoBehaviour
{
    void Start()
    {
        Mesh mesh = GetComponent<MeshFilter>().mesh;
        
        // 표면이 안쪽을 향하도록 껍질을 뒤집습니다
        int[] triangles = mesh.triangles;
        for (int i = 0; i < triangles.Length; i += 3)
        {
            int temp = triangles[i + 0];
            triangles[i + 0] = triangles[i + 1];
            triangles[i + 1] = temp;
        }
        mesh.triangles = triangles;
    }
}