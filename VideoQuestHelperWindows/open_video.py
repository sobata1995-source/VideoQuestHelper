import ctypes
from ctypes import wintypes
from pathlib import Path
import time
import webbrowser
import sys
from urllib.parse import urlencode

from PIL import ImageGrab


ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
CELL_COUNT = 93
WOW_EXECUTABLES = {"wow.exe", "wowforever.exe", "wowt.exe", "wowclassic.exe"}


def decode(pixels, include_pitch=False):
    def magenta(p):
        r, g, b = p[:3]
        return r > 160 and g < 85 and b > 160

    def cyan(p):
        r, g, b = p[:3]
        return r < 85 and g > 160 and b > 160

    width = len(pixels)
    for left in range(width // 2):
        if not magenta(pixels[left]) or (left and magenta(pixels[left - 1])):
            continue
        expected = width - left - 1
        for right in range(min(width - 1, expected + 4), max(width // 2, expected - 5), -1):
            if not cyan(pixels[right]) or (right + 1 < width and cyan(pixels[right + 1])):
                continue
            cell = (right - left + 1) / CELL_COUNT
            if cell < 2 or not magenta(pixels[int(left + cell / 2)]):
                continue
            if not cyan(pixels[int(right + 1 - cell / 2)]):
                continue
            bits = []
            for index in range(1, CELL_COUNT - 1):
                color = pixels[int(left + (index + 0.5) * cell)][:3]
                if min(color) > 170:
                    bits.append("1")
                elif max(color) < 85:
                    bits.append("0")
                else:
                    break
            if len(bits) != 91:
                continue
            bits = "".join(bits)
            values = [int(bits[i:i + 6], 2) for i in range(0, 66, 6)]
            seconds = int(bits[66:75], 2)
            sequence = int(bits[75:83], 2)
            checksum = sum(i * value for i, value in enumerate(values, 1)) + seconds + sequence
            if checksum % 256 == int(bits[83:91], 2):
                request = ("".join(ALPHABET[value] for value in values), seconds, sequence)
                return (*request, 2 * cell) if include_pitch else request


def decode_request(image):
    width, height = image.size
    header = decode(list(image.crop((0, 0, width, 1)).getdata()), include_pitch=True)
    if not header:
        return None
    token, seconds, sequence, pitch = header
    if seconds != 511:
        url = "https://www.youtube.com/watch?v=" + token
        if seconds:
            url += "&t=" + str(seconds) + "s"
        return url, sequence
    if not token.isascii() or not token.isdecimal() or not 1 <= int(token) <= 150:
        return None
    length = int(token)
    chunks = []
    for index in range(1, (length + 4) // 5 + 1):
        y = round(index * pitch)
        if y >= height:
            return None
        row = decode(list(image.crop((0, y, width, y + 1)).getdata()))
        if not row or row[1:] != (index, sequence):
            return None
        chunks.append(row[0][:10])
    try:
        query = bytes.fromhex("".join(chunks))[:length].decode("utf-8", errors="ignore")
    except ValueError:
        return None
    return "https://www.youtube.com/results?" + urlencode({"search_query": query}), sequence


def monitor():
    user = ctypes.windll.user32
    kernel = ctypes.windll.kernel32
    user.SetProcessDPIAware()
    user.GetForegroundWindow.restype = wintypes.HWND
    user.GetWindowThreadProcessId.argtypes = (wintypes.HWND, ctypes.POINTER(wintypes.DWORD))
    user.GetClientRect.argtypes = (wintypes.HWND, ctypes.POINTER(wintypes.RECT))
    user.ClientToScreen.argtypes = (wintypes.HWND, ctypes.POINTER(wintypes.POINT))
    kernel.OpenProcess.restype = wintypes.HANDLE
    kernel.QueryFullProcessImageNameW.argtypes = (
        wintypes.HANDLE, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD)
    )
    kernel.CloseHandle.argtypes = (wintypes.HANDLE,)

    def is_wow(pid):
        handle = kernel.OpenProcess(0x1000, False, pid)
        if not handle:
            return False
        try:
            path = ctypes.create_unicode_buffer(32768)
            length = wintypes.DWORD(len(path))
            return bool(kernel.QueryFullProcessImageNameW(handle, 0, path, ctypes.byref(length))) and (
                Path(path.value).name.lower() in WOW_EXECUTABLES
            )
        finally:
            kernel.CloseHandle(handle)

    print("Video Quest Helper is ready. Keep this window open while playing.")
    last_request, last_seen = None, 0
    while True:
        hwnd = user.GetForegroundWindow()
        pid = wintypes.DWORD()
        user.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
        rect = wintypes.RECT()
        if is_wow(pid.value) and user.GetClientRect(hwnd, ctypes.byref(rect)):
            width = min(rect.right, 1800)
            point = wintypes.POINT((rect.right - width) // 2, rect.bottom // 2)
            if width > 100 and user.ClientToScreen(hwnd, ctypes.byref(point)):
                try:
                    height = rect.bottom - rect.bottom // 2
                    with ImageGrab.grab((point.x, point.y, point.x + width, point.y + height),
                                        all_screens=True) as image:
                        request = decode_request(image)
                except OSError:
                    request = None
                if request:
                    now = time.monotonic()
                    if request != last_request or now - last_seen > 1:
                        webbrowser.open(request[0])
                    last_request, last_seen = request, now
        time.sleep(0.12)


if __name__ == "__main__":
    if sys.argv[1:] == ["--check"]:
        ctypes.windll.user32.GetForegroundWindow()
        print("Video Quest Helper: Windows and Pillow loaded.")
        sys.exit(0)
    try:
        monitor()
    except KeyboardInterrupt:
        pass
