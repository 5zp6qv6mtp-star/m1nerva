#!/usr/bin/env bash
set -euo pipefail

ROOT='/Users/dylanyoung/Documents/New project/minerva'
URLS_FILE="$ROOT/all_folder_urls_from_log.txt"
PATHS_FILE="$ROOT/.all_folder_paths_encoded.txt"

[[ -s "$URLS_FILE" ]] || { echo "Missing $URLS_FILE"; exit 1; }

html_escape() {
  sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

url_decode() {
  local s="${1//+/ }"
  printf '%b' "${s//%/\\x}"
}

escape_regex() {
  printf '%s' "$1" | sed -e 's/[.[\*^$()+?{}|]/\\&/g' -e 's#/#\\/#g'
}

path_prefix() {
  local path="$1"
  local depth
  depth=$(awk -F'/' '{print NF}' <<< "$path")
  local p=""
  local i
  for ((i=0; i<depth; i++)); do
    p+="../"
  done
  printf '%s' "$p"
}

# Build unique encoded folder paths relative to /files/
grep -E '^https?://[^/]+/files(/.*)?/$' "$URLS_FILE" \
  | sed -E 's#^https?://[^/]+/files/?##; s#/$##' \
  | sed '/[?#]/d' \
  | sort -u > "$PATHS_FILE"

count=0
while IFS= read -r path; do
  [[ -n "$path" ]] || continue

  decoded_path="$(url_decode "$path")"
  out_dir="$ROOT/$decoded_path"
  out_file="$out_dir/index.html"
  mkdir -p "$out_dir"

  escaped="$(escape_regex "$path")"
  prefix="$(path_prefix "$path")"

  {
    echo '<!DOCTYPE html><html><head>'
    echo '<meta charset="utf-8">'
    echo '<meta http-equiv="x-ua-compatible" content="IE=edge">'
    echo '<title>Content Listing | Minerva</title>'
    echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
    printf '<link rel="stylesheet" href="%scss/main.css">\n' "$prefix"
    printf '<script type="text/javascript" src="%sjs/jquery.min.js"></script>\n' "$prefix"
    echo '</head>'
    echo '<body>'
    echo '<pre style="font: 10px/9px monospace; color: white; text-align: center;"> __  __ ___ _   _ _____ ______     ___    '
    echo '|  \/  |_ _| \ | | ____|  _ \ \   / / \   '
    echo '| |\/| || ||  \| |  _| | |_) \ \ / / _ \  '
    echo '| |  | || || |\  | |___|  _ < \ V / ___ \ '
    echo '|_|  |_|___|_| \_|_____|_| \_\ \_/_/   \_\'
    echo ''
    echo '</pre>'
    echo '<pre style="font: 14px/13px monospace; color: white; text-align: center;">Where sharing is a priority</pre>'
    echo '<br>'
    echo '<p style="text-align: center; color: #39FF14; font-size: 1.4em;">What comes down must go up.</p>'
    echo '<br>'
    echo '<div class="row">'
    printf '<a href="%sindex.html" class="menu">Home</a> | \n' "$prefix"
    printf '<a href="%sindex.html" class="menu">Files</a> | \n' "$prefix"
    echo '<a href="#" class="menu upload-toggle">Upload</a>'
    echo '</div>'
    echo '<br>'
    echo '<div class="noscriptnotice">'
    echo '<noscript>Please enable JavaScript in order to use Minerva search features.</noscript>'
    echo '</div>'
    echo '<div class="upload-panel" style="display:none; max-width: 900px; margin: 0 auto 14px auto; border: 1px solid #39FF14; padding: 12px;">'
    printf '<p style="margin: 0 0 8px 0; color: #39FF14;">Upload to this section: /files/%s/</p>\n' "$(printf '%s' "$decoded_path" | html_escape)"
    echo '<form class="upload-form" action="/upload/" method="post" enctype="multipart/form-data">'
    printf '<input type="hidden" name="section" value="/files/%s/">\n' "$(printf '%s' "$decoded_path" | html_escape)"
    echo '<p style="margin: 0 0 8px 0;">'
    echo '<label>Name: <input type="text" name="name" style="width: 320px;"></label>'
    echo '</p>'
    echo '<p style="margin: 0 0 8px 0;">'
    echo '<label>Direct Download URL: <input type="url" name="direct_url" placeholder="https://example.com/file.zip" style="width: 520px;"></label>'
    echo '</p>'
    echo '<p style="margin: 0 0 8px 0;">'
    echo '<label>Bulk Direct URLs (one per line)</label><br>'
    echo '<textarea name="bulk_urls" rows="5" style="width: 700px;" placeholder="https://example.com/a.zip&#10;https://example.com/b.zip"></textarea>'
    echo '</p>'
    echo '<p style="margin: 0 0 8px 0;">'
    echo '<label>Notes: <input type="text" name="notes" style="width: 520px;"></label>'
    echo '</p>'
    echo '<p style="margin: 0 0 8px 0;"><input type="file" name="files" multiple></p>'
    echo '<button type="submit">Submit</button>'
    echo '<p class="upload-status" style="margin: 8px 0 0 0; color: #39FF14;"></p>'
    echo '</form>'
    echo '</div>'
    echo '<div style="max-width: 900px; margin: 0 auto 14px auto; border: 1px solid #39FF14; padding: 12px;">'
    echo '<p style="margin: 0 0 8px 0; color: #39FF14;">Create new subdirectory in this section</p>'
    echo '<form class="newdir-form">'
    echo '<label>Directory Name: <input type="text" class="newdir-input" required style="width: 320px;"></label>'
    echo '<button type="submit">Create Directory</button>'
    echo '</form>'
    echo '</div>'
    echo '<div>'
    printf '<h1>Index of \n/files/%s/</h1>\n' "$(printf '%s' "$decoded_path" | html_escape)"
    echo '<table id="list"><thead><tr><th style="width:55%">File Name</th><th style="width:20%">File Size</th><th style="width:25%">Date</th></tr></thead>'
    echo '<tbody>'
    echo '<tr><td class="link"><a href="../index.html">Parent directory/</a></td><td class="size">-</td><td class="date">-</td></tr>'

    grep -E "^${escaped}/[^/]+$" "$PATHS_FILE" | sort -u > "$ROOT/.tmp_children" || true

    if [[ -s "$ROOT/.tmp_children" ]]; then
      while IFS= read -r child_path; do
        child_segment="${child_path#${path}/}"
        child_decoded="$(url_decode "$child_segment")"
        safe_text="$(printf '%s' "$child_decoded" | html_escape)"
        safe_href="$(printf '%s' "$child_decoded" | html_escape)"
        printf '<tr><td class="link"><a href="%s/index.html" title="%s">%s/</a></td><td class="size">-</td><td class="date">-</td></tr>\n' "$safe_href" "$safe_text" "$safe_text"
      done < "$ROOT/.tmp_children"
    fi

    echo '</tbody></table></div>'
    echo '<p style="text-align: center;">Minerva is a Myrient Clone</p>'
    echo '<footer>'
    echo '<a href="#">Non-Affiliation Disclaimer</a> | '
    echo '<a href="#">DMCA</a>'
    echo '</footer>'
    printf '<div id="minerva-page-meta" data-section="%s" data-prefix="%s" style="display:none;"></div>\n' "$(printf '%s' "/files/$decoded_path/" | html_escape)" "$(printf '%s' "$prefix" | html_escape)"
    printf '<script src="%sjs/xregexp-all.js"></script>\n' "$prefix"
    printf '<script type="text/javascript" src="%sjs/search.js"></script>\n' "$prefix"
    printf '<script src="%sjs/minerva-config.js"></script>\n' "$prefix"
    echo '<script>'
    echo '(function () {'
    echo '  var meta = document.getElementById("minerva-page-meta");'
    echo '  if (!meta) return;'
    echo '  var section = meta.getAttribute("data-section") || "/files/";'
    echo '  var prefix = meta.getAttribute("data-prefix") || "";'
    echo '  var tbody = document.querySelector("#list tbody");'
    echo '  var uploadToggle = document.querySelector(".upload-toggle");'
    echo '  var uploadPanel = document.querySelector(".upload-panel");'
    echo '  var uploadForm = document.querySelector(".upload-form");'
    echo '  var uploadStatus = document.querySelector(".upload-status");'
    echo '  var form = document.querySelector(".newdir-form");'
    echo '  var input = document.querySelector(".newdir-input");'
    echo '  if (!tbody || !form || !input || !uploadForm) return;'
    echo '  if (uploadToggle && uploadPanel) {'
    echo '    uploadToggle.addEventListener("click", function (e) {'
    echo '      e.preventDefault();'
    echo '      uploadPanel.style.display = (uploadPanel.style.display === "none" || !uploadPanel.style.display) ? "block" : "none";'
    echo '    });'
    echo '  }'
    echo '  var key = "minerva_custom_dirs::" + section;'
    echo '  var uploadKey = "minerva_upload_items::" + section;'
    echo '  var seedUploads = [];'
    echo '  var cloudUrl = (window.MINERVA_SUPABASE_URL || "").replace(/\/$/, "");'
    echo '  var cloudKey = window.MINERVA_SUPABASE_ANON_KEY || "";'
    echo '  function cloudEnabled() {'
    echo '    return !!cloudUrl && !!cloudKey;'
    echo '  }'
    echo '  function cloudHeaders(extra) {'
    echo '    var h = { "apikey": cloudKey, "Authorization": "Bearer " + cloudKey };'
    echo '    if (extra) { for (var k in extra) h[k] = extra[k]; }'
    echo '    return h;'
    echo '  }'
    echo '  function readDirs() {'
    echo '    try {'
    echo '      var raw = localStorage.getItem(key);'
    echo '      var parsed = raw ? JSON.parse(raw) : [];'
    echo '      return Array.isArray(parsed) ? parsed : [];'
    echo '    } catch (e) {'
    echo '      return [];'
    echo '    }'
    echo '  }'
    echo '  function saveDirs(dirs) {'
    echo '    localStorage.setItem(key, JSON.stringify(dirs));'
    echo '  }'
    echo '  function readUploads() {'
    echo '    try {'
    echo '      var raw = localStorage.getItem(uploadKey);'
    echo '      var parsed = raw ? JSON.parse(raw) : [];'
    echo '      return Array.isArray(parsed) ? parsed : [];'
    echo '    } catch (e) {'
    echo '      return [];'
    echo '    }'
    echo '  }'
    echo '  function saveUploads(items) {'
    echo '    try {'
    echo '      localStorage.setItem(uploadKey, JSON.stringify(items));'
    echo '      return true;'
    echo '    } catch (e) {'
    echo '      return false;'
    echo '    }'
    echo '  }'
    echo '  async function loadSeedUploads() {'
    echo '    try {'
    echo '      var resp = await fetch(prefix + "data/seed-links.json", { cache: "no-store" });'
    echo '      if (!resp.ok) {'
    echo '        if (uploadStatus) uploadStatus.textContent = "Cloud read failed (" + resp.status + "). Showing local items.";'
    echo '        return;'
    echo '      }'
    echo '      var rows = await resp.json();'
    echo '      if (!Array.isArray(rows)) return;'
    echo '      seedUploads = rows.filter(function (r) { return r && r.section === section; }).map(function (r) {'
    echo '        return {'
    echo '          name: r.name || "Untitled",'
    echo '          direct_url: r.direct_url || "",'
    echo '          notes: r.notes || "",'
    echo '          size: r.size || "-",'
    echo '          date: r.date || "Seed"'
    echo '        };'
    echo '      });'
    echo '      render();'
    echo '    } catch (e) {}'
    echo '  }'
    echo '  async function syncUploadsFromCloud() {'
    echo '    if (!cloudEnabled()) return;'
    echo '    try {'
    echo '      var url = cloudUrl + "/rest/v1/links?select=name,direct_url,notes,size,date,created_at&section=eq." + encodeURIComponent(section) + "&order=created_at.asc";'
    echo '      var resp = await fetch(url, { headers: cloudHeaders() });'
    echo '      if (!resp.ok) return;'
    echo '      var rows = await resp.json();'
    echo '      var mapped = rows.map(function (r) {'
    echo '        return {'
    echo '          name: r.name || "Untitled",'
    echo '          direct_url: r.direct_url || "",'
    echo '          notes: r.notes || "",'
    echo '          size: r.size || "-",'
    echo '          date: r.date || "Custom"'
    echo '        };'
    echo '      });'
    echo '      saveUploads(mapped);'
    echo '      render();'
    echo '    } catch (e) {'
    echo '      if (uploadStatus) uploadStatus.textContent = "Cloud read failed. Showing local items.";'
    echo '    }'
    echo '  }'
    echo '  async function pushUploadsToCloud(items) {'
    echo '    if (!cloudEnabled() || !items || items.length === 0) return { ok: false, reason: "cloud-disabled" };'
    echo '    try {'
    echo '      var payload = items.map(function (i) {'
    echo '        return {'
    echo '          section: section,'
    echo '          name: i.name || "Untitled",'
    echo '          direct_url: i.direct_url || "",'
    echo '          notes: i.notes || "",'
    echo '          size: i.size || "-",'
    echo '          date: i.date || "Custom"'
    echo '        };'
    echo '      });'
    echo '      var resp = await fetch(cloudUrl + "/rest/v1/links", {'
    echo '        method: "POST",'
    echo '        headers: cloudHeaders({ "Content-Type": "application/json", "Prefer": "return=minimal" }),'
    echo '        body: JSON.stringify(payload)'
    echo '      });'
    echo '      if (!resp.ok) {'
    echo '        return { ok: false, reason: "http-" + resp.status };'
    echo '      }'
    echo '      return { ok: true };'
    echo '    } catch (e) {'
    echo '      return { ok: false, reason: "network" };'
    echo '    }'
    echo '  }'
    echo '  function safeName(v) {'
    echo '    return v.trim().replace(/[\\/]+/g, "").replace(/[<>:\"|?*]/g, "");'
    echo '  }'
    echo '  function nameFromUrl(url) {'
    echo '    try {'
    echo '      var clean = (url || "").split("#")[0].split("?")[0];'
    echo '      var part = clean.substring(clean.lastIndexOf("/") + 1) || "Untitled";'
    echo '      return decodeURIComponent(part);'
    echo '    } catch (e) {'
    echo '      return "Untitled";'
    echo '    }'
    echo '  }'
    echo '  function render() {'
    echo '    var old = tbody.querySelectorAll("tr.custom-dir-row, tr.custom-upload-row");'
    echo '    old.forEach(function (n) { n.remove(); });'
    echo '    var insertAt = tbody.children.length > 1 ? tbody.children[1] : null;'
    echo '    var dirs = readDirs();'
    echo '    dirs.forEach(function (name) {'
    echo '      var tr = document.createElement("tr");'
    echo '      tr.className = "custom-dir-row";'
    echo '      var tdLink = document.createElement("td");'
    echo '      tdLink.className = "link";'
    echo '      var a = document.createElement("a");'
    echo '      a.href = prefix + "custom.html?path=" + encodeURIComponent(section + name + "/");'
    echo '      a.title = name + " (custom)";'
    echo '      a.textContent = name + "/";'
    echo '      tdLink.appendChild(a);'
    echo '      var tdSize = document.createElement("td");'
    echo '      tdSize.className = "size";'
    echo '      tdSize.textContent = "-";'
    echo '      var tdDate = document.createElement("td");'
    echo '      tdDate.className = "date";'
    echo '      tdDate.textContent = "Custom";'
    echo '      tr.appendChild(tdLink);'
    echo '      tr.appendChild(tdSize);'
    echo '      tr.appendChild(tdDate);'
    echo '      tbody.insertBefore(tr, insertAt);'
    echo '    });'
    echo '    var uploads = seedUploads.concat(readUploads());'
    echo '    var newItems = [];'
    echo '    uploads.forEach(function (item) {'
    echo '      var tr = document.createElement("tr");'
    echo '      tr.className = "custom-upload-row";'
    echo '      var tdLink = document.createElement("td");'
    echo '      tdLink.className = "link";'
    echo '      var a = document.createElement("a");'
    echo '      a.href = item.direct_url || "#";'
    echo '      if (item.direct_url) {'
    echo '        a.target = "_blank";'
    echo '        a.rel = "noopener noreferrer";'
    echo '      }'
    echo '      a.title = item.notes || item.name || "Upload";'
    echo '      a.textContent = (item.name || "Untitled") + " [Upload]";'
    echo '      tdLink.appendChild(a);'
    echo '      var tdSize = document.createElement("td");'
    echo '      tdSize.className = "size";'
    echo '      tdSize.textContent = item.size || "-";'
    echo '      var tdDate = document.createElement("td");'
    echo '      tdDate.className = "date";'
    echo '      tdDate.textContent = item.date || "Custom";'
    echo '      tr.appendChild(tdLink);'
    echo '      tr.appendChild(tdSize);'
    echo '      tr.appendChild(tdDate);'
    echo '      tbody.insertBefore(tr, insertAt);'
    echo '    });'
    echo '  }'
    echo '  form.addEventListener("submit", function (e) {'
    echo '    e.preventDefault();'
    echo '    var name = safeName(input.value);'
    echo '    if (!name) return;'
    echo '    var dirs = readDirs();'
    echo '    if (dirs.indexOf(name) === -1) {'
    echo '      dirs.push(name);'
    echo '      dirs.sort();'
    echo '      saveDirs(dirs);'
    echo '      render();'
    echo '    }'
    echo '    input.value = "";'
    echo '  });'
    echo '  uploadForm.addEventListener("submit", function (e) {'
    echo '    e.preventDefault();'
    echo "    var nameInput = uploadForm.querySelector('input[name=\"name\"]');"
    echo "    var urlInput = uploadForm.querySelector('input[name=\"direct_url\"]');"
    echo "    var bulkInput = uploadForm.querySelector('textarea[name=\"bulk_urls\"]');"
    echo "    var notesInput = uploadForm.querySelector('input[name=\"notes\"]');"
    echo "    var filesInput = uploadForm.querySelector('input[name=\"files\"]');"
    echo '    var name = nameInput ? nameInput.value.trim() : "";'
    echo '    var directUrl = urlInput ? urlInput.value.trim() : "";'
    echo '    var bulkText = bulkInput ? bulkInput.value : "";'
    echo '    var bulkUrls = bulkText.split(/\r?\n/).map(function (x) { return x.trim(); }).filter(Boolean);'
    echo '    var notes = notesInput ? notesInput.value.trim() : "";'
    echo '    var size = "-";'
    echo '    if (filesInput && filesInput.files && filesInput.files.length > 0) {'
    echo '      size = filesInput.files.length + " file(s)";'
    echo '    }'
    echo '    var uploads = readUploads();'
    echo '    var added = false;'
    echo '    if (bulkUrls.length > 0) {'
    echo '      bulkUrls.forEach(function (u) {'
    echo '        var item = { name: nameFromUrl(u), direct_url: u, notes: notes, size: "-", date: "Custom" };'
    echo '        uploads.push(item);'
    echo '        newItems.push(item);'
    echo '      });'
    echo '      added = true;'
    echo '    }'
    echo '    if (name || directUrl || (filesInput && filesInput.files && filesInput.files.length > 0)) {'
    echo '      var one = {'
    echo '        name: name || (directUrl ? nameFromUrl(directUrl) : "Untitled"),'
    echo '        direct_url: directUrl,'
    echo '        notes: notes,'
    echo '        size: size,'
    echo '        date: "Custom"'
    echo '      };'
    echo '      uploads.push(one);'
    echo '      newItems.push(one);'
    echo '      added = true;'
    echo '    }'
    echo '    if (!added) {'
    echo '      if (uploadStatus) uploadStatus.textContent = "Nothing to add. Fill name/url or paste bulk links.";'
    echo '      return;'
    echo '    }'
    echo '    if (!saveUploads(uploads)) {'
    echo '      if (uploadStatus) uploadStatus.textContent = "Local save blocked by browser settings.";'
    echo '      return;'
    echo '    }'
    echo '    uploadForm.reset();'
    echo '    render();'
    echo '    if (uploadStatus) uploadStatus.textContent = "Added " + newItems.length + " link(s). Syncing...";'
    echo '    pushUploadsToCloud(newItems).then(function (result) {'
    echo '      if (result && result.ok) {'
    echo '        if (uploadStatus) uploadStatus.textContent = "Synced " + newItems.length + " link(s).";'
    echo '        syncUploadsFromCloud();'
    echo '      } else {'
    echo '        if (uploadStatus) uploadStatus.textContent = "Saved locally, but cloud sync failed.";'
    echo '      }'
    echo '    });'
    echo '  });'
    echo '  render();'
    echo '  loadSeedUploads();'
    echo '  syncUploadsFromCloud();'
    echo '})();'
    echo '</script>'
    echo '</body></html>'
  } > "$out_file"

  count=$((count+1))
done < "$PATHS_FILE"

rm -f "$ROOT/.tmp_children"
echo "Generated/updated $count folder pages."
