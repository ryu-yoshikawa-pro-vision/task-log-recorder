export const STORAGE_KEYS = {
  LOGS: "logs",
  SETTINGS: "settings",
  LAST_FINGERPRINT: "lastFingerprint",
  LAST_TASK_NAME: "lastTaskName",
  SHORTCUT_STATUS: "shortcutStatus",
};

export const DEFAULT_SETTINGS = {
  profileLabel: "",
  duplicateWindowSeconds: 10,
  includeHeaderOnCopy: true,
  shortcutUsesLastTask: true,
};

export async function getSettings() {
  const result = await chrome.storage.local.get(STORAGE_KEYS.SETTINGS);
  return {
    ...DEFAULT_SETTINGS,
    ...(result[STORAGE_KEYS.SETTINGS] || {}),
  };
}

export async function saveSettings(settings) {
  const merged = {
    ...DEFAULT_SETTINGS,
    ...(settings || {}),
  };
  await chrome.storage.local.set({ [STORAGE_KEYS.SETTINGS]: merged });
  return merged;
}

export async function getLogs() {
  const result = await chrome.storage.local.get(STORAGE_KEYS.LOGS);
  return Array.isArray(result[STORAGE_KEYS.LOGS])
    ? result[STORAGE_KEYS.LOGS]
    : [];
}

export async function saveLogs(logs) {
  await chrome.storage.local.set({ [STORAGE_KEYS.LOGS]: logs });
}

export async function appendLog(log) {
  const logs = await getLogs();
  logs.push(log);
  await saveLogs(logs);
  return logs;
}

export async function updateLog(updatedLog) {
  const logs = await getLogs();
  const next = logs.map((log) =>
    log.record_id === updatedLog.record_id ? { ...log, ...updatedLog } : log,
  );
  await saveLogs(next);
  return next;
}

export async function removeLogById(recordId) {
  const logs = await getLogs();
  const next = logs.filter((log) => log.record_id !== recordId);
  await saveLogs(next);
  return next;
}

export async function getLastFingerprint() {
  const result = await chrome.storage.local.get(STORAGE_KEYS.LAST_FINGERPRINT);
  return result[STORAGE_KEYS.LAST_FINGERPRINT] || null;
}

export async function setLastFingerprint(value) {
  await chrome.storage.local.set({ [STORAGE_KEYS.LAST_FINGERPRINT]: value });
}

export async function getLastTaskName() {
  const result = await chrome.storage.local.get(STORAGE_KEYS.LAST_TASK_NAME);
  return result[STORAGE_KEYS.LAST_TASK_NAME] || "";
}

export async function setLastTaskName(taskName) {
  await chrome.storage.local.set({
    [STORAGE_KEYS.LAST_TASK_NAME]: taskName || "",
  });
}

export async function getShortcutStatus() {
  const result = await chrome.storage.local.get(STORAGE_KEYS.SHORTCUT_STATUS);
  return result[STORAGE_KEYS.SHORTCUT_STATUS] || "";
}

export async function setShortcutStatus(statusText) {
  await chrome.storage.local.set({
    [STORAGE_KEYS.SHORTCUT_STATUS]: statusText || "",
  });
}
