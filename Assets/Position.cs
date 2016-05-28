using UnityEngine;
using UnityEngine.SceneManagement;
using System.Collections;

public class Position : MonoBehaviour {
    private bool _grabbing = false;
    private bool _using = false;
    private bool _flying = false;
    private bool _resetrotate = false;
    private bool _rotateleft = false;
    private bool _rotateright = false;
    private Transform eyeCamera;

	void Start () {
        eyeCamera = GameObject.FindObjectOfType<SteamVR_Camera>().GetComponent<Transform>();

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
            ev.TouchpadAxisChanged += new ControllerClickedEventHandler(ev_TouchpadAxisChanged);
        }
    }

    void ev_TouchpadAxisChanged(object sender, ControllerClickedEventArgs e) {
        if (((SteamVR_ControllerEvents)sender).gameObject.tag == "Left") {
            if (e.touchpadAxis[0] <= -0.6f && _resetrotate) {
                _rotateleft = true;
                _rotateright = false;
            } else if (e.touchpadAxis[0] >= 0.6f && _resetrotate) {
                _rotateleft = false;
                _rotateright = true;
            } else {
                _rotateleft = false;
                _rotateright = false;
                _resetrotate = true;
            }
        }
    }

    void ev_AliasUseOff(object sender, ControllerClickedEventArgs e) {
        if (((SteamVR_ControllerEvents)sender).gameObject.tag == "Right") {
            _using = false;
        }
    }

    void ev_AliasUseOn(object sender, ControllerClickedEventArgs e) {
        if (((SteamVR_ControllerEvents)sender).gameObject.tag == "Right") {
            _using = true;
            if (_grabbing)
                DoReset();
        }
    }

    void ev_AliasGrabOff(object sender, ControllerClickedEventArgs e) {
        if (((SteamVR_ControllerEvents)sender).gameObject.tag == "Right") {
            _grabbing = false;
        } else {
            _flying = false;
        }
    }

    void ev_AliasGrabOn(object sender, ControllerClickedEventArgs e) {
        if (((SteamVR_ControllerEvents)sender).gameObject.tag == "Right") {
            _grabbing = true;
            if (_using)
                DoReset();
        } else {
            _flying = true;
        }
    }

    private void DoReset() {
        SteamVR_Fade.Start(Color.black, 0);
        SteamVR_Fade.Start(Color.clear, 0.6f);
        this.transform.position = LevelDefs.Defs[LevelDefs.CurrentLevel].CameraStart;
    }

    private void MenuPressed(object sender, ControllerClickedEventArgs e) {
        SceneManager.LoadScene("Menu");
    }

    public void Update() {
        if (_flying) {
            Vector3 direction = this.eyeCamera.forward;
            float distance = 16 * Time.deltaTime;
            RaycastHit hitinfo;
            if (Physics.Raycast(new Ray(this.eyeCamera.position, direction), out hitinfo)) {
                if (hitinfo.distance < 3) {
                    // try to slide along slope
                    direction = Quaternion.AngleAxis(90, Vector3.Cross(hitinfo.normal, direction)) * hitinfo.normal;
                    if (Physics.Raycast(new Ray(this.eyeCamera.position, direction))) {
                        // new direction is blocked too, give up
                        return;
                    }
                }
            }

            this.transform.position += direction * distance;
        }
        if (_rotateleft || _rotateright) {
            SteamVR_Fade.Start(Color.black, 0);
            float rotation = _rotateleft ? -15.0f : 15.0f;
            this.transform.RotateAround(this.eyeCamera.position, Vector3.up, rotation);
            _rotateleft = false;
            _rotateright = false;
            _resetrotate = false;
            SteamVR_Fade.Start(Color.clear, 0.6f);
        }
    }
}
