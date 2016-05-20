using UnityEngine;
using UnityEngine.SceneManagement;
using System.Collections;

public class ResetPosition : MonoBehaviour {
    private bool _grabbing = false;
    private bool _using = false;

	void Start () {
        InitControllerListener();

        DoReset();
	}

    private void InitControllerListener() {
        SteamVR_ControllerEvents[] evs = GameObject.FindObjectsOfType<SteamVR_ControllerEvents>();

        if (evs.Length == 0) {
            Invoke("InitControllerListener", 0.25f);
        }

        foreach (SteamVR_ControllerEvents ev in evs) {
            ev.AliasMenuOn += new ControllerClickedEventHandler(MenuPressed);
            ev.AliasGrabOn += new ControllerClickedEventHandler(ev_AliasGrabOn);
            ev.AliasGrabOff += new ControllerClickedEventHandler(ev_AliasGrabOff);
            ev.AliasUseOn += new ControllerClickedEventHandler(ev_AliasUseOn);
            ev.AliasUseOff += new ControllerClickedEventHandler(ev_AliasUseOff);
        }
    }

    void ev_AliasUseOff(object sender, ControllerClickedEventArgs e) {
        _using = false;
    }

    void ev_AliasUseOn(object sender, ControllerClickedEventArgs e) {
        _using = true;
        if (_grabbing)
            DoReset();
    }

    void ev_AliasGrabOff(object sender, ControllerClickedEventArgs e) {
        _grabbing = false;
    }

    void ev_AliasGrabOn(object sender, ControllerClickedEventArgs e) {
        _grabbing = true;
        if (_using)
            DoReset();
    }

    private void DoReset() {
        SteamVR_Fade.Start(Color.black, 0);
        SteamVR_Fade.Start(Color.clear, 0.6f);
        this.transform.position = LevelDefs.Defs[LevelDefs.CurrentLevel].CameraStart;
    }

    private void MenuPressed(object sender, ControllerClickedEventArgs e) {
        SceneManager.LoadScene("Menu");
    }
}
