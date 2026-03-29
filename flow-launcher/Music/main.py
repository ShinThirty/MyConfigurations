# -*- coding: utf-8 -*-

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

sys.path.append(os.path.join(os.path.dirname(__file__), "lib"))

from flowlauncher import FlowLauncher  # noqa: E402

PLAYLIST_DIR: Path = Path.home() / "Music" / "playlists"
MPV_PIPE: str = r"\\.\pipe\mpv-music"
ICON: str = "Images/icon.png"
ACTION_KEYWORD: str = "m"

QueryResult = dict[str, Any]


class Music(FlowLauncher):
    def query(self, param: str = "") -> list[QueryResult]:
        query: str = param.strip()

        if not PLAYLIST_DIR.exists():
            return [
                {
                    "Title": "No playlists directory",
                    "SubTitle": str(PLAYLIST_DIR),
                    "IcoPath": ICON,
                }
            ]

        if not query:
            results: list[QueryResult] = []
            title: str | None = _mpv_get_property("media-title")
            if title is not None:
                results.extend(self._playback_controls(title))
            results.extend(self._list_playlists())
            return results

        playlist_name, search = _split_query(query)
        return self._list_tracks(playlist_name, search)

    def _playback_controls(self, title: str) -> list[QueryResult]:
        paused: bool | None = _mpv_get_property("pause")
        state: str = "Paused" if paused else "Now Playing"
        toggle: str = "Resume" if paused else "Pause"

        return [
            {
                "Title": f"{state}: {title}",
                "SubTitle": f"Enter to {toggle.lower()}",
                "IcoPath": ICON,
                "JsonRPCAction": {
                    "method": "mpv_command",
                    "parameters": [["cycle", "pause"]],
                    "dontHideAfterAction": True,
                },
            },
            {
                "Title": "Next Track",
                "IcoPath": ICON,
                "JsonRPCAction": {
                    "method": "mpv_command",
                    "parameters": [["playlist-next"]],
                    "dontHideAfterAction": True,
                },
            },
            {
                "Title": "Previous Track",
                "IcoPath": ICON,
                "JsonRPCAction": {
                    "method": "mpv_command",
                    "parameters": [["playlist-prev"]],
                    "dontHideAfterAction": True,
                },
            },
            {
                "Title": "Stop Music",
                "IcoPath": ICON,
                "JsonRPCAction": {
                    "method": "mpv_command",
                    "parameters": [["quit"]],
                },
            },
        ]

    def _playlist_item(self, playlist_file: Path) -> QueryResult:
        count: int = len(_read_entries(playlist_file))
        return {
            "Title": playlist_file.stem,
            "SubTitle": f"{count} track{'s' if count != 1 else ''} — Enter to play, Ctrl+Tab to browse",
            "IcoPath": ICON,
            "JsonRPCAction": {
                "method": "play_all",
                "parameters": [playlist_file.stem, False],
            },
        }

    def _list_playlists(self) -> list[QueryResult]:
        results: list[QueryResult] = [
            self._playlist_item(f) for f in sorted(PLAYLIST_DIR.glob("*.txt"))
        ]
        if not results:
            return [
                {
                    "Title": "No playlists found",
                    "SubTitle": f"Add .txt files to {PLAYLIST_DIR}",
                    "IcoPath": ICON,
                }
            ]
        return results

    def _list_tracks(self, playlist_name: str, search: str = "") -> list[QueryResult]:
        playlist_file: Path = PLAYLIST_DIR / f"{playlist_name}.txt"

        if not playlist_file.exists():
            results: list[QueryResult] = [
                self._playlist_item(f)
                for f in sorted(PLAYLIST_DIR.glob("*.txt"))
                if playlist_name.lower() in f.stem.lower()
            ]
            return results or [
                {
                    "Title": f"No playlist matching: {playlist_name}",
                    "IcoPath": ICON,
                }
            ]

        entries: list[str] = _read_entries(playlist_file)
        if not entries:
            return [{"Title": "Playlist is empty", "IcoPath": ICON}]

        tracks: list[list[str]] = _parse_tracks(entries)

        if search:
            tracks = [t for t in tracks if search in t[0].lower()]
            if not tracks:
                return [{"Title": f"No tracks matching: {search}", "IcoPath": ICON}]

        results: list[QueryResult] = [
            {
                "Title": "Play All",
                "SubTitle": f"{len(tracks)} tracks",
                "IcoPath": ICON,
                "JsonRPCAction": {
                    "method": "play_all",
                    "parameters": [playlist_name, False],
                },
            },
            {
                "Title": "Shuffle All",
                "SubTitle": f"{len(tracks)} tracks",
                "IcoPath": ICON,
                "JsonRPCAction": {
                    "method": "play_all",
                    "parameters": [playlist_name, True],
                },
            },
        ]

        for title, url in tracks:
            results.append(
                {
                    "Title": title,
                    "SubTitle": url,
                    "IcoPath": ICON,
                    "JsonRPCAction": {
                        "method": "play",
                        "parameters": [[[title, url]], False],
                        "dontHideAfterAction": True,
                    },
                }
            )

        return results

    def mpv_command(self, cmd: list[str]) -> None:
        _mpv_send(cmd)

    def play_all(self, name: str, shuffle: bool) -> None:
        entries: list[str] = _read_entries(PLAYLIST_DIR / f"{name}.txt")
        tracks: list[list[str]] = _parse_tracks(entries)
        _launch_mpv(tracks, shuffle)

    def play(self, tracks: list[list[str]], shuffle: bool) -> None:
        _launch_mpv(tracks, shuffle)


def _split_query(query: str) -> tuple[str, str]:
    """Split query into (playlist_name, search_term), handling spaces in names."""
    stems: set[str] = {f.stem for f in PLAYLIST_DIR.glob("*.txt")}
    words: list[str] = query.split()
    for i in range(len(words), 0, -1):
        candidate: str = " ".join(words[:i])
        if candidate in stems:
            search: str = " ".join(words[i:]).lower()
            return candidate, search
    return query, ""


def _read_entries(filepath: Path) -> list[str]:
    try:
        lines: list[str] = filepath.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    return [s for line in lines if (s := line.strip()) and not s.startswith("#")]


def _mpv_send(cmd: list[str]) -> dict[str, Any] | None:
    try:
        with open(MPV_PIPE, "r+b", buffering=0) as f:
            f.write((json.dumps({"command": cmd}) + "\n").encode())
            f.flush()
            resp: bytes = f.readline()
            if resp:
                return json.loads(resp)
    except (OSError, json.JSONDecodeError):
        return None
    return None


def _mpv_get_property(prop: str) -> Any:
    resp: dict[str, Any] | None = _mpv_send(["get_property", prop])
    if resp and "data" in resp:
        return resp["data"]
    return None


def _parse_tracks(entries: list[str]) -> list[list[str]]:
    tracks: list[list[str]] = []
    for entry in entries:
        parts: list[str] = entry.split("|", 1)
        if len(parts) == 2:
            tracks.append([parts[0].strip(), parts[1].strip()])
        else:
            tracks.append([entry.strip(), entry.strip()])
    return tracks


def _launch_mpv(tracks: list[list[str]], shuffle: bool) -> None:
    _mpv_send(["quit"])
    time.sleep(0.3)
    urls: list[str] = [url for _, url in tracks]
    cmd: list[str] = [
        "mpv",
        "--no-video",
        "--force-window=no",
        f"--input-ipc-server={MPV_PIPE}",
    ]
    if shuffle:
        cmd.append("--shuffle")
    cmd.extend(urls)
    subprocess.Popen(cmd, creationflags=0x08000000)  # CREATE_NO_WINDOW


if __name__ == "__main__":
    Music()
