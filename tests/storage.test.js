import { beforeEach, describe, expect, test } from "vitest";

import {
  appendLog,
  clearLogs,
  DEFAULT_SETTINGS,
  getLastFingerprint,
  getLastTaskName,
  getLogs,
  getSettings,
  normalizeSettings,
  getShortcutStatus,
  removeLogById,
  saveSettings,
  setLastFingerprint,
  setLastTaskName,
  setShortcutStatus,
  updateLog,
} from "../chrome-extension/lib/storage.js";

beforeEach(() => {
  globalThis.__resetChromeStorage();
});

describe("storage", () => {
  test("getSettings returns defaults when storage is empty", async () => {
    await expect(getSettings()).resolves.toEqual(DEFAULT_SETTINGS);
  });

  test("saveSettings merges defaults with partial settings", async () => {
    await expect(
      saveSettings({
        profileLabel: "仕事用",
        duplicateWindowSeconds: 30,
      }),
    ).resolves.toEqual({
      ...DEFAULT_SETTINGS,
      profileLabel: "仕事用",
      duplicateWindowSeconds: 30,
    });

    await expect(getSettings()).resolves.toEqual({
      ...DEFAULT_SETTINGS,
      profileLabel: "仕事用",
      duplicateWindowSeconds: 30,
    });
  });

  test("getSettings reads legacy shortcutUsesLastTask values", async () => {
    globalThis.__resetChromeStorage({
      settings: {
        profileLabel: "legacy",
        shortcutUsesLastTask: true,
      },
    });

    await expect(getSettings()).resolves.toEqual({
      ...DEFAULT_SETTINGS,
      profileLabel: "legacy",
      shortcutTaskNameMode: "last-task",
    });
  });

  test("normalizeSettings migrates legacy false values to page-title mode", () => {
    expect(
      normalizeSettings({
        shortcutUsesLastTask: false,
      }),
    ).toEqual(DEFAULT_SETTINGS);
  });

  test("appendLog, updateLog, and removeLogById manage stored logs", async () => {
    const firstLog = { record_id: "1", task_name: "first" };
    const secondLog = { record_id: "2", task_name: "second" };

    await appendLog(firstLog);
    await expect(appendLog(secondLog)).resolves.toEqual([firstLog, secondLog]);

    await expect(
      updateLog({ record_id: "2", task_name: "updated", memo: "keep" }),
    ).resolves.toEqual([
      firstLog,
      { record_id: "2", task_name: "updated", memo: "keep" },
    ]);

    await expect(removeLogById("1")).resolves.toEqual([
      { record_id: "2", task_name: "updated", memo: "keep" },
    ]);
    await expect(getLogs()).resolves.toEqual([
      { record_id: "2", task_name: "updated", memo: "keep" },
    ]);
  });

  test("clearLogs removes only stored logs", async () => {
    await appendLog({ record_id: "1", task_name: "first" });
    await setLastTaskName("残すタスク");
    await setShortcutStatus("残す状態");

    await expect(clearLogs()).resolves.toEqual([]);
    await expect(getLogs()).resolves.toEqual([]);
    await expect(getLastTaskName()).resolves.toBe("残すタスク");
    await expect(getShortcutStatus()).resolves.toBe("残す状態");
  });

  test("lastFingerprint round-trips through storage", async () => {
    const fingerprint = {
      fingerprint: "abc",
      created_at_epoch: 123,
    };

    await setLastFingerprint(fingerprint);
    await expect(getLastFingerprint()).resolves.toEqual(fingerprint);
  });

  test("lastTaskName and shortcutStatus round-trip through storage", async () => {
    await setLastTaskName("タスク");
    await setShortcutStatus("記録しました");

    await expect(getLastTaskName()).resolves.toBe("タスク");
    await expect(getShortcutStatus()).resolves.toBe("記録しました");
  });
});
