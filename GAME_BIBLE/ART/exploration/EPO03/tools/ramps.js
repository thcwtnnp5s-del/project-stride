// ramps.js — the ART-13 material ledger, as data. Shadow -> base -> mid ->
// highlight -> fleck. Nothing here is invented: every hex is copied from
// MILESTONES/evidence/FMPO02/wave1/ART-13_material_brief.md section 1 and 2, and
// the chassis ramp from PIXELLAB_UI_PRODUCTION_PLAN section 6.
'use strict';

const SURFACE = {
  journal_leaf: ['#1C1811', '#241F17', '#332B1F', '#463A28', '#5C4C34'],
  oilcloth:     ['#1A1C15', '#23261B', '#333524', '#464A31', '#5B5E3F'],
  buckram:      ['#1D1912', '#26211A', '#362E22', '#4B4030', '#61533E'],
  leather:      ['#1B1310', '#241914', '#3A2620', '#54372C', '#6C4736'],
  bench_oak:    ['#160F0A', '#1E140E', '#2E2015', '#43301F', '#5A4229'],
  steel:        ['#14161A', '#1C1F24', '#2B2F36', '#3E434C', '#535A63'],
  slate:        ['#15161A', '#1E2024', '#2C2F34', '#3F444A', '#565B60'],
  chart_vellum: ['#1A1712', '#23201A', '#332E25', '#463F32', '#5A5142'],
  cork:         ['#1C170F', '#26201A', '#372E22', '#4C4130', '#63533D'],
  plan_linen:   ['#12161C', '#1A2028', '#28323E', '#3B4A58', '#4E6072'],
};

// Production plan section 6. The frame/ornament/glyph ramp.
const CHASSIS = ['#0F0D0B', '#33291F', '#4A3B2B', '#6B5A3E', '#7C6A4A'];

// ART-13 section 2 button ramps: shadow / mid / sheen / edge.
const BUTTON = {
  leather_primary: ['#241F18', '#3A332B', '#4A4034', '#6B5A3E'],
  steel_secondary: ['#1E222A', '#2E3440', '#3E4A5C', '#5A6B80'],
  oxblood_danger:  ['#2E1614', '#4A211E', '#68302A', '#7A4238'],
  moss_ready:      ['#20281A', '#324226', '#465C33', '#5E7842'],
  bluesteel_brace: ['#1C2130', '#2A3348', '#3A4268', '#4E5C86'],
  wood_eat:        ['#1A120C', '#2A1D12', '#3E2C1B', '#5A4128'],
};

module.exports = { SURFACE, CHASSIS, BUTTON };
