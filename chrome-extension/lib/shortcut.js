import {
  buildFingerprint,
  createId,
  EVENT_LABELS,
  isDuplicate,
  toLocalString,
  trimTo,
} from "./utils.js";

export const SHORTCUT_TASK_NAME_MODES = Object.freeze({
  PAGE_TITLE: "page-title",
  LAST_TASK: "last-task",
});

export const SHORTCUT_COMMAND_TO_EVENT_TYPE = Object.freeze({
  "start-log": "START",
  "break-log": "BREAK",
  "end-day-log": "END_DAY",
});

export const SHORTCUT_COMMANDS = Object.keys(SHORTCUT_COMMAND_TO_EVENT_TYPE);

export const FALLBACK_PAGE_TITLE = "タイトル取得不可";
export const FALLBACK_PAGE_URL = "URL取得不可";

const SHORTCUT_COMMAND_LABELS = Object.freeze({
  "start-log": "開始",
  "break-log": "休憩",
  "end-day-log": "終了",
});

export function getShortcutCommandLabel(commandName) {
  return SHORTCUT_COMMAND_LABELS[commandName] || commandName;
}

export function normalizeShortcutTaskNameMode(settings = {}) {
  if (
    settings?.shortcutTaskNameMode === SHORTCUT_TASK_NAME_MODES.PAGE_TITLE ||
    settings?.shortcutTaskNameMode === SHORTCUT_TASK_NAME_MODES.LAST_TASK
  ) {
    return settings.shortcutTaskNameMode;
  }

  if (typeof settings?.shortcutUsesLastTask === "boolean") {
    return settings.shortcutUsesLastTask
      ? SHORTCUT_TASK_NAME_MODES.LAST_TASK
      : SHORTCUT_TASK_NAME_MODES.PAGE_TITLE;
  }

  return SHORTCUT_TASK_NAME_MODES.PAGE_TITLE;
}

export function getEventTypeForCommand(command) {
  return SHORTCUT_COMMAND_TO_EVENT_TYPE[command] || null;
}

export function isKnownShortcutCommand(command) {
  return Boolean(getEventTypeForCommand(command));
}

export function getResolvedTabInfo(tab = null) {
  return {
    id: Number.isInteger(tab?.id) ? tab.id : null,
    title:
      typeof tab?.title === "string" && tab.title.trim()
        ? tab.title.trim()
        : FALLBACK_PAGE_TITLE,
    url:
      typeof tab?.url === "string" && tab.url.trim()
        ? tab.url
        : FALLBACK_PAGE_URL,
  };
}

export function resolveShortcutTaskName({
  settings = {},
  tab = null,
  lastTaskName = "",
}) {
  const taskNameMode = normalizeShortcutTaskNameMode(settings);
  const resolvedTab = getResolvedTabInfo(tab);
  const fallbackTaskName = resolvedTab.title || FALLBACK_PAGE_TITLE;

  if (taskNameMode === SHORTCUT_TASK_NAME_MODES.LAST_TASK) {
    return String(lastTaskName || fallbackTaskName).trim();
  }

  return fallbackTaskName;
}

export function buildShortcutPayload({
  command,
  settings = {},
  lastTaskName = "",
  tab = null,
  now = Date.now(),
  recordId = createId(),
} = {}) {
  const eventType = getEventTypeForCommand(command);
  if (!eventType) {
    return null;
  }

  const resolvedTab = getResolvedTabInfo(tab);
  const task_name = resolveShortcutTaskName({
    settings,
    tab: resolvedTab,
    lastTaskName,
  });
  const payload = {
    record_id: recordId,
    recorded_at_iso: new Date(now).toISOString(),
    recorded_at_local: toLocalString(now),
    event_type: eventType,
    task_name,
    memo: "",
    page_title: resolvedTab.title,
    page_url: resolvedTab.url,
    profile_label: settings.profileLabel || "",
    created_at_epoch: now,
    source: "shortcut",
  };

  return {
    eventType,
    fingerprint: buildFingerprint(payload),
    payload,
    tab: resolvedTab,
    taskNameMode: normalizeShortcutTaskNameMode(settings),
  };
}

export function getShortcutDisplayTaskName(logLike) {
  const raw = (logLike?.task_name || logLike?.page_title || "未入力").trim();
  return trimTo(raw || "未入力", 36);
}

export function buildShortcutNotificationMessage(logLike) {
  const eventLabel = EVENT_LABELS[logLike?.event_type] || logLike?.event_type;
  return `「${getShortcutDisplayTaskName(logLike)}」を${eventLabel}として記録しました`;
}

export function buildShortcutStatusMessage(logLike, totalLogs) {
  const suffix = Number.isFinite(totalLogs) ? `（計 ${totalLogs} 件）` : "";
  return `${buildShortcutNotificationMessage(logLike)}${suffix}`;
}

export function buildShortcutDuplicateStatusMessage() {
  return "重複のため記録しませんでした";
}

export function buildShortcutFailureStatusMessage(error) {
  return `記録失敗: ${error?.message || String(error)}`;
}

export function buildShortcutBindingStatusMessage(commands = []) {
  const shortcuts = new Map(
    commands.map((command) => [command.name, command.shortcut || ""]),
  );
  const missingLabels = SHORTCUT_COMMANDS.filter(
    (name) => !shortcuts.get(name),
  ).map((name) => getShortcutCommandLabel(name));

  if (!missingLabels.length) {
    return "ショートカットはすべて割り当て済みです。";
  }

  return `未割り当て: ${missingLabels.join(" / ")}。chrome://extensions/shortcuts で設定してください。`;
}

export function getShortcutBindingDetails(commands = []) {
  const shortcuts = new Map(
    commands.map((command) => [command.name, command.shortcut || ""]),
  );

  return SHORTCUT_COMMANDS.map((name) => {
    const shortcut = shortcuts.get(name) || "";
    return {
      name,
      label: getShortcutCommandLabel(name),
      shortcut,
      isAssigned: Boolean(shortcut),
    };
  });
}

async function notifyPageSafely(notifyPage, tab, message, kind) {
  if (typeof notifyPage !== "function") {
    return false;
  }

  try {
    return (await notifyPage({ tab, message, kind })) !== false;
  } catch {
    return false;
  }
}

export async function handleShortcutCommand({
  command,
  commandTab = null,
  getActiveTab,
  getSettings,
  getLastTaskName,
  getLastFingerprint,
  appendLog,
  setLastFingerprint,
  setLastTaskName,
  getLogs,
  setShortcutStatus,
  notifyPage,
  now = () => Date.now(),
} = {}) {
  let currentTab = commandTab || null;

  try {
    if (!isKnownShortcutCommand(command)) {
      return { kind: "ignored" };
    }

    const settings = await getSettings();
    const lastTaskName = await getLastTaskName();
    if (!currentTab && typeof getActiveTab === "function") {
      currentTab = await getActiveTab();
    }

    const shortcut = buildShortcutPayload({
      command,
      settings,
      lastTaskName,
      tab: currentTab,
      now: now(),
    });
    const last = await getLastFingerprint();
    const duplicated = isDuplicate(
      last?.fingerprint,
      shortcut.fingerprint,
      last?.created_at_epoch,
      shortcut.payload.created_at_epoch,
      settings.duplicateWindowSeconds,
    );

    if (duplicated) {
      const statusText = buildShortcutDuplicateStatusMessage();
      await setShortcutStatus(statusText);
      const notified = await notifyPageSafely(
        notifyPage,
        currentTab,
        statusText,
        "warn",
      );
      return {
        kind: "warn",
        reason: "duplicate",
        statusText,
        notified,
        payload: shortcut.payload,
      };
    }

    const appendedLogs = await appendLog(shortcut.payload);
    await setLastFingerprint({
      fingerprint: shortcut.fingerprint,
      created_at_epoch: shortcut.payload.created_at_epoch,
    });
    if (shortcut.payload.task_name) {
      await setLastTaskName(shortcut.payload.task_name);
    }

    const totalLogs = Array.isArray(appendedLogs)
      ? appendedLogs.length
      : typeof getLogs === "function"
        ? (await getLogs())?.length
        : undefined;
    const statusText = buildShortcutStatusMessage(shortcut.payload, totalLogs);
    const notifyMessage = buildShortcutNotificationMessage(shortcut.payload);
    await setShortcutStatus(statusText);
    const notified = await notifyPageSafely(
      notifyPage,
      currentTab,
      notifyMessage,
      "ok",
    );

    return {
      kind: "ok",
      notified,
      notifyMessage,
      payload: shortcut.payload,
      statusText,
    };
  } catch (error) {
    const statusText = buildShortcutFailureStatusMessage(error);
    await setShortcutStatus(statusText);
    const notified = await notifyPageSafely(
      notifyPage,
      currentTab,
      statusText,
      "warn",
    );
    return {
      kind: "error",
      error,
      notified,
      statusText,
    };
  }
}
