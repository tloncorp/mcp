#!/usr/bin/env python3
"""Exercise a fake ship against a localhost Calendar API; no Google credentials."""

import argparse
import json
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import parse_qs, urlsplit
from urllib.request import Request, urlopen

MOCK_URL = "http://127.0.0.1:18891/calendar/v3/"
PREFIX = "google-calendar_calendar."
METHODS = {
    "calendarList.get": True, "calendarList.list": True,
    "events.get": True, "events.list": True,
    "events.insert": False, "events.patch": False, "freebusy.query": True,
}
ENDPOINT = "http://127.0.0.1:18781/apps/mcp/mcp"
API_KEY = "calendar-local-test"


class MockCalendar(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def handle_request(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if self.path == "/discovery.json":
            result = json.loads(Path(__file__).with_name("discovery.json").read_text())
            result["baseUrl"] = MOCK_URL
        else:
            result = {
                "id": "mock-event",
                "echo": {
                    "method": self.command, "path": self.path,
                    "body": json.loads(body) if body else None,
                    "authorization": self.headers.get("Authorization"),
                },
            }
        data = json.dumps(result).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    do_GET = handle_request
    do_POST = handle_request
    do_PATCH = handle_request


def rpc(name, arguments):
    payload = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
               "params": {"name": name, "arguments": arguments}}
    request = Request(ENDPOINT, json.dumps(payload).encode(),
                      {"Content-Type": "application/json", "X-Api-Key": API_KEY})
    with urlopen(request, timeout=20) as response:
        result = json.load(response)["result"]
    if result.get("isError"):
        raise AssertionError(result)
    return json.loads(result["content"][0]["text"])


class CalendarSmokeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Refuse write tests unless the fake ship points at this mock API.
        upstreams = rpc("list_upstreams", {})["upstreams"]
        calendar = next(u for u in upstreams if u["id"] == "google-calendar")
        if calendar["url"] != MOCK_URL or not calendar["enabled"]:
            raise AssertionError("Configure the localhost mock upstream before testing")
        echo = rpc("call", {"name": PREFIX + "calendarList.list", "arguments": {}})["echo"]
        if echo["path"] != "/calendar/v3/users/me/calendarList":
            raise AssertionError("Calendar reads must reach the mock API before write tests")

    def invoke(self, method, args):
        result = rpc("call", {"name": PREFIX + method, "arguments": args})["echo"]
        self.assertEqual(result["authorization"], "Bearer calendar-mock-access-token")
        return result

    def test_catalog_and_schemas(self):
        catalog = rpc("search", {"server": "google-calendar"})
        self.assertEqual({t["name"] for t in catalog["tools"]},
                         {PREFIX + method for method in METHODS})
        for method, readonly in METHODS.items():
            with self.subTest(method=method):
                tool = rpc("describe", {"name": PREFIX + method})
                self.assertEqual(tool["annotations"]["readOnlyHint"], readonly)
                self.assertNotIn('"$ref"', json.dumps(tool["inputSchema"]))
        creation = rpc("describe", {"name": PREFIX + "events.insert"})["inputSchema"]
        body = creation["properties"]["body"]
        self.assertEqual(body["required"], ["start", "end"])
        self.assertEqual(body["properties"]["attendees"]["items"]["type"], "object")

    def test_reads_and_repeated_query(self):
        for method, args, path in (
            ("calendarList.get", {"calendarId": "primary"}, "/users/me/calendarList/primary"),
            ("events.get", {"calendarId": "team@example.com", "eventId": "event"}, "/calendars/team@example.com/events/event"),
        ):
            with self.subTest(method=method):
                result = self.invoke(method, args)
                self.assertEqual(result["method"], "GET")
                self.assertEqual(result["path"], "/calendar/v3" + path)
        result = self.invoke("events.list", {"calendarId": "primary", "maxResults": 5,
                                             "eventTypes": ["default", "outOfOffice"]})
        query = parse_qs(urlsplit(result["path"]).query)
        self.assertEqual(query["eventTypes"], ["default", "outOfOffice"])
        self.assertEqual(query["maxResults"], ["5"])

    def test_create_and_patch(self):
        body = {"summary": "Mock meeting", "attendees": [{"email": "test@example.invalid"}],
                "start": {"dateTime": "2026-10-13T10:00:00-04:00", "timeZone": "America/New_York"},
                "end": {"dateTime": "2026-10-13T10:30:00-04:00", "timeZone": "America/New_York"}}
        result = self.invoke("events.insert", {"calendarId": "primary", "sendUpdates": "none", "body": body})
        self.assertEqual(result["method"], "POST")
        self.assertEqual(result["body"], body)
        self.assertEqual(parse_qs(urlsplit(result["path"]).query)["sendUpdates"], ["none"])
        changes = {"summary": "Changed"}
        result = self.invoke("events.patch", {"calendarId": "primary", "eventId": "mock-event", "body": changes})
        self.assertEqual(result["method"], "PATCH")
        self.assertEqual(result["body"], changes)
        self.assertEqual(result["path"], "/calendar/v3/calendars/primary/events/mock-event")

    def test_availability(self):
        body = {"timeMin": "2026-10-13T00:00:00Z", "timeMax": "2026-10-14T00:00:00Z",
                "items": [{"id": "primary"}]}
        result = self.invoke("freebusy.query", {"body": body})
        self.assertEqual(result["method"], "POST")
        self.assertEqual(result["path"], "/calendar/v3/freeBusy")
        self.assertEqual(result["body"], body)

    def test_delete_is_unavailable(self):
        with self.assertRaises(HTTPError) as error:
            rpc("call", {"name": PREFIX + "events.delete",
                         "arguments": {"calendarId": "primary", "eventId": "event"}})
        self.assertEqual(error.exception.code, 404)

    @unittest.expectedFailure
    def test_urbit_preserves_encoded_path_separator(self):
        # Existing Vere cttp decodes paths and writes segments without escaping.
        # Track this transport limitation separately from normal Calendar IDs.
        result = self.invoke("events.get", {"calendarId": "a/b", "eventId": "event"})
        self.assertEqual(result["path"], "/calendar/v3/calendars/a%2Fb/events/event")


def main():
    global ENDPOINT, API_KEY
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["serve", "test"])
    parser.add_argument("--endpoint", default=ENDPOINT)
    parser.add_argument("--api-key", default=API_KEY)
    args = parser.parse_args()
    if args.mode == "serve":
        print("Mock Calendar API: http://127.0.0.1:18891", flush=True)
        ThreadingHTTPServer(("127.0.0.1", 18891), MockCalendar).serve_forever()
    else:
        if urlsplit(args.endpoint).hostname not in {"127.0.0.1", "localhost", "::1"}:
            parser.error("Use a local fake ship for smoke tests")
        ENDPOINT, API_KEY = args.endpoint, args.api_key
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(CalendarSmokeTest)
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        raise SystemExit(0 if result.wasSuccessful() else 1)


if __name__ == "__main__":
    main()
