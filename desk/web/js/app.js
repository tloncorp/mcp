var App = {
  servers: [],
  oauthProviders: [],
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
      OAuthAPI.getRelayProviders().catch(function() { return { providers: [] }; })
    ]).then(function(results) {
      self.ship = results[0].ship || '';
      self.servers = results[0].servers || [];
      self.oauthProviders = results[1].providers || [];
      self.clientKey = results[2].clientKey || null;
      self.codeMode = !!results[2].codeMode;
      self.relayProviders = results[3].providers || [];
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
          '# generate an API key first, then:\n' +
          'claude mcp add --transport http ' + name + ' \\\n  ' + url +
          ' \\\n  --header "X-Api-Key: <your-key>"';
      }
    }
    if (footShip) footShip.textContent = this.ship || '—';

    var codeModeToggle = document.getElementById('code-mode-toggle');
    if (codeModeToggle) codeModeToggle.checked = !!this.codeMode;
  },

  // ── connectors ──────────────────────────────────────────────────────

  renderConnectors: function() {
    this.renderConnectorButtons();
    this.renderConnectedList();
  },

  renderConnectorButtons: function() {
    var container = document.getElementById('connector-buttons');
    if (!container) return;

    // find relay providers that aren't yet added as oauth providers
    var existingIds = {};
    for (var i = 0; i < this.oauthProviders.length; i++) {
      existingIds[this.oauthProviders[i].id] = true;
    }

    var html = '';
    for (var j = 0; j < this.relayProviders.length; j++) {
      var rp = this.relayProviders[j];
      var alreadyAdded = existingIds[rp.id];
      var prov = alreadyAdded ? this.oauthProviders.find(function(p) { return p.id === rp.id; }) : null;
      var isConnected = prov && prov.hasGrant;

      if (isConnected) continue; // already connected — shown in list below

      html += '<button type="button" class="connector-btn' +
        (alreadyAdded ? ' pending' : '') +
        '" onclick="App.quickConnect(\'' + this.esc(rp.id) + '\')">' +
        '<span class="connector-btn-name">' + this.esc(rp.displayName || rp.id) + '</span>' +
        '<span class="connector-btn-action">' + (alreadyAdded ? 'Authorize' : 'Connect') + '</span>' +
      '</button>';
    }

    if (!html && this.relayProviders.length === 0) {
      html = '<div class="empty-hint">No connectors available from relay</div>';
    }

    container.innerHTML = html;
  },

  renderConnectedList: function() {
    var container = document.getElementById('connected-list');
    if (!container) return;

    // build a set of server ids that are linked to an oauth provider
    // so we can group them under that provider's card
    var oauthLinked = {};
    for (var i = 0; i < this.servers.length; i++) {
      var sv = this.servers[i];
      if (sv.oauthProvider) oauthLinked[sv.id] = sv.oauthProvider;
    }

    // grant lookup
    var grantMap = {};
    for (var g = 0; g < this.oauthProviders.length; g++) {
      var op = this.oauthProviders[g];
      if (op.hasGrant) grantMap[op.id] = op;
    }

    var html = '';

    // 1. servers without an oauth provider (standalone upstreams like the built-in MCP server)
    for (var j = 0; j < this.servers.length; j++) {
      var s = this.servers[j];
      if (s.oauthProvider) continue; // shown under its provider below
      var modeBadge = s.mode === 'openapi' ? 'openapi' : 'proxy';
      html += '<div class="server-card' + (s.enabled ? '' : ' disabled') + '">' +
        '<div class="card-row">' +
          '<div class="card-identity">' +
            '<div class="card-name">' + this.esc(s.name) + '</div>' +
            '<div class="card-id">' + this.esc(s.id) + '</div>' +
          '</div>' +
          '<div class="card-badges">' +
            '<span class="badge mode-' + modeBadge + '">' + modeBadge + '</span>' +
            '<span class="badge ' + (s.enabled ? 'enabled' : 'disabled') + '">' + (s.enabled ? 'enabled' : 'disabled') + '</span>' +
          '</div>' +
        '</div>' +
        (s.url ? '<div class="card-meta"><div class="meta-row"><div class="meta-key">URL</div><div class="meta-val accent">' + this.esc(s.url) + '</div></div></div>' : '') +
      '</div>';
    }

    // 2. oauth-linked servers grouped by provider
    var shownProviders = {};
    for (var k = 0; k < this.servers.length; k++) {
      var srv = this.servers[k];
      if (!srv.oauthProvider) continue;
      if (shownProviders[srv.oauthProvider]) continue;
      shownProviders[srv.oauthProvider] = true;

      var prov = grantMap[srv.oauthProvider];
      var isConnected = !!prov;
      var relay = this.relayProviders.find(function(r) { return r.id === srv.oauthProvider; });
      var displayName = (relay && relay.displayName) || srv.oauthProvider;

      // collect all servers for this provider
      var linked = this.servers.filter(function(x) { return x.oauthProvider === srv.oauthProvider; });
      var serverTags = '';
      for (var m = 0; m < linked.length; m++) {
        var ls = linked[m];
        serverTags += '<span class="tag">' + this.esc(ls.name || ls.id) +
          ' <span class="badge mode-' + (ls.mode === 'openapi' ? 'openapi' : 'proxy') + '">' +
          ls.mode + '</span></span>';
      }

      html += '<div class="server-card">' +
        '<div class="card-row">' +
          '<div class="card-identity">' +
            '<div class="card-name">' + this.esc(displayName) + '</div>' +
            '<div class="card-id">' + this.esc(srv.oauthProvider) + '</div>' +
          '</div>' +
          '<div class="card-badges">' +
            '<span class="badge ' + (isConnected ? 'connected' : 'disconnected') + '">' +
              (isConnected ? 'connected' : 'disconnected') + '</span>' +
          '</div>' +
        '</div>' +
        '<div class="card-meta">' +
          '<div class="meta-row"><div class="meta-key">UPSTREAMS</div><div class="meta-val">' + serverTags + '</div></div>' +
        '</div>' +
        '<div class="card-actions">' +
          (isConnected
            ? '<button type="button" class="row-btn danger" onclick="App.disconnectProvider(\'' + this.esc(srv.oauthProvider) + '\')">Disconnect</button>'
            : '<button type="button" class="row-btn accent" onclick="App.quickConnect(\'' + this.esc(srv.oauthProvider) + '\')">Connect</button>') +
        '</div>' +
      '</div>';
    }

    if (!html) {
      html = '<div class="empty">No upstreams configured</div>';
    }

    container.innerHTML = html;
  },

  // one-click: add provider + upstream + redirect to oauth
  quickConnect: function(relayId) {
    var self = this;
    var relay = this.relayProviders.find(function(r) { return r.id === relayId; });
    if (!relay) { alert('Provider not found'); return; }

    // check if provider already exists on ship
    var existing = this.oauthProviders.find(function(p) { return p.id === relayId; });

    var doConnect = function() {
      var returnTo = window.location.origin + '/apps/mcp/';
      OAuthAPI.remoteConnect(relayId, returnTo).then(function(data) {
        if (data && data.url) {
          window.location.href = data.url;
        } else {
          alert('No authorize URL returned');
        }
      }).catch(function(e) { alert('Connect failed: ' + e.message); });
    };

    if (existing) {
      // provider already on ship, just trigger connect
      doConnect();
      return;
    }

    // add provider first
    var providerData = {
      action: 'add-provider',
      id: relayId,
      'auth-url': '',
      'token-url': '',
      'revoke-url': null,
      'client-id': '',
      'client-secret': 'managed',
      'redirect-uri': '',
      scopes: ''
    };

    OAuthAPI.addProvider(providerData).then(function() {
      // auto-create upstream if relay has a suggestion
      if (relay.suggestedUpstream) {
        var hint = relay.suggestedUpstream;
        return McpProxyAPI.addServer(
          relayId,
          hint.name || relay.displayName || relayId,
          hint.url || '',
          [],
          {
            mode: hint.mode || 'proxy',
            oauthProvider: relayId,
            schemaUrl: hint.schemaUrl || null
          }
        ).catch(function(e) {
          console.warn('upstream auto-create failed', e);
        });
      }
    }).then(function() {
      doConnect();
    }).catch(function(e) {
      alert('Setup failed: ' + e.message);
    });
  },

  disconnectProvider: function(id) {
    var self = this;
    OAuthAPI.disconnect(id).then(function() {
      self.loadAll();
      self.toast('Disconnected');
    }).catch(function(e) { alert('Failed: ' + e.message); });
  },

  // ── events ──────────────────────────────────────────────────────────

  bindEvents: function() {
    var self = this;

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

    // generate key
    var regenBtn = document.getElementById('btn-regen-key');
    if (regenBtn) regenBtn.addEventListener('click', function() {
      McpProxyAPI.regenerateClientKey().then(function() {
        self.loadAll();
        self.toast('API key generated');
      }).catch(function(e) { alert('Failed: ' + e.message); });
    });

    // code mode toggle
    var codeModeToggle = document.getElementById('code-mode-toggle');
    if (codeModeToggle) {
      codeModeToggle.addEventListener('change', function() {
        var on = codeModeToggle.checked;
        McpProxyAPI.setCodeMode(on).then(function() {
          self.codeMode = on;
          self.toast(on ? 'Code mode enabled' : 'Code mode disabled');
        }).catch(function(e) {
          codeModeToggle.checked = !on;
          alert('Failed: ' + e.message);
        });
      });
    }
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
