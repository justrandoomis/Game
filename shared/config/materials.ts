/** Filament materials and the colour palette spools come in. */

import type { ColorId, MaterialId } from '../types';

export interface Material {
  id: MaterialId;
  name: string;
  /** Coins per 1000 g spool. */
  pricePerSpool: number;
  spoolSize: number;
  /** 0..100. Feeds into failure odds and delivered quality. */
  baseQuality: number;
  /** Multiplier on print duration. Engineering materials print slower. */
  timeFactor: number;
  /** Added failure probability — ABS warps, TPU is fussy. */
  difficulty: number;
  /** Player level at which the shop stocks it. */
  unlockLevel: number;
  /** Swatch used for the material chip. */
  tint: string;
}

export const MATERIALS: Material[] = [
  { id: 'pla',  name: 'PLA',  pricePerSpool: 120, spoolSize: 1000, baseQuality: 70, timeFactor: 1.0,  difficulty: 0.00, unlockLevel: 1,  tint: '#4FBF7F' },
  { id: 'petg', name: 'PETG', pricePerSpool: 175, spoolSize: 1000, baseQuality: 76, timeFactor: 1.15, difficulty: 0.02, unlockLevel: 4,  tint: '#3FA9D6' },
  { id: 'tpu',  name: 'TPU',  pricePerSpool: 240, spoolSize: 1000, baseQuality: 68, timeFactor: 1.55, difficulty: 0.06, unlockLevel: 8,  tint: '#F2A03D' },
  { id: 'abs',  name: 'ABS',  pricePerSpool: 200, spoolSize: 1000, baseQuality: 74, timeFactor: 1.2,  difficulty: 0.07, unlockLevel: 12, tint: '#E4685D' },
  { id: 'asa',  name: 'ASA',  pricePerSpool: 265, spoolSize: 1000, baseQuality: 80, timeFactor: 1.25, difficulty: 0.06, unlockLevel: 16, tint: '#B07BD6' },
  { id: 'pa',   name: 'PA / Nylon', pricePerSpool: 420, spoolSize: 1000, baseQuality: 84, timeFactor: 1.4, difficulty: 0.09, unlockLevel: 22, tint: '#7E8AA3' },
  { id: 'pc',   name: 'PC',   pricePerSpool: 520, spoolSize: 1000, baseQuality: 88, timeFactor: 1.45, difficulty: 0.10, unlockLevel: 28, tint: '#5C6BC0' },
  { id: 'cf',   name: 'CF Composite', pricePerSpool: 760, spoolSize: 1000, baseQuality: 93, timeFactor: 1.5, difficulty: 0.08, unlockLevel: 34, tint: '#3D4450' },
];

export interface FilamentColor {
  id: ColorId;
  name: string;
  hex: string;
  /** Darker edge used for the spool's shaded side. */
  shade: string;
}

export const COLORS: FilamentColor[] = [
  { id: 'white',  name: 'White',  hex: '#F5F7FA', shade: '#D3D9E2' },
  { id: 'black',  name: 'Black',  hex: '#3A3F49', shade: '#23262D' },
  { id: 'gray',   name: 'Gray',   hex: '#9AA4B2', shade: '#77808C' },
  { id: 'red',    name: 'Red',    hex: '#EF5B52', shade: '#C33F38' },
  { id: 'orange', name: 'Orange', hex: '#F79B3E', shade: '#CE7723' },
  { id: 'yellow', name: 'Yellow', hex: '#F6CE4B', shade: '#CFA524' },
  { id: 'green',  name: 'Green',  hex: '#54C98A', shade: '#36A268' },
  { id: 'blue',   name: 'Blue',   hex: '#4EA8DE', shade: '#2E82B4' },
  { id: 'purple', name: 'Purple', hex: '#A97BD6', shade: '#8355AE' },
];

export const MATERIAL_BY_ID = new Map(MATERIALS.map((m) => [m.id, m]));
export const COLOR_BY_ID = new Map(COLORS.map((c) => [c.id, c]));
