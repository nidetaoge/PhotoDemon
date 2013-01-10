VERSION 5.00
Begin VB.Form FormColorize 
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   " Colorize Options"
   ClientHeight    =   6570
   ClientLeft      =   45
   ClientTop       =   285
   ClientWidth     =   12345
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   438
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   823
   ShowInTaskbar   =   0   'False
   StartUpPosition =   1  'CenterOwner
   Begin VB.CommandButton CmdOK 
      Caption         =   "&OK"
      Default         =   -1  'True
      Height          =   495
      Left            =   9360
      TabIndex        =   0
      Top             =   5925
      Width           =   1365
   End
   Begin VB.CommandButton CmdCancel 
      Cancel          =   -1  'True
      Caption         =   "&Cancel"
      Height          =   495
      Left            =   10830
      TabIndex        =   1
      Top             =   5925
      Width           =   1365
   End
   Begin VB.CheckBox chkSaturation 
      Appearance      =   0  'Flat
      BackColor       =   &H80000005&
      Caption         =   "preserve existing saturation"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   9.75
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00404040&
      Height          =   435
      Left            =   6240
      TabIndex        =   3
      Top             =   3240
      Value           =   1  'Checked
      Width           =   4215
   End
   Begin VB.HScrollBar hsHue 
      Height          =   255
      Left            =   6240
      Max             =   359
      Min             =   1
      TabIndex        =   2
      Top             =   2160
      Value           =   180
      Width           =   5775
   End
   Begin VB.PictureBox picHueDemo 
      Appearance      =   0  'Flat
      AutoRedraw      =   -1  'True
      BackColor       =   &H80000005&
      BeginProperty Font 
         Name            =   "Arial"
         Size            =   8.25
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H80000008&
      Height          =   375
      Left            =   6480
      ScaleHeight     =   23
      ScaleMode       =   3  'Pixel
      ScaleWidth      =   352
      TabIndex        =   4
      Top             =   2520
      Width           =   5310
   End
   Begin PhotoDemon.fxPreviewCtl fxPreview 
      Height          =   5625
      Left            =   120
      TabIndex        =   6
      Top             =   120
      Width           =   5625
      _ExtentX        =   9922
      _ExtentY        =   9922
   End
   Begin VB.Label lblTitle 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "color to apply:"
      BeginProperty Font 
         Name            =   "Tahoma"
         Size            =   12
         Charset         =   0
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H00404040&
      Height          =   285
      Left            =   6000
      TabIndex        =   7
      Top             =   1680
      Width           =   1545
   End
   Begin VB.Label lblBackground 
      Height          =   855
      Left            =   0
      TabIndex        =   5
      Top             =   5760
      Width           =   12375
   End
End
Attribute VB_Name = "FormColorize"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Colorize Form
'Copyright �2006-2013 by Tanner Helland
'Created: 12/January/07
'Last updated: 09/September/12
'Last update: added "maintain saturation" check box
'
'Fairly simple and standard routine - look in the Miscellaneous Filters module
' for the HSL transformation code
'
'***************************************************************************

Option Explicit

'When the "maintain saturation" check box is clicked, redraw the image
Private Sub chkSaturation_Click()
    If chkSaturation.Value = vbChecked Then ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), True, True, fxPreview Else ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), False, True, fxPreview
End Sub

'CANCEL button
Private Sub CmdCancel_Click()
    Unload Me
End Sub

'OK button
Private Sub cmdOK_Click()
    Me.Visible = False
    
    If chkSaturation.Value = vbChecked Then
        Process Colorize, CSng((CSng(hsHue.Value) - 60) / 60), True
    Else
        Process Colorize, CSng((CSng(hsHue.Value) - 60) / 60), False
    End If
        
    Unload Me
End Sub

'Colorize an image using a hue defined between -1 and 5
' Input: desired hue, whether to force saturation to 0.5 or maintain the existing value
Public Sub ColorizeImage(ByVal hToUse As Single, Optional ByVal maintainSaturation As Boolean = True, Optional ByVal toPreview As Boolean = False, Optional ByRef dstPic As fxPreviewCtl)
    
    If toPreview = False Then Message "Colorizing image..."
    
    'Create a local array and point it at the pixel data we want to operate on
    Dim ImageData() As Byte
    Dim tmpSA As SAFEARRAY2D
    
    prepImageData tmpSA, toPreview, dstPic
    CopyMemory ByVal VarPtrArray(ImageData()), VarPtr(tmpSA), 4
        
    'Local loop variables can be more efficiently cached by VB's compiler, so we transfer all relevant loop data here
    Dim x As Long, y As Long, initX As Long, initY As Long, finalX As Long, finalY As Long
    initX = curLayerValues.Left
    initY = curLayerValues.Top
    finalX = curLayerValues.Right
    finalY = curLayerValues.Bottom
            
    'These values will help us access locations in the array more quickly.
    ' (qvDepth is required because the image array may be 24 or 32 bits per pixel, and we want to handle both cases.)
    Dim QuickVal As Long, qvDepth As Long
    qvDepth = curLayerValues.BytesPerPixel
    
    'To keep processing quick, only update the progress bar when absolutely necessary.  This function calculates that value
    ' based on the size of the area to be processed.
    Dim progBarCheck As Long
    progBarCheck = findBestProgBarValue()
    
    'Color variables
    Dim r As Long, g As Long, b As Long
    Dim h As Single, s As Single, l As Single
        
    'Loop through each pixel in the image, converting values as we go
    For x = initX To finalX
        QuickVal = x * qvDepth
    For y = initY To finalY
    
        'Get the source pixel color values
        r = ImageData(QuickVal + 2, y)
        g = ImageData(QuickVal + 1, y)
        b = ImageData(QuickVal, y)
        
        'Get the hue and saturation
        tRGBToHSL r, g, b, h, s, l
        
        'Convert back to RGB using our artificial hue value
        If maintainSaturation Then
            tHSLToRGB hToUse, s, l, r, g, b
        Else
            tHSLToRGB hToUse, 0.5, l, r, g, b
        End If
        
        'Assign the new values to each color channel
        ImageData(QuickVal + 2, y) = r
        ImageData(QuickVal + 1, y) = g
        ImageData(QuickVal, y) = b
        
    Next y
        If toPreview = False Then
            If (x And progBarCheck) = 0 Then SetProgBarVal x
        End If
    Next x
    
    'With our work complete, point ImageData() away from the DIB and deallocate it
    CopyMemory ByVal VarPtrArray(ImageData), 0&, 4
    Erase ImageData
    
    'Pass control to finalizeImageData, which will handle the rest of the rendering
    finalizeImageData toPreview, dstPic
    
End Sub


Private Sub Form_Activate()

    'This short routine is for drawing the picture box below the hue slider
    Dim hVal As Single
    Dim r As Long, g As Long, b As Long
    
    'Simple gradient-ish code implementation of drawing hue
    Dim x As Long
    For x = 0 To picHueDemo.ScaleWidth
    
        'Based on our x-position, gradient a value between -1 and 5
        hVal = x / picHueDemo.ScaleWidth
        hVal = hVal * 360
        hVal = (hVal - 60) / 60
        
        'Generate a hue for this position (the 1 and 0.5 correspond to full saturation and half luminance, respectively)
        tHSLToRGB hVal, 1, 0.5, r, g, b
        
        'Draw the color
        picHueDemo.Line (x, 0)-(x, picHueDemo.ScaleHeight), RGB(r, g, b)
        
    Next x
    
    picHueDemo.Picture = picHueDemo.Image
    
    'Assign the system hand cursor to all relevant objects
    makeFormPretty Me
    
    'Display the previewed effect in the neighboring window
    If chkSaturation.Value = vbChecked Then ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), True, True, fxPreview Else ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), False, True, fxPreview
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub

'When the hue scroll bar is changed, redraw the preview
Private Sub hsHue_Change()
    If chkSaturation.Value = vbChecked Then ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), True, True, fxPreview Else ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), False, True, fxPreview
End Sub

Private Sub hsHue_Scroll()
    If chkSaturation.Value = vbChecked Then ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), True, True, fxPreview Else ColorizeImage CSng((CSng(hsHue.Value) - 60) / 60), False, True, fxPreview
End Sub
