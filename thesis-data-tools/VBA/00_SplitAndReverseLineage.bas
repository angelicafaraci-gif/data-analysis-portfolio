Attribute VB_Name = "SplitAndReverseLineage"
Option Explicit

'==============================================================================
' Step 0 (18S) - Prepare the lineage exported by the metabarcoding pipeline
'
' Input: sheet "aggregation" with, in column A, one line per OTU: the OTU id
'   followed by its lineage, all separated by commas, from the most specific
'   to the most general name.
' The macro:
'   1. splits column A on the commas into separate columns;
'   2. reverses the order of the columns from B to the last one, so the
'      lineage reads from the most general to the most specific name;
'   3. writes "Classification" in B1, the header expected by worms_18s.py.
'==============================================================================

Private Const SHEET_NAME As String = "aggregation"
Private Const FIRST_ROW As Long = 1   ' row 1 is the header line of the exported file
Private Const FIRST_COL As Long = 1   ' column A


Public Sub SplitAndReverseLineage()
    Dim ws As Worksheet, lastRow As Long, nCols As Long
    Dim srcArr As Variant, outArr() As Variant, parts As Variant
    Dim r As Long, c As Long, txt As String

    On Error GoTo ErrHandler
    Application.ScreenUpdating = False
    Set ws = ThisWorkbook.Worksheets(SHEET_NAME)

    lastRow = ws.Cells(ws.Rows.Count, FIRST_COL).End(xlUp).Row
    If lastRow < FIRST_ROW Or IsEmpty(ws.Cells(lastRow, FIRST_COL).Value) Then
        MsgBox "No data in column A.", vbInformation
        GoTo SafeExit
    End If

    ' 1. Split column A on commas
    srcArr = ws.Range(ws.Cells(FIRST_ROW, FIRST_COL), ws.Cells(lastRow, FIRST_COL)).Value
    nCols = 1
    For r = 1 To UBound(srcArr, 1)
        txt = CStr(srcArr(r, 1))
        If Len(txt) > 0 Then
            parts = Split(txt, ",")
            If UBound(parts) + 1 > nCols Then nCols = UBound(parts) + 1
        End If
    Next r

    ReDim outArr(1 To UBound(srcArr, 1), 1 To nCols)
    For r = 1 To UBound(srcArr, 1)
        txt = CStr(srcArr(r, 1))
        If Len(txt) > 0 Then
            parts = Split(txt, ",")
            For c = 0 To UBound(parts)
                outArr(r, c + 1) = Trim$(parts(c))
            Next c
        End If
    Next r
    ws.Cells(FIRST_ROW, FIRST_COL).Resize(UBound(outArr, 1), nCols).Value = outArr

    ' 2. Reverse the order of the columns from B to the last one
    Dim firstRev As Long, lastRev As Long, rng As Range, arr2 As Variant, revArr() As Variant
    firstRev = FIRST_COL + 1
    lastRev = FIRST_COL + nCols - 1
    If lastRev > firstRev Then
        Set rng = ws.Range(ws.Cells(FIRST_ROW, firstRev), ws.Cells(lastRow, lastRev))
        arr2 = rng.Value
        ReDim revArr(1 To UBound(arr2, 1), 1 To UBound(arr2, 2))
        For r = 1 To UBound(arr2, 1)
            For c = 1 To UBound(arr2, 2)
                revArr(r, UBound(arr2, 2) - c + 1) = arr2(r, c)
            Next c
        Next r
        rng.Value = revArr
    End If

    ' 3. Header expected by worms_18s.py
    ws.Cells(1, FIRST_COL + 1).Value = "Classification"
    MsgBox "Lineage split into " & nCols & " columns and reversed.", vbInformation

SafeExit:
    Application.ScreenUpdating = True
    Exit Sub

ErrHandler:
    Application.ScreenUpdating = True
    MsgBox "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub
