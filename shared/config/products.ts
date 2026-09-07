/** Printable products — what customers order and what the store sells. */

import type { MaterialId, ProductId } from '../types';

export type ProductCategory =
  | 'decor'
  | 'functional'
  | 'accessory'
  | 'miniature'
  | 'storage'
  | 'mechanical'
  | 'multicolor';

export interface Product {
  id: ProductId;
  name: string;
  category: ProductCategory;
  /** Grams of filament for a single unit. */
  grams: number;
  /** Minutes to print one unit on a baseline (speed 1.0) machine. */
  minutes: number;
  /** 1..5. Raises failure odds and reward. */
  complexity: number;
  /** Materials that make sense for this part. */
  materials: MaterialId[];
  /** Base coins the in-game store sells one unit for. */
  salePrice: number;
  /** Player level at which it starts appearing. */
  unlockLevel: number;
  /** Sprite key for the little model on the build plate. */
  icon: string;
  /** Needs a multicolor-capable machine. */
  multicolor?: boolean;
}

export const PRODUCTS: Product[] = [
  { id: 'keychain',    name: 'Keychain',        category: 'accessory',  grams: 8,   minutes: 22,  complexity: 1, materials: ['pla', 'petg'],                 salePrice: 34,   unlockLevel: 1,  icon: 'keychain' },
  { id: 'mini_dino',   name: 'Mini Dinosaur',   category: 'decor',      grams: 26,  minutes: 68,  complexity: 2, materials: ['pla'],                         salePrice: 85,   unlockLevel: 1,  icon: 'dino' },
  { id: 'phone_stand', name: 'Phone Stand',     category: 'functional', grams: 42,  minutes: 96,  complexity: 2, materials: ['pla', 'petg', 'abs'],          salePrice: 120,  unlockLevel: 1,  icon: 'stand' },
  { id: 'plant_pot',   name: 'Plant Pot',       category: 'decor',      grams: 58,  minutes: 130, complexity: 2, materials: ['pla', 'petg'],                 salePrice: 150,  unlockLevel: 2,  icon: 'pot' },
  { id: 'cable_clip',  name: 'Cable Clip',      category: 'accessory',  grams: 6,   minutes: 15,  complexity: 1, materials: ['pla', 'petg', 'tpu'],          salePrice: 26,   unlockLevel: 2,  icon: 'clip' },
  { id: 'desk_tray',   name: 'Desk Organizer',  category: 'storage',    grams: 96,  minutes: 205, complexity: 3, materials: ['pla', 'petg', 'abs'],          salePrice: 260,  unlockLevel: 4,  icon: 'tray' },
  { id: 'benchy',      name: 'Test Boat',       category: 'miniature',  grams: 14,  minutes: 44,  complexity: 2, materials: ['pla', 'petg'],                 salePrice: 52,   unlockLevel: 4,  icon: 'boat' },
  { id: 'bracket',     name: 'Wall Bracket',    category: 'mechanical', grams: 54,  minutes: 118, complexity: 3, materials: ['petg', 'abs', 'asa', 'pa'],    salePrice: 185,  unlockLevel: 6,  icon: 'bracket' },
  { id: 'figurine',    name: 'Character Figure',category: 'miniature',  grams: 34,  minutes: 165, complexity: 4, materials: ['pla', 'abs'],                  salePrice: 210,  unlockLevel: 7,  icon: 'figure' },
  { id: 'storage_bin', name: 'Storage Bin',     category: 'storage',    grams: 148, minutes: 290, complexity: 3, materials: ['pla', 'petg', 'abs'],          salePrice: 340,  unlockLevel: 9,  icon: 'bin' },
  { id: 'gear_set',    name: 'Gear Set',        category: 'mechanical', grams: 72,  minutes: 210, complexity: 4, materials: ['petg', 'abs', 'pa', 'pc'],     salePrice: 320,  unlockLevel: 11, icon: 'gear' },
  { id: 'phone_case',  name: 'Flexible Case',   category: 'functional', grams: 38,  minutes: 155, complexity: 3, materials: ['tpu'],                         salePrice: 200,  unlockLevel: 12, icon: 'case' },
  { id: 'lamp_shade',  name: 'Lamp Shade',      category: 'decor',      grams: 120, minutes: 255, complexity: 3, materials: ['pla', 'petg'],                 salePrice: 300,  unlockLevel: 13, icon: 'lamp' },
  { id: 'toy_articulated', name: 'Articulated Toy', category: 'multicolor', grams: 46, minutes: 190, complexity: 4, materials: ['pla', 'petg'],             salePrice: 265,  unlockLevel: 15, icon: 'articulated', multicolor: true },
  { id: 'drone_frame', name: 'Drone Frame',     category: 'mechanical', grams: 210, minutes: 430, complexity: 5, materials: ['pa', 'pc', 'cf'],              salePrice: 780,  unlockLevel: 20, icon: 'frame' },
  { id: 'enclosure',   name: 'Device Enclosure',category: 'functional', grams: 265, minutes: 520, complexity: 4, materials: ['abs', 'asa', 'pc'],            salePrice: 860,  unlockLevel: 24, icon: 'enclosure' },
];

export const PRODUCT_BY_ID = new Map(PRODUCTS.map((p) => [p.id, p]));
