import {
  appendLog,
  getLastFingerprint,
  getLastTaskName,
  getLogs,
  getSettings,
  saveSettings,
  setLastFingerprint,
  setLastTaskName,
  setShortcutStatus,
} from "./lib/storage.js";
import {
  buildFingerprint,
  createId,
  EVENT_LABELS,
  isDuplicate,
  toLocalString,
} from "./lib/utils.js";

chrome.runtime.onInstalled.addListener(async () => {
  await saveSettings(await getSettings());
});

chrome.commands.onCommand.addListener(async (command) => {
  try {
    if (!["start-log", "break-log", "end-day-log"].includes(command)) {
      return;
    }

    const eventType =
      command === "start-log"
        ? "START"
        : command === "break-log"
          ? "BREAK"
          : "END_DAY";

    const settings = await getSettings();
    const lastTaskName = await getLastTaskName();
    const [tab] = await chrome.tabs.query({
      active: true,
      currentWindow: true,
    });
    const now = Date.now();

    const payload = {
      record_id: createId(),
      recorded_at_iso: new Date(now).toISOString(),
      recorded_at_local: toLocalString(now),
      event_type: eventType,
      task_name: settings.shortcutUsesLastTask ? lastTaskName || "" : "",
      memo: "",
      page_title: tab?.title || "タイトル取得不可",
      page_url: tab?.url || "URL取得不可",
      profile_label: settings.profileLabel || "",
      created_at_epoch: now,
      source: "shortcut",
    };

    const fingerprint = buildFingerprint(payload);
    const last = await getLastFingerprint();
    const duplicated = isDuplicate(
      last?.fingerprint,
      fingerprint,
      last?.created_at_epoch,
      now,
      settings.duplicateWindowSeconds,
    );

    if (duplicated) {
      await setShortcutStatus("重複のため記録しませんでした");
      return;
    }

    await appendLog(payload);
    await setLastFingerprint({ fingerprint, created_at_epoch: now });
    if (payload.task_name) {
      await setLastTaskName(payload.task_name);
    }

    const logs = await getLogs();
    await setShortcutStatus(
      `${EVENT_LABELS[eventType]}を記録しました（計 ${logs.length} 件）`,
    );
  } catch (error) {
    await setShortcutStatus(`記録失敗: ${error?.message || String(error)}`);
  }
});
