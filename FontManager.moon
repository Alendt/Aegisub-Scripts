export script_name        = "Font Manager"
export script_description = "Manage your fonts without leaving Aegisub"
export script_version     = "0.0.1"

local ILL, Ass, Line
ILL = require "ILL.ILL"
{:Line, :Ass} = ILL

ffi = require "ffi"
import C, cast, cdef, new from ffi

--
WM_COMMAND = 0x0111
WM_HSCROLL = 0x0114
WM_DRAWITEM = 0x002B
BN_CLICKED = 0
LBN_SELCHANGE = 1
EN_CHANGE = 0x0300
LB_ADDSTRING = 0x0180
LB_SETCURSEL = 0x0186
LB_GETCURSEL = 0x0188
LB_GETTEXTLEN = 0x018A
LB_GETTEXT = 0x0189
LB_RESETCONTENT = 0x0184
BM_SETCHECK = 0x00F1
BST_CHECKED = 1
BST_UNCHECKED = 0
TBS_HORZ = 0x0000
TBM_SETRANGE = 0x0405
TBM_SETPOS = 0x0407
TBM_GETPOS = 0x0400
ICC_BAR_CLASSES = 0x00000004
LBS_OWNERDRAWFIXED = 0x0010
LBS_HASSTRINGS = 0x0040
LBS_DISABLENOSCROLL = 0x1000
WS_VSCROLL = 0x00200000
WS_CHILD = 0x40000000
WS_VISIBLE = 0x10000000
LBS_NOTIFY = 0x0001
WM_GETTEXT = 0x000D
WM_GETTEXTLENGTH = 0x000E
DT_LEFT = 0x0000
DT_VCENTER = 0x0004
DT_SINGLELINE = 0x0020
SEARCH_EDIT = 1012
WS_OVERLAPPED = 0x00000000
WS_CAPTION = 0x00C00000
WS_SYSMENU = 0x00080000
WS_MINIMIZEBOX = 0x00020000
WINDOW_STYLE = WS_OVERLAPPED + WS_CAPTION + WS_SYSMENU + WS_MINIMIZEBOX
DEFAULT_CHARSET = 1
WS_BORDER = 0x00800000
WS_EX_CLIENTEDGE = 0x00000200
WM_KEYDOWN = 0x0100
VK_ESCAPE = 0x1B
VK_RETURN = 0x0D

COLOR_HIGHLIGHT = 13

cdef [[
    typedef void* HWND;
    typedef void* HINSTANCE;
    typedef void* HFONT;
    typedef void* HDC;
    typedef unsigned int UINT;
    typedef long LRESULT;
    typedef struct { int x, y; } POINT;
    typedef struct { 
        UINT cbSize;
        UINT style;
        LRESULT (__stdcall *lpfnWndProc)(HWND, UINT, uintptr_t, uintptr_t);
        int cbClsExtra;
        int cbWndExtra;
        HINSTANCE hInstance;
        void* hIcon;
        void* hCursor;
        void* hbrBackground;
        const char* lpszMenuName;
        const char* lpszClassName;
        void* hIconSm;
    } WNDCLASSEX;
    typedef struct { 
        HWND hwnd; 
        UINT message; 
        uintptr_t wParam; 
        uintptr_t lParam; 
        unsigned long time; 
        POINT pt; 
    } MSG;
    typedef struct {
        int x, y, nWidth, nHeight;
    } RECT;
    typedef struct {
        HDC hdc;
        int fErase;
        RECT rcPaint;
        int fRestore;
        int fIncUpdate;
        char rgbReserved[32];
    } PAINTSTRUCT;
    typedef struct {
        int lfHeight;
        int lfWidth;
        int lfEscapement;
        int lfOrientation;
        int lfWeight;
        char lfItalic;
        char lfUnderline;
        char lfStrikeOut;
        char lfCharSet;
        char lfOutPrecision;
        char lfClipPrecision;
        char lfQuality;
        char lfPitchAndFamily;
        char lfFaceName[32];
    } LOGFONT;
    typedef struct {
        LOGFONT elfLogFont;
        char elfFullName[64];
        char elfStyle[32];
        char elfScript[32];
    } ENUMLOGFONTEX;
    typedef struct {
        int elfStyle[32];
    } NEWTEXTMETRICEX;
    typedef struct {
        unsigned long dwSize;
        unsigned long dwICC;
    } INITCOMMONCONTROLSEX;
    typedef struct {
        UINT CtlType;
        UINT CtlID;
        UINT itemID;
        UINT itemAction;
        UINT itemState;
        HWND hwndItem;
        HDC hDC;
        RECT rcItem;
        uintptr_t itemData;
    } DRAWITEMSTRUCT;
    typedef struct {
        long tmHeight;
        long tmAscent;
        long tmDescent;
        long tmInternalLeading;
        long tmExternalLeading;
        long tmAveCharWidth;
        long tmMaxCharWidth;
        long tmWeight;
        long tmOverhang;
        long tmDigitizedAspectX;
        long tmDigitizedAspectY;
        char tmFirstChar;
        char tmLastChar;
        char tmDefaultChar;
        char tmBreakChar;
        char tmItalic;
        char tmUnderlined;
        char tmStruckOut;
        char tmPitchAndFamily;
        char tmCharSet;
    } TEXTMETRIC;

    HINSTANCE GetModuleHandleA(const char*);
    HWND CreateWindowExA(int, const char*, const char*, int, int, int, int, int, HWND, void*, HINSTANCE, void*);
    int RegisterClassExA(const WNDCLASSEX*);
    int UnregisterClassA(const char*, HINSTANCE);
    int DestroyWindow(HWND);
    int ShowWindow(HWND, int);
    int UpdateWindow(HWND);
    int GetMessageA(MSG*, HWND, UINT, UINT);
    int TranslateMessage(const MSG*);
    int DispatchMessageA(const MSG*);
    LRESULT DefWindowProcA(HWND, UINT, uintptr_t, uintptr_t);
    HDC BeginPaint(HWND, PAINTSTRUCT*);
    int EndPaint(HWND, PAINTSTRUCT*);
    HFONT CreateFontA(int, int, int, int, int, int, int, int, int, int, int, int, int, const char*);
    HFONT SelectObject(HDC, HFONT);
    int SetTextColor(HDC, int);
    int SetBkMode(HDC, int);
    int SetBkColor(HDC, unsigned long);
    int DrawTextA(HDC, const char*, int, RECT*, UINT);
    int TextOutA(HDC, int, int, const char*, int);
    int DeleteObject(void*);
    HWND GetDlgItem(HWND, int);
    int InvalidateRect(HWND, void*, int);
    LRESULT SendMessageA(HWND, UINT, uintptr_t, uintptr_t);
    HDC CreateDCA(const char*, const char*, const char*, void*);
    int DeleteDC(HDC);
    int EnumFontFamiliesExA(HDC, void*, void*, void*, unsigned long);
    int InitCommonControlsEx(const INITCOMMONCONTROLSEX*);
    unsigned long GetLastError();
    int GetDeviceCaps(HDC, int);
    int MulDiv(int, int, int);
    int TextOutW(HDC, int, int, const wchar_t*, int);
    int MultiByteToWideChar(unsigned int, unsigned long, const char*, int, wchar_t*, int);
    int WideCharToMultiByte(unsigned int, unsigned long, const wchar_t*, int, char*, int, const char*, int*);
    LRESULT SendMessageW(HWND, UINT, uintptr_t, uintptr_t);
    int GetTextMetricsA(HDC, TEXTMETRIC*);
    unsigned long GetSysColor(int nIndex);
]]

dialog_ok = false
currentFont = "Arial"
currentFontSize = 40
currentText = "The quick brown fox jumps over the lazy dog"
isBold = false
isItalic = false
isUnderline = false
isStrikethrough = false
className = "AegisubFontWindowClass"
fonts = {}
sizeLabel = nil
fontFamilies = {}

MAKELONG = (low, high) ->
    return (high * 65536) + low

stringToWide = (str) ->
    if not str or str == ""
        return ffi.new "wchar_t[1]", 0, 0
    cStr = ffi.new "char[?]", #str + 1, str
    len = C.MultiByteToWideChar(65001, 0, cStr, -1, nil, 0)
    if len == 0
        return ffi.new "wchar_t[1]", 0, 0
    wStr = ffi.new "wchar_t[?]", len
    if C.MultiByteToWideChar(65001, 0, cStr, -1, wStr, len) == 0
        return ffi.new "wchar_t[1]", 0, 0
    return wStr, len - 1

wideToString = (wStr, wLen) ->
    if wLen <= 0
        return ""
    len = C.WideCharToMultiByte(65001, 0, wStr, wLen, nil, 0, nil, nil)
    if len == 0
        return ""
    cStr = ffi.new "char[?]", len + 1
    if C.WideCharToMultiByte(65001, 0, wStr, wLen, cStr, len, nil, nil) == 0
        return ""
    return ffi.string(cStr, len)

updateSizeLabel = (hwnd) ->
    if sizeLabel ~= nil
        sizeText = "Dim: #{currentFontSize}"
        cSizeText = ffi.new "char[?]", #sizeText + 1, sizeText
        C.SendMessageA sizeLabel, 0x000C, 0, ffi.cast("uintptr_t", cSizeText)

extractFontFamily = (fontName) ->
    commonStyles = {
        "Bold", "Semibold", "Light", "Regular", "Italic", "Medium", "Thin", "ExtraLight",
        "ExtraBold", "Black", "Narrow", "Condensed", "Oblique", "Ultra", "Heavy", "Book",
        "Demi", "Roman", "Normal"
    }
    words = {}
    for word in fontName\gmatch("%S+")
        table.insert words, word
    familyWords = {}
    for i, word in ipairs words
        for _, style in ipairs commonStyles
            if word\lower! == style\lower!
                if #familyWords > 0
                    return table.concat(familyWords, " "), word
                else
                    remainingWords = {}
                    for j = i + 1, #words
                        table.insert remainingWords, words[j]
                    if #remainingWords > 0
                        return table.concat(remainingWords, " "), word
                    return fontName, nil
        table.insert familyWords, word
    return fontName, nil

getRepresentativeFont = (familyName) ->
    if not fontFamilies[familyName]
        return familyName
    return familyName

enumFontFamExProc = ffi.cast "int (__stdcall *)(const ENUMLOGFONTEX*, const NEWTEXTMETRICEX*, int, void*)", (lpelfe, lpntme, FontType, lParam) ->
    fontName = ffi.string lpelfe.elfLogFont.lfFaceName
    if fontName ~= "" and fontName\sub(1, 1) ~= "@"
        fontFamilies[fontName] = true
    return 1

populateFontList = ->
    hdc = C.CreateDCA "DISPLAY", nil, nil, nil
    if hdc == nil
        return false
    logfont = ffi.new "LOGFONT"
    logfont.lfCharSet = DEFAULT_CHARSET
    logfont.lfFaceName[0] = 0
    lParam = ffi.cast "void*", 0
    if C.EnumFontFamiliesExA(hdc, logfont, enumFontFamExProc, lParam, 0) == 0
        C.DeleteDC hdc
        return false
    C.DeleteDC hdc
    return true

updateFontList = (listBox, searchText) ->
    C.SendMessageA listBox, LB_RESETCONTENT, 0, 0
    searchText = searchText\lower!
    filteredFonts = [name for name in pairs fontFamilies when name\lower!\find(searchText, 1, true) == 1]
    table.sort filteredFonts
    defaultFontIndex = 0

    for i, name in ipairs filteredFonts
        cName = ffi.new "char[?]", #name + 1, name
        result = C.SendMessageA(listBox, LB_ADDSTRING, 0, ffi.cast("uintptr_t", cName))
        if name\lower! == "arial" and searchText == ""
            defaultFontIndex = i - 1

    if #filteredFonts > 0
        result = C.SendMessageA listBox, LB_SETCURSEL, defaultFontIndex, 0

        selIndex = C.SendMessageA listBox, LB_GETCURSEL, 0, 0
        if selIndex >= 0
            textLen = C.SendMessageA listBox, LB_GETTEXTLEN, selIndex, 0
            if textLen > 0
                buffer = ffi.new "char[?]", textLen + 1
                if C.SendMessageA(listBox, LB_GETTEXT, selIndex, ffi.cast("uintptr_t", buffer)) ~= -1
                    currentFont = ffi.string buffer
                else
                    currentFont = "Arial"
            else
                currentFont = "Arial"
    else
        currentFont = "Arial"
    C.InvalidateRect listBox, nil, 1

getFontHeight = (fontName, fontSize) ->
    hdc = C.CreateDCA "DISPLAY", nil, nil, nil
    if hdc == nil
        return 40
    cFontName = ffi.new "char[?]", #fontName + 1, fontName
    hFont = C.CreateFontA(fontSize, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 0, 0, cFontName)
    if hFont == nil
        C.DeleteDC hdc
        return 40
    oldFont = C.SelectObject hdc, hFont
    tm = ffi.new "TEXTMETRIC"
    if C.GetTextMetricsA(hdc, tm) == 0
        C.SelectObject hdc, oldFont
        C.DeleteObject hFont
        C.DeleteDC hdc
        return 40
    height = tm.tmHeight + tm.tmExternalLeading
    C.SelectObject hdc, oldFont
    C.DeleteObject hFont
    C.DeleteDC hdc
    return height

setListBoxItemHeight = (listBox, height) ->
    if C.SendMessageA(listBox, 0x01A0, 0, height) == -1
        return -------

createCheckbox = (hwndParent, hInstance, label, id, x, y) ->
    cLabel = ffi.new "char[?]", #label + 1, label
    checkbox = C.CreateWindowExA(0, "BUTTON", cLabel, 0x50010003, x, y, 100, 20, hwndParent, cast("void*", id), hInstance, nil)
    return checkbox

createListBox = (hwndParent, hInstance, id, x, y, width, height) ->
    styles = WS_CHILD + WS_VISIBLE + LBS_NOTIFY + LBS_HASSTRINGS + LBS_DISABLENOSCROLL
    if id == 1001
        styles = styles + LBS_OWNERDRAWFIXED + WS_VSCROLL
    listBox = C.CreateWindowExA(0x00000004, "LISTBOX", "", styles, x, y, width, height, hwndParent, cast("void*", id), hInstance, nil)
    return listBox

createStaticText = (hwndParent, hInstance, text, x, y, width, height, id = nil) ->
    cText = ffi.new "char[?]", #text + 1, text
    static = C.CreateWindowExA(0, "STATIC", cText, 0x50010000, x, y, width, height, hwndParent, cast("void*", id), hInstance, nil)
    return static

createButton = (hwndParent, hInstance, text, id, x, y, width, height) ->
    cText = ffi.new "char[?]", #text + 1, text
    button = C.CreateWindowExA(0, "BUTTON", cText, 0x50010000, x, y, width, height, hwndParent, cast("void*", id), hInstance, nil)
    return button

createTrackbar = (hwndParent, hInstance, id, x, y, width, height) ->
    trackbar = C.CreateWindowExA(0, "msctls_trackbar32", "", 0x50010000, x, y, width, height, hwndParent, cast("void*", id), hInstance, nil)
    C.SendMessageA trackbar, TBM_SETRANGE, 1, MAKELONG(8, 72)
    C.SendMessageA trackbar, TBM_SETPOS, 1, 24
    return trackbar

createEditBox = (hwndParent, hInstance, id, x, y, width, height, initialText) ->
    exStyle = id == SEARCH_EDIT and WS_EX_CLIENTEDGE or 0x00000004
    style = WS_CHILD + WS_VISIBLE + WS_BORDER + 0x00001080
    editBox = C.CreateWindowExA(exStyle, "EDIT", "", style, x, y, width, height, hwndParent, cast("void*", id), hInstance, nil)
    cText = ffi.new "char[?]", #initialText + 1, initialText
    C.SendMessageA editBox, 0x000C, 0, ffi.cast("uintptr_t", cText)
    return editBox

wndProc = ffi.cast "LRESULT (__stdcall *)(HWND, UINT, uintptr_t, uintptr_t)", (hwnd, msg, wParam, lParam) ->
    if msg == 0x0010
        C.DestroyWindow hwnd
        return 0
    elseif msg == 0x0012
        return 0
    elseif msg == WM_KEYDOWN
        if wParam == VK_ESCAPE
            C.SendMessageA hwnd, WM_COMMAND, MAKELONG(1006, BN_CLICKED), 0
            return 0
        elseif wParam == VK_RETURN
            C.SendMessageA hwnd, WM_COMMAND, MAKELONG(1005, BN_CLICKED), 0
            RESULT_TO_AEGI = 0
            return 0
    elseif msg == WM_COMMAND
        control_id = tonumber(wParam) % 65536
        notification_code = math.floor(tonumber(wParam) / 65536)
        if control_id == 1001 and notification_code == LBN_SELCHANGE
            listBox = C.GetDlgItem hwnd, 1001
            selIndex = C.SendMessageA listBox, LB_GETCURSEL, 0, 0
            if selIndex >= 0
                textLen = C.SendMessageA listBox, LB_GETTEXTLEN, selIndex, 0
                if textLen <= 0
                    currentFont = "Arial"
                else
                    buffer = ffi.new "char[?]", textLen + 1
                    if C.SendMessageA(listBox, LB_GETTEXT, selIndex, ffi.cast("uintptr_t", buffer)) == -1
                        currentFont = "Arial"
                    else
                        currentFont = ffi.string buffer
                        if currentFont == nil or currentFont == ""
                            currentFont = "Arial"
                C.InvalidateRect hwnd, nil, 1
        elseif control_id == 1003 and notification_code == BN_CLICKED
            checkbox = C.GetDlgItem hwnd, 1003
            isStrikethrough = not isStrikethrough
            C.SendMessageA checkbox, BM_SETCHECK, isStrikethrough and BST_CHECKED or BST_UNCHECKED, 0
            C.InvalidateRect hwnd, nil, 1
        elseif control_id == 1004 and notification_code == BN_CLICKED
            checkbox = C.GetDlgItem hwnd, 1004
            isUnderline = not isUnderline
            C.SendMessageA checkbox, BM_SETCHECK, isUnderline and BST_CHECKED or BST_UNCHECKED, 0
            C.InvalidateRect hwnd, nil, 1
        elseif control_id == 1007 and notification_code == LBN_SELCHANGE
            listBox = C.GetDlgItem hwnd, 1007
            selIndex = C.SendMessageA listBox, LB_GETCURSEL, 0, 0
            if selIndex >= 0
                isBold = false
                isItalic = false
                if selIndex == 1
                    isBold = true
                elseif selIndex == 2
                    isItalic = true
                elseif selIndex == 3
                    isBold = true
                    isItalic = true
                C.InvalidateRect hwnd, nil, 1
        elseif control_id == 1011 and notification_code == EN_CHANGE
            editBox = C.GetDlgItem hwnd, 1011
            textLen = C.SendMessageW editBox, WM_GETTEXTLENGTH, 0, 0
            if textLen > 0
                wBuffer = ffi.new "wchar_t[?]", textLen + 1
                C.SendMessageW editBox, WM_GETTEXT, textLen + 1, ffi.cast("uintptr_t", wBuffer)
                currentText = wideToString wBuffer, textLen
                C.InvalidateRect hwnd, nil, 1
            else
                currentText = ""
                C.InvalidateRect hwnd, nil, 1
        elseif control_id == SEARCH_EDIT and notification_code == EN_CHANGE
            editBox = C.GetDlgItem hwnd, SEARCH_EDIT
            textLen = C.SendMessageA editBox, WM_GETTEXTLENGTH, 0, 0
            searchText = ""
            if textLen > 0
                buffer = ffi.new "char[?]", textLen + 1
                C.SendMessageA editBox, WM_GETTEXT, textLen + 1, ffi.cast("uintptr_t", buffer)
                searchText = ffi.string buffer
            fontList = C.GetDlgItem hwnd, 1001
            updateFontList fontList, searchText
            return 0
        elseif control_id == 1005 and notification_code == BN_CLICKED
            dialog_ok = true
            C.DestroyWindow hwnd
        elseif control_id == 1006 and notification_code == BN_CLICKED
            C.DestroyWindow hwnd
        return 0
    elseif msg == WM_HSCROLL
        trackbar = C.GetDlgItem hwnd, 1008
        if trackbar ~= nil
            lParamPtr = ffi.cast("uintptr_t", lParam)
            trackbarPtr = ffi.cast("uintptr_t", trackbar)
            if lParamPtr == trackbarPtr
                currentFontSize = C.SendMessageA trackbar, TBM_GETPOS, 0, 0
                updateSizeLabel hwnd
                fontList = C.GetDlgItem hwnd, 1001
                if fontList ~= nil
                    arialHeight = getFontHeight "Arial", 16
                    previewHeight = getFontHeight "Arial", currentFontSize
                    itemHeight = arialHeight + previewHeight + 15
                    setListBoxItemHeight fontList, itemHeight
                C.InvalidateRect hwnd, nil, 1
        return 0
    elseif msg == WM_DRAWITEM
        dis = ffi.cast("DRAWITEMSTRUCT*", lParam)
        if dis.CtlID == 1001
            if dis.itemID == -1
                return 1
            textLen = C.SendMessageA dis.hwndItem, LB_GETTEXTLEN, dis.itemID, 0
            if textLen <= 0
                return 1
            buffer = ffi.new "char[?]", textLen + 1
            if C.SendMessageA(dis.hwndItem, LB_GETTEXT, dis.itemID, ffi.cast("uintptr_t", buffer)) == -1
                return 1
            fontName = ffi.string buffer
            isSelected = (dis.itemState % 2) == 1
            if isSelected
                C.SetTextColor dis.hDC, 0xFFFFFF
                C.SetBkColor dis.hDC, C.GetSysColor(COLOR_HIGHLIGHT)
            else
                C.SetTextColor dis.hDC, 0x000000
                C.SetBkColor dis.hDC, 0xFFFFFF
            C.SetBkMode dis.hDC, 2
            cArialName = ffi.new "char[?]", 6, "Arial"
            hFontArial = C.CreateFontA(16, 0, 0, 0, 400, 0, 0, 0, 0, 0, 0, 0, 0, cArialName)
            if hFontArial == nil
                return 1
            oldFont = C.SelectObject dis.hDC, hFontArial
            tmArial = ffi.new "TEXTMETRIC"
            C.GetTextMetricsA dis.hDC, tmArial
            arialHeight = tmArial.tmHeight
            yPosArial = dis.rcItem.top + 5
            cFontName = ffi.new "char[?]", #fontName + 1, fontName
            C.TextOutA dis.hDC, dis.rcItem.left + 5, yPosArial, cFontName, #fontName
            C.SelectObject dis.hDC, oldFont
            C.DeleteObject hFontArial
            cFontName = ffi.new "char[?]", #fontName + 1, fontName
            hFont = C.CreateFontA(currentFontSize, 0, 0, 0, isBold and 700 or 400, isItalic and 1 or 0, isUnderline and 1 or 0, isStrikethrough and 1 or 0, 0, 0, 0, 0, 0, cFontName)
            if hFont == nil
                cFontName = ffi.new "char[?]", 6, "Arial"
                hFont = C.CreateFontA(currentFontSize, 0, 0, 0, isBold and 700 or 400, isItalic and 1 or 0, isUnderline and 1 or 0, isStrikethrough and 1 or 0, 0, 0, 0, 0, 0, cArialName)
                if hFont == nil
                    return 1
            oldFont = C.SelectObject dis.hDC, hFont
            tm = ffi.new "TEXTMETRIC"
            C.GetTextMetricsA dis.hDC, tm
            textHeight = tm.tmHeight
            previewText = currentText and currentText ~= "" and currentText or "The quick brown fox jumps over the lazy dog"
            cPreviewText = ffi.new "char[?]", #previewText + 1, previewText
            yPosPreview = yPosArial + arialHeight + 5
            C.TextOutA dis.hDC, dis.rcItem.left + 5, yPosPreview, cPreviewText, #previewText
            C.SelectObject dis.hDC, oldFont
            C.DeleteObject hFont
            return 1
        return 0
    elseif msg == 0x000F
        ps = ffi.new "PAINTSTRUCT"
        hdc = C.BeginPaint hwnd, ps
        C.EndPaint hwnd, ps
        return 0
    elseif msg == 0x0007
        focusedWnd = ffi.cast("HWND", wParam)
        return 0
    return C.DefWindowProcA hwnd, msg, wParam, lParam

registerClass = (hInstance) ->
    wndClass = ffi.new "WNDCLASSEX"
    wndClass.cbSize = ffi.sizeof "WNDCLASSEX"
    wndClass.style = 0x0003
    wndClass.lpfnWndProc = wndProc
    wndClass.hInstance = hInstance
    wndClass.lpszClassName = className
    wndClass.hbrBackground = ffi.cast "void*", 1 + 5
    result = C.RegisterClassExA(wndClass)
    if result == 0
        errorCode = ffi.errno!
        if errorCode == 1410
            return true
        return false
    return true

createWindow = ->
    dialog_ok = false

    icc = ffi.new "INITCOMMONCONTROLSEX"
    icc.dwSize = ffi.sizeof "INITCOMMONCONTROLSEX"
    icc.dwICC = ICC_BAR_CLASSES

    hInstance = C.GetModuleHandleA nil
    if hInstance == nil
        return

    unless registerClass hInstance
        return

    cClassName = ffi.new "char[?]", #className + 1, className
    hwnd = C.CreateWindowExA(0, cClassName, "Font Manager", WINDOW_STYLE, 1920 / 2 - 1000 / 2, 1080 / 2 - 810 / 2, 1000, 810, nil, nil, hInstance, nil)
    if hwnd == nil
        return

    unless populateFontList!
        return
        
    fontList = createListBox hwnd, hInstance, 1001, 10, 40, 820, 720
    if fontList == nil
        return

    --
    createStaticText hwnd, hInstance, "Font:", 10, 10, 130, 20
    createStaticText hwnd, hInstance, "Style:", 840, 10, 100, 20
    createStaticText hwnd, hInstance, "Effect", 840, 120, 100, 20
    createStaticText hwnd, hInstance, "Text Preview:", 840, 600, 100, 20
    sizeLabel = createStaticText hwnd, hInstance, "Dim: #{currentFontSize}", 840, 200, 60, 20, 1010
    createEditBox hwnd, hInstance, SEARCH_EDIT, 150, 10, 600, 25, ""
    styleList = createListBox hwnd, hInstance, 1007, 840, 30, 120, 80
    styles = {"Regular", "Bold", "Italic", "Bold Italic"}

    for i, style in ipairs styles
        cStyle = ffi.new "char[?]", #style + 1, style
        C.SendMessageA styleList, LB_ADDSTRING, 0, ffi.cast("uintptr_t", cStyle)
    C.SendMessageA styleList, LB_SETCURSEL, 0, 0
    sizeTrackbar = createTrackbar hwnd, hInstance, 1008, 840, 220, 100, 20

    createCheckbox hwnd, hInstance, "Strikeout", 1003, 840, 140
    createCheckbox hwnd, hInstance, "Underline", 1004, 840, 160
    createEditBox hwnd, hInstance, 1011, 840, 620, 200, 20, currentText
    createButton hwnd, hInstance, "OK", 1005, 845, 735, 60, 25
    createButton hwnd, hInstance, "Cancel", 1006, 910, 735, 60, 25
    arialHeight = getFontHeight "Arial", 16
    previewHeight = getFontHeight "Arial", currentFontSize
    itemHeight = arialHeight + previewHeight + 15
    setListBoxItemHeight fontList, itemHeight
    updateFontList fontList, ""

    C.ShowWindow hwnd, 1
    C.UpdateWindow hwnd
    msg = ffi.new "MSG"
    while C.GetMessageA(msg, hwnd, 0, 0) > 0
        C.TranslateMessage msg
        C.DispatchMessageA msg
        if msg.message == 0x0010 or msg.message == 0x0012
            break
    C.DestroyWindow hwnd
    if C.UnregisterClassA(className, hInstance) == 0
        aegisub.log "Error: #{ffi.errno!}\n"

    if dialog_ok
        return true, {
            font: currentFont
            size: currentFontSize
            bold: isBold
            italic: isItalic
            underline: isUnderline
            strikethrough: isStrikethrough
        }

FontManager = (sub, sel, activeLine) ->
    editLine, fontData = createWindow!
    ass = Ass sub, sel, activeLine
    
    if not editLine
        return

    for l, s, i, n in ass\iterSel!
		ass\progressLine s, i, n
		Line.extend ass, l
        ass\removeLine l, s
        
        l.tags\insert {{"fn", fontData.font}}
        l.tags\insert {{"fs", fontData.size}}
        l.tags\insert {{"b",  fontData.bold}}
        l.tags\insert {{"i",  fontData.italic}}
        l.tags\insert {{"u",  fontData.underline}}
        l.tags\insert {{"s",  fontData.strikethrough}}
        ass\insertLine l, s

	return ass\getNewSelection!

aegisub.register_macro ": Font Manager :", "", FontManager