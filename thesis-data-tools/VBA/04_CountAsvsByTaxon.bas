Attribute VB_Name = "CountAsvsByTaxon"
Option Explicit

'==============================================================================
' Step 3 - Number of ASVs per taxon in each sample
'
' Reads every ASV table in the workbook (all sheets except "board" and the
' output sheets). In each sheet:
'   - sample columns are the ones whose header starts with "ARMS";
'   - the taxonomy columns are found by their headers ("kingdom", "phylum", "class").
' For every taxon at each rank it counts in how many ASVs the taxon is present
' (reads > 0) in each sample. Samples with the same name in different sheets
' are added together.
'
' Output: one sheet per rank ("count_kingdom", "count_phylum", "count_class")
' with taxa in rows (sorted A-Z), samples in columns and explicit zeros.
'==============================================================================

Private Const SKIP_SHEET As String = "board"
Private Const SAMPLE_PREFIX As String = "ARMS"
Private Const OUTPUT_PREFIX As String = "count_"

Private Function Ranks() As Variant
    Ranks = Array("kingdom", "phylum", "class")
End Function


Public Sub CountAsvsByTaxon()
    Dim t0 As Double: t0 = Timer
    Dim wb As Workbook: Set wb = ThisWorkbook
    Dim rankList As Variant: rankList = Ranks()
    Dim nRanks As Long: nRanks = UBound(rankList) + 1

    Dim oldCalc As XlCalculation: oldCalc = Application.Calculation
    Dim oldScreen As Boolean: oldScreen = Application.ScreenUpdating
    Dim oldEvents As Boolean: oldEvents = Application.EnableEvents
    Application.ScreenUpdating = False
    Application.EnableEvents = False
    Application.Calculation = xlCalculationManual
    On Error GoTo CleanFail

    ' Sample name -> global index 1..nSamples (same name in two sheets = same sample)
    Dim sampleIndex As Object: Set sampleIndex = CreateObject("Scripting.Dictionary")
    sampleIndex.CompareMode = vbTextCompare
    Dim sampleNames() As String, nSamples As Long

    ' One dictionary per rank: taxon -> (sample index -> number of ASVs)
    Dim counts() As Object, k As Long
    ReDim counts(0 To nRanks - 1)
    For k = 0 To nRanks - 1
        Set counts(k) = CreateObject("Scripting.Dictionary")
        counts(k).CompareMode = vbTextCompare
    Next k

    Dim ws As Worksheet, nProcessed As Long, sheetsWithoutSamples As String
    Dim lastRow As Long, lastCol As Long, head As Variant, data As Variant
    Dim rankCols() As Long, localCols As Variant, globalIdx As Variant
    Dim r As Long, j As Long, taxon As String

    For Each ws In wb.Worksheets
        If Not IsSkipped(ws.Name, rankList) Then
            GetLastCell ws, lastRow, lastCol
            If lastRow >= 2 Then
                Application.StatusBar = "Counting ASVs: reading '" & ws.Name & "'..."
                head = ws.Range(ws.Cells(1, 1), ws.Cells(1, lastCol)).Value2

                ReDim rankCols(0 To nRanks - 1)
                For k = 0 To nRanks - 1
                    rankCols(k) = FindHeaderCol(head, CStr(rankList(k)))
                Next k

                GetSampleCols head, sampleIndex, sampleNames, nSamples, localCols, globalIdx
                If IsEmpty(localCols) Then
                    sheetsWithoutSamples = sheetsWithoutSamples & vbCrLf & " - " & ws.Name
                Else
                    data = ws.Range(ws.Cells(2, 1), ws.Cells(lastRow, lastCol)).Value2
                    For r = 1 To UBound(data, 1)
                        For j = 1 To UBound(localCols)
                            If IsNonZero(data(r, localCols(j))) Then
                                For k = 0 To nRanks - 1
                                    If rankCols(k) > 0 Then
                                        taxon = Trim$(SafeString(data(r, rankCols(k))))
                                        If Len(taxon) > 0 Then AddCount counts(k), taxon, CLng(globalIdx(j))
                                    End If
                                Next k
                            End If
                        Next j
                    Next r
                    nProcessed = nProcessed + 1
                End If
            End If
        End If
    Next ws

    If nSamples = 0 Then
        MsgBox "No column with a header starting with '" & SAMPLE_PREFIX & "' found in any sheet.", vbExclamation
        GoTo CleanExit
    End If

    Application.StatusBar = "Counting ASVs: writing output..."
    For k = 0 To nRanks - 1
        WriteOutput GetOrCreateSheet(wb, OUTPUT_PREFIX & rankList(k)), CStr(rankList(k)), _
                    counts(k), sampleNames, nSamples
    Next k

    If Len(sheetsWithoutSamples) > 0 Then
        MsgBox "No '" & SAMPLE_PREFIX & "' columns found in these sheets:" & sheetsWithoutSamples, vbExclamation
    End If
    MsgBox "Done. Sheets processed: " & nProcessed & vbCrLf & _
           "Samples: " & nSamples & vbCrLf & _
           "Time: " & Format$(Timer - t0, "0.00") & " s", vbInformation

CleanExit:
    Application.StatusBar = False
    Application.Calculation = oldCalc
    Application.ScreenUpdating = oldScreen
    Application.EnableEvents = oldEvents
    Exit Sub

CleanFail:
    MsgBox "Error " & Err.Number & ": " & Err.Description, vbCritical
    Resume CleanExit
End Sub


'------------------------------------------------------------------------------
' Helpers
'------------------------------------------------------------------------------

Private Function IsSkipped(ByVal sheetName As String, ByVal rankList As Variant) As Boolean
    Dim k As Long
    If StrComp(sheetName, SKIP_SHEET, vbTextCompare) = 0 Then IsSkipped = True: Exit Function
    For k = 0 To UBound(rankList)
        If StrComp(sheetName, OUTPUT_PREFIX & rankList(k), vbTextCompare) = 0 Then IsSkipped = True: Exit Function
    Next k
End Function

Private Sub GetLastCell(ByVal ws As Worksheet, ByRef lastRow As Long, ByRef lastCol As Long)
    Dim c As Range
    Set c = ws.Cells.Find(What:="*", LookIn:=xlFormulas, SearchOrder:=xlByRows, SearchDirection:=xlPrevious)
    If c Is Nothing Then
        lastRow = 0: lastCol = 0
    Else
        lastRow = c.Row
        lastCol = ws.Cells.Find(What:="*", LookIn:=xlFormulas, SearchOrder:=xlByColumns, _
                                SearchDirection:=xlPrevious).Column
    End If
End Sub

' Column whose header is exactly `target` (case-insensitive); 0 if not found.
Private Function FindHeaderCol(ByVal head As Variant, ByVal target As String) As Long
    Dim c As Long
    For c = 1 To UBound(head, 2)
        If StrComp(Trim$(SafeString(head(1, c))), target, vbTextCompare) = 0 Then
            FindHeaderCol = c
            Exit Function
        End If
    Next c
End Function

' Sample columns of one sheet (1-based arrays):
'   localCols(j) = column in the sheet, globalIdx(j) = index of that sample in the output.
Private Sub GetSampleCols(ByVal head As Variant, ByVal sampleIndex As Object, _
                          ByRef sampleNames() As String, ByRef nSamples As Long, _
                          ByRef localCols As Variant, ByRef globalIdx As Variant)
    Dim tmpLocal As New Collection, tmpGlobal As New Collection
    Dim c As Long, hdr As String
    For c = 1 To UBound(head, 2)
        hdr = Trim$(SafeString(head(1, c)))
        If UCase$(Left$(hdr, Len(SAMPLE_PREFIX))) = UCase$(SAMPLE_PREFIX) Then
            If Not sampleIndex.Exists(hdr) Then
                nSamples = nSamples + 1
                sampleIndex.Add hdr, nSamples
                ReDim Preserve sampleNames(1 To nSamples)
                sampleNames(nSamples) = hdr
            End If
            tmpLocal.Add c
            tmpGlobal.Add sampleIndex(hdr)
        End If
    Next c

    If tmpLocal.Count = 0 Then
        localCols = Empty
        globalIdx = Empty
        Exit Sub
    End If
    Dim j As Long
    ReDim localCols(1 To tmpLocal.Count)
    ReDim globalIdx(1 To tmpLocal.Count)
    For j = 1 To tmpLocal.Count
        localCols(j) = CLng(tmpLocal(j))
        globalIdx(j) = CLng(tmpGlobal(j))
    Next j
End Sub

Private Sub AddCount(ByVal outer As Object, ByVal key As String, ByVal sampleIdx As Long)
    If Not outer.Exists(key) Then outer.Add key, CreateObject("Scripting.Dictionary")
    Dim inner As Object: Set inner = outer(key)
    inner(sampleIdx) = inner(sampleIdx) + 1   ' a missing key starts from Empty = 0
End Sub

Private Function IsNonZero(ByVal v As Variant) As Boolean
    If IsError(v) Or IsEmpty(v) Then Exit Function
    If IsNumeric(v) Then IsNonZero = (CDbl(v) <> 0)
End Function

Private Function SafeString(ByVal v As Variant) As String
    If Not IsError(v) And Not IsEmpty(v) Then SafeString = CStr(v)
End Function

Private Function GetOrCreateSheet(ByVal wb As Workbook, ByVal sheetName As String) As Worksheet
    On Error Resume Next
    Set GetOrCreateSheet = wb.Worksheets(sheetName)
    On Error GoTo 0
    If GetOrCreateSheet Is Nothing Then
        Set GetOrCreateSheet = wb.Worksheets.Add(After:=wb.Worksheets(wb.Worksheets.Count))
        GetOrCreateSheet.Name = sheetName
    End If
End Function

' Writes taxa x samples, sorted by taxon name, with explicit zeros.
Private Sub WriteOutput(ByVal wsOut As Worksheet, ByVal rankLabel As String, ByVal outer As Object, _
                        ByRef sampleNames() As String, ByVal nSamples As Long)
    wsOut.Cells.Clear
    Dim headerRow() As Variant, i As Long
    ReDim headerRow(1 To 1, 1 To nSamples + 1)
    headerRow(1, 1) = rankLabel
    For i = 1 To nSamples
        headerRow(1, i + 1) = sampleNames(i)
    Next i
    wsOut.Range(wsOut.Cells(1, 1), wsOut.Cells(1, nSamples + 1)).Value = headerRow
    wsOut.Rows(1).Font.Bold = True

    If outer.Count > 0 Then
        Dim keys As Variant: keys = outer.keys
        If outer.Count > 1 Then QuickSortStrings keys, LBound(keys), UBound(keys)

        Dim outArr() As Variant, r As Long, inner As Object
        ReDim outArr(1 To outer.Count, 1 To nSamples + 1)
        For r = 1 To outer.Count
            outArr(r, 1) = keys(LBound(keys) + r - 1)
            Set inner = outer(outArr(r, 1))
            For i = 1 To nSamples
                If inner.Exists(i) Then outArr(r, i + 1) = inner(i) Else outArr(r, i + 1) = 0
            Next i
        Next r
        wsOut.Range(wsOut.Cells(2, 1), wsOut.Cells(outer.Count + 1, nSamples + 1)).Value = outArr
    End If
    wsOut.Columns.AutoFit
End Sub

' In-place QuickSort of an array of strings (case-insensitive).
Private Sub QuickSortStrings(ByRef arr As Variant, ByVal first As Long, ByVal last As Long)
    Dim i As Long, j As Long, pivot As String, tmp As Variant
    i = first: j = last
    pivot = CStr(arr((first + last) \ 2))
    Do While i <= j
        Do While StrComp(CStr(arr(i)), pivot, vbTextCompare) < 0: i = i + 1: Loop
        Do While StrComp(CStr(arr(j)), pivot, vbTextCompare) > 0: j = j - 1: Loop
        If i <= j Then
            tmp = arr(i): arr(i) = arr(j): arr(j) = tmp
            i = i + 1: j = j - 1
        End If
    Loop
    If first < j Then QuickSortStrings arr, first, j
    If i < last Then QuickSortStrings arr, i, last
End Sub
