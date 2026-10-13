# Google Calendar connector

Calendar v1 uses the existing Tlon connector UI, hosting OAuth flow, and
`oauth-proxy` Google template. The relay registers `google-calendar:google`,
delivers its grant and upstream configuration to the moon, and `%mcp-proxy`
converts the curated Discovery document into tools. No new OAuth service is
needed.

This is a locally tested implementation. It has not been deployed or connected
to a real Google account yet.

## Tool surface

| Tool | Purpose | Read-only |
| --- | --- | --- |
| `calendar.calendarList.list` | Choose a calendar; includes calendar time zones | Yes |
| `calendar.calendarList.get` | Read a calendar-list entry | Yes |
| `calendar.events.list` | Search events, with pagination and time filters | Yes |
| `calendar.events.get` | Read an event by Google event ID | Yes |
| `calendar.events.insert` | Create an event | No |
| `calendar.events.patch` | Edit an event | No |
| `calendar.freebusy.query` | Check availability across calendars | Yes |

MCP prefixes names with `google-calendar_`. Use the aggregate endpoint's
`search`, `describe`, and `call` tools to discover and invoke them.

`discovery.json` omits event-delete, calendar-management, sharing/ACL, import,
and subscription methods. A direct call to an omitted operation fails lookup.
Event input schemas include times, recurrence, attendees, reminders, and basic
event metadata. Creation requires `start` and `end`; patch allows partial
updates. These schemas guide the model; the generic proxy does not validate
every argument against JSON Schema before forwarding it.

All read operations carry `annotations.readOnlyHint=true`, including Google's
read-only freebusy POST. Event writes carry `false`, allowing the bot's existing
scheduled-run policy to distinguish reads from writes. The trusted schema can
override the default HTTP-method classification with `x-mcp-read-only`.

Event creation and editing are supported for direct user requests. The
read-only restriction applies to scheduled/background runs, not the interactive
Calendar connector.

Use `sendUpdates=none` for event writes unless the user requested attendee
notifications. Follow Google's notification behavior: some emails may still
be sent even with `none`, and it can affect external calendar synchronization.
See [events.insert](https://developers.google.com/workspace/calendar/api/v3/reference/events/insert).

For timed events, send an RFC3339 time and the intended IANA `timeZone`. For
all-day events, use `date`; the end date is exclusive. List calls may return
`nextPageToken`; pass it back as `pageToken` to continue. For recurring event
expansion, use `singleEvents=true` and time bounds.

## OAuth registration and rollout

1. Release the updated `%mcp` desk to pilot moons first. The previous converter
   exposes request bodies as strings and treats uppercase Discovery verbs as
   GET, so provider registration alone is insufficient.
2. Publish `discovery.json` at an HTTPS URL. Pin its URL to the release commit
   or another immutable deployment; do not use Google's full Discovery URL or
   a mutable branch for production. Check that the relay/moon can fetch it.
3. Create a Google Cloud test project, enable the Google Calendar API, and
   configure an External OAuth consent screen in Testing. Add pilot Google
   accounts as test users.
4. Create a Web application OAuth client. Register the exact redirect URI
   `https://oauth.test.tlon.systems/v1/callback`. For production, create a
   separate client/project with `https://oauth.tlon.io/v1/callback`.
   Select **Use this client for an AI-powered agent**. Google identifies agent
   tool execution separately from human-driven integrations; keep their OAuth
   clients separate. Download the new client secret immediately and store it in
   the secret manager: Google only reveals/downloads it when it is created.
   See [Google's OAuth client guidance](https://support.google.com/cloud/answer/15549257#agentic-client).
5. Set the variables in [oauth-proxy.env.example](oauth-proxy.env.example)
   through the deployment's secret manager. Replace the release-commit
   placeholder. Append `google-calendar:google` to the existing `PROVIDERS`
   value so other connectors remain registered.
6. Deploy/restart the test relay. Confirm the providers response includes
   `google-calendar`, then connect through Tlon's existing connector screen.
   The existing Google template supplies offline access, consent prompting,
   incremental authorization, and PKCE. Client secrets stay on the relay.
7. Complete the live pilot checks below before enabling production users.

### Scopes

| Scope | Justification for Google review |
| --- | --- |
| `calendar.calendarlist.readonly` | Let the user select among their calendars and read the calendar's display name/time zone. |
| `calendar.events` | Read calendar events and create/edit events at the user's request. |
| `calendar.events.freebusy` | Return availability for calendars the user can access. |

Each value above is prefixed with `https://www.googleapis.com/auth/` in the
configuration. Google lists freebusy separately from event access; do not
omit its scope. This connector requests no Gmail scopes.

The Google Auth Platform console currently classifies `calendar.events` as
sensitive; the calendar-list and freebusy scopes above are non-sensitive. The
event scope still requires sensitive-scope verification for a public release.

For an external public release, submit the sensitive scopes for Google OAuth
verification. Prepare the public homepage/privacy policy, domain ownership,
scope justifications, and a video of the actual consent and feature flow.
The privacy policy must describe Calendar data sent through Tlonbot and its
model providers, actual retention/deletion behavior, and how to disconnect.
Review the [Workspace API user data policy](https://developers.google.com/workspace/workspace-api-user-data-developer-policy)
against the deployed bot's data handling. Calendar-only scope review does not
require the restricted-scope security assessment associated with Gmail reads.
See [Calendar scopes](https://developers.google.com/workspace/calendar/api/auth)
and [sensitive-scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification).

Testing-mode grants normally expire after seven days for these scopes, so
reconnection is expected during development. Production approval and deployment
do not happen as part of these local changes.

## Verification

Native library tests run after assembling and installing the desk on a fake
ship:

```dojo
-test /=mcp=/tests/mcp-libraries ~
```

The suite covers Discovery bodies/ref expansion, bounded recursive schemas,
POST/PATCH verbs, repeated query keys, and read-only annotations, as well as
existing API/OAuth helpers.

Local validation on 2026-10-13: all 17 native tests passed on an isolated Urbit
4.3 fake ship, and the `%mcp-server`, `%mcp-proxy`, and `%oauth` agents compiled
and installed. All seven generated input schemas passed JSON Schema 2020-12
meta-validation. The five smoke tests below passed; the transport test is an
expected failure. The desk was assembled using the exact dependency pins in
`build.zig`; the Zig 0.15.2 build runner encountered macOS system-library linker
errors on this machine, so the standard Zig build was not validated here.

For end-to-end smoke tests, use an isolated fake ship, never a production moon.
Start the mock API in one terminal:

```sh
python3 connectors/google-calendar/smoke_test.py serve
```

On the fake ship with the updated desk installed, configure the dummy grant
and mock upstream:

```dojo
:mcp-proxy &mcp-proxy-action [%set-client-key 'calendar-local-test']
:oauth &oauth-action [%receive-grant %google-calendar ['calendar-mock-access-token' ~ 'Bearer' ~ 'calendar.events' %google-calendar]]
:mcp-proxy &mcp-proxy-action [%config-oauth-server %google-calendar ['Google Calendar' 'http://127.0.0.1:18891/calendar/v3/' ~ %.y `%google-calendar %openapi `'http://127.0.0.1:18891/discovery.json']]
```

After the schema fetch completes, run:

```sh
python3 connectors/google-calendar/smoke_test.py test \
  --endpoint http://127.0.0.1:18781/apps/mcp/mcp
```

Five tests cover the exact tool catalog, full schema descriptions, bearer
injection, reads, event creation/patching, availability, and rejection of an
omitted delete operation. One expected failure records an existing Urbit
transport limitation: its `cttp` URL parser decodes an escaped slash inside a
path segment. The native request-builder test still verifies correct escaping.
The smoke tests exercise `primary` and email-address calendar IDs, the forms
described by [Google's calendar model](https://developers.google.com/workspace/calendar/api/concepts/events-calendars).

### Live pilot checks

- Connect a test user and verify that the grant has all three requested scopes
  and a refresh token. Partial consent should surface the relevant Google
  permission error; reconnect to grant missing scopes.
- List calendars; read the correct timezone; query events and follow pagination.
- Create an event on a dedicated test calendar, then patch it and confirm it
  in Calendar. Check all-day and recurring events, timezone/DST behavior, and
  notification choices with consented test attendees.
- Check availability across two authorized calendars.
- Force access-token expiry and exercise refresh through the relay. Restart
  the moon and confirm schema/grant restoration.
- Revoke access in the Google account and confirm an actionable reconnect
  path; test quota, permission, and missing/deleted-event errors.
- Confirm scheduled reads can run and scheduled event writes are blocked by
  the bot's existing policy.

The existing hosting disconnect path removes the local grant; it does not
itself revoke the Google authorization. Until that path supports provider
revocation, users can revoke through their Google account's third-party access
settings. Public-release disconnect/deletion copy must describe the actual
behavior. This shared lifecycle gap is separate from Calendar API conversion.

## Schema maintenance

Regenerate deliberately when Google changes the Discovery document:

```sh
curl -fsSL https://www.googleapis.com/discovery/v1/apis/calendar/v3/rest \
  -o /tmp/google-calendar-discovery.json
python3 connectors/google-calendar/generate.py /tmp/google-calendar-discovery.json
```

Review the resulting diff and rerun native/smoke tests before publishing a new
schema URL. The generator checks each chosen method against the configured
scopes and includes only the referenced input schemas. Adding operations or
scopes requires a deliberate generator/configuration change and possibly a
new Google verification submission.
