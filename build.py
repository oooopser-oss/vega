#!/usr/bin/env python3
"""Собирает папку src/ в готовый файл места Roblox (LifeCity.rbxlx).

Запуск:  python3 build.py
Затем откройте LifeCity.rbxlx в Roblox Studio (File -> Open from File).

Структура такая же, как в default.project.json (Rojo):
  src/shared  -> ReplicatedStorage.Shared
  src/server  -> ServerScriptService.Server
  src/client  -> StarterPlayer.StarterPlayerScripts.Client
Файлы *.server.luau становятся Script, *.client.luau — LocalScript,
остальные *.luau — ModuleScript, папки — Folder.
"""

import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "LifeCity.rbxlx")

_ref = 0


def ref():
    global _ref
    _ref += 1
    return f"RBX{_ref:08X}"


def cdata(text):
    # "]]>" нельзя держать внутри CDATA — разбиваем.
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, body="", props=""):
    return (
        f'<Item class="{cls}" referent="{ref()}"><Properties>'
        f'<string name="Name">{escape(name)}</string>{props}</Properties>{body}</Item>'
    )


def script_item(path):
    fname = os.path.basename(path)
    base = fname[: -len(".luau")]
    if base.endswith(".server"):
        cls, name = "Script", base[: -len(".server")]
    elif base.endswith(".client"):
        cls, name = "LocalScript", base[: -len(".client")]
    else:
        cls, name = "ModuleScript", base
    with open(path, encoding="utf-8") as f:
        source = f.read()
    props = f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return item(cls, name, props=props)


def folder(path, name):
    children = []
    for entry in sorted(os.listdir(path)):
        full = os.path.join(path, entry)
        if os.path.isdir(full):
            children.append(folder(full, entry))
        elif entry.endswith(".luau"):
            children.append(script_item(full))
    return item("Folder", name, body="".join(children))


def main():
    shared = folder(os.path.join(SRC, "shared"), "Shared")
    server = folder(os.path.join(SRC, "server"), "Server")
    client = folder(os.path.join(SRC, "client"), "Client")

    parts = [
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">',
        # Потоковая загрузка карты: клиент держит в памяти только ближайшие районы.
        item("Workspace", "Workspace", props='<bool name="StreamingEnabled">true</bool>'
             '<int name="StreamingTargetRadius">1024</int><int name="StreamingMinRadius">256</int>'),
        # Освещение Future: тени и свет фонарей; на слабых устройствах Roblox сам упрощает.
        item("Lighting", "Lighting", props='<token name="Technology">4</token>'),
        item("ReplicatedStorage", "ReplicatedStorage", body=shared),
        item("ServerScriptService", "ServerScriptService", body=server),
        item("StarterPlayer", "StarterPlayer", body=item("StarterPlayerScripts", "StarterPlayerScripts", body=client)),
        "</roblox>",
    ]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print(f"Готово: {OUT}")


if __name__ == "__main__":
    main()
