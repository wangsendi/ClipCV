import json
import sys
import xml.etree.ElementTree as ET
from base64 import b64decode
from datetime import datetime
from email.utils import format_datetime
from pathlib import Path

SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SPARKLE = f"{{{SPARKLE_NAMESPACE}}}"
FEED_URL = "https://raw.githubusercontent.com/wangsendi/ClipCV/main/appcast.xml"
ET.register_namespace("sparkle", SPARKLE_NAMESPACE)


def validate_item(item: ET.Element, release: dict) -> None:
    expected = release["tag_name"].removeprefix("v")
    build = item.findtext(SPARKLE + "version")
    display = item.findtext(SPARKLE + "shortVersionString")
    if display != expected or build != expected:
        raise ValueError(f"Release {expected} requires matching Version and Build; " f"got {display} ({build})")

    asset = next(asset for asset in release["assets"] if asset["name"] == "ClipCV.dmg")
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise ValueError("Missing appcast enclosure")
    if enclosure.get("url") != asset["browser_download_url"]:
        raise ValueError("Appcast URL does not match the release")
    if int(enclosure.get("length", "0")) != asset["size"]:
        raise ValueError("Appcast file size does not match the release")

    signature = enclosure.get(SPARKLE + "edSignature", "")
    if len(b64decode(signature, validate=True)) != 64:
        raise ValueError("Missing or invalid EdDSA signature")
    if not item.findtext(SPARKLE + "minimumSystemVersion"):
        raise ValueError("Missing minimum macOS version")


def update_appcast(path: Path, release: dict) -> None:
    tree = ET.parse(path)
    channel = tree.find("channel")
    item = tree.find("channel/item")
    if channel is None or item is None:
        raise ValueError("Missing appcast channel or item")
    validate_item(item, release)

    published_at = datetime.fromisoformat(release["published_at"].replace("Z", "+00:00"))
    item.find("pubDate").text = format_datetime(published_at)
    channel.find("title").text = "ClipCV"
    feed_link = channel.find("link")
    if feed_link is None:
        feed_link = ET.SubElement(channel, "link")
    feed_link.text = FEED_URL

    ET.indent(tree, space="  ")
    tree.write(path, encoding="utf-8", xml_declaration=True)
    print(f"Validated ClipCV {release['tag_name']}")


if __name__ == "__main__":
    appcast_path = Path(sys.argv[1])
    release_path = Path(sys.argv[2])
    update_appcast(appcast_path, json.loads(release_path.read_text()))
