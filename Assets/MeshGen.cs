using UnityEngine;
using System;
using System.IO;
using System.Text;
using System.Collections;
using System.Collections.Generic;

public class MeshGen : MonoBehaviour {
    public Material baseMaterial;

	void Start () {
        Mesh mesh = new Mesh();

        var materials = LoadLevel(mesh, LevelDefs.Defs[LevelDefs.CurrentLevel]);

        mesh.RecalculateBounds();

        // TODO: fix skybox and floor for levels that need it
        // TODO: locomotion
        // TODO: more maps
        // TODO: fix teleportation falling through floor sometimes
        // TODO: investigate Zelda OOT

        GetComponent<MeshFilter>().mesh = mesh;

        GetComponent<MeshCollider>().sharedMesh = mesh;

        GetComponent<MeshRenderer>().materials = materials;

        if (LevelDefs.Defs[LevelDefs.CurrentLevel].Indoor)
            GameObject.FindWithTag("DirectionalLight").SetActive(false);
	}

    private Material[] LoadLevel(Mesh mesh, LevelDef def) {
        int num = def.Index;

        List<Vector3> vertices = new List<Vector3>();
        List<Vector2> uv = new List<Vector2>();
        List<List<int>> triangles = new List<List<int>>();

        Dictionary<int, Material> materialdict = new Dictionary<int, Material>();
        List<Material> materials = new List<Material>();

        var path = Application.dataPath + @"\..\M64_Levels";
        var transpath = Application.dataPath + @"\..\transparent.txt";

        var transparent = new HashSet<string>();
        using (StreamReader sr = new StreamReader(transpath, Encoding.ASCII)) {
            string line;
            while ((line = sr.ReadLine()) != null) {
                var c = line.Split(',');
                transparent.Add(c[0]);
            }
        }

        using (StreamReader sr = new StreamReader(string.Format(@"{0}\{1}\model.obj", path, num))) {
            string line;
            List<int> currentTris = null;
            while ((line = sr.ReadLine()) != null) {
                line = line.Trim();
                if (line.StartsWith("usemtl mat")) {
                    if (triangles.Count > 0 && triangles[triangles.Count - 1].Count == 0) {
                        triangles.RemoveAt(triangles.Count - 1);
                        materials.RemoveAt(materials.Count - 1);
                    }

                    currentTris = new List<int>();

                    int matnum = int.Parse(line.Substring("usemtl mat".Length));

                    if (!def.RemoveMats.Contains(matnum)) {
                        Material mat;
                        if (materialdict.ContainsKey(matnum)) {
                            mat = materialdict[matnum];
                        } else {
                            var tex = new Texture2D(0, 0, TextureFormat.ARGB32, false);
                            
                            byte[] pngdata;
                            using (FileStream p = File.OpenRead(string.Format(@"{0}\{1}\{2}.png", path, num, matnum))) {
                                pngdata = new byte[p.Length];
                                p.Read(pngdata, 0, pngdata.Length);
                            }
                            tex.LoadImage(pngdata);
 
                            mat = new Material(baseMaterial);
                            if (transparent.Contains(string.Format(@"{0}\{1}.bmp", num, matnum))) {
                                mat.shader = Shader.Find("Unlit/Transparent");
                            }
                            mat.mainTexture = tex;
                            mat.name = matnum.ToString();
                        }
                        materials.Add(mat);

                        triangles.Add(currentTris);
                    }
                } else if (line.StartsWith("v ")) {
                    var c = line.Substring("v ".Length).Split(' ');
                    vertices.Add(new Vector3(float.Parse(c[0]), float.Parse(c[1]), float.Parse(c[2])));
                } else if (line.StartsWith("vt ")) {
                    var c = line.Substring("vt ".Length).Split(' ');
                    uv.Add(new Vector2(float.Parse(c[0]), float.Parse(c[1])));
                } else if (line.StartsWith("f ")) {
                    foreach (var t in line.Substring("f ".Length).Split(' ')) {
                        currentTris.Add(int.Parse(t.Split('/')[0]) - 1);
                    }
                }
            }
        }

        // now duplicate everything with reverse winding order, so we always show back faces
        var origlen = vertices.Count;
        for (var i = 0; i < origlen; i++)
            vertices.Add(vertices[i]);
        for (var i = 0; i < origlen; i++)
            uv.Add(uv[i]);
        foreach (var tris in triangles) {
            var trilen = tris.Count;
            for (var i = 0; i < trilen; i += 3) {
                tris.Add(tris[i] + origlen);
                tris.Add(tris[i + 2] + origlen);
                tris.Add(tris[i + 1] + origlen);
            }
        }

        mesh.subMeshCount = triangles.Count;
        mesh.vertices = vertices.ToArray();
        mesh.uv = uv.ToArray();
        for (var i = 0; i < triangles.Count; i++)
            mesh.SetTriangles(triangles[i].ToArray(), i);

        return materials.ToArray();
    }
}
