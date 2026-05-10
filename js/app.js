/* =========================================================================
   zirizima — app
   - Hash router with iOS-style page transitions
   - State (language, location, filter, rating)
   - Screen renderers (splash, language, permission, home, detail,
                       list, search, filter, rate)
   - "Take me there" hands off to Google Maps via universal URL

   Notes on safety: every dynamic string interpolated into markup is run
   through escapeHtml(). Markup application uses Range.createContextualFragment
   on trusted templates (no .innerHTML mutation).
   ========================================================================= */

(function (window, document) {
  'use strict';

  const { api, helpers, USER_LOCATION } = window.zirizimaData;
  const i18n = window.zirizimaI18n;
  const ICONS = window.zirizimaIcons;

  // -------------------------------------------------------------------
  // Markup helpers — parse trusted HTML strings without using innerHTML
  // -------------------------------------------------------------------
  let _range = null;
  function getRange() {
    if (!_range) {
      _range = document.createRange();
      _range.selectNodeContents(document.body || document.documentElement);
    }
    return _range;
  }

  // Replace element children with parsed markup
  function setMarkup(el, str) {
    while (el.firstChild) el.removeChild(el.firstChild);
    if (str) el.appendChild(getRange().createContextualFragment(str));
  }

  // Append parsed markup
  function appendMarkup(el, str) {
    if (str) el.appendChild(getRange().createContextualFragment(str));
  }

  // Parse markup string into a DOM fragment
  function fromMarkup(str) {
    return getRange().createContextualFragment(str);
  }

  // -------------------------------------------------------------------
  // Global state
  // -------------------------------------------------------------------
  const state = {
    language: 'en',
    locationGranted: false,
    userLocation: { ...USER_LOCATION },
    filter: {
      accessible: false,
      babyChange: false,
      open24h: false,
      englishSign: false
    },
    rate: {
      rating: 0,
      tags: new Set(),
      photo: false
    },
    saved: new Set(),
    routeHistory: [],
    currentRoute: null
  };

  // -------------------------------------------------------------------
  // Tiny utilities
  // -------------------------------------------------------------------
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
    }[c]));
  }

  function fmtDistance(m) {
    if (m < 1000) return m;
    return (m / 1000).toFixed(1);
  }

  function fmtDistanceUnit(m) {
    return m < 1000 ? 'm' : 'km';
  }

  function starsGlyph(rating) {
    const full = Math.round(rating);
    return '★★★★★'.slice(0, full) + '☆☆☆☆☆'.slice(0, 5 - full);
  }

  function activeFilterCount() {
    return Object.values(state.filter).filter(Boolean).length;
  }

  // -------------------------------------------------------------------
  // Router — hash-based with transition direction tracking
  // -------------------------------------------------------------------
  const ROUTE_DEPTH = {
    splash: 0,
    language: 1,
    permission: 2,
    home: 3,
    detail: 4,
    list: 4,
    search: 4,
    filter: 5,
    rate: 5
  };

  const MODAL_ROUTES = new Set(['filter']);

  function parseHash() {
    const raw = (window.location.hash || '#splash').replace(/^#/, '');
    const [name, ...args] = raw.split('/');
    return { name: name || 'splash', args };
  }

  function nav(hash) {
    if (window.location.hash === hash) {
      handleRouteChange(true);
    } else {
      window.location.hash = hash;
    }
  }

  function back() {
    if (state.routeHistory.length >= 2) {
      state.routeHistory.pop();
      const prev = state.routeHistory.pop();
      window.location.hash = prev;
    } else {
      window.location.hash = '#home';
    }
  }

  function decideTransition(from, to) {
    if (!from) return 'fade';
    if (MODAL_ROUTES.has(to.name)) return 'modal';
    if (MODAL_ROUTES.has(from.name) && !MODAL_ROUTES.has(to.name)) return 'modal-back';
    const fromDepth = ROUTE_DEPTH[from.name] ?? 0;
    const toDepth = ROUTE_DEPTH[to.name] ?? 0;
    if (toDepth > fromDepth) return 'forward';
    if (toDepth < fromDepth) return 'back';
    return 'fade';
  }

  function handleRouteChange(force = false) {
    const next = parseHash();
    const prev = state.currentRoute;

    if (!force && prev && prev.name === next.name && prev.args.join() === next.args.join()) return;

    const transition = decideTransition(prev, next);

    state.routeHistory.push(window.location.hash);
    if (state.routeHistory.length > 30) state.routeHistory.shift();

    state.currentRoute = next;
    renderScreen(next, transition);
  }

  // -------------------------------------------------------------------
  // Screen rendering with transitions
  // -------------------------------------------------------------------
  function renderScreen(route, transition) {
    const container = document.getElementById('screen-container');
    const oldScreen = container.querySelector('.screen.current');

    const newScreen = document.createElement('section');
    newScreen.className = 'screen';
    newScreen.dataset.route = route.name;

    if (transition === 'forward')        newScreen.classList.add('entering');
    else if (transition === 'back')      newScreen.classList.add('entering-back');
    else if (transition === 'modal')     newScreen.classList.add('entering-modal');
    else if (transition === 'modal-back')newScreen.classList.add('entering');
    else                                 newScreen.classList.add('entering-fade');

    renderScreenContent(route, newScreen);

    container.appendChild(newScreen);

    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        newScreen.classList.remove('entering', 'entering-back', 'entering-modal', 'entering-fade');
        newScreen.classList.add('current');

        if (oldScreen) {
          oldScreen.classList.remove('current');
          if (transition === 'forward')        oldScreen.classList.add('exiting');
          else if (transition === 'back')      oldScreen.classList.add('exiting-back');
          else if (transition === 'modal')     oldScreen.classList.add('exiting-fade');
          else if (transition === 'modal-back')oldScreen.classList.add('exiting-modal');
          else                                 oldScreen.classList.add('exiting-fade');

          let removed = false;
          const cleanup = () => {
            if (!removed) {
              removed = true;
              if (oldScreen._cleanup) try { oldScreen._cleanup(); } catch (e) {}
              oldScreen.remove();
            }
          };
          oldScreen.addEventListener('transitionend', cleanup, { once: true });
          setTimeout(cleanup, 600);
        }
      });
    });

    bindHandlers(route, newScreen);
  }

  function renderScreenContent(route, screenEl) {
    setMarkup(screenEl, '');
    switch (route.name) {
      case 'splash':     return setMarkup(screenEl, renderSplash());
      case 'language':   return setMarkup(screenEl, renderLanguage());
      case 'permission': return setMarkup(screenEl, renderPermission());
      case 'home':       return renderHome(screenEl);
      case 'detail':     return renderDetail(screenEl, route.args[0]);
      case 'list':       return renderList(screenEl);
      case 'search':     return renderSearch(screenEl);
      case 'filter':     return renderFilter(screenEl);
      case 'rate':       return renderRate(screenEl, route.args[0]);
      default:           return setMarkup(screenEl, renderSplash());
    }
  }

  // -------------------------------------------------------------------
  // SCREEN: Splash
  // -------------------------------------------------------------------
  function renderSplash() {
    return `
      <div class="splash">
        <div class="wordmark">zirizima.</div>
        <div class="accent-dot"></div>
        <div class="tagline">${escapeHtml(i18n.t('tagline'))}</div>
        <button class="pill" data-nav="#language">${escapeHtml(i18n.t('getStarted'))}</button>
      </div>
    `;
  }

  // -------------------------------------------------------------------
  // SCREEN: Language picker
  // -------------------------------------------------------------------
  function renderLanguage() {
    const items = i18n.languages.map((lang) => {
      const selected = lang === state.language;
      const tmp = i18n.current;
      i18n.set(lang);
      const name = i18n.t('langName');
      i18n.set(tmp);
      return `
        <div class="lang-item ${selected ? 'selected' : ''}" data-lang="${escapeHtml(lang)}">
          <span class="name">${escapeHtml(name)}</span>
          <span class="check">${selected ? '✓' : ''}</span>
        </div>
      `;
    }).join('');

    return `
      <div class="lang">
        <h1>${escapeHtml(i18n.t('chooseLanguage'))}</h1>
        <div class="sub">${escapeHtml(i18n.t('chooseLanguageSub'))}</div>
        <div class="lang-list">${items}</div>
        <button class="pill block" data-action="lang-continue">${escapeHtml(i18n.t('continue'))}</button>
      </div>
    `;
  }

  // -------------------------------------------------------------------
  // SCREEN: Permission
  // -------------------------------------------------------------------
  function renderPermission() {
    return `
      <div class="perm">
        <div class="perm-icon"><div class="pin"></div></div>
        <h1>${escapeHtml(i18n.t('findToilets'))}</h1>
        <p>${escapeHtml(i18n.t('findToiletsBody'))}</p>
        <div class="actions">
          <button class="pill block" data-action="grant-location">${escapeHtml(i18n.t('allowLocation'))}</button>
          <div class="tlink-row"><a class="tlink" data-nav="#home">${escapeHtml(i18n.t('maybeLater'))}</a></div>
        </div>
      </div>
    `;
  }

  // -------------------------------------------------------------------
  // SCREEN: Home
  // -------------------------------------------------------------------
  async function renderHome(screenEl) {
    setMarkup(screenEl, `<div class="home"><div class="topbar"><span class="word">zirizima.</span></div></div>`);
    const list = await api.getNearestToilets(state.userLocation.lat, state.userLocation.lng, 3, state.filter);
    const [hero, ...alts] = list;

    if (!hero) {
      setMarkup(screenEl, renderHomeEmpty());
      return;
    }

    const badges = renderBadges(hero);
    const altsHtml = alts.map((t) => `
      <div class="alt" data-nav="#detail/${escapeHtml(t.id)}">
        <div class="l">
          <div class="n">${escapeHtml(i18n.name(t.name))}</div>
          <div class="stars-line"><span class="stars-glyph">${starsGlyph(t.rating)}</span> ${t.rating.toFixed(1)} (${t.reviewCount})</div>
        </div>
        <div class="r">
          <div class="d">${fmtDistance(t.distanceMeters)}<span style="font-size:11px; color:var(--ink-48); margin-left:1px;">${fmtDistanceUnit(t.distanceMeters)}</span></div>
          <div class="t">${escapeHtml(i18n.t('minWalkOnly', { n: t.walkMinutes }))}</div>
        </div>
      </div>
    `).join('');

    setMarkup(screenEl, `
      <div class="home">
        <div class="topbar">
          <span class="word">zirizima.</span>
          <div class="topbar-right">
            <span class="lang-chip" data-nav="#language">${escapeHtml(state.language.toUpperCase())}</span>
            <button class="icon-chip" data-nav="#search" aria-label="search">${ICONS.search}</button>
          </div>
        </div>

        <div class="hero" data-nav="#detail/${escapeHtml(hero.id)}">
          <div class="label">${escapeHtml(i18n.t('nearestFreeToilet'))}</div>
          <div class="name">${escapeHtml(i18n.name(hero.name))}</div>
          <div class="dist-row">
            <span class="dist">${fmtDistance(hero.distanceMeters)}</span>
            <span class="dist-unit">${fmtDistanceUnit(hero.distanceMeters)}</span>
          </div>
          <div class="time">${escapeHtml(i18n.t('minWalk', { n: hero.walkMinutes }))} · ${escapeHtml(i18n.t('directionWord', { dir: i18n.direction(hero.direction) }))}</div>
          <div class="rating-row star-row">
            <span class="stars-glyph">${starsGlyph(hero.rating)}</span>
            <span class="num">${hero.rating.toFixed(1)}</span>
            <span class="cnt">(${hero.reviewCount} ${escapeHtml(i18n.t('reviews'))})</span>
          </div>
          ${badges ? `<div class="badges">${badges}</div>` : ''}
          <button class="pill" data-stop data-action="open-maps" data-lat="${hero.lat}" data-lng="${hero.lng}">→ ${escapeHtml(i18n.t('takeMeThere'))}</button>
        </div>

        ${alts.length > 0 ? `
          <div class="alts-label">${escapeHtml(i18n.t('alternatives'))}</div>
          ${altsHtml}
        ` : ''}

        <div class="home-bottom-nav">
          <div class="nav-btn on" data-nav="#home">
            ${ICONS.home}
            <span>${escapeHtml(i18n.t('home'))}</span>
          </div>
          <div class="nav-btn" data-nav="#list">
            ${ICONS.list}
            <span>${escapeHtml(i18n.t('browse'))}</span>
          </div>
          <div class="nav-btn" data-nav="#search">
            ${ICONS.search}
            <span>${escapeHtml(i18n.t('search'))}</span>
          </div>
        </div>
      </div>
    `);
  }

  function renderHomeEmpty() {
    return `
      <div class="home">
        <div class="topbar">
          <span class="word">zirizima.</span>
          <div class="topbar-right">
            <span class="lang-chip" data-nav="#language">${escapeHtml(state.language.toUpperCase())}</span>
          </div>
        </div>
        <div class="empty-state">
          <div class="glyph">○</div>
          <div class="title">${escapeHtml(i18n.t('noResults'))}</div>
          <div class="sub">${escapeHtml(i18n.t('tryAdjust'))}</div>
          <button class="pill compact" data-action="clear-filter">${escapeHtml(i18n.t('all'))}</button>
        </div>
      </div>
    `;
  }

  function renderBadges(t) {
    const parts = [];
    if (t.accessible)  parts.push(`<span class="badge">♿ ${escapeHtml(i18n.t('accessible'))}</span>`);
    if (t.babyChange)  parts.push(`<span class="badge">👶 ${escapeHtml(i18n.t('babyChange'))}</span>`);
    if (t.hours.is24h) parts.push(`<span class="badge">${escapeHtml(i18n.t('open24'))}</span>`);
    if (t.englishSign) parts.push(`<span class="badge">EN</span>`);
    return parts.join('');
  }

  // -------------------------------------------------------------------
  // SCREEN: Detail
  // -------------------------------------------------------------------
  async function renderDetail(screenEl, toiletId) {
    const t = await api.getToiletById(toiletId, state.userLocation.lat, state.userLocation.lng);
    if (!t) { setMarkup(screenEl, `<div class="empty-state">Not found</div>`); return; }
    const reviews = await api.getReviews(toiletId, 3);
    const isSaved = state.saved.has(toiletId);

    // Type-driven gradient (no photos in MVP)
    const TYPE_GRADIENTS = {
      subway:          'linear-gradient(135deg, #c8d6e5 0%, #a4c0d6 60%, #d6dee6 100%)',
      park:            'linear-gradient(135deg, #d6e8d4 0%, #b8d4b0 60%, #e3eee0 100%)',
      tourist_info:    'linear-gradient(135deg, #e0d4e8 0%, #c4b0d4 60%, #ede0e8 100%)',
      public_building: 'linear-gradient(135deg, #e6e8ea 0%, #c8ccd4 60%, #eef0f2 100%)',
      public:          'linear-gradient(135deg, #e8e4dc 0%, #d4c8b8 60%, #ede8de 100%)'
    };
    const bgGradient = TYPE_GRADIENTS[t.type] || TYPE_GRADIENTS.public;

    const typeLabelMap = {
      subway: 'typeSubway', park: 'typePark', public: 'typePublic',
      tourist_info: 'typeTouristInfo', public_building: 'typePublicBuilding'
    };
    const typeLabel = i18n.t(typeLabelMap[t.type] || '');

    const reviewsHtml = reviews.length === 0
      ? `<div class="review-empty">${escapeHtml(i18n.t('noReviewsYet'))}</div>`
      : reviews.map((r) => `
          <div class="review">
            <div class="head">
              <span class="author">${escapeHtml(r.author)} · ${escapeHtml(i18n.t('daysAgo', { n: r.daysAgo }))}</span>
              <span class="stars-glyph">${starsGlyph(r.rating)}</span>
            </div>
            ${r.comment ? `<div>${escapeHtml(r.comment)}</div>` : ''}
            ${r.tags && r.tags.length ? `<div class="review-tags">${r.tags.map(tag => `<span class="badge">${escapeHtml(tag.replace(/_/g, ' '))}</span>`).join('')}</div>` : ''}
          </div>
        `).join('');

    setMarkup(screenEl, `
      <div class="detail">
        <div class="detail-photo" style="background: ${bgGradient};">
          <div class="photo-controls">
            <button class="icon-btn" data-action="back" aria-label="back">${ICONS.chevronLeft}</button>
            <button class="icon-btn save-btn" data-action="toggle-save" data-toilet="${escapeHtml(t.id)}" aria-label="save">${isSaved ? ICONS.heartFilled : ICONS.heart}</button>
          </div>
        </div>

        <div class="detail-body">
          <div>
            <h1 class="detail-name">${escapeHtml(i18n.name(t.name))}</h1>
            <div class="detail-sub">
              ${fmtDistance(t.distanceMeters)}${fmtDistanceUnit(t.distanceMeters)} · ${escapeHtml(i18n.t('minWalk', { n: t.walkMinutes }))} · ${escapeHtml(typeLabel)}
            </div>
          </div>

          <div class="star-row" style="font-size:14px;">
            <span class="stars-glyph">${starsGlyph(t.rating)}</span>
            <span class="num">${t.rating.toFixed(1)}</span>
            <span class="cnt">${t.reviewCount} ${escapeHtml(i18n.t('reviews'))}</span>
          </div>

          <div class="detail-grid">
            <div class="info-cell">
              <div class="k">${escapeHtml(i18n.t('hours'))}</div>
              <div class="v">${t.hours.is24h ? escapeHtml(i18n.t('open24')) : escapeHtml(t.hours.open + ' – ' + t.hours.close)}</div>
            </div>
            <div class="info-cell">
              <div class="k">${escapeHtml(i18n.t('accessible'))}</div>
              <div class="v">${t.accessible ? '♿ ' + escapeHtml(i18n.t('yes')) : escapeHtml(i18n.t('no'))}</div>
            </div>
            <div class="info-cell">
              <div class="k">${escapeHtml(i18n.t('babyChange'))}</div>
              <div class="v">${t.babyChange ? '👶 ' + escapeHtml(i18n.t('yes')) : escapeHtml(i18n.t('no'))}</div>
            </div>
            <div class="info-cell">
              <div class="k">${escapeHtml(i18n.t('paper'))}</div>
              <div class="v">${t.paper ? escapeHtml(i18n.t('provided')) : escapeHtml(i18n.t('notProvided'))}</div>
            </div>
          </div>

          <div class="review-section">
            <div class="alts-label" style="padding: 0;">${escapeHtml(i18n.t('recentReviews'))}</div>
            ${reviewsHtml}
          </div>
        </div>

        <div class="detail-cta">
          <button class="pill flex-1" data-action="open-maps" data-lat="${t.lat}" data-lng="${t.lng}">→ ${escapeHtml(i18n.t('takeMeThere'))}</button>
          <button class="pill ghost flex-1" data-nav="#rate/${escapeHtml(t.id)}">${escapeHtml(i18n.t('rate'))}</button>
        </div>
      </div>
    `);

    // Render reviews asynchronously below the static info
    const reviewsAnchor = screenEl.querySelector('.review-section');
    if (reviewsAnchor && reviews.length > 0) {
      // already rendered above via reviewsHtml, no extra work needed
    }
  }

  // -------------------------------------------------------------------
  // Google Maps handoff — "Take me there" opens Google Maps with walking
  // directions. On mobile, the universal URL launches the Google Maps app
  // if installed; otherwise it opens in a browser tab. iOS native version
  // will use the same URL via UIApplication.shared.open().
  // -------------------------------------------------------------------
  function buildMapsUrl(origin, dest) {
    const params = new URLSearchParams({
      api: '1',
      destination: `${dest.lat},${dest.lng}`,
      travelmode: 'walking'
    });
    if (origin && Number.isFinite(origin.lat) && Number.isFinite(origin.lng)) {
      params.set('origin', `${origin.lat},${origin.lng}`);
    }
    return `https://www.google.com/maps/dir/?${params.toString()}`;
  }

  function openInGoogleMapsAt(lat, lng) {
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return false;
    const url = buildMapsUrl(state.userLocation, { lat, lng });
    // Synchronous window.open from a user gesture — popup blockers allow it.
    window.open(url, '_blank', 'noopener,noreferrer');
    return true;
  }

  // -------------------------------------------------------------------
  // SCREEN: List view
  // -------------------------------------------------------------------
  async function renderList(screenEl) {
    const list = await api.getAllToilets(state.userLocation.lat, state.userLocation.lng, state.filter);

    const chipsHtml = `
      <div class="filter-chips">
        <span class="chip ${activeFilterCount() === 0 ? 'on' : ''}" data-action="clear-filter">${escapeHtml(i18n.t('all'))}</span>
        <span class="chip ${state.filter.accessible ? 'on' : ''}" data-toggle-filter="accessible">♿</span>
        <span class="chip ${state.filter.babyChange ? 'on' : ''}" data-toggle-filter="babyChange">👶</span>
        <span class="chip ${state.filter.open24h ? 'on' : ''}" data-toggle-filter="open24h">🌙 ${escapeHtml(i18n.t('open24'))}</span>
        <span class="chip ${state.filter.englishSign ? 'on' : ''}" data-toggle-filter="englishSign">EN</span>
        <span class="chip" data-nav="#filter">${escapeHtml(i18n.t('filter'))}${activeFilterCount() > 0 ? ' (' + activeFilterCount() + ')' : ''}</span>
      </div>
    `;

    const rowsHtml = list.length === 0
      ? `<div class="empty-state">
           <div class="glyph">○</div>
           <div class="title">${escapeHtml(i18n.t('noResults'))}</div>
           <div class="sub">${escapeHtml(i18n.t('tryAdjust'))}</div>
         </div>`
      : list.map((t) => `
          <div class="list-row" data-nav="#detail/${escapeHtml(t.id)}">
            <div>
              <div class="name">${escapeHtml(i18n.name(t.name))}</div>
              <div class="stars-line"><span class="stars-glyph">${starsGlyph(t.rating)}</span> ${t.rating.toFixed(1)} (${t.reviewCount})</div>
              <div class="badges-line">${renderBadges(t)}</div>
            </div>
            <div class="right">
              <div class="d">${fmtDistance(t.distanceMeters)}<span style="font-size:11px; color:var(--ink-48); margin-left:1px;">${fmtDistanceUnit(t.distanceMeters)}</span></div>
              <div class="t">${escapeHtml(i18n.t('minWalkOnly', { n: t.walkMinutes }))}</div>
            </div>
          </div>
        `).join('');

    setMarkup(screenEl, `
      <div class="list">
        <div class="subnav" style="padding-top: 14px;">
          <div class="row">
            <span class="title">${escapeHtml(i18n.t('nearby'))}</span>
            <span class="seg">
              <button data-action="back">${escapeHtml(i18n.t('map'))}</button>
              <button class="on">${escapeHtml(i18n.t('list'))}</button>
            </span>
          </div>
          ${chipsHtml}
        </div>
        <div class="list-body">${rowsHtml}</div>
      </div>
    `);
  }

  // -------------------------------------------------------------------
  // SCREEN: Search by area
  // -------------------------------------------------------------------
  async function renderSearch(screenEl) {
    const areas = await api.searchAreas('');

    function buildRows(query, results) {
      const header = (query && results.length > 0) ? '' : `<div class="alts-label" style="padding: 0;">${escapeHtml(i18n.t('popularAreas'))}</div>`;
      const rows = results.map((a) => `
        <div class="list-row" data-area="${escapeHtml(a.id)}">
          <div>
            <div class="name">${escapeHtml(i18n.name(a.name))}</div>
            <div class="stars-line">${escapeHtml(i18n.t('nToilets', { n: a.count }))}</div>
          </div>
          <div class="right" style="color: var(--primary); font-size: 18px; align-self: center;">›</div>
        </div>
      `).join('');
      return header + rows;
    }

    setMarkup(screenEl, `
      <div class="search">
        <div class="subnav" style="padding-top: 14px;">
          <div class="row">
            <span class="title">${escapeHtml(i18n.t('search'))}</span>
            <button class="icon-btn" data-action="back" style="background: var(--parchment);">${ICONS.close}</button>
          </div>
          <div class="search-input-wrap">
            ${ICONS.search}
            <input class="search-input" type="text" id="search-input" placeholder="${escapeHtml(i18n.t('searchPlaceholder'))}" autocomplete="off" />
            <span class="search-clear" id="search-clear" style="display:none;">✕</span>
          </div>
        </div>
        <div class="search-body" id="search-body">${buildRows('', areas)}</div>
      </div>
    `);

    const input = screenEl.querySelector('#search-input');
    const clear = screenEl.querySelector('#search-clear');
    const body = screenEl.querySelector('#search-body');

    async function update(query) {
      clear.style.display = query ? 'inline' : 'none';
      const results = await api.searchAreas(query);
      if (results.length === 0) {
        setMarkup(body, `<div class="empty-state"><div class="glyph">○</div><div class="title">${escapeHtml(i18n.t('noResults'))}</div></div>`);
      } else {
        setMarkup(body, buildRows(query, results));
      }
    }

    input.addEventListener('input', (e) => update(e.target.value));
    clear.addEventListener('click', () => { input.value = ''; update(''); input.focus(); });
  }

  // -------------------------------------------------------------------
  // SCREEN: Filter (modal sheet)
  // -------------------------------------------------------------------
  async function renderFilter(screenEl) {
    const count = await api.filterCount(state.userLocation.lat, state.userLocation.lng, state.filter);

    const row = (key, name, sub, icon) => `
      <div class="filter-row" data-toggle-filter="${escapeHtml(key)}">
        <div class="l">
          <div class="icon-square">${escapeHtml(icon)}</div>
          <div>
            <div class="name">${escapeHtml(name)}</div>
            <div class="sub">${escapeHtml(sub)}</div>
          </div>
        </div>
        <div class="toggle ${state.filter[key] ? 'on' : ''}"></div>
      </div>
    `;

    setMarkup(screenEl, `
      <div class="filter-screen">
        <div class="scrim" data-action="back"></div>
        <div class="filter-sheet">
          <div class="sheet-grabber"></div>
          <h2>${escapeHtml(i18n.t('filter'))}</h2>
          <div>
            ${row('accessible',  i18n.t('wheelchairAccessible'), i18n.t('wheelchairAccessibleSub'), '♿')}
            ${row('babyChange',  i18n.t('babyChanging'),         i18n.t('babyChangingSub'),         '👶')}
            ${row('open24h',     i18n.t('open24hours'),          i18n.t('open24hoursSub'),          '🌙')}
            ${row('englishSign', i18n.t('englishSignage'),       i18n.t('englishSignageSub'),       'EN')}
          </div>
          <button class="pill block" data-action="apply-filter">
            ${escapeHtml(count === 1 ? i18n.t('showNToilet', { n: count }) : i18n.t('showNToilets', { n: count }))}
          </button>
        </div>
      </div>
    `);
  }

  // -------------------------------------------------------------------
  // SCREEN: Rate
  // -------------------------------------------------------------------
  async function renderRate(screenEl, toiletId) {
    state.rate = { rating: 0, tags: new Set(), comment: '' };
    const t = await api.getToiletById(toiletId, state.userLocation.lat, state.userLocation.lng);
    if (!t) { setMarkup(screenEl, `<div class="empty-state">Not found</div>`); return; }

    const tagOptions = [
      { key: 'clean',          label: i18n.t('tagClean') },
      { key: 'spacious',       label: i18n.t('tagSpacious') },
      { key: 'quiet',          label: i18n.t('tagQuiet') },
      { key: 'busy',           label: i18n.t('tagBusy') },
      { key: 'english_signs',  label: i18n.t('tagEnglishSigns') },
      { key: 'has_paper',      label: i18n.t('tagHasPaper') },
      { key: 'dirty',          label: i18n.t('tagDirty') }
    ];

    setMarkup(screenEl, `
      <div class="rate">
        <div class="rate-top">
          <span class="x" data-action="back">✕</span>
          <span class="skip" data-action="back">${escapeHtml(i18n.t('skip'))}</span>
        </div>
        <div class="rate-name-eyebrow">${escapeHtml(i18n.t('ratingThisToilet'))}</div>
        <div class="rate-name-real">${escapeHtml(i18n.name(t.name))}</div>

        <div class="rate-stars">
          ${[1,2,3,4,5].map(n => `<span class="rate-star" data-star="${n}">★</span>`).join('')}
        </div>
        <div class="rate-q">${escapeHtml(i18n.t('howWasIt'))}</div>

        <div class="tag-grid">
          ${tagOptions.map(o => `<span class="tag" data-tag="${escapeHtml(o.key)}">${escapeHtml(o.label)}</span>`).join('')}
        </div>

        <textarea class="rate-comment" maxlength="280" placeholder="${escapeHtml(i18n.t('commentPlaceholder'))}"></textarea>

        <button class="pill block rate-submit" disabled data-action="submit-rating" data-toilet="${escapeHtml(toiletId)}">${escapeHtml(i18n.t('submit'))}</button>
      </div>
    `);

    function reflectRateState() {
      const stars = screenEl.querySelectorAll('.rate-star');
      stars.forEach((s, i) => s.classList.toggle('on', i < state.rate.rating));
      const tags = screenEl.querySelectorAll('.tag');
      tags.forEach((tg) => tg.classList.toggle('on', state.rate.tags.has(tg.dataset.tag)));
      const submit = screenEl.querySelector('.rate-submit');
      if (submit) submit.disabled = state.rate.rating === 0;
    }

    screenEl.addEventListener('click', (e) => {
      const star = e.target.closest('.rate-star');
      if (star) {
        state.rate.rating = parseInt(star.dataset.star, 10);
        reflectRateState();
        return;
      }
      const tag = e.target.closest('.tag');
      if (tag) {
        const k = tag.dataset.tag;
        if (state.rate.tags.has(k)) state.rate.tags.delete(k);
        else state.rate.tags.add(k);
        reflectRateState();
      }
    });

    const commentEl = screenEl.querySelector('.rate-comment');
    if (commentEl) commentEl.addEventListener('input', (e) => {
      state.rate.comment = e.target.value;
    });
  }

  // -------------------------------------------------------------------
  // Toast
  // -------------------------------------------------------------------
  function showToast(text) {
    const container = document.getElementById('screen-container');
    const fragment = fromMarkup(`<div class="toast">${escapeHtml(text)}</div>`);
    const toastEl = fragment.firstElementChild;
    container.appendChild(toastEl);
    setTimeout(() => toastEl.remove(), 2200);
  }

  // -------------------------------------------------------------------
  // Event delegation per screen
  // -------------------------------------------------------------------
  function bindHandlers(route, screenEl) {
    screenEl.addEventListener('click', async (e) => {
      // [data-stop] support — primary CTA inside a tappable card swallows the parent nav
      const stopEl = e.target.closest('[data-stop]');
      if (stopEl) e.stopPropagation();

      // Nav links
      const navTarget = e.target.closest('[data-nav]');
      if (navTarget) {
        e.preventDefault();
        nav(navTarget.dataset.nav);
        return;
      }

      // Filter chip toggles
      const filterChip = e.target.closest('[data-toggle-filter]');
      if (filterChip) {
        const k = filterChip.dataset.toggleFilter;
        state.filter[k] = !state.filter[k];
        if (route.name === 'filter' || route.name === 'list' || route.name === 'home') {
          renderScreenContent(route, screenEl);
        }
        return;
      }

      // Area pick
      const areaTarget = e.target.closest('[data-area]');
      if (areaTarget) {
        const areaId = areaTarget.dataset.area;
        const area = window.zirizimaData.AREAS.find((a) => a.id === areaId);
        if (area) {
          state.userLocation = { lat: area.lat, lng: area.lng };
          showToast(i18n.name(area.name));
          nav('#home');
        }
        return;
      }

      // Action handlers
      const actionEl = e.target.closest('[data-action]');
      if (actionEl) {
        const action = actionEl.dataset.action;
        switch (action) {
          case 'back':
            if (screenEl._cleanup) try { screenEl._cleanup(); } catch (_) {}
            back();
            break;

          case 'lang-continue': {
            const selected = screenEl.querySelector('.lang-item.selected');
            if (selected) {
              state.language = selected.dataset.lang;
              i18n.set(state.language);
            }
            if (state.locationGranted) nav('#home');
            else nav('#permission');
            break;
          }

          case 'grant-location':
            // Real production: navigator.geolocation.getCurrentPosition(...)
            state.locationGranted = true;
            nav('#home');
            break;

          case 'apply-filter':
            back();
            break;

          case 'clear-filter':
            state.filter = { accessible: false, babyChange: false, open24h: false, englishSign: false };
            renderScreenContent(route, screenEl);
            break;

          case 'toggle-save': {
            const id = actionEl.dataset.toilet;
            if (state.saved.has(id)) state.saved.delete(id);
            else state.saved.add(id);
            setMarkup(actionEl, state.saved.has(id) ? ICONS.heartFilled : ICONS.heart);
            break;
          }

          case 'open-maps': {
            // Synchronous handoff to Google Maps — must run inside the user
            // gesture, so no awaits before window.open().
            const lat = parseFloat(actionEl.dataset.lat);
            const lng = parseFloat(actionEl.dataset.lng);
            const opened = openInGoogleMapsAt(lat, lng);
            if (opened) showToast(i18n.t('openingMaps'));
            break;
          }

          case 'submit-rating': {
            const id = actionEl.dataset.toilet;
            const originalLabel = actionEl.textContent;
            actionEl.disabled = true;
            actionEl.textContent = i18n.t('submitting');
            try {
              await api.submitRating(id, state.rate.rating, [...state.rate.tags], state.rate.comment);
              showToast(i18n.t('thanks'));
              setTimeout(() => back(), 600);
            } catch (err) {
              const isRateLimit = String(err && err.message || '').includes('rate_limit_exceeded');
              showToast(isRateLimit ? i18n.t('rateLimit') : i18n.t('submitFailed'));
              actionEl.disabled = false;
              actionEl.textContent = originalLabel;
            }
            break;
          }
        }
        return;
      }

      // Language item selection
      if (route.name === 'language') {
        const langItem = e.target.closest('.lang-item');
        if (langItem) {
          screenEl.querySelectorAll('.lang-item').forEach((el) => {
            el.classList.remove('selected');
            const ck = el.querySelector('.check'); if (ck) ck.textContent = '';
          });
          langItem.classList.add('selected');
          const ck = langItem.querySelector('.check'); if (ck) ck.textContent = '✓';
        }
      }
    });
  }

  // -------------------------------------------------------------------
  // Boot
  // -------------------------------------------------------------------
  function boot() {
    const browserLang = (navigator.language || 'en').slice(0, 2);
    if (['en', 'ko', 'zh', 'ja'].includes(browserLang)) {
      state.language = browserLang;
      i18n.set(browserLang);
    }

    if (!window.location.hash) {
      window.location.hash = '#splash';
    } else {
      handleRouteChange();
    }

    window.addEventListener('hashchange', () => handleRouteChange());
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})(window, document);
