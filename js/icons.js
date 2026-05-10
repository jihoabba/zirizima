/* =========================================================================
   zirizima — inline SVG icons (Apple-style stroke 1.6)
   ========================================================================= */

(function (window) {
  'use strict';

  // Common stroke style: 1.6px, round, currentColor
  const SW = 'fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"';

  const ICONS = {
    chevronLeft:  `<svg viewBox="0 0 20 20" ${SW}><polyline points="13,4 7,10 13,16"/></svg>`,
    chevronRight: `<svg viewBox="0 0 20 20" ${SW}><polyline points="7,4 13,10 7,16"/></svg>`,
    close:        `<svg viewBox="0 0 20 20" ${SW}><line x1="5" y1="5" x2="15" y2="15"/><line x1="15" y1="5" x2="5" y2="15"/></svg>`,
    heart:        `<svg viewBox="0 0 20 20" ${SW}><path d="M10 17 C 4 13, 2 9, 2 6.5 A 3.5 3.5 0 0 1 10 5 A 3.5 3.5 0 0 1 18 6.5 C 18 9, 16 13, 10 17 Z"/></svg>`,
    heartFilled:  `<svg viewBox="0 0 20 20" fill="currentColor" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M10 17 C 4 13, 2 9, 2 6.5 A 3.5 3.5 0 0 1 10 5 A 3.5 3.5 0 0 1 18 6.5 C 18 9, 16 13, 10 17 Z"/></svg>`,
    search:       `<svg viewBox="0 0 20 20" ${SW}><circle cx="9" cy="9" r="5.5"/><line x1="13" y1="13" x2="17" y2="17"/></svg>`,
    pin:          `<svg viewBox="0 0 20 20" ${SW}><path d="M10 2 C 6 2, 4 5, 4 8 C 4 12, 10 18, 10 18 C 10 18, 16 12, 16 8 C 16 5, 14 2, 10 2 Z"/><circle cx="10" cy="8" r="2.2"/></svg>`,
    home:         `<svg viewBox="0 0 20 20" ${SW}><polyline points="3,9 10,3 17,9"/><path d="M5 9 V 16 H 15 V 9"/></svg>`,
    list:         `<svg viewBox="0 0 20 20" ${SW}><line x1="6" y1="5" x2="17" y2="5"/><line x1="6" y1="10" x2="17" y2="10"/><line x1="6" y1="15" x2="17" y2="15"/><circle cx="3.5" cy="5" r="0.8" fill="currentColor"/><circle cx="3.5" cy="10" r="0.8" fill="currentColor"/><circle cx="3.5" cy="15" r="0.8" fill="currentColor"/></svg>`,
    star:         `<svg viewBox="0 0 20 20" fill="currentColor"><path d="M10 1.5 L 12.36 7.06 L 18.4 7.69 L 13.86 11.71 L 15.18 17.65 L 10 14.43 L 4.82 17.65 L 6.14 11.71 L 1.6 7.69 L 7.64 7.06 Z"/></svg>`,
    starOutline:  `<svg viewBox="0 0 20 20" ${SW}><path d="M10 1.5 L 12.36 7.06 L 18.4 7.69 L 13.86 11.71 L 15.18 17.65 L 10 14.43 L 4.82 17.65 L 6.14 11.71 L 1.6 7.69 L 7.64 7.06 Z"/></svg>`,
    arrow:        `<svg viewBox="0 0 20 20" ${SW}><line x1="10" y1="17" x2="10" y2="4"/><polyline points="5,9 10,4 15,9"/></svg>`,
    plus:         `<svg viewBox="0 0 20 20" ${SW}><line x1="10" y1="4" x2="10" y2="16"/><line x1="4" y1="10" x2="16" y2="10"/></svg>`,
    settings:     `<svg viewBox="0 0 20 20" ${SW}><circle cx="10" cy="10" r="2.5"/><line x1="10" y1="2" x2="10" y2="4.5"/><line x1="10" y1="15.5" x2="10" y2="18"/><line x1="2" y1="10" x2="4.5" y2="10"/><line x1="15.5" y1="10" x2="18" y2="10"/><line x1="4.3" y1="4.3" x2="6.1" y2="6.1"/><line x1="13.9" y1="13.9" x2="15.7" y2="15.7"/><line x1="4.3" y1="15.7" x2="6.1" y2="13.9"/><line x1="13.9" y1="6.1" x2="15.7" y2="4.3"/></svg>`,
    direction:    `<svg viewBox="0 0 20 20" ${SW}><polygon points="10,2 16,18 10,14 4,18" fill="currentColor"/></svg>`,
    accessible:   `<svg viewBox="0 0 20 20" ${SW}><circle cx="10" cy="4.5" r="1.6"/><path d="M8 8 L 8 12 L 12 12 L 14 16"/><path d="M8 12 C 5.5 12, 4 13.5, 4 15.5 C 4 17.5, 5.5 19, 7.5 19 C 9.5 19, 11 17.5, 11 16"/></svg>`,
    baby:         `<svg viewBox="0 0 20 20" ${SW}><circle cx="10" cy="6" r="3"/><path d="M5 17 C 5 13, 7 11, 10 11 C 13 11, 15 13, 15 17"/></svg>`,
    moon:         `<svg viewBox="0 0 20 20" ${SW}><path d="M16 12 A 6 6 0 1 1 8 4 A 5 5 0 0 0 16 12 Z"/></svg>`,
    globe:        `<svg viewBox="0 0 20 20" ${SW}><circle cx="10" cy="10" r="7"/><line x1="3" y1="10" x2="17" y2="10"/><path d="M10 3 C 7 6, 7 14, 10 17 C 13 14, 13 6, 10 3"/></svg>`,
    camera:       `<svg viewBox="0 0 20 20" ${SW}><path d="M3 7 L 6 7 L 7 5 L 13 5 L 14 7 L 17 7 V 16 H 3 Z"/><circle cx="10" cy="11.5" r="3.2"/></svg>`,
    check:        `<svg viewBox="0 0 20 20" ${SW}><polyline points="4,11 8,15 16,5"/></svg>`
  };

  window.zirizimaIcons = ICONS;
})(window);
