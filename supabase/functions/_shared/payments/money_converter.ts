/**
 * Converts integer minor units (e.g. piastres) to exact 2-decimal string representation.
 * Prevents binary floating-point rounding errors.
 * Example: 125075 minor units -> "1250.75", 100 minor units -> "1.00"
 */
export function minorUnitsToDecimalString(minorUnits: number): string {
  const isNegative = minorUnits < 0;
  const absMinor = Math.abs(Math.floor(minorUnits));
  const units = Math.floor(absMinor / 100);
  const remainder = absMinor % 100;
  const remainderStr = remainder.toString().padStart(2, '0');
  const sign = isNegative ? '-' : '';
  return `${sign}${units}.${remainderStr}`;
}

/**
 * Converts 2-decimal string representation back to integer minor units.
 * Example: "1250.75" -> 125075
 */
export function decimalStringToMinorUnits(decimalStr: string): number {
  const parts = decimalStr.trim().split('.');
  const units = parseInt(parts[0] || '0', 10);
  let remainder = 0;
  if (parts.length > 1) {
    const rawRem = parts[1].padEnd(2, '0').substring(0, 2);
    remainder = parseInt(rawRem, 10);
  }
  return units * 100 + (units >= 0 ? remainder : -remainder);
}
