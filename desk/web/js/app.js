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

    // show connected providers and their linked upstreams
    var connected = [];
    for (var i = 0; i < this.oauthProviders.length; i++) {
      var p = this.oauthProviders[i];
      if (p.hasGrant) connected.push(p);
    }

    if (connected.length === 0) {
      container.innerHTML = '<div class="empty">No connectors active<em>connect a service above to get started</em></div>';
      return;
    }

    var html = '';
    for (var k = 0; k < connected.length; k++) {
      var prov = connected[k];
      // find servers linked to this provider
      var linkedServers = [];
      for (var s = 0; s < this.servers.length; s++) {
        if (this.servers[s].oauthProvider === prov.id) {
          linkedServers.push(this.servers[s]);
        }
      }

      var serverInfo = '';
      if (linkedServers.length > 0) {
        for (var m = 0; m < linkedServers.length; m++) {
          var srv = linkedServers[m];
          serverInfo += '<span class="tag">' + this.esc(srv.name || srv.id) +
            ' <span class="badge mode-' + (srv.mode === 'openapi' ? 'openapi' : 'proxy') + '">' +
            srv.mode + '</span></span>';
        }
      }

      // find the relay provider for display name
      var relay = this.relayProviders.find(function(r) { return r.id === prov.id; });
      var displayName = (relay && relay.displayName) || prov.id;

      html += '<div class="server-card">' +
        '<div class="card-row">' +
          '<div class="card-identity">' +
            '<div class="card-name">' + this.esc(displayName) + '</div>' +
            '<div class="card-id">' + this.esc(prov.id) + '</div>' +
          '</div>' +
          '<div class="card-badges">' +
            '<span class="badge connected">connected</span>' +
            (prov.scopes ? '<span class="badge mode-proxy">' + this.esc(prov.scopes) + '</span>' : '') +
          '</div>' +
        '</div>' +
        (serverInfo ? '<div class="card-meta"><div class="meta-row"><div class="meta-key">UPSTREAMS</div><div class="meta-val">' + serverInfo + '</div></div></div>' : '') +
        '<div class="card-actions">' +
          '<button type="button" class="row-btn danger" onclick="App.disconnectProvider(\'' + this.esc(prov.id) + '\')">Disconnect</button>' +
        '</div>' +
      '</div>';
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
