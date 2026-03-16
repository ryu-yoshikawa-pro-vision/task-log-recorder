import { describe, expect, test, vi } from "vitest";

import {
  SHORTCUT_TASK_NAME_MODES,
  buildShortcutBindingStatusMessage,
  buildShortcutPayload,
  getShortcutBindingDetails,
  handleShortcutCommand,
} from "../chrome-extension/lib/shortcut.js";

describe("shortcut helpers", () => {
  test("buildShortcutPayload uses page title by default", () => {
    const result = buildShortcutPayload({
      command: "start-log",
      settings: {
        profileLabel: "仕事用",
        shortcutTaskNameMode: SHORTCUT_TASK_NAME_MODES.PAGE_TITLE,
      },
      tab: {
        title: "現在のページ",
        url: "https://example.com/tasks",
      },
      now: 1_742_000_000_000,
      recordId: "record-1",
    });

    expect(result.payload).toMatchObject({
      record_id: "record-1",
      event_type: "START",
      task_name: "現在のページ",
      page_title: "現在のページ",
      page_url: "https://example.com/tasks",
      profile_label: "仕事用",
      source: "shortcut",
    });
  });

  test("buildShortcutPayload can use last task mode", () => {
    const result = buildShortcutPayload({
      command: "end-day-log",
      settings: {
        shortcutTaskNameMode: SHORTCUT_TASK_NAME_MODES.LAST_TASK,
      },
      lastTaskName: "前回のタスク",
      tab: {
        title: "現在のページ",
        url: "https://example.com/tasks",
      },
      now: 1_742_000_000_000,
      recordId: "record-2",
    });

    expect(result.payload).toMatchObject({
      event_type: "END_DAY",
      task_name: "前回のタスク",
    });
  });

  test("buildShortcutBindingStatusMessage reports missing shortcuts", () => {
    expect(
      buildShortcutBindingStatusMessage([
        { name: "start-log", shortcut: "Ctrl+Shift+1" },
        { name: "break-log", shortcut: "" },
      ]),
    ).toBe(
      "未割り当て: 休憩 / 終了。chrome://extensions/shortcuts で設定してください。",
    );
  });

  test("getShortcutBindingDetails lists current bindings for all commands", () => {
    expect(
      getShortcutBindingDetails([
        { name: "start-log", shortcut: "Ctrl+Shift+1" },
        { name: "break-log", shortcut: "" },
      ]),
    ).toEqual([
      {
        name: "start-log",
        label: "開始",
        shortcut: "Ctrl+Shift+1",
        isAssigned: true,
      },
      {
        name: "break-log",
        label: "休憩",
        shortcut: "",
        isAssigned: false,
      },
      {
        name: "end-day-log",
        label: "終了",
        shortcut: "",
        isAssigned: false,
      },
    ]);
  });
});

describe("handleShortcutCommand", () => {
  test("records shortcut logs and notifies the page", async () => {
    const setShortcutStatus = vi.fn();
    const notifyPage = vi.fn().mockResolvedValue(true);
    const appendLog = vi.fn().mockResolvedValue([{ record_id: "record-1" }]);
    const setLastFingerprint = vi.fn();
    const setLastTaskName = vi.fn();

    const result = await handleShortcutCommand({
      command: "break-log",
      commandTab: {
        id: 9,
        title: "記録対象ページ",
        url: "https://example.com/tasks",
      },
      getSettings: async () => ({
        profileLabel: "個人",
        duplicateWindowSeconds: 10,
        includeHeaderOnCopy: true,
        shortcutTaskNameMode: SHORTCUT_TASK_NAME_MODES.PAGE_TITLE,
      }),
      getLastTaskName: async () => "前回タスク",
      getLastFingerprint: async () => null,
      appendLog,
      setLastFingerprint,
      setLastTaskName,
      getLogs: async () => [{ record_id: "record-1" }],
      setShortcutStatus,
      notifyPage,
      now: () => 1_742_000_000_000,
    });

    expect(result.kind).toBe("ok");
    expect(appendLog).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: "BREAK",
        task_name: "記録対象ページ",
        page_title: "記録対象ページ",
      }),
    );
    expect(setLastFingerprint).toHaveBeenCalledTimes(1);
    expect(setLastTaskName).toHaveBeenCalledWith("記録対象ページ");
    expect(setShortcutStatus).toHaveBeenCalledWith(
      expect.stringContaining("記録しました"),
    );
    expect(notifyPage).toHaveBeenCalledWith(
      expect.objectContaining({
        kind: "ok",
      }),
    );
  });

  test("supports legacy shortcutUsesLastTask values", async () => {
    const appendLog = vi.fn().mockResolvedValue([{ record_id: "record-1" }]);

    await handleShortcutCommand({
      command: "start-log",
      commandTab: {
        title: "現在のページ",
        url: "https://example.com/tasks",
      },
      getSettings: async () => ({
        duplicateWindowSeconds: 10,
        shortcutUsesLastTask: true,
      }),
      getLastTaskName: async () => "前回タスク",
      getLastFingerprint: async () => null,
      appendLog,
      setLastFingerprint: async () => {},
      setLastTaskName: async () => {},
      getLogs: async () => [{ record_id: "record-1" }],
      setShortcutStatus: async () => {},
      notifyPage: async () => true,
      now: () => 1_742_000_000_000,
    });

    expect(appendLog).toHaveBeenCalledWith(
      expect.objectContaining({
        task_name: "前回タスク",
      }),
    );
  });

  test("skips duplicate logs and emits a warning", async () => {
    const setShortcutStatus = vi.fn();
    const notifyPage = vi.fn().mockResolvedValue(false);
    const appendLog = vi.fn();

    const result = await handleShortcutCommand({
      command: "break-log",
      commandTab: {
        title: "現在のページ",
        url: "https://example.com/tasks",
      },
      getSettings: async () => ({
        duplicateWindowSeconds: 10,
        shortcutTaskNameMode: SHORTCUT_TASK_NAME_MODES.PAGE_TITLE,
      }),
      getLastTaskName: async () => "前回タスク",
      getLastFingerprint: async () => ({
        fingerprint: '{"page_url":"https://example.com/tasks"}',
        created_at_epoch: 1_742_000_000_000,
      }),
      appendLog,
      setLastFingerprint: async () => {},
      setLastTaskName: async () => {},
      getLogs: async () => [],
      setShortcutStatus,
      notifyPage,
      now: () => 1_742_000_005_000,
    });

    expect(result).toMatchObject({
      kind: "warn",
      reason: "duplicate",
    });
    expect(appendLog).not.toHaveBeenCalled();
    expect(setShortcutStatus).toHaveBeenCalledWith(
      "重複のため記録しませんでした",
    );
    expect(notifyPage).toHaveBeenCalledWith(
      expect.objectContaining({
        kind: "warn",
      }),
    );
  });

  test("continues recording when notification cannot be injected", async () => {
    const setShortcutStatus = vi.fn();
    const appendLog = vi.fn().mockResolvedValue([{ record_id: "record-1" }]);

    const result = await handleShortcutCommand({
      command: "end-day-log",
      commandTab: {
        title: "現在のページ",
        url: "chrome://extensions/shortcuts",
      },
      getSettings: async () => ({
        duplicateWindowSeconds: 10,
        shortcutTaskNameMode: SHORTCUT_TASK_NAME_MODES.PAGE_TITLE,
      }),
      getLastTaskName: async () => "",
      getLastFingerprint: async () => null,
      appendLog,
      setLastFingerprint: async () => {},
      setLastTaskName: async () => {},
      getLogs: async () => [{ record_id: "record-1" }],
      setShortcutStatus,
      notifyPage: async () => false,
      now: () => 1_742_000_000_000,
    });

    expect(result).toMatchObject({
      kind: "ok",
      notified: false,
    });
    expect(appendLog).toHaveBeenCalledTimes(1);
    expect(setShortcutStatus).toHaveBeenCalledWith(
      expect.stringContaining("記録しました"),
    );
  });

  test("returns an error result when log persistence fails", async () => {
    const setShortcutStatus = vi.fn();

    const result = await handleShortcutCommand({
      command: "end-day-log",
      commandTab: {
        title: "現在のページ",
        url: "chrome://extensions/shortcuts",
      },
      getSettings: async () => ({
        duplicateWindowSeconds: 10,
        shortcutTaskNameMode: SHORTCUT_TASK_NAME_MODES.PAGE_TITLE,
      }),
      getLastTaskName: async () => "",
      getLastFingerprint: async () => null,
      appendLog: async () => {
        throw new Error("storage write failed");
      },
      setLastFingerprint: async () => {},
      setLastTaskName: async () => {},
      getLogs: async () => [],
      setShortcutStatus,
      notifyPage: async () => false,
      now: () => 1_742_000_000_000,
    });

    expect(result.kind).toBe("error");
    expect(setShortcutStatus).toHaveBeenCalledWith(
      "記録失敗: storage write failed",
    );
  });
});
