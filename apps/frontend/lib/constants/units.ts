// Single source of truth for the raw-material / packaging unit-of-measure
// list, so every dropdown in the app that lets someone pick a unit stays
// in sync instead of each form hardcoding (and drifting from) its own
// option list.
//
// If the client needs a different/extra unit, add it here once and it
// shows up everywhere UNIT_OPTIONS is used.
export type UnitOption = {
  value: string;
  label: string;
};

export const UNIT_OPTIONS: UnitOption[] = [
  { value: "kg", label: "kg" },
  { value: "g", label: "g" },
  { value: "litre", label: "litre" },
  { value: "ml", label: "ml" },
  { value: "piece", label: "piece" },
  { value: "dozen", label: "dozen" },
  { value: "box", label: "box" },
  { value: "packet", label: "packet" },
  { value: "bag", label: "bag" },
];
