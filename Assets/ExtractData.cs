using UnityEngine;
using System.IO;
using System.Diagnostics;
using System.Collections.Generic;

public class ExtractData : MonoBehaviour {

    private Process _toolproc;
    private Process _pngproc;
    private List<GameObject> _menuitems = new List<GameObject>();

	void Start () {
        // unity can't find objects that aren't active, so we store references to these before deactivating.
        foreach (var obj in FindObjectsOfType<TextMesh>()) {
            if (obj.tag == "Menu Item") {
                _menuitems.Add(obj.gameObject);
                obj.gameObject.SetActive(false);
            }
        }

        var testpath = Application.dataPath + @"\..\BMPToPNG.ran.v1";
        var rompath = Application.dataPath + @"\..\Super Mario 64 (USA).n64";
        var exepath = Application.dataPath + @"\..\m64tool_r3.2\m64tool.exe";

        if (File.Exists(testpath)) {
            Finish();
            return;
        }

        if (!File.Exists(rompath)) {
            //GetComponent<TextMesh>().text = "Error: ROM file \"Super Mario 64 (USA).n64\" not found";
            GetComponent<TextMesh>().text = rompath;
            return;
        }

        _toolproc = Process.Start(exepath, string.Format("\"{0}\"", rompath));
        Invoke("CheckToolProc", .25f);
	}

    private void CheckToolProc() {
        if (_toolproc.HasExited) {
            if (_toolproc.ExitCode != 0) {
                GetComponent<TextMesh>().text = "Error: Failed to extract game files from ROM";
            } else {
                var exepath = Application.dataPath + @"\..\BMPToPNG.exe";

                _pngproc = Process.Start(exepath);
                Invoke("CheckPNGProc", .25f);
            }
        } else {
            Invoke("CheckToolProc", .25f);
        }
    }

    private void CheckPNGProc() {
        if (_pngproc.HasExited) {
            if (_pngproc.ExitCode != 0) {
                GetComponent<TextMesh>().text = "Error: Failed to convert texture maps to PNG";
            } else {
                Finish();
            }
        } else {
            Invoke("CheckPNGProc", .25f);
        }
    }

    private void Finish() {
        gameObject.SetActive(false);
        foreach (var obj in _menuitems) {
            obj.SetActive(true);
        }
    }
	
}
