import {
  appendLog,
  getSettings,
  saveSettings,
  getLastFingerprint,
  getLastTaskName,
  getLogs,
  setLastFingerprint,
  setLastTaskName,
  setShortcutStatus,
} from "./lib/storage.js";
import { handleShortcutCommand } from "./lib/shortcut.js";

chrome.runtime.onInstalled.addListener(async () => {
  await saveSettings(await getSettings());
});

function canShowPageNotification(tab) {
  if (!Number.isInteger(tab?.id)) {
    return false;
  }

  return !/^(chrome|chrome-extension|edge|about|view-source|devtools):/.test(
    tab?.url || "",
  );
}

function showSnackbarOnPage(message, kind) {
  const rootId = "__task_log_recorder_shortcut_snackbar__";
  const timerKey = "__taskLogRecorderShortcutSnackbarTimer__";
  let root = document.getElementById(rootId);

  if (!root) {
    root = document.createElement("div");
    root.id = rootId;
    root.setAttribute("role", "status");
    root.setAttribute("aria-live", "polite");
    root.style.position = "fixed";
    root.style.right = "24px";
    root.style.bottom = "24px";
    root.style.zIndex = "2147483647";
    root.style.maxWidth = "min(420px, calc(100vw - 32px))";
    root.style.padding = "14px 18px";
    root.style.borderRadius = "16px";
    root.style.boxShadow = "0 18px 40px rgba(0, 0, 0, 0.28)";
    root.style.backdropFilter = "blur(14px)";
    root.style.font =
      '600 13px/1.55 Inter, "Noto Sans JP", system-ui, sans-serif';
    root.style.letterSpacing = "0.01em";
    root.style.opacity = "0";
    root.style.transform = "translateY(18px)";
    root.style.transition = "opacity 180ms ease, transform 180ms ease";
    root.style.pointerEvents = "none";
    (document.body || document.documentElement).append(root);
  }

  const palette =
    kind === "ok"
      ? {
          background:
            "linear-gradient(180deg, rgba(15, 31, 34, 0.96) 0%, rgba(10, 23, 28, 0.98) 100%)",
          border: "1px solid rgba(54, 211, 162, 0.34)",
          color: "#f3fffb",
        }
      : {
          background:
            "linear-gradient(180deg, rgba(42, 27, 18, 0.96) 0%, rgba(30, 20, 14, 0.98) 100%)",
          border: "1px solid rgba(255, 182, 89, 0.38)",
          color: "#fff7ec",
        };

  root.textContent = message;
  root.style.background = palette.background;
  root.style.border = palette.border;
  root.style.color = palette.color;

  if (window[timerKey]) {
    window.clearTimeout(window[timerKey]);
  }

  window.requestAnimationFrame(() => {
    root.style.opacity = "1";
    root.style.transform = "translateY(0)";
  });

  window[timerKey] = window.setTimeout(() => {
    root.style.opacity = "0";
    root.style.transform = "translateY(18px)";
  }, 2200);
}

async function getActiveTabForCommand() {
  const [lastFocusedTab] = await chrome.tabs.query({
    active: true,
    lastFocusedWindow: true,
  });
  if (lastFocusedTab) {
    return lastFocusedTab;
  }

  const [currentWindowTab] = await chrome.tabs.query({
    active: true,
    currentWindow: true,
  });
  return currentWindowTab || null;
}

async function notifyPage({ tab, message, kind }) {
  if (!canShowPageNotification(tab)) {
    return false;
  }

  try {
    await chrome.scripting.executeScript({
      target: { tabId: tab.id },
      func: showSnackbarOnPage,
      args: [message, kind],
    });
    return true;
  } catch {
    return false;
  }
}

chrome.commands.onCommand.addListener(async (command, commandTab) => {
  await handleShortcutCommand({
    command,
    commandTab,
    getActiveTab: getActiveTabForCommand,
    getSettings,
    getLastTaskName,
    getLastFingerprint,
    appendLog,
    setLastFingerprint,
    setLastTaskName,
    getLogs,
    setShortcutStatus,
    notifyPage,
  });
});
