(function () {
  var apiBase = (window.MINERVA_SUPABASE_URL || window.location.origin || '').replace(/\/$/, '');
  var apiKey = window.MINERVA_SUPABASE_ANON_KEY || '';

  var refs = {
    menuUpload: document.querySelector('.upload-toggle'),
    uploadPanel: document.querySelector('.upload-panel'),
    uploadForm: document.querySelector('.upload-form'),
    uploadStatus: document.querySelector('.upload-status'),
    newDirForm: document.querySelector('.newdir-form'),
    newDirInput: document.querySelector('.newdir-input'),
    searchForm: document.getElementById('search-form'),
    searchInput: document.getElementById('search-input'),
    dirBody: document.getElementById('dir-body'),
    pathTitle: document.getElementById('path-title'),
    uploadTarget: document.getElementById('upload-target'),
    uploadSection: document.getElementById('upload-section')
  };

  var state = {
    section: '/files/',
    tree: {},
    seedLinks: [],
    cloudLinks: [],
    localLinks: [],
    cloudDirs: [],
    localDirs: [],
    searchTerm: ''
  };

  function headers(extra) {
    var h = {};
    if (apiKey) {
      h.apikey = apiKey;
      h.Authorization = 'Bearer ' + apiKey;
    }
    if (extra) {
      Object.keys(extra).forEach(function (k) { h[k] = extra[k]; });
    }
    return h;
  }

  function normalizeSection(path) {
    var p = (path || '/files/').trim();
    if (!p.startsWith('/files/')) p = '/files/';
    if (!p.endsWith('/')) p += '/';
    return p;
  }

  function getSectionFromLocation() {
    var qs = new URLSearchParams(window.location.search);
    return normalizeSection(qs.get('path') || '/files/');
  }

  function setSection(section) {
    state.section = normalizeSection(section);
    refs.pathTitle.innerHTML = 'Index of <br>' + state.section;
    refs.uploadTarget.textContent = 'Upload to this section: ' + state.section;
    refs.uploadSection.value = state.section;
  }

  function parentSection(section) {
    if (section === '/files/') return null;
    var t = section.slice(0, -1);
    var i = t.lastIndexOf('/');
    var p = t.slice(0, i + 1);
    return p.startsWith('/files/') ? p : '/files/';
  }

  function localKey(prefix) {
    return prefix + '::' + state.section;
  }

  function readLocal(prefix) {
    try {
      var raw = localStorage.getItem(localKey(prefix));
      var parsed = raw ? JSON.parse(raw) : [];
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      return [];
    }
  }

  function writeLocal(prefix, items) {
    try {
      localStorage.setItem(localKey(prefix), JSON.stringify(items));
      return true;
    } catch (e) {
      return false;
    }
  }

  function status(msg) {
    if (refs.uploadStatus) refs.uploadStatus.textContent = msg || '';
  }

  function escapeHtml(s) {
    return (s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/\"/g, '&quot;');
  }

  function nameFromUrl(url) {
    try {
      var clean = (url || '').split('#')[0].split('?')[0];
      var part = clean.substring(clean.lastIndexOf('/') + 1) || 'Untitled';
      return decodeURIComponent(part);
    } catch (e) {
      return 'Untitled';
    }
  }

  async function loadTree() {
    try {
      var r = await fetch('data/tree.json', { cache: 'no-store' });
      if (!r.ok) return;
      var j = await r.json();
      if (j && typeof j === 'object') state.tree = j;
    } catch (e) {}
  }

  async function loadSeedLinks() {
    try {
      var r = await fetch('data/seed-links.json', { cache: 'no-store' });
      if (!r.ok) return;
      var j = await r.json();
      if (Array.isArray(j)) {
        state.seedLinks = j.filter(function (x) { return x && x.section === state.section; });
      }
    } catch (e) {}
  }

  async function loadCloudLinks() {
    try {
      var url = apiBase + '/rest/v1/links?select=name,direct_url,notes,size,date,created_at&section=eq.' + encodeURIComponent(state.section) + '&order=created_at.asc';
      var r = await fetch(url, { headers: headers() });
      if (!r.ok) throw new Error('links:' + r.status);
      var j = await r.json();
      state.cloudLinks = Array.isArray(j) ? j : [];
      writeLocal('minerva_upload_items', state.cloudLinks);
    } catch (e) {
      state.cloudLinks = [];
    }
    state.localLinks = readLocal('minerva_upload_items');
  }

  async function loadCloudDirs() {
    try {
      var url = apiBase + '/rest/v1/directories?parent_section=eq.' + encodeURIComponent(state.section);
      var r = await fetch(url, { headers: headers() });
      if (!r.ok) throw new Error('dirs:' + r.status);
      var j = await r.json();
      state.cloudDirs = Array.isArray(j) ? j : [];
      writeLocal('minerva_custom_dirs', state.cloudDirs);
    } catch (e) {
      state.cloudDirs = [];
    }
    state.localDirs = readLocal('minerva_custom_dirs');
  }

  function staticChildren() {
    return (state.tree[state.section] || []).slice();
  }

  function mergedDirs() {
    var names = new Set(staticChildren());
    state.cloudDirs.forEach(function (d) { if (d && d.name) names.add(d.name); });
    state.localDirs.forEach(function (d) {
      if (typeof d === 'string') names.add(d);
      else if (d && d.name) names.add(d.name);
    });
    return Array.from(names).sort();
  }

  function mergedLinks() {
    var out = [];
    var add = function (arr, tag) {
      (arr || []).forEach(function (x) {
        if (!x) return;
        out.push({
          name: x.name || 'Untitled',
          direct_url: x.direct_url || '',
          notes: x.notes || '',
          size: x.size || '-',
          date: x.date || tag
        });
      });
    };
    add(state.seedLinks, 'Seed');
    add(state.cloudLinks, 'Cloud');
    add(state.localLinks, 'Local');
    return out;
  }

  function row(link, label, size, date, isExternal) {
    var aAttrs = isExternal ? ' target="_blank" rel="noopener noreferrer"' : '';
    return '<tr><td class="link"><a href="' + escapeHtml(link) + '"' + aAttrs + '>' + escapeHtml(label) + '</a></td><td class="size">' + escapeHtml(size || '-') + '</td><td class="date">' + escapeHtml(date || '-') + '</td></tr>';
  }

  function render() {
    var html = '';
    var q = state.searchTerm.trim().toLowerCase();
    var matches = function (text) {
      return !q || (text || '').toLowerCase().indexOf(q) !== -1;
    };
    var p = parentSection(state.section);
    if (p) html += row('index.html?path=' + encodeURIComponent(p), 'Parent directory/', '-', '-');
    else html += row('index.html', 'Parent directory/', '-', '-');

    mergedDirs().forEach(function (name) {
      var child = normalizeSection(state.section + name + '/');
      if (matches(name)) {
        html += row('index.html?path=' + encodeURIComponent(child), name + '/', '-', 'Directory');
      }
    });

    mergedLinks().forEach(function (item) {
      var text = (item.name || '') + ' ' + (item.notes || '') + ' ' + (item.direct_url || '');
      if (matches(text)) {
        html += row(item.direct_url || '#', item.name + ' [Upload]', item.size || '-', item.date || 'Custom', !!item.direct_url);
      }
    });

    refs.dirBody.innerHTML = html;
  }

  async function postLinks(items) {
    if (!items.length) return { ok: false };
    try {
      var r = await fetch(apiBase + '/rest/v1/links', {
        method: 'POST',
        headers: headers({ 'Content-Type': 'application/json' }),
        body: JSON.stringify(items.map(function (i) {
          return {
            section: state.section,
            name: i.name,
            direct_url: i.direct_url,
            notes: i.notes,
            size: i.size,
            date: i.date
          };
        }))
      });
      return { ok: r.ok, status: r.status };
    } catch (e) {
      return { ok: false };
    }
  }

  async function postDirectory(name) {
    try {
      var r = await fetch(apiBase + '/rest/v1/directories', {
        method: 'POST',
        headers: headers({ 'Content-Type': 'application/json' }),
        body: JSON.stringify([{ parent_section: state.section, name: name }])
      });
      return { ok: r.ok, status: r.status };
    } catch (e) {
      return { ok: false };
    }
  }

  function bindEvents() {
    if (refs.menuUpload && refs.uploadPanel) {
      refs.menuUpload.addEventListener('click', function (e) {
        e.preventDefault();
        refs.uploadPanel.style.display = (refs.uploadPanel.style.display === 'none' || !refs.uploadPanel.style.display) ? 'block' : 'none';
      });
    }

    refs.newDirForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      var name = (refs.newDirInput.value || '').trim().replace(/[\\/]+/g, '').replace(/[<>:"|?*]/g, '');
      if (!name) return;

      var locals = readLocal('minerva_custom_dirs');
      if (!locals.some(function (d) { return (typeof d === 'string' ? d : d.name) === name; })) {
        locals.push({ name: name });
        writeLocal('minerva_custom_dirs', locals);
      }

      await postDirectory(name);
      refs.newDirInput.value = '';
      await loadCloudDirs();
      render();
    });

    if (refs.searchForm && refs.searchInput) {
      refs.searchForm.addEventListener('submit', function (e) {
        e.preventDefault();
        state.searchTerm = refs.searchInput.value || '';
        render();
      });
    }

    refs.uploadForm.addEventListener('submit', async function (e) {
      e.preventDefault();
      status('Processing upload...');

      var name = (refs.uploadForm.querySelector('input[name="name"]').value || '').trim();
      var directUrl = (refs.uploadForm.querySelector('input[name="direct_url"]').value || '').trim();
      var bulkText = refs.uploadForm.querySelector('textarea[name="bulk_urls"]').value || '';
      var notes = (refs.uploadForm.querySelector('input[name="notes"]').value || '').trim();
      var filesInput = refs.uploadForm.querySelector('input[name="files"]');
      var size = (filesInput && filesInput.files && filesInput.files.length > 0) ? (filesInput.files.length + ' file(s)') : '-';

      var bulkUrls = bulkText.split(/\r?\n/).map(function (x) { return x.trim(); }).filter(Boolean);
      var items = [];

      bulkUrls.forEach(function (u) {
        items.push({ name: nameFromUrl(u), direct_url: u, notes: notes, size: '-', date: 'Custom' });
      });

      if (name || directUrl || (filesInput && filesInput.files && filesInput.files.length > 0)) {
        items.push({ name: name || (directUrl ? nameFromUrl(directUrl) : 'Untitled'), direct_url: directUrl, notes: notes, size: size, date: 'Custom' });
      }

      if (!items.length) {
        status('Nothing to add. Fill name/url or paste bulk links.');
        return;
      }

      var locals = readLocal('minerva_upload_items').concat(items);
      if (!writeLocal('minerva_upload_items', locals)) {
        status('Local save blocked by browser settings.');
        return;
      }

      refs.uploadForm.reset();
      await loadCloudLinks();
      render();

      var res = await postLinks(items);
      if (res.ok) {
        status('Synced ' + items.length + ' link(s).');
      } else {
        status('Saved locally, but server sync failed.');
      }

      await loadCloudLinks();
      render();
    });
  }

  async function init() {
    setSection(getSectionFromLocation());
    await Promise.all([loadTree(), loadSeedLinks(), loadCloudDirs(), loadCloudLinks()]);
    render();
    bindEvents();
  }

  init();
})();
