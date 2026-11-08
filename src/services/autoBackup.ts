import { Capacitor } from '@capacitor/core'
import { Directory, Encoding, Filesystem } from '@capacitor/filesystem'
import { createBackupPayload, parseBackupText } from '../data/backup'
import { hasStoredAppData } from '../data/persistence'
import type { ParsedBackupData } from '../data/types'

export interface AutoBackupData {
  records: ParsedBackupData['records']
  entries: ParsedBackupData['entries']
  customCategories: ParsedBackupData['customCategories']
  workProfiles: ParsedBackupData['workProfiles']
  budgetTargets: ParsedBackupData['budgetTargets']
}

export interface AutoBackupStatus {
  enabled: true
  lastSuccessAt: number | null
  lastError: string | null
  location: 'indexeddb' | 'data' | 'documents' | 'localstorage' | null
  lastRestoredAt: number | null
}

const FALLBACK_KEY = 'my-hours.autoBackup.v1'
const SUPPRESS_KEY = 'my-hours.autoBackupSuppressed.v1'
const DB_NAME = 'my-hours-auto-backup'
const STORE_NAME = 'snapshots'
const LATEST_ID = 'latest'
const NATIVE_DIR = 'auto-backups'
const NATIVE_FILE = NATIVE_DIR + '/latest.json'
const PUBLIC_DIR = '时账自动备份'
const PUBLIC_FILE = PUBLIC_DIR + '/时账-自动备份.json'
const AUTO_BACKUP_DELAY = 2000
let lastFingerprint = ''

let timer = 0
let statusValue: AutoBackupStatus = {
  enabled: true,
  lastSuccessAt: null,
  lastError: null,
  location: null,
  lastRestoredAt: null,
}
const listeners = new Set<() => void>()

function setStatus(next: Partial<AutoBackupStatus>): void {
  statusValue = Object.assign({}, statusValue, next)
  for (const listener of listeners) listener()
}

export function getAutoBackupStatus(): AutoBackupStatus {
  return statusValue
}

export function subscribeAutoBackup(listener: () => void): () => void {
  listeners.add(listener)
  return function remove() { listeners.delete(listener) }
}

export function isAutoBackupSuppressed(): boolean {
  try { return window.localStorage.getItem(SUPPRESS_KEY) === '1' } catch { return false }
}

export function suppressAutoBackup(): void {
  try { window.localStorage.setItem(SUPPRESS_KEY, '1') } catch {}
}

function clearSuppression(): void {
  try { window.localStorage.removeItem(SUPPRESS_KEY) } catch {}
}

export function hasStoredAppRecords(data: AutoBackupData): boolean {
  if (data.records.length > 0 || data.entries.length > 0) return true
  if (data.customCategories.length > 0) return true
  if (data.workProfiles.some((p) => p.id !== 'work-default')) return true
  return data.budgetTargets.monthlyExpenseBudget > 0 || data.budgetTargets.monthlyIncomeGoal > 0
}

function toBackupJson(data: AutoBackupData): string {
  return JSON.stringify(createBackupPayload(data.records, data.entries, data.customCategories, data.workProfiles, data.budgetTargets))
}

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    if (typeof indexedDB === 'undefined') { reject(new Error('IndexedDB 不可用')); return }
    const request = indexedDB.open(DB_NAME, 1)
    request.onupgradeneeded = function () {
      const db = request.result
      if (!db.objectStoreNames.contains(STORE_NAME)) db.createObjectStore(STORE_NAME, { keyPath: 'id' })
    }
    request.onsuccess = function () { resolve(request.result) }
    request.onerror = function () { reject(request.error || new Error('IndexedDB 打开失败')) }
  })
}

function idbPut(db: IDBDatabase, value: Record<string, unknown>): Promise<void> {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite')
    tx.objectStore(STORE_NAME).put(value)
    tx.oncomplete = function () { resolve() }
    tx.onerror = function () { reject(tx.error || new Error('写入自动备份失败')) }
  })
}

function idbGet(db: IDBDatabase): Promise<string | null> {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly')
    const request = tx.objectStore(STORE_NAME).get(LATEST_ID)
    request.onsuccess = function () {
      const row = request.result as { payload?: string } | undefined
      resolve(typeof row?.payload === 'string' ? row.payload : null)
    }
    request.onerror = function () { reject(request.error || new Error('读取自动备份失败')) }
  })
}

function idbClear(db: IDBDatabase): Promise<void> {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite')
    tx.objectStore(STORE_NAME).delete(LATEST_ID)
    tx.oncomplete = function () { resolve() }
    tx.onerror = function () { reject(tx.error || new Error('清理自动备份失败')) }
  })
}

async function webSave(json: string): Promise<'indexeddb' | 'localstorage'> {
  try {
    const db = await openDb()
    await idbPut(db, { id: LATEST_ID, createdAt: Date.now(), payload: json })
    db.close()
    return 'indexeddb'
  } catch {
    try { window.localStorage.setItem(FALLBACK_KEY, json) } catch {}
    return 'localstorage'
  }
}

function readFallback(): string | null {
  try { return window.localStorage.getItem(FALLBACK_KEY) } catch { return null }
}

async function webLoad(): Promise<string | null> {
  try {
    const db = await openDb()
    const value = await idbGet(db)
    db.close()
    return value || readFallback()
  } catch { return readFallback() }
}

async function webClear(): Promise<void> {
  try {
    const db = await openDb()
    await idbClear(db)
    db.close()
  } catch {}
  try { window.localStorage.removeItem(FALLBACK_KEY) } catch {}
}

async function nativeWrite(path: string, json: string, directory: Directory): Promise<void> {
  await Filesystem.writeFile({ path, data: json, directory, encoding: Encoding.UTF8, recursive: true })
}

async function nativeSave(json: string): Promise<'documents' | 'data'> {
  await nativeWrite(NATIVE_FILE, json, Directory.Data)
  try {
    await Filesystem.mkdir({ path: PUBLIC_DIR, directory: Directory.Documents, recursive: true })
    await nativeWrite(PUBLIC_FILE, json, Directory.Documents)
    return 'documents'
  } catch { return 'data' }
}

async function nativeRead(path: string, directory: Directory): Promise<string | null> {
  try {
    const result = await Filesystem.readFile({ path, directory, encoding: Encoding.UTF8 })
    return typeof result.data === 'string' && result.data ? result.data : null
  } catch { return null }
}

async function nativeLoad(): Promise<string | null> {
  const data = await nativeRead(NATIVE_FILE, Directory.Data)
  if (data) return data
  return nativeRead(PUBLIC_FILE, Directory.Documents)
}

async function nativeDelete(path: string, directory: Directory): Promise<void> {
  try { await Filesystem.deleteFile({ path, directory }) } catch {}
}

async function nativeClear(): Promise<void> {
  await nativeDelete(NATIVE_FILE, Directory.Data)
  await nativeDelete(PUBLIC_FILE, Directory.Documents)
}

async function writeSnapshot(data: AutoBackupData): Promise<AutoBackupStatus['location']> {
  const json = toBackupJson(data)
  return Capacitor.isNativePlatform() ? nativeSave(json) : webSave(json)
}

export async function loadAutoBackup(): Promise<ParsedBackupData | null> {
  const json = Capacitor.isNativePlatform() ? await nativeLoad() : await webLoad()
  if (!json) return null
  try { return parseBackupText(json) } catch { return null }
}

export async function runAutoBackup(data: AutoBackupData): Promise<boolean> {
  if (!hasStoredAppRecords(data)) return false
  try {
    const json = toBackupJson(data)
    const fingerprint = json
    if (fingerprint === lastFingerprint) return true
    const location = await writeSnapshot(data)
    lastFingerprint = fingerprint
    clearSuppression()
    setStatus({ lastSuccessAt: Date.now(), lastError: null, location })
    return true
  } catch (error) {
    const message = error instanceof Error ? error.message : '自动备份失败'
    setStatus({ lastError: message })
    return false
  }
}

export function scheduleAutoBackup(data: AutoBackupData): void {
  if (timer) window.clearTimeout(timer)
  timer = window.setTimeout(function () {
    timer = 0
    void runAutoBackup(data)
  }, AUTO_BACKUP_DELAY)
}

export async function recoverAutoBackupIfNeeded(): Promise<ParsedBackupData | null> {
  if (isAutoBackupSuppressed() || hasStoredAppData()) return null
  const payload = await loadAutoBackup()
  if (!payload) return null
  setStatus({ lastRestoredAt: Date.now() })
  return payload
}

export async function clearAutoBackups(): Promise<void> {
  lastFingerprint = ''
  suppressAutoBackup()
  if (Capacitor.isNativePlatform()) await nativeClear()
  await webClear()
  setStatus({ lastSuccessAt: null, lastError: null, location: null })
}
