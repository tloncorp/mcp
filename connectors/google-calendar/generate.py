#!/usr/bin/env python3
"""Produce the Calendar v1 tool surface from Google's Discovery document."""

import argparse
import copy
import json
from pathlib import Path

SCOPES = {
    "https://www.googleapis.com/auth/calendar.events",
    "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
    "https://www.googleapis.com/auth/calendar.events.freebusy",
}
METHODS = {
    "calendarList": {"list", "get"},
    "events": {"list", "get", "insert", "patch"},
    "freebusy": {"query"},
}
EVENT_FIELDS = {
    "summary", "description", "location", "start", "end", "recurrence",
    "attendees", "reminders", "transparency", "visibility", "colorId",
}


def generate(source):
    if source.get("name") != "calendar" or source.get("version") != "v3":
        raise ValueError("Expected the Google Calendar v3 Discovery document")
    result = {
        key: copy.deepcopy(source[key])
        for key in ("kind", "name", "version", "id", "rootUrl", "baseUrl", "servicePath")
        if key in source
    }
    result["description"] = "Tlonbot Calendar v1: calendars, events, and availability."
    result["resources"] = {}
    refs = set()
    for resource, names in METHODS.items():
        methods = {}
        for name in sorted(names):
            method = copy.deepcopy(source["resources"][resource]["methods"][name])
            if not SCOPES.intersection(method.get("scopes", [])):
                raise ValueError(f"Configured scopes cannot call {method['id']}")
            method["scopes"] = sorted(SCOPES.intersection(method["scopes"]))
            method.pop("response", None)
            method.pop("supportsSubscription", None)
            if method["id"] == "calendar.events.insert":
                method["request"]["$ref"] = "TlonCalendarEventCreate"
            if name in {"insert", "patch"}:
                method["description"] += (
                    " Only send attendee notifications when the user requested them;"
                    " otherwise set sendUpdates=none. Google may still send some emails."
                )
            methods[name] = method
            collect_refs(method.get("request", {}), refs)
        result["resources"][resource] = {"methods": methods}

    # Use Google's schemas, narrowing the writable event fields for this release.
    schemas = copy.deepcopy(source["schemas"])
    schemas["Event"]["properties"] = {
        key: value for key, value in schemas["Event"]["properties"].items()
        if key in EVENT_FIELDS
    }
    schemas["Event"].pop("id", None)
    schemas["TlonCalendarEventCreate"] = copy.deepcopy(schemas["Event"])
    schemas["TlonCalendarEventCreate"]["required"] = ["start", "end"]
    schemas["FreeBusyRequest"]["required"] = ["timeMin", "timeMax", "items"]
    result["schemas"] = {}
    while refs:
        name = min(refs)
        refs.remove(name)
        if name in result["schemas"]:
            continue
        schema = schemas[name]
        result["schemas"][name] = schema
        collect_refs(schema, refs)
    return result


def collect_refs(value, refs):
    if isinstance(value, dict):
        if "$ref" in value:
            refs.add(value["$ref"])
        for child in value.values():
            collect_refs(child, refs)
    elif isinstance(value, list):
        for child in value:
            collect_refs(child, refs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Downloaded official Calendar Discovery JSON")
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("discovery.json"))
    args = parser.parse_args()
    result = generate(json.loads(args.source.read_text()))
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")


if __name__ == "__main__":
    main()
