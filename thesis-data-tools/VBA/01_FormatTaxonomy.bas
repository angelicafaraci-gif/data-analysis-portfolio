Attribute VB_Name = "FormatTaxonomy"
Option Explicit

'==============================================================================
' Step 1 - Format the taxonomic classification table
'
' Input: sheet "paste" with the raw output of the taxonomic classifier.
'   Column A holds the ASV (or OTU) identifier. From column B onwards each row
'   holds a variable number of triplets (taxon name, rank, confidence score),
'   so the same rank can end up in different columns on different rows.
'   Row 1 holds the rank names (superkingdom, phylum, class, order, family,
'   genus, species) above the middle column of each triplet: C, F, I, L, O, R, U.
'
' AlignTaxonomyTriplets moves every triplet under the column of its rank.
' CleanTaxonomyTable then writes a tidy copy in the sheet "taxonomy_clean":
'   ASV | superkingdom | superkingdom_score | phylum | phylum_score | ... | species | species_score
'==============================================================================

Private Const INPUT_SHEET As String = "paste"
Private Const OUTPUT_SHEET As String = "taxonomy_clean"


Public Sub AlignTaxonomyTriplets()
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets(INPUT_SHEET)

    Dim headerCols As Variant
    headerCols = Array(3, 6, 9, 12, 15, 18, 21)   ' columns C, F, I, L, O, R, U
    Const FIRST_TRIPLET_COL As Long = 2           ' column B

    ' Last row and column with data
    Dim lastRow As Long, lastCol As Long
    On Error Resume Next
    lastRow = ws.Cells.Find("*", , , , xlByRows, xlPrevious).Row
    lastCol = ws.Cells.Find("*", , , , xlByColumns, xlPrevious).Column
    On Error GoTo 0
    If lastRow < 2 Then
        MsgBox "No data to process.", vbInformation
        Exit Sub
    End If

    ' Map rank name (upper case) -> column of that rank
    Dim headerMap As Object
    Set headerMap = CreateObject("Scripting.Dictionary")
    Dim i As Long, hc As Long, hVal As String
    For i = LBound(headerCols) To UBound(headerCols)
        hc = headerCols(i)
        If hc <= lastCol Then
            hVal = Trim(CStr(ws.Cells(1, hc).Value))
            If Len(hVal) > 0 Then headerMap(UCase(hVal)) = hc
        End If
    Next i
    If headerMap.Count = 0 Then
        MsgBox "No rank names found in row 1 (columns C, F, I, L, O, R, U).", vbExclamation
        Exit Sub
    End If

    ' Read everything into memory (much faster than cell by cell)
    Dim dataRng As Range
    Set dataRng = ws.Range(ws.Cells(1, 1), ws.Cells(lastRow, lastCol))
    Dim inArr As Variant
    inArr = dataRng.Value

    Dim outArr() As Variant
    ReDim outArr(1 To UBound(inArr, 1), 1 To UBound(inArr, 2))

    ' Copy header row and ASV column unchanged
    Dim r As Long, c As Long
    For c = 1 To UBound(inArr, 2)
        outArr(1, c) = inArr(1, c)
    Next c
    For r = 2 To UBound(inArr, 1)
        outArr(r, 1) = inArr(r, 1)
    Next r

    Dim oldScreen As Boolean: oldScreen = Application.ScreenUpdating
    Dim oldCalc As XlCalculation: oldCalc = Application.Calculation
    Dim oldEvents As Boolean: oldEvents = Application.EnableEvents
    Application.ScreenUpdating = False
    Application.Calculation = xlCalculationManual
    Application.EnableEvents = False
    On Error GoTo Cleanup

    ' Scan each row triplet by triplet
    Dim taxonVal As Variant, rankVal As Variant, scoreVal As Variant
    Dim rankKey As String, targetCol As Long, col As Long
    For r = 2 To UBound(inArr, 1)
        col = FIRST_TRIPLET_COL
        Do While col + 2 <= UBound(inArr, 2)
            taxonVal = inArr(r, col)
            rankVal = inArr(r, col + 1)
            scoreVal = inArr(r, col + 2)
            If Not IsEmpty(rankVal) Then
                rankKey = UCase(Trim(CStr(rankVal)))
                If headerMap.Exists(rankKey) Then
                    targetCol = headerMap(rankKey)
                    ' Place the triplet centred on the column of its rank
                    If targetCol - 1 >= 1 And targetCol + 1 <= UBound(inArr, 2) Then
                        outArr(r, targetCol - 1) = taxonVal
                        outArr(r, targetCol) = rankVal
                        outArr(r, targetCol + 1) = scoreVal
                    End If
                End If
            End If
            col = col + 3
        Loop
    Next r

    dataRng.Value = outArr   ' write back in one operation
    MsgBox "Taxonomy aligned.", vbInformation

Cleanup:
    Application.ScreenUpdating = oldScreen
    Application.Calculation = oldCalc
    Application.EnableEvents = oldEvents
    If Err.Number <> 0 Then MsgBox "Error " & Err.Number & ": " & Err.Description, vbCritical
End Sub


Public Sub CleanTaxonomyTable()
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

    ' Create (or replace) the output sheet
    Application.DisplayAlerts = False
    On Error Resume Next
    wb.Worksheets(OUTPUT_SHEET).Delete
    On Error GoTo 0
    Application.DisplayAlerts = True
    Set wsDst = wb.Worksheets.Add
    wsDst.Name = OUTPUT_SHEET

    ' Copy values only
    wsSrc.Range(wsSrc.Cells(1, 1), wsSrc.Cells(lastRow, lastCol)).Copy
    wsDst.Cells(1, 1).PasteSpecial xlPasteValues
    Application.CutCopyMode = False

    ' 1. Rename identifiers "OTU..." to "ASV..." in column A
    Dim arr As Variant, v As String, r As Long
    arr = wsDst.Range("A1", wsDst.Cells(lastRow, 1)).Value
    For r = 1 To UBound(arr, 1)
        v = Trim(CStr(arr(r, 1)))
        If Len(v) >= 3 Then
            If UCase(Left(v, 3)) = "OTU" Then arr(r, 1) = "ASV" & Mid(v, 4)
        End If
    Next r
    wsDst.Range("A1", wsDst.Cells(lastRow, 1)).Value = arr

    ' 2. Final column names
    Dim ranks As Variant, k As Long
    ranks = Array("superkingdom", "phylum", "class", "order", "family", "genus", "species")
    wsDst.Cells(1, 1).Value = "ASV"
    For k = 0 To UBound(ranks)
        wsDst.Cells(1, 2 + 3 * k).Value = ranks(k)               ' taxon name: B, E, H, ...
        wsDst.Cells(1, 4 + 3 * k).Value = ranks(k) & "_score"    ' score:      D, G, J, ...
    Next k

    ' 3. Delete the rank-label columns C, F, I, L, O, R, U (right to left)
    Application.ScreenUpdating = False
    Dim delCols As Variant
    delCols = Array("U", "R", "O", "L", "I", "F", "C")
    For k = 0 To UBound(delCols)
        wsDst.Columns(delCols(k)).Delete
    Next k
    Application.ScreenUpdating = True

    MsgBox "Clean taxonomy table written to sheet '" & OUTPUT_SHEET & "'.", vbInformation
End Sub
