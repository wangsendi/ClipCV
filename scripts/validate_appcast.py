import base64
import datetime
import email.utils
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"
ET.register_namespace("sparkle", SPARKLE[1:-1])


def validate(generated, release):
    tree = ET.parse(generated)
    channel = tree.find("channel")
    item = channel.find("item")
    enclosure = item.find("enclosure")
    build = item.findtext(SPARKLE + "version")
    display = item.findtext(SPARKLE + "shortVersionString")
    expected = release["tag_name"].removeprefix("v")
    if display != expected or build != expected:
        raise ValueError(f"Release {expected} requires application Version and Build {expected}; got {display} ({build})")
    asset = next(asset for asset in release["assets"] if asset["name"] == "ClipCV.dmg")
    if enclosure.get("url") != asset["browser_download_url"] or int(enclosure.get("length")) != asset["size"]:
        raise ValueError("Appcast URL or file size does not match the release")
    if len(base64.b64decode(enclosure.get(SPARKLE + "edSignature"), validate=True)) != 64:
        raise ValueError("Missing or invalid EdDSA signature")
    if not item.findtext(SPARKLE + "minimumSystemVersion"):
        raise ValueError("Missing minimum macOS version")
    item.find("pubDate").text = email.utils.format_datetime(datetime.datetime.fromisoformat(release["published_at"].replace("Z", "+00:00")))
    channel.find("title").text = "ClipCV"
    feed_link = channel.find("link")
    if feed_link is None:
        feed_link = ET.SubElement(channel, "link")
    feed_link.text = "https://raw.githubusercontent.com/wangsendi/ClipCV/main/appcast.xml"
    ET.indent(tree, space="  ")
    tree.write(generated, encoding="utf-8", xml_declaration=True)
    print(f"Validated ClipCV {display}, build {build}, {asset['size']} bytes")


if __name__ == "__main__":
    validate(Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text()))
