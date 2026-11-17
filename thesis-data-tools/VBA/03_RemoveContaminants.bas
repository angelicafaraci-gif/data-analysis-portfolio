Attribute VB_Name = "RemoveContaminants"
Option Explicit

'==============================================================================
' Step 2 (complete version) - Remove contaminant ASVs from every sheet
'
' Runs on every sheet of the workbook except "board" (the sheet with the
' buttons). In each sheet, a row (ASV) is deleted when:
'   1. it has reads in at least one control column (a header containing
'      "control", "blank" or "ceb"), or
'   2. its genus is in the list of contaminant genera, or
'   3. its species is in the list of contaminant species.
' The genus and species columns are found by their headers ("genus", "species").
'
' Contaminants are typically human DNA, domestic animals and terrestrial
' insects that end up in marine samples during collection or lab work.
' The lists below are EXAMPLES: edit them for your own data.
'
' WARNING: rows are deleted in place. Run it on a copy of the workbook.
'==============================================================================

Private Const SKIP_SHEET As String = "board"

Private Function ControlTokens() As Variant
    ControlTokens = Array("control", "blank", "ceb")   ' also matches "controllo", "controlli"
End Function

Private Function ContaminantGenera() As Variant
    ContaminantGenera = Array("Homo", "Bos", "Canis", "Felis", "Sus", "Gallus")
End Function

Private Function ContaminantSpecies() As Variant
    ContaminantSpecies = Array("Homo sapiens", "Canis lupus")
End Function


Public Sub RemoveContaminantsAllSheets()
    Dim ws As Worksheet, oldCalc As XlCalculation
    Dim nSheets As Long, nRemoved As Long, currentSheet As String, failed As Boolean

    oldCalc = Application.Calculation
    Application.ScreenUpdating = False
    Application.EnableEvents = False
    Application.DisplayAlerts = False
    Application.Calculation = xlCalculationManual
    On Error GoTo CleanFail

    For Each ws In ThisWorkbook.Worksheets
        If LCase$(ws.Name) <> LCase$(SKIP_SHEET) Then
            currentSheet = ws.Name
            nRemoved = nRemoved + CleanSheet(ws)
            nSheets = nSheets + 1
        End If
    Next ws

CleanExit:
    ' restore Excel settings in every case, also after an error
    Application.DisplayAlerts = True
    Application.Calculation = oldCalc
    Application.EnableEvents = True
    Application.ScreenUpdating = True
    If Not failed Then MsgBox nSheets & " sheets cleaned, " & nRemoved & " rows removed.", vbInformation
    Exit Sub

CleanFail:
    failed = True
    MsgBox "Error " & Err.Number & ": " & Err.Description & " (sheet '" & currentSheet & "')", vbCritical
    Resume CleanExit
End Sub


' Removes the contaminant rows from one sheet and returns how many were removed.
Private Function CleanSheet(ByVal ws As Worksheet) As Long
    Dim lastCell As Range, lastRow As Long, lastCol As Long

    Set lastCell = ws.Cells.Find(What:="*", LookIn:=xlFormulas, LookAt:=xlPart, _
                                 SearchOrder:=xlByRows, SearchDirection:=xlPrevious)
    If lastCell Is Nothing Then Exit Function
    lastRow = lastCell.Row
    lastCol = ws.Cells.Find(What:="*", LookIn:=xlFormulas, LookAt:=xlPart, _
                            SearchOrder:=xlByColumns, SearchDirection:=xlPrevious).Column
    If lastRow < 2 Then Exit Function

    Dim arr As Variant
    arr = ws.Range(ws.Cells(1, 1), ws.Cells(lastRow, lastCol)).Value2   ' read into memory

    ' Find the control, genus and species columns from the header row
    Dim ctrlCols As New Collection, genusCol As Long, speciesCol As Long
    Dim c As Long, hdr As String, tok As Variant
    For c = 1 To lastCol
        hdr = LCase$(Trim$(CStr(arr(1, c))))
        If hdr <> vbNullString Then
            For Each tok In ControlTokens()
                If InStr(1, hdr, tok, vbTextCompare) > 0 Then ctrlCols.Add c: Exit For
            Next tok
            If genusCol = 0 And hdr = "genus" Then genusCol = c
            If speciesCol = 0 And hdr = "species" Then speciesCol = c
        End If
    Next c
    If ctrlCols.Count = 0 And genusCol = 0 And speciesCol = 0 Then Exit Function

    ' Dictionaries for fast, case-insensitive lookup
    Dim dGenus As Object: Set dGenus = CreateObject("Scripting.Dictionary")
    Dim dSpecies As Object: Set dSpecies = CreateObject("Scripting.Dictionary")
    Dim item As Variant
    For Each item In ContaminantGenera()
        dGenus(LCase$(item)) = True
    Next item
    For Each item In ContaminantSpecies()
        dSpecies(LCase$(item)) = True
    Next item

    ' Mark the rows to remove
    Dim removeRow() As Boolean
    ReDim removeRow(1 To lastRow)
    Dim r As Long, v As Variant, colIdx As Variant
    For r = 2 To lastRow
        ' 1. reads in a control column
        For Each colIdx In ctrlCols
            v = arr(r, CLng(colIdx))
            If Not IsError(v) Then
                If IsNumeric(v) Then
                    If CDbl(v) <> 0 Then removeRow(r) = True: Exit For
                End If
            End If
        Next colIdx
        ' 2. contaminant genus
        If Not removeRow(r) And genusCol > 0 Then
            If dGenus.Exists(TaxonName(arr(r, genusCol))) Then removeRow(r) = True
        End If
        ' 3. contaminant species
        If Not removeRow(r) And speciesCol > 0 Then
            If dSpecies.Exists(TaxonName(arr(r, speciesCol))) Then removeRow(r) = True
        End If
    Next r

    ' Rebuild the table with the rows to keep, write it back in one go and
    ' delete the leftover rows at the bottom with a single Delete
    Dim kept As Long: kept = 1
    For r = 2 To lastRow
        If Not removeRow(r) Then kept = kept + 1
    Next r
    Dim outArr() As Variant, rr As Long
    ReDim outArr(1 To kept, 1 To lastCol)
    rr = 0
    For r = 1 To lastRow
        If Not removeRow(r) Then
            rr = rr + 1
            For c = 1 To lastCol
                outArr(rr, c) = arr(r, c)
            Next c
        End If
    Next r
    ws.Range(ws.Cells(1, 1), ws.Cells(kept, lastCol)).Value2 = outArr
    If kept < lastRow Then ws.Rows(CStr(kept + 1) & ":" & CStr(lastRow)).Delete

    CleanSheet = lastRow - kept
End Function


' Taxon name in lower case, without spaces or a leading ":" left by the classifier.
Private Function TaxonName(ByVal v As Variant) As String
    If IsError(v) Then Exit Function
    Dim s As String: s = LCase$(Trim$(CStr(v)))
    If Left$(s, 1) = ":" Then s = Trim$(Mid$(s, 2))
    TaxonName = s
End Function
