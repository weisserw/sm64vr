﻿//=====================================================================================
//
// Purpose: Provide a mechanism for determining if a game world object is interactable
//
// This script should be attached to any object that needs touch, use or grab
//
// An optional highlight color can be set to change the object's appearance if it is
// invoked.
//
//=====================================================================================

using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class SteamVR_InteractableObject : MonoBehaviour
{
    public enum GrabType
    {
        Simple_Snap,
        Rotation_Snap,
        Precision_Snap
    }

    public bool isGrabbable = false;
    public bool holdButtonToGrab = true;
    public bool isUsable = false;
    public bool holdButtonToUse = true;
    public bool highlightOnTouch = false;
    public bool pointerActivatesUseAction = false;
    public Color touchHighlightColor = Color.clear;
    public GrabType grabSnapType = GrabType.Simple_Snap;
    public Vector3 snapToRotation = Vector3.zero;
    public float detachThreshold = 500f;
    public float jointDamper = 100f;
    public bool pauseCollisionsOnGrab = true;

    private bool isTouched = false;
    private bool isUsing = false;
    private int usingState = 0;
    private Color[] originalObjectColours = null;

    private Dictionary<string, GameObject> grabbingObjects = new Dictionary<string, GameObject>();

    public bool IsTouched()
    {
        return isTouched;
    }

    public bool IsGrabbed()
    {
        return (grabbingObjects.Count > 0);
    }

    public bool IsUsing()
    {
        return isUsing;
    }

    public virtual void StartTouching(GameObject touchingObject)
    {
        isTouched = true;
    }

    public virtual void StopTouching(GameObject previousTouchingObject)
    {
        isTouched = false;
    }

    public virtual void Grabbed(GameObject grabbingObject)
    {
        grabbingObjects.Add(grabbingObject.name, grabbingObject);
    }

    public virtual void Ungrabbed(GameObject previousGrabbingObject)
    {
        grabbingObjects.Remove(previousGrabbingObject.name);
    }

    public virtual void StartUsing(GameObject usingObject)
    {
        isUsing = true;
    }

    public virtual void StopUsing(GameObject previousUsingObject)
    {
        isUsing = false;
    }

    public virtual void ToggleHighlight(bool toggle)
    {
        ToggleHighlight(toggle, Color.clear);
    }

    public virtual void ToggleHighlight(bool toggle, Color globalHighlightColor)
    {
        if (highlightOnTouch)
        {
            if (toggle && !IsGrabbed() && !isUsing)
            {
                Color color = (touchHighlightColor != Color.clear ? touchHighlightColor : globalHighlightColor);
                if (color != Color.clear)
                {
                    var colorArray = BuildHighlightColorArray(color);
                    ChangeColor(colorArray);
                }
            }
            else
            {
                if(originalObjectColours == null)
                {
                    Debug.LogError("SteamVR_InteractableObject has not had the Start() method called, if you are inheriting this class then call base.Start() in your Start() method. [Error raised on line 78 of SteamVR_InteractableObject.cs]");
                    return;
                }
                ChangeColor(originalObjectColours);
            }
        }
    }

    public int UsingState
    {
        get { return usingState; }
        set{ usingState = value;  }
    }

    public void PauseCollisions(float pauseTime)
    {
        if (pauseCollisionsOnGrab)
        {
            if (this.GetComponent<Rigidbody>())
            {
                this.GetComponent<Rigidbody>().detectCollisions = false;
            }
            foreach (Rigidbody rb in this.GetComponentsInChildren<Rigidbody>())
            {
                rb.detectCollisions = false;
            }
            Invoke("UnpauseCollisions", pauseTime);
        }
    }

    protected virtual void Start()
    {
        originalObjectColours = StoreOriginalColors();
    }

    private void UnpauseCollisions()
    {
        if (this.GetComponent<Rigidbody>())
        {
            this.GetComponent<Rigidbody>().detectCollisions = true;
        }
        foreach (Rigidbody rb in this.GetComponentsInChildren<Rigidbody>())
        {
            rb.detectCollisions = true;
        }
    }

    private Renderer[] GetRendererArray()
    {
        return (GetComponents<Renderer>().Length > 0 ? GetComponents<Renderer>() : GetComponentsInChildren<Renderer>());
    }

    private Color[] StoreOriginalColors()
    {
        Renderer[] rendererArray = GetRendererArray();
        int length = rendererArray.Length;
        Color[] colors = new Color[length];

        for (int i = 0; i < length; i++)
        {
            var renderer = rendererArray[i];
            colors[i] = renderer.material.color;
        }
        return colors;
    }

    private Color[] BuildHighlightColorArray(Color color)
    {
        Renderer[] rendererArray = GetRendererArray();
        int length = rendererArray.Length;
        Color[] colors = new Color[length];

        for (int i = 0; i < length; i++)
        {
            colors[i] = color;
        }
        return colors;
    }

    private void ChangeColor(Color[] colors)
    {
        Renderer[] rendererArray = GetRendererArray();
        int i = 0;
        foreach (Renderer renderer in rendererArray)
        {
            renderer.material.color = colors[i];
            i++;
        }
    }

    private void OnJointBreak(float force)
    {
        List<string> grabbersAffected = new List<string>();
        foreach(var entry in grabbingObjects)
        {
            if (entry.Value.GetComponent<SteamVR_InteractGrab>()) {
                grabbersAffected.Add(entry.Key);
            }
        }

        foreach(var entry in grabbersAffected)
        {
            grabbingObjects[entry].GetComponent<SteamVR_InteractGrab>().ForceRelease();
        }
    }
}