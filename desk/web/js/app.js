var App = {
  servers: [],
  oauthProviders: [],
  oauthGrants: [],
  relayProviders: [],
  ship: '',
  clientKey: null,
  codeMode: false,

  init: function() {
    this.bindEvents();
    this.loadAll();
  },

  loadAll: function() {
    var self = this;
    Promise.all([
      McpProxyAPI.getServers(),
      OAuthAPI.getProviders().catch(function() { return { providers: [] }; }),
      McpProxyAPI.getClientKey().catch(function() { return {}; }),
      OAuthAPI.getRelayProviders().catch(function() { return { providers: [] }; }),
      OAuthAPI.getGrants().catch(function() { return { grants: [] }; })
    ]).then(function(results) {
      self.ship = results[0].ship || '';
      self.servers = results[0].servers || [];
      self.oauthProviders = results[1].providers || [];
      self.clientKey = results[2].clientKey || null;
      self.codeMode = !!results[2].codeMode;
      self.relayProviders = results[3].providers || [];
      self.oauthGrants = results[4].grants || [];
      self.updateEndpoint();
      self.renderConnectors();
    }).catch(function(e) {
      console.error('loadAll failed', e);
    });
  },

  updateEndpoint: function() {
    var url = window.location.origin + '/apps/mcp/mcp';
    var urlEl = document.getElementById('agg-url');
    var keyEl = document.getElementById('agg-key');
    var exampleEl = document.getElementById('endpoint-example');
    var footShip = document.getElementById('foot-ship');
    var hasKey = !!this.clientKey;
    var key = this.clientKey || '';

    if (urlEl) urlEl.textContent = url;
    if (keyEl) {
      keyEl.textContent = hasKey ? key : '— not set —';
      keyEl.classList.toggle('is-unset', !hasKey);
    }
    if (exampleEl) {
      var name = (this.ship || 'mcp').replace(/^~/, '') || 'mcp';
      if (hasKey) {
        exampleEl.textContent =
          'claude mcp add --transport http ' + name + ' \\\n  ' + url +
          ' \\\n  --header "X-Api-Key: ' + key + '"';
      } else {
        exampleEl.textContent =
          '# API key is not configured yet\n' +
          'claude mcp add --transport http ' + name + ' \\\n  ' + url +
          ' \\\n  --header "X-Api-Key: <your-key>"';
      }
    }
    if (footShip) footShip.textContent = this.ship || '—';

    var codeModeStatus = document.getElementById('code-mode-status');
    var codeModeBadge = document.getElementById('code-mode-badge');
    if (codeModeStatus) {
      codeModeStatus.textContent = this.codeMode
        ? 'enabled: upstream tools are exposed through compact discovery meta-tools.'
        : 'disabled: upstream tools are exposed directly to the MCP client.';
    }
    if (codeModeBadge) {
      codeModeBadge.textContent = this.codeMode ? 'enabled' : 'disabled';
      codeModeBadge.className = 'badge ' + (this.codeMode ? 'enabled' : 'disabled');
    }
  },

  // ── connectors ──────────────────────────────────────────────────────

  renderConnectors: function() {
    this.renderHostedSummary();
    this.renderConnectedList();
  },

  renderHostedSummary: function() {
    var container = document.getElementById('hosted-summary');
    if (!container) return;

    var grantMap = this.grantMap();
    var configured = this.oauthProviders.length;
    var granted = Object.keys(grantMap).length;
    var upstreams = this.servers.length;
    var refreshable = 0;
    Object.keys(grantMap).forEach(function(id) {
      if (grantMap[id].hasRefreshToken) refreshable += 1;
    });

    container.innerHTML =
      '<div class="summary-cell">' +
        '<div class="summary-label">Providers</div>' +
        '<div class="summary-value">' + configured + '</div>' +
      '</div>' +
      '<div class="summary-cell">' +
        '<div class="summary-label">Grants</div>' +
        '<div class="summary-value">' + granted + '</div>' +
      '</div>' +
      '<div class="summary-cell">' +
        '<div class="summary-label">Refreshable</div>' +
        '<div class="summary-value">' + refreshable + '</div>' +
      '</div>' +
      '<div class="summary-cell">' +
        '<div class="summary-label">Upstreams</div>' +
        '<div class="summary-value">' + upstreams + '</div>' +
      '</div>';
  },

  renderConnectedList: function() {
    var container = document.getElementById('connected-list');
    if (!container) return;

    var grantMap = this.grantMap();
    var providerMap = this.providerMap();
    var relayMap = this.relayMap();
    var shownProviders = {};

    var html = '';

    for (var i = 0; i < this.oauthProviders.length; i++) {
      var provider = this.oauthProviders[i];
      shownProviders[provider.id] = true;
      html += this.renderProviderCard(provider, grantMap[provider.id], relayMap[provider.id]);
    }

    for (var j = 0; j < this.oauthGrants.length; j++) {
      var grant = this.oauthGrants[j];
      var grantId = grant.providerId || grant.provider;
      if (!grantId || shownProviders[grantId]) continue;
      html += this.renderProviderCard({ id: grantId, name: grantId, hasGrant: true }, grant, relayMap[grantId]);
      shownProviders[grantId] = true;
    }

    for (var k = 0; k < this.servers.length; k++) {
      var s = this.servers[k];
      if (s.oauthProvider && shownProviders[s.oauthProvider]) continue;
      html += this.renderStandaloneServerCard(s, providerMap[s.oauthProvider]);
    }

    if (!html) {
      html = '<div class="empty">No hosted configuration has been deposited yet</div>';
    }

    container.innerHTML = html;
  },

  renderProviderCard: function(provider, grant, relay) {
    var id = provider.id || (grant && (grant.providerId || grant.provider)) || '';
    var displayName = (relay && relay.displayName) || provider.name || id;
    var linked = this.servers.filter(function(server) { return server.oauthProvider === id; });
    var hasGrant = !!grant || !!provider.hasGrant;
    var expiry = grant ? this.expiryInfo(grant.expiresAt) : { label: 'not connected', state: 'missing' };
    var grantBadge = hasGrant ? (expiry.state === 'expired' ? 'expired' : 'connected') : 'disconnected';
    var refreshBadge = grant && grant.hasRefreshToken ? 'refreshable' : 'no refresh';
    var serverRows = linked.length ? linked.map(this.renderUpstreamRow.bind(this)).join('') : '<div class="sub-row muted">No linked upstreams</div>';
    var scopes = (grant && grant.scopes) || provider.scopes || '';

    return '<div class="server-card hosted-card">' +
      '<div class="card-row">' +
        '<div class="card-identity">' +
          '<div class="card-name">' + this.esc(displayName) + '</div>' +
          '<div class="card-id">' + this.esc(id) + '</div>' +
        '</div>' +
        '<div class="card-badges">' +
          '<span class="badge ' + grantBadge + '">' + grantBadge + '</span>' +
          '<span class="badge ' + (grant && grant.hasRefreshToken ? 'enabled' : 'disabled') + '">' + this.esc(refreshBadge) + '</span>' +
        '</div>' +
      '</div>' +
      '<div class="card-meta hosted-meta">' +
        this.metaRow('Grant expiry', expiry.label, expiry.state === 'expired' ? 'danger' : 'accent') +
        this.metaRow('Token type', grant && grant.tokenType ? grant.tokenType : '—') +
        this.metaRow('Scopes', scopes || '—') +
        this.metaRow('Client id', provider.clientId || '—') +
        this.metaRow('Token URL', provider.tokenUrl || '—') +
        this.metaRow('Auth URL', provider.authUrl || '—') +
        this.metaRow('Redirect', provider.redirectUri || '—') +
        this.metaRow('Resource', provider.tokenResource || '—') +
        this.metaRow('Token auth', provider.tokenAuth || '—') +
        this.metaRow('Client secret', provider.hasSecret === undefined ? '—' : (provider.hasSecret ? 'stored' : 'not stored')) +
        '<div class="meta-row meta-row-block"><div class="meta-key">Upstreams</div><div class="meta-val upstream-list">' + serverRows + '</div></div>' +
      '</div>' +
    '</div>';
  },

  renderStandaloneServerCard: function(server, provider) {
    var modeBadge = server.mode === 'openapi' ? 'openapi' : 'proxy';
    return '<div class="server-card hosted-card' + (server.enabled ? '' : ' disabled') + '">' +
        '<div class="card-row">' +
          '<div class="card-identity">' +
          '<div class="card-name">' + this.esc(server.name || server.id) + '</div>' +
          '<div class="card-id">' + this.esc(server.id) + '</div>' +
          '</div>' +
          '<div class="card-badges">' +
            '<span class="badge mode-' + modeBadge + '">' + modeBadge + '</span>' +
          '<span class="badge ' + (server.enabled ? 'enabled' : 'disabled') + '">' + (server.enabled ? 'enabled' : 'disabled') + '</span>' +
          '</div>' +
        '</div>' +
      '<div class="card-meta hosted-meta">' +
        this.metaRow('URL', server.url || '—', server.url ? 'accent' : '') +
        this.metaRow('OAuth provider', server.oauthProvider || '—') +
        this.metaRow('Provider config', provider ? 'present' : (server.oauthProvider ? 'missing' : 'not required')) +
        this.metaRow('Schema URL', server.schemaUrl || '—') +
        this.metaRow('Cached spec', server.hasCachedSpec ? 'yes' : 'no') +
        this.metaRow('Headers', server.headers && server.headers.length ? String(server.headers.length) : 'none') +
      '</div>' +
    '</div>';
  },

  renderUpstreamRow: function(server) {
    var mode = server.mode === 'openapi' ? 'openapi' : 'proxy';
    return '<div class="sub-row">' +
      '<div class="sub-row-main">' + this.esc(server.name || server.id) + '</div>' +
      '<div class="sub-row-meta">' +
        '<span>' + this.esc(server.id) + '</span>' +
        '<span class="badge mode-' + mode + '">' + mode + '</span>' +
        '<span class="badge ' + (server.enabled ? 'enabled' : 'disabled') + '">' + (server.enabled ? 'enabled' : 'disabled') + '</span>' +
      '</div>' +
      (server.url ? '<div class="sub-row-url">' + this.esc(server.url) + '</div>' : '') +
    '</div>';
  },

  metaRow: function(key, value, tone) {
    var cls = 'meta-val' + (tone ? ' ' + tone : '');
    return '<div class="meta-row"><div class="meta-key">' + this.esc(key) + '</div><div class="' + cls + '">' + this.esc(value) + '</div></div>';
  },

  // ── events ──────────────────────────────────────────────────────────

  bindEvents: function() {
    // copy buttons (delegated)
    document.body.addEventListener('click', function(e) {
      var btn = e.target.closest('.copy-btn');
      if (!btn) return;
      var targetId = btn.getAttribute('data-copy');
      if (!targetId) return;
      var el = document.getElementById(targetId);
      if (!el) return;
      if (navigator.clipboard) {
        navigator.clipboard.writeText(el.textContent).then(function() {
          btn.classList.add('copied');
          var label = btn.querySelector('.copy-btn-label');
          var prev = label ? label.textContent : null;
          if (label) label.textContent = 'OK';
          setTimeout(function() {
            btn.classList.remove('copied');
            if (label && prev !== null) label.textContent = prev;
          }, 1200);
        });
      }
    });

    // hosted view is intentionally read-only; mutating actions are handled by Horizon.
  },

  // ── helpers ─────────────────────────────────────────────────────────

  toast: function(msg) {
    var el = document.getElementById('toast');
    if (!el) {
      el = document.createElement('div');
      el.id = 'toast';
      el.className = 'toast';
      document.body.appendChild(el);
    }
    el.textContent = msg;
    el.classList.add('show');
    clearTimeout(this._toastTimer);
    this._toastTimer = setTimeout(function() { el.classList.remove('show'); }, 2200);
  },

  providerMap: function() {
    var map = {};
    for (var i = 0; i < this.oauthProviders.length; i++) {
      var provider = this.oauthProviders[i];
      if (provider.id) map[provider.id] = provider;
    }
    return map;
  },

  grantMap: function() {
    var map = {};
    for (var i = 0; i < this.oauthGrants.length; i++) {
      var grant = this.oauthGrants[i];
      var id = grant.providerId || grant.provider;
      if (id) map[id] = grant;
    }
    return map;
  },

  relayMap: function() {
    var map = {};
    for (var i = 0; i < this.relayProviders.length; i++) {
      var provider = this.relayProviders[i];
      if (provider.id) map[provider.id] = provider;
    }
    return map;
  },

  expiryInfo: function(raw) {
    if (!raw) return { label: 'no expiry', state: 'none' };
    var parsed = this.parseUrbitDate(raw);
    if (!parsed) return { label: raw, state: 'unknown' };
    var diff = parsed.getTime() - Date.now();
    var state = diff < 0 ? 'expired' : 'valid';
    return {
      label: raw + ' (' + this.relativeTime(diff) + ')',
      state: state
    };
  },

  parseUrbitDate: function(raw) {
    var match = String(raw).match(/^~(\d{4})\.(\d{1,2})\.(\d{1,2})\.\.(\d{1,2})\.(\d{1,2})\.(\d{1,2})(?:\..*)?$/);
    if (!match) return null;
    return new Date(Date.UTC(
      Number(match[1]),
      Number(match[2]) - 1,
      Number(match[3]),
      Number(match[4]),
      Number(match[5]),
      Number(match[6])
    ));
  },

  relativeTime: function(ms) {
    var abs = Math.abs(ms);
    var suffix = ms < 0 ? 'ago' : 'remaining';
    var minute = 60 * 1000;
    var hour = 60 * minute;
    var day = 24 * hour;
    if (abs < minute) return Math.round(abs / 1000) + 's ' + suffix;
    if (abs < hour) return Math.round(abs / minute) + 'm ' + suffix;
    if (abs < day) return Math.round(abs / hour) + 'h ' + suffix;
    return Math.round(abs / day) + 'd ' + suffix;
  },

  esc: function(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }
};

document.addEventListener('DOMContentLoaded', function() { App.init(); });
