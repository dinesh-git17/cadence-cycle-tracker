const state = {
  manifest: null,
  documents: [],
  documentsById: new Map(),
  documentsByPath: new Map(),
  selectedDocId: null,
  query: "",
  expandedFolders: new Set(["foundation-design-docs"]),
  cache: new Map(),
  loadingDocId: null,
  loadError: null,
  drawerOpen: false,
  requestToken: 0,
};

const refs = {};
const media = {
  desktop: window.matchMedia("(min-width: 62rem)"),
  reducedMotion: window.matchMedia("(prefers-reduced-motion: reduce)"),
};

document.addEventListener("DOMContentLoaded", init);

async function init() {
  cacheDom();
  bindEvents();

  try {
    const manifest = await fetchManifest();
    hydrateState(manifest);
    renderLanding();
    renderNavigation();
    syncRepoLink();
    applyRoute(parseRoute(window.location.hash), {
      updateHash: false,
      focusTarget: false,
    });
    refs.shell.dataset.ready = "true";
  } catch (error) {
    renderFatalState(error);
  }
}

function cacheDom() {
  refs.shell = document.getElementById("app-shell");
  refs.menuButton = document.getElementById("menu-button");
  refs.brandButton = document.getElementById("brand-button");
  refs.repoLink = document.getElementById("repo-link");
  refs.sidebar = document.getElementById("docs-sidebar");
  refs.drawerBackdrop = document.getElementById("drawer-backdrop");
  refs.navRoot = document.getElementById("nav-root");
  refs.searchInput = document.getElementById("search-input");
  refs.main = document.getElementById("main-content");
  refs.landing = document.getElementById("landing-panel");
  refs.reader = document.getElementById("reader-panel");
  refs.readerTitle = document.getElementById("reader-title");
  refs.readerBody = document.getElementById("reader-body");
}

function bindEvents() {
  refs.menuButton.addEventListener("click", () =>
    toggleDrawer(!state.drawerOpen),
  );
  refs.drawerBackdrop.addEventListener("click", () => toggleDrawer(false));
  refs.brandButton.addEventListener("click", () => navigateHome());
  refs.searchInput.addEventListener("input", handleSearchInput);
  refs.navRoot.addEventListener("click", handleNavigationClick);
  refs.landing.addEventListener("click", handleLandingClick);
  refs.readerBody.addEventListener("click", handleNavigationClick);
  window.addEventListener("hashchange", handleHashChange);
  window.addEventListener("keydown", handleKeydown);
  media.desktop.addEventListener("change", handleDesktopChange);
  window.addEventListener("beforeunload", revokeCachedObjectUrls);
}

async function fetchManifest() {
  const response = await fetch("docs-index.json", { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`Unable to load docs-index.json (${response.status})`);
  }

  return response.json();
}

function hydrateState(manifest) {
  state.manifest = manifest;
  state.documents = manifest.documents.map((documentMeta) => ({
    ...documentMeta,
    type: documentMeta.type || inferDocumentType(documentMeta.path),
  }));

  state.documents.forEach((documentMeta) => {
    state.documentsById.set(documentMeta.id, documentMeta);
    state.documentsByPath.set(normalizePath(documentMeta.path), documentMeta);
  });
}

function inferDocumentType(path) {
  return path.toLowerCase().endsWith(".pdf") ? "pdf" : "markdown";
}

function normalizePath(path) {
  return path
    .replace(/^\.?\//, "")
    .replace(/^docs\//, "")
    .toLowerCase();
}

function syncRepoLink() {
  const repoUrl = deriveRepoUrl();
  if (!repoUrl) {
    refs.repoLink.classList.add("is-hidden");
    return;
  }

  refs.repoLink.href = repoUrl;
  refs.repoLink.querySelector("span").textContent =
    state.manifest.site.repoLabel || "Repository";
  refs.repoLink.classList.remove("is-hidden");
}

function deriveRepoUrl() {
  if (state.manifest.site.repoUrl) {
    return state.manifest.site.repoUrl;
  }

  const { hostname, pathname } = window.location;
  if (!hostname.endsWith(".github.io")) {
    return "";
  }

  const owner = hostname.replace(/\.github\.io$/i, "");
  const [repoName] = pathname.split("/").filter(Boolean);
  if (!owner || !repoName) {
    return "";
  }

  return `https://github.com/${owner}/${repoName}`;
}

function handleSearchInput(event) {
  state.query = event.target.value.trim();
  renderNavigation();
}

function handleNavigationClick(event) {
  const folderTrigger = event.target.closest("[data-action='toggle-folder']");
  if (folderTrigger) {
    toggleFolder(folderTrigger.dataset.folderId);
    return;
  }

  const docTrigger = event.target.closest("[data-action='open-doc']");
  if (docTrigger) {
    openDocument(docTrigger.dataset.docId);
    return;
  }

  const homeTrigger = event.target.closest("[data-action='go-home']");
  if (homeTrigger) {
    navigateHome();
  }
}

function handleLandingClick(event) {
  const docTrigger = event.target.closest("[data-action='open-doc']");
  if (docTrigger) {
    openDocument(docTrigger.dataset.docId);
  }
}

function handleHashChange() {
  applyRoute(parseRoute(window.location.hash), {
    updateHash: false,
    focusTarget: false,
  });
}

function handleKeydown(event) {
  if (event.key === "Escape" && state.drawerOpen) {
    toggleDrawer(false);
  }
}

function handleDesktopChange(event) {
  if (event.matches) {
    toggleDrawer(false);
  }
}

function parseRoute(hashValue) {
  if (!hashValue || hashValue === "#" || hashValue === "#home") {
    return { view: "home" };
  }

  const raw = hashValue.replace(/^#/, "");
  const params = new URLSearchParams(raw);
  const docId = params.get("doc");
  if (docId && state.documentsById.has(docId)) {
    return { view: "document", docId };
  }

  return { view: "home" };
}

function applyRoute(route, options = {}) {
  if (route.view === "home") {
    setHomeState(options);
    return;
  }

  if (route.docId) {
    setDocumentState(route.docId, options);
  }
}

function setHomeState(options = {}) {
  state.selectedDocId = null;
  state.loadingDocId = null;
  state.loadError = null;
  refs.shell.dataset.view = "home";
  renderNavigation();
  renderReaderHomeState();
  scrollMainToTop();

  if (options.updateHash !== false) {
    updateHash("#home");
  }

  if (options.focusTarget !== false) {
    focusLandingTitle();
  }
}

function setDocumentState(docId, options = {}) {
  const documentMeta = state.documentsById.get(docId);
  if (!documentMeta) {
    setHomeState(options);
    return;
  }

  state.selectedDocId = docId;
  state.loadError = null;
  refs.shell.dataset.view = "document";
  expandAncestorsForDocument(docId);
  renderNavigation();
  renderReader(documentMeta);

  if (options.updateHash !== false) {
    updateHash(`#doc=${encodeURIComponent(docId)}`);
  }

  if (!state.cache.has(docId)) {
    loadDocument(documentMeta);
  }

  if (!media.desktop.matches) {
    toggleDrawer(false);
  }

  if (options.focusTarget !== false) {
    focusReaderTitle();
  }

  scrollMainToTop();
}

function navigateHome() {
  setHomeState();
}

function openDocument(docId) {
  setDocumentState(docId);
}

function updateHash(nextHash) {
  if (window.location.hash === nextHash) {
    return;
  }

  window.location.hash = nextHash;
}

function toggleDrawer(nextState) {
  state.drawerOpen = nextState;
  refs.shell.dataset.drawerOpen = String(nextState);
  refs.menuButton.setAttribute("aria-expanded", String(nextState));

  if (nextState && !media.desktop.matches) {
    refs.searchInput.focus();
  }
}

function toggleFolder(folderId) {
  if (state.expandedFolders.has(folderId)) {
    state.expandedFolders.delete(folderId);
  } else {
    state.expandedFolders.add(folderId);
  }

  renderNavigation();
}

function expandAncestorsForDocument(docId) {
  state.manifest.navigation.forEach((section) => {
    section.items.forEach((item) => expandAncestorFolders(item, docId));
  });
}

function expandAncestorFolders(item, docId) {
  if (item.type !== "folder") {
    return false;
  }

  const containsDocument = item.items.some((child) => {
    if (child.type === "doc") {
      return child.docId === docId;
    }

    return expandAncestorFolders(child, docId);
  });

  if (containsDocument) {
    state.expandedFolders.add(item.id);
  }

  return containsDocument;
}

function renderLanding() {
  const totalDocuments = state.documents.length;
  const phaseFolders = state.manifest.navigation
    .find((section) => section.id === "build-phases")
    .items.filter((item) => item.type === "folder").length;
  const featuredCards = state.manifest.featured
    .map(renderFeaturedCard)
    .join("");
  const overviewCards = state.manifest.site.highlights
    .map(renderOverviewCard)
    .join("");

  refs.landing.innerHTML = `
    <section class="landing-hero">
      <div class="landing-hero__copy">
        <div class="landing-hero__eyebrow">Curated GitHub Pages Reader</div>
        <h1 class="landing-title" id="landing-title" tabindex="-1">${escapeHtml(state.manifest.site.title)}</h1>
        <p class="landing-summary">${escapeHtml(state.manifest.site.summary)}</p>
      </div>

      <div class="landing-chip-row" aria-label="Documentation stats">
        <div class="landing-chip">
          <span class="landing-chip__value">${totalDocuments} source docs</span>
          <span class="landing-chip__label">Markdown and PDF assets loaded in place</span>
        </div>
        <div class="landing-chip">
          <span class="landing-chip__value">${phaseFolders} build phases</span>
          <span class="landing-chip__label">Manifest folders ready for future PH additions</span>
        </div>
        <div class="landing-chip">
          <span class="landing-chip__value">Hash-routed reader</span>
          <span class="landing-chip__label">Home and document state restore on reload</span>
        </div>
      </div>

      <section class="landing-section" aria-labelledby="featured-documents-title">
        <div class="landing-section__header">
          <div>
            <h2 class="landing-section__title" id="featured-documents-title">Featured Documents</h2>
            <p class="landing-section__copy">The three documents that define the product, the visual bar, and the execution order.</p>
          </div>
        </div>
        <div class="featured-grid">${featuredCards}</div>
      </section>

      <section class="landing-section" aria-labelledby="overview-title">
        <div class="landing-section__header">
          <div>
            <h2 class="landing-section__title" id="overview-title">Curated Structure</h2>
            <p class="landing-section__copy">The raw file tree is preserved on disk, but the reader organizes it into a calmer, human-first model.</p>
          </div>
        </div>
        <div class="landing-overview">${overviewCards}</div>
      </section>
    </section>
  `;
}

function renderFeaturedCard(featuredDocument) {
  const documentMeta = state.documentsById.get(featuredDocument.docId);
  return `
    <button class="featured-card" type="button" data-action="open-doc" data-doc-id="${escapeHtml(documentMeta.id)}">
      <span class="featured-card__eyebrow">${escapeHtml(featuredDocument.eyebrow || "Featured")}</span>
      <h3 class="featured-card__title">${escapeHtml(documentMeta.title)}</h3>
      <p class="featured-card__body">${escapeHtml(documentMeta.summary || "Open this document in the same reader shell.")}</p>
      <span class="featured-card__meta">${escapeHtml(documentMeta.type === "pdf" ? "PDF" : "Markdown")}</span>
    </button>
  `;
}

function renderOverviewCard(highlight) {
  return `
    <article class="overview-card">
      <h3 class="overview-card__title">${escapeHtml(highlight.label)}</h3>
      <p class="overview-card__body">${escapeHtml(highlight.description)}</p>
    </article>
  `;
}

function renderNavigation() {
  const renderedSections = state.manifest.navigation
    .map((section) => renderNavigationSection(section))
    .filter(Boolean)
    .join("");

  refs.navRoot.innerHTML = renderedSections || renderSearchEmptyState();
}

function renderNavigationSection(section) {
  const query = state.query.toLowerCase();
  const renderedItems = section.items
    .map((item) => renderNavigationItem(item, query, false))
    .filter(Boolean)
    .join("");

  if (!renderedItems) {
    return "";
  }

  return `
    <section class="nav-section" aria-labelledby="section-${escapeHtml(section.id)}">
      <h2 class="nav-section__label" id="section-${escapeHtml(section.id)}">${escapeHtml(section.label)}</h2>
      <div class="nav-stack">${renderedItems}</div>
    </section>
  `;
}

function renderNavigationItem(item, query, forceVisibleChildren) {
  if (item.type === "home") {
    const isVisible = !query || item.label.toLowerCase().includes(query);
    if (!isVisible) {
      return "";
    }

    const isActive = !state.selectedDocId;
    return `
      <button class="nav-item nav-item--home ${isActive ? "nav-item--active" : ""}" type="button" data-action="go-home">
        <span class="nav-item__content">
          <span class="nav-item__label">${escapeHtml(item.label)}</span>
          <span class="nav-item__meta">Featured landing and featured cards</span>
        </span>
      </button>
    `;
  }

  if (item.type === "doc") {
    const documentMeta = state.documentsById.get(item.docId);
    if (!documentMeta) {
      return "";
    }

    const titleMatch = documentMeta.title.toLowerCase().includes(query);
    const isVisible = !query || forceVisibleChildren || titleMatch;
    if (!isVisible) {
      return "";
    }

    const isActive = state.selectedDocId === documentMeta.id;
    return `
      <button
        class="nav-item ${isActive ? "nav-item--active" : ""}"
        type="button"
        data-action="open-doc"
        data-doc-id="${escapeHtml(documentMeta.id)}"
      >
        <span class="nav-item__content">
          <span class="nav-item__label">${escapeHtml(documentMeta.title)}</span>
          <span class="nav-item__meta">${escapeHtml(documentMeta.type === "pdf" ? "PDF document" : "Markdown document")}</span>
        </span>
      </button>
    `;
  }

  if (item.type === "folder") {
    const folderMatch =
      item.label.toLowerCase().includes(query) ||
      (item.code || "").toLowerCase().includes(query);
    const childMarkup = item.items
      .map((child) =>
        renderNavigationItem(child, query, forceVisibleChildren || folderMatch),
      )
      .filter(Boolean)
      .join("");

    if (!childMarkup) {
      return "";
    }

    const isExpanded = query
      ? true
      : state.expandedFolders.has(item.id) ||
        folderContainsSelectedDocument(item);
    const isActive = folderContainsSelectedDocument(item);

    return `
      <section class="accordion ${isActive ? "accordion--active" : ""}" data-expanded="${String(isExpanded)}">
        <button
          class="accordion__trigger"
          type="button"
          data-action="toggle-folder"
          data-folder-id="${escapeHtml(item.id)}"
          aria-expanded="${String(isExpanded)}"
        >
          <span class="accordion__trigger-copy">
            <span class="accordion__title">${escapeHtml(item.label)}</span>
            <span class="accordion__meta">${escapeHtml(item.description || `${countDocumentsInFolder(item)} docs`)}</span>
          </span>
          <span class="accordion__code">${escapeHtml(item.code || `${countDocumentsInFolder(item)} docs`)}</span>
          <svg class="accordion__caret" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <path
              d="M6 9L12 15L18 9"
              fill="none"
              stroke="currentColor"
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1.5"
            />
          </svg>
        </button>
        <div class="accordion__panel" ${isExpanded ? "" : "hidden"}>${childMarkup}</div>
      </section>
    `;
  }

  return "";
}

function folderContainsSelectedDocument(folder) {
  return folder.items.some((child) => {
    if (child.type === "doc") {
      return child.docId === state.selectedDocId;
    }

    if (child.type === "folder") {
      return folderContainsSelectedDocument(child);
    }

    return false;
  });
}

function countDocumentsInFolder(folder) {
  return folder.items.reduce((count, child) => {
    if (child.type === "doc") {
      return count + 1;
    }

    if (child.type === "folder") {
      return count + countDocumentsInFolder(child);
    }

    return count;
  }, 0);
}

function renderSearchEmptyState() {
  return `
    <div class="search-empty">
      <strong>No matching documents</strong>
      <p>Try searching by a document title like Design, Prediction, Tracker, or Notification.</p>
    </div>
  `;
}

function renderReaderHomeState() {
  refs.readerTitle.textContent = state.manifest.site.title;
  refs.readerBody.innerHTML = `
    <div class="reader-state">
      <div class="reader-state__dot"></div>
      <strong>Choose a featured document or browse the sidebar.</strong>
      <p>The landing surface remains available until a document becomes active.</p>
    </div>
  `;
}

function renderReader(documentMeta) {
  refs.readerTitle.textContent = documentMeta.title;

  if (state.loadError && state.loadError.docId === documentMeta.id) {
    refs.readerBody.innerHTML = `
      <div class="reader-surface">
        <div class="reader-state">
          <div class="reader-state__dot"></div>
          <strong>Unable to load this document.</strong>
          <p>${escapeHtml(state.loadError.message)}</p>
          <div class="reader-actions">
            <button class="reader-action" type="button" data-action="open-doc" data-doc-id="${escapeHtml(documentMeta.id)}">Retry</button>
            <a class="reader-action" href="${escapeAttribute(encodeURI(documentMeta.path))}" target="_blank" rel="noreferrer noopener">Open raw file</a>
          </div>
        </div>
      </div>
    `;
    return;
  }

  const cached = state.cache.get(documentMeta.id);
  if (!cached || state.loadingDocId === documentMeta.id) {
    refs.readerBody.innerHTML = `
      <div class="reader-surface">
        <div class="loading-stack" aria-hidden="true">
          <div class="skeleton-line skeleton-line--wide"></div>
          <div class="skeleton-line skeleton-line--mid"></div>
          <div class="skeleton-line skeleton-line--short"></div>
          <div class="skeleton-table"></div>
          <div class="skeleton-code"></div>
        </div>
      </div>
    `;
    return;
  }

  if (cached.kind === "markdown") {
    refs.readerBody.innerHTML = `
      <div class="reader-surface">
        <div class="prose">${cached.html || renderEmptyDocumentState()}</div>
      </div>
    `;
    return;
  }

  if (cached.kind === "pdf") {
    refs.readerBody.innerHTML = `
      <div class="reader-surface">
        <div class="pdf-viewer">
          <iframe class="pdf-frame" src="${escapeAttribute(cached.url)}" title="${escapeAttribute(documentMeta.title)}"></iframe>
          <div class="reader-actions">
            <a class="reader-action" href="${escapeAttribute(cached.url)}" target="_blank" rel="noreferrer noopener">Open PDF in new tab</a>
          </div>
        </div>
      </div>
    `;
  }
}

function renderEmptyDocumentState() {
  return `
    <div class="reader-state">
      <div class="reader-state__dot"></div>
      <strong>This document is empty.</strong>
      <p>No renderable content was returned from the source file.</p>
    </div>
  `;
}

async function loadDocument(documentMeta) {
  const currentToken = ++state.requestToken;
  state.loadingDocId = documentMeta.id;
  state.loadError = null;
  renderReader(documentMeta);

  try {
    const response = await fetch(encodeURI(documentMeta.path), {
      cache: "no-store",
    });
    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}.`);
    }

    let cacheEntry;

    if (documentMeta.type === "pdf") {
      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      cacheEntry = {
        kind: "pdf",
        url: objectUrl,
        objectUrl,
      };
    } else {
      const markdown = await response.text();
      cacheEntry = {
        kind: "markdown",
        html: renderMarkdown(markdown, documentMeta),
      };
    }

    state.cache.set(documentMeta.id, cacheEntry);
    if (
      currentToken !== state.requestToken ||
      state.selectedDocId !== documentMeta.id
    ) {
      return;
    }

    state.loadingDocId = null;
    renderReader(documentMeta);
  } catch (error) {
    if (
      currentToken !== state.requestToken ||
      state.selectedDocId !== documentMeta.id
    ) {
      return;
    }

    state.loadingDocId = null;
    state.loadError = {
      docId: documentMeta.id,
      message:
        error instanceof Error ? error.message : "Unknown loading error.",
    };
    renderReader(documentMeta);
  }
}

function renderFatalState(error) {
  refs.repoLink.classList.add("is-hidden");
  refs.navRoot.innerHTML = `
    <div class="fatal-state">
      <strong>Navigation could not be initialized.</strong>
      <p>${escapeHtml(error instanceof Error ? error.message : "Unknown initialization error.")}</p>
    </div>
  `;

  refs.landing.innerHTML = `
    <div class="fatal-state">
      <strong>Cadence Documentation failed to load.</strong>
      <p>The manifest or shell assets could not be initialized in this environment.</p>
    </div>
  `;

  refs.readerBody.innerHTML = `
    <div class="fatal-state">
      <strong>Reader unavailable.</strong>
      <p>Reload the page after fixing the static asset path or manifest issue.</p>
    </div>
  `;
}

function focusLandingTitle() {
  const landingTitle = document.getElementById("landing-title");
  if (landingTitle) {
    landingTitle.focus({ preventScroll: true });
  }
}

function focusReaderTitle() {
  refs.readerTitle.focus({ preventScroll: true });
}

function scrollMainToTop() {
  refs.main.scrollTo({
    top: 0,
    behavior: media.reducedMotion.matches ? "auto" : "smooth",
  });
}

function revokeCachedObjectUrls() {
  state.cache.forEach((entry) => {
    if (entry.objectUrl) {
      URL.revokeObjectURL(entry.objectUrl);
    }
  });
}

function renderMarkdown(markdown, documentMeta) {
  const lines = markdown.replace(/\r\n?/g, "\n").split("\n");
  const renderer = createHeadingIdFactory();
  const html = [];

  let index = 0;
  while (index < lines.length) {
    const line = lines[index];

    if (!line.trim()) {
      index += 1;
      continue;
    }

    const fenceMatch = line.match(/^(```|~~~)\s*([\w-]*)\s*$/);
    if (fenceMatch) {
      const fence = fenceMatch[1];
      const language = fenceMatch[2];
      const buffer = [];
      index += 1;

      while (index < lines.length && !lines[index].startsWith(fence)) {
        buffer.push(lines[index]);
        index += 1;
      }

      if (index < lines.length) {
        index += 1;
      }

      html.push(renderCodeBlock(buffer.join("\n"), language));
      continue;
    }

    if (/^(?:---|\*\*\*|___)\s*$/.test(line.trim())) {
      html.push("<hr>");
      index += 1;
      continue;
    }

    const headingMatch = line.match(/^(#{1,6})\s+(.*)$/);
    if (headingMatch) {
      const level = headingMatch[1].length;
      const headingText = headingMatch[2].trim();
      const headingId = renderer(headingText);
      html.push(
        `<h${level} id="${escapeAttribute(headingId)}">${renderInline(headingText, documentMeta)}</h${level}>`,
      );
      index += 1;
      continue;
    }

    if (isTableStart(lines, index)) {
      const table = parseTable(lines, index, documentMeta);
      html.push(table.html);
      index = table.nextIndex;
      continue;
    }

    if (/^\s*>/.test(line)) {
      const blockquote = parseBlockquote(lines, index, documentMeta);
      html.push(blockquote.html);
      index = blockquote.nextIndex;
      continue;
    }

    if (isListItem(line)) {
      const list = parseList(lines, index, getIndentLevel(line), documentMeta);
      html.push(list.html);
      index = list.nextIndex;
      continue;
    }

    const paragraph = parseParagraph(lines, index, documentMeta);
    html.push(paragraph.html);
    index = paragraph.nextIndex;
  }

  return html.join("\n");
}

function createHeadingIdFactory() {
  const counts = new Map();
  return (text) => {
    const slug =
      text
        .toLowerCase()
        .replace(/[^a-z0-9\s-]/g, "")
        .trim()
        .replace(/\s+/g, "-") || "section";
    const nextCount = (counts.get(slug) || 0) + 1;
    counts.set(slug, nextCount);
    return nextCount === 1 ? slug : `${slug}-${nextCount}`;
  };
}

function parseParagraph(lines, startIndex, documentMeta) {
  const buffer = [];
  let index = startIndex;

  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) {
      break;
    }

    if (
      /^(```|~~~)\s*([\w-]*)\s*$/.test(line) ||
      /^(#{1,6})\s+/.test(line) ||
      /^(?:---|\*\*\*|___)\s*$/.test(line.trim()) ||
      /^\s*>/.test(line) ||
      isListItem(line) ||
      isTableStart(lines, index)
    ) {
      break;
    }

    buffer.push(line.trim());
    index += 1;
  }

  return {
    html: `<p>${renderInline(buffer.join(" "), documentMeta)}</p>`,
    nextIndex: index,
  };
}

function parseBlockquote(lines, startIndex, documentMeta) {
  const buffer = [];
  let index = startIndex;

  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) {
      buffer.push("");
      index += 1;
      continue;
    }

    if (!/^\s*>/.test(line)) {
      break;
    }

    buffer.push(line.replace(/^\s*>\s?/, ""));
    index += 1;
  }

  return {
    html: `<blockquote>${renderMarkdown(buffer.join("\n"), documentMeta)}</blockquote>`,
    nextIndex: index,
  };
}

function parseList(lines, startIndex, baseIndent, documentMeta) {
  const firstMarker = getListMarker(lines[startIndex]);
  const ordered = Boolean(firstMarker && /\d+\./.test(firstMarker));
  const items = [];
  let index = startIndex;

  while (index < lines.length) {
    const line = lines[index];
    if (!line.trim()) {
      index += 1;
      continue;
    }

    const marker = getListMarker(line);
    if (
      !marker ||
      getIndentLevel(line) < baseIndent ||
      Boolean(/\d+\./.test(marker)) !== ordered
    ) {
      break;
    }

    if (getIndentLevel(line) > baseIndent) {
      break;
    }

    const markerMatch = line.match(/^(\s*)([-+*]|\d+\.)\s+(.*)$/);
    const contentLines = [markerMatch[3]];
    index += 1;

    while (index < lines.length) {
      const nextLine = lines[index];
      if (!nextLine.trim()) {
        break;
      }

      const nextIndent = getIndentLevel(nextLine);
      const nextMarker = getListMarker(nextLine);

      if (!nextMarker && nextIndent <= baseIndent) {
        break;
      }

      if (nextMarker && nextIndent === baseIndent) {
        break;
      }

      if (nextMarker && nextIndent > baseIndent) {
        break;
      }

      if (nextIndent < baseIndent) {
        break;
      }

      contentLines.push(
        nextLine.slice(Math.min(nextLine.length, baseIndent + 2)),
      );
      index += 1;
    }

    let itemHtml = renderMarkdown(contentLines.join("\n"), documentMeta);

    while (index < lines.length) {
      const nextLine = lines[index];
      if (!nextLine.trim()) {
        index += 1;
        continue;
      }

      if (isListItem(nextLine) && getIndentLevel(nextLine) > baseIndent) {
        const nestedList = parseList(
          lines,
          index,
          getIndentLevel(nextLine),
          documentMeta,
        );
        itemHtml += nestedList.html;
        index = nestedList.nextIndex;
        continue;
      }

      break;
    }

    items.push(`<li>${itemHtml}</li>`);
  }

  return {
    html: `<${ordered ? "ol" : "ul"}>${items.join("")}</${ordered ? "ol" : "ul"}>`,
    nextIndex: index,
  };
}

function parseTable(lines, startIndex, documentMeta) {
  const headerCells = splitTableRow(lines[startIndex]);
  const alignments = splitTableRow(lines[startIndex + 1]).map((cell) =>
    parseAlignment(cell),
  );
  const bodyRows = [];
  let index = startIndex + 2;

  while (index < lines.length && isTableRow(lines[index])) {
    bodyRows.push(splitTableRow(lines[index]));
    index += 1;
  }

  const headerMarkup = headerCells
    .map(
      (cell, cellIndex) =>
        `<th style="text-align:${alignments[cellIndex]}">${renderInline(cell, documentMeta)}</th>`,
    )
    .join("");

  const bodyMarkup = bodyRows
    .map((row) => {
      const cells = row
        .map(
          (cell, cellIndex) =>
            `<td style="text-align:${alignments[cellIndex] || "left"}">${renderInline(cell, documentMeta)}</td>`,
        )
        .join("");
      return `<tr>${cells}</tr>`;
    })
    .join("");

  return {
    html: `<div class="table-wrap"><table><thead><tr>${headerMarkup}</tr></thead><tbody>${bodyMarkup}</tbody></table></div>`,
    nextIndex: index,
  };
}

function isTableStart(lines, index) {
  return isTableRow(lines[index]) && isTableSeparator(lines[index + 1]);
}

function isTableRow(line) {
  return typeof line === "string" && line.includes("|");
}

function isTableSeparator(line) {
  if (typeof line !== "string") {
    return false;
  }

  return splitTableRow(line).every((cell) => /^:?-{3,}:?$/.test(cell.trim()));
}

function splitTableRow(line) {
  return line
    .trim()
    .replace(/^\|/, "")
    .replace(/\|$/, "")
    .split("|")
    .map((cell) => cell.trim());
}

function parseAlignment(cell) {
  const trimmed = cell.trim();
  if (trimmed.startsWith(":") && trimmed.endsWith(":")) {
    return "center";
  }

  if (trimmed.endsWith(":")) {
    return "right";
  }

  return "left";
}

function isListItem(line) {
  return /^(\s*)([-+*]|\d+\.)\s+/.test(line);
}

function getListMarker(line) {
  const match = line.match(/^(\s*)([-+*]|\d+\.)\s+/);
  return match ? match[2] : "";
}

function getIndentLevel(line) {
  const match = line.match(/^(\s*)/);
  return match ? match[1].length : 0;
}

function renderCodeBlock(content, language) {
  const languageClass = language
    ? ` class="language-${escapeAttribute(language)}"`
    : "";
  return `<pre><code${languageClass}>${escapeHtml(content)}</code></pre>`;
}

function renderInline(text, documentMeta) {
  const tokens = [];
  let html = text;

  html = html.replace(/`([^`]+)`/g, (_, code) => {
    const token = `INLINECODETOKEN${tokens.length}TOKEN`;
    tokens.push(`<code>${escapeHtml(code)}</code>`);
    return token;
  });

  html = html.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, rawUrl) => {
    const token = `INLINELINKTOKEN${tokens.length}TOKEN`;
    tokens.push(renderLink(label, rawUrl, documentMeta));
    return token;
  });

  html = escapeHtml(html);
  html = html.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  html = html.replace(/__([^_]+)__/g, "<strong>$1</strong>");
  html = html.replace(
    /(^|[\s(])\*([^*]+)\*(?=$|[\s).,!?:;])/g,
    "$1<em>$2</em>",
  );
  html = html.replace(/(^|[\s(])_([^_]+)_(?=$|[\s).,!?:;])/g, "$1<em>$2</em>");

  tokens.forEach((tokenMarkup, tokenIndex) => {
    html = html.replace(`INLINECODETOKEN${tokenIndex}TOKEN`, tokenMarkup);
    html = html.replace(`INLINELINKTOKEN${tokenIndex}TOKEN`, tokenMarkup);
  });

  return html;
}

function renderLink(label, rawUrl, documentMeta) {
  const resolved = resolveLink(rawUrl, documentMeta);
  const safeLabel = renderInline(label, documentMeta);

  if (resolved.type === "route") {
    return `<a href="#doc=${escapeAttribute(resolved.docId)}">${safeLabel}</a>`;
  }

  if (!resolved.href) {
    return safeLabel;
  }

  const isExternal = /^(https?:|mailto:|tel:)/i.test(resolved.href);
  const target = isExternal ? ' target="_blank" rel="noreferrer noopener"' : "";
  return `<a href="${escapeAttribute(resolved.href)}"${target}>${safeLabel}</a>`;
}

function resolveLink(rawUrl, documentMeta) {
  const url = rawUrl.trim();
  if (!url) {
    return { href: "" };
  }

  if (/^(https?:|mailto:|tel:)/i.test(url)) {
    return { href: url };
  }

  if (url.startsWith("#")) {
    return { href: "" };
  }

  const [pathPart] = url.split("#");
  const normalizedRelativePath = normalizePath(
    resolveRelativePath(documentMeta.path, pathPart),
  );
  const documentForPath = state.documentsByPath.get(normalizedRelativePath);

  if (documentForPath) {
    return { type: "route", docId: documentForPath.id };
  }

  return { href: encodeURI(resolveRelativePath(documentMeta.path, url)) };
}

function resolveRelativePath(basePath, relativePath) {
  if (/^(\/|https?:|mailto:|tel:)/i.test(relativePath)) {
    return relativePath;
  }

  const baseSegments = basePath.split("/");
  baseSegments.pop();

  relativePath.split("/").forEach((segment) => {
    if (!segment || segment === ".") {
      return;
    }

    if (segment === "..") {
      baseSegments.pop();
      return;
    }

    baseSegments.push(segment);
  });

  return baseSegments.join("/");
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function escapeAttribute(value) {
  return escapeHtml(value).replace(/`/g, "&#96;");
}
