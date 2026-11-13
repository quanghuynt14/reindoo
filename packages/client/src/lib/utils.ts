import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function normalizeString(str: string): string {
  return str
    .trim()
    .toLowerCase()
    .normalize()
    .replace(/\s+/g, ' ') // Replace multiple spaces with single space
}
