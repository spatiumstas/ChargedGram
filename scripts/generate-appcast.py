import argparse
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
import plistlib
import xml.etree.ElementTree as ET
import zipfile


def generate_appcast(archive):
    with zipfile.ZipFile(archive) as bundle:
        info = plistlib.loads(bundle.read("ChargedGram.app/Contents/Info.plist"))
    version = info["CFBundleShortVersionString"]
    build = info["CFBundleVersion"]
    tag = f"{version}.{build}"
    releases = "https://github.com/spatiumstas/ChargedGram/releases"
    sparkle = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    ET.register_namespace("sparkle", sparkle)
    rss = ET.Element("rss", {"version": "2.0"})
    channel = ET.SubElement(rss, "channel")
    ET.SubElement(channel, "title").text = "ChargedGram"
    ET.SubElement(channel, "link").text = f"{releases}/latest"
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"ChargedGram {version} ({build})"
    ET.SubElement(item, "pubDate").text = format_datetime(datetime.now(timezone.utc), usegmt=True)
    ET.SubElement(item, f"{{{sparkle}}}minimumSystemVersion").text = info["LSMinimumSystemVersion"]
    ET.SubElement(item, "enclosure", {
        "url": f"{releases}/download/{tag}/{archive.name}",
        "length": str(archive.stat().st_size),
        "type": "application/octet-stream",
        f"{{{sparkle}}}version": build,
        f"{{{sparkle}}}shortVersionString": version,
    })
    output = archive.parent / "appcast.xml"
    ET.indent(rss)
    ET.ElementTree(rss).write(output, encoding="utf-8", xml_declaration=True)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    print(generate_appcast(parser.parse_args().archive))
