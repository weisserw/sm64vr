using UnityEngine;
using UnityEngine.SceneManagement;
using System.Collections;

public class MenuSelect : MonoBehaviour {
	void Start () {
        GetComponent<SteamVR_SimplePointer>().WorldPointerIn += new WorldPointerEventHandler(MenuSelect_WorldPointerIn);
        GetComponent<SteamVR_SimplePointer>().WorldPointerOut += new WorldPointerEventHandler(MenuSelect_WorldPointerOut);
        GetComponent<SteamVR_SimplePointer>().WorldPointerDestinationSet += new WorldPointerEventHandler(MenuSelect_WorldPointerDestinationSet);
	}

    void MenuSelect_WorldPointerIn(object sender, WorldPointerEventArgs e) {
        foreach (var collider in Physics.OverlapSphere(e.destinationPosition, 0.1f)) {
            var mesh = (TextMesh)collider.GetComponent("TextMesh");
            if (mesh != null) {
                mesh.color = new Color(1, 1, 1);
                return;
            }
        }
    }

    void MenuSelect_WorldPointerOut(object sender, WorldPointerEventArgs e) {
        foreach (var collider in Physics.OverlapSphere(e.destinationPosition, 0.1f)) {
            var mesh = (TextMesh)collider.GetComponent("TextMesh");
            if (mesh != null) {
                mesh.color = new Color(0, 0, 0);
                return;
            }
        }
    }

    void MenuSelect_WorldPointerDestinationSet(object sender, WorldPointerEventArgs e) {
        foreach (var collider in Physics.OverlapSphere(e.destinationPosition, 0.1f)) {
            var mesh = (TextMesh)collider.GetComponent("TextMesh");
            if (mesh != null) {
                LevelDefs.CurrentLevel = mesh.text;
                SceneManager.LoadScene("Level");
                return;
            }
        }
    }
}
