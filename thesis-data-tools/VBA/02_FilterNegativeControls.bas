Attribute VB_Name = "FilterNegativeControls"
Option Explicit

'==============================================================================
' Step 2 (simple version) - Remove ASVs found in the negative controls
'
' Input: sheet "paste" with an ASV table (one row per ASV, one column per
'   sample). Negative-control columns have a header starting with "CEB_".
' Output: sheet "filtered" with only the ASVs that have zero reads in every
'   negative control. The input sheet is not modified.
'
' Reads that appear in a negative control come from contamination in the lab,
' so those ASVs cannot be trusted in the real samples either.
'==============================================================================

Private Const INPUT_SHEET As String = "paste"
Private Const OUTPUT_SHEET As String = "filtered"
Private Const CONTROL_PREFIX As String = "CEB_"


Public Sub FilterNegativeControls()
    Dim wb As Workbook: Set wb = ThisWorkbook
    Dim wsSrc As Worksheet, wsDst As Worksheet

    On Error Resume Next
    Set wsSrc = wb.Worksheets(INPUT_SHEET)
    On Error GoTo 0
    If wsSrc Is Nothing Then
        MsgBox "Sheet '" & INPUT_SHEET & "' not found.", vbCritical
        Exit Sub
    End If

    Dim lastCell As Range
    Set lastCell = wsSrc.Cells.Find("*", , , , xlByRows, xlPrevious)
    If lastCell Is Nothing Then
        MsgBox "Sheet '" & INPUT_SHEET & "' is empty.", vbExclamation
        Exit Sub
    End If
    Dim lastRow As Long, lastCol As Long
    lastRow = lastCell.Row
    lastCol = wsSrc.Cells.Find("*", , , , xlByColumns, xlPrevious).Column

    Dim inArr As Variant
    inArr = wsSrc.Range(wsSrc.Cells(1, 1), wsSrc.Cells(lastRow, lastCol)).Value

    ' Find the negative-control columns
    Dim ctrlCols As New Collection, c As Long
    For c = 1 To lastCol
        If UCase(Left(Trim(CStr(inArr(1, c))), Len(CONTROL_PREFIX))) = CONTROL_PREFIX Then ctrlCols.Add c
    Next c
    If ctrlCols.Count = 0 Then
        MsgBox "No column with a header starting with '" & CONTROL_PREFIX & "' found.", vbExclamation
        Exit Sub
    End If

    Dim outArr() As Variant
    ReDim outArr(1 To UBound(inArr, 1), 1 To UBound(inArr, 2))
    For c = 1 To UBound(inArr, 2)
        outArr(1, c) = inArr(1, c)
    Next c

    Dim oldScreen As Boolean: oldScreen = Application.ScreenUpdating
    Dim oldCalc As XlCalculation: oldCalc = Application.Calculation
    Dim oldEvents As Boolean: oldEvents = Application.EnableEvents
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    Application.EnableEvents = False
    On Error GoTo Cleanup

    ' Keep a row only if every control column is empty or zero
    Dim r As Long, outRow As Long, keepRow As Boolean, colIndex As Variant, v As Variant
    outRow = 2
    For r = 2 To UBound(inArr, 1)
        keepRow = True
        For Each colIndex In ctrlCols
            v = inArr(r, colIndex)
            If Not IsError(v) And Not IsEmpty(v) Then
                If IsNumeric(v) Then
                    If CDbl(v) <> 0 Then keepRow = False: Exit For
                End If
            End If
        Next colIndex
        If keepRow Then
            For c = 1 To UBound(inArr, 2)
                outArr(outRow, c) = inArr(r, c)
            Next c
            outRow = outRow + 1
        End If
    Next r

    ' Create (or replace) the output sheet and write the kept rows
    Application.DisplayAlerts = False
    On Error Resume Next
    wb.Worksheets(OUTPUT_SHEET).Delete
    On Error GoTo Cleanup
    Application.DisplayAlerts = True
    Set wsDst = wb.Worksheets.Add
    wsDst.Name = OUTPUT_SHEET
    wsDst.Range(wsDst.Cells(1, 1), wsDst.Cells(outRow - 1, UBound(inArr, 2))).Value = outArr

    MsgBox "Sheet '" & OUTPUT_SHEET & "' created: " & (outRow - 2) & " of " & (lastRow - 1) & _
           " ASVs kept.", vbInformation

Cleanup:
    Application.DisplayAlerts = True
    Application.ScreenUpdating = oldScreen
    Application.Calculation = oldCalc
    Application.EnableEvents = oldEvents
    If Err.Number <> 0 Then MsgBox "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub
