import {
  buildShortcutBindingStatusMessage,
  getShortcutBindingDetails,
  SHORTCUT_TASK_NAME_MODES,
} from "./lib/shortcut.js";
import { getSettings, saveSettings } from "./lib/storage.js";

const SHORTCUTS_URL = "chrome://extensions/shortcuts";

const elements = {
  profileLabelInput: document.getElementById("profileLabelInput"),
  duplicateSecondsInput: document.getElementById("duplicateSecondsInput"),
  includeHeaderSelect: document.getElementById("includeHeaderSelect"),
  shortcutTaskNameModeSelect: document.getElementById(
    "shortcutTaskNameModeSelect",
  ),
  shortcutBindingsList: document.getElementById("shortcutBindingsList"),
  shortcutBindingsStatus: document.getElementById("shortcutBindingsStatus"),
  openShortcutSettingsButton: document.getElementById(
    "openShortcutSettingsButton",
  ),
  saveStatus: document.getElementById("saveStatus"),
  saveButton: document.getElementById("saveButton"),
  closeButton: document.getElementById("closeButton"),
};

async function init() {
  const settings = await getSettings();
  elements.profileLabelInput.value = settings.profileLabel || "";
  elements.duplicateSecondsInput.value = String(
    settings.duplicateWindowSeconds ?? 10,
  );
  elements.includeHeaderSelect.value = String(
    Boolean(settings.includeHeaderOnCopy),
  );
  elements.shortcutTaskNameModeSelect.value =
    settings.shortcutTaskNameMode || SHORTCUT_TASK_NAME_MODES.PAGE_TITLE;
  await loadShortcutBindingsStatus();
}

async function loadShortcutBindingsStatus() {
  if (!elements.shortcutBindingsStatus || !elements.shortcutBindingsList) {
    return;
  }

  try {
    const commands = await chrome.commands.getAll();
    renderShortcutBindingDetails(commands);
    elements.shortcutBindingsStatus.textContent =
      buildShortcutBindingStatusMessage(commands);
  } catch {
    elements.shortcutBindingsList.innerHTML = `<p class="options-note">開始・休憩・終了の割り当て確認は ${SHORTCUTS_URL} で行います。</p>`;
    elements.shortcutBindingsStatus.textContent = `ショートカット変更は ${SHORTCUTS_URL} で行います。`;
  }
}

function renderShortcutBindingDetails(commands) {
  if (!elements.shortcutBindingsList) {
    return;
  }

  const items = getShortcutBindingDetails(commands);
  elements.shortcutBindingsList.innerHTML = items
    .map(
      (item) => `
        <div class="shortcut-binding-item">
          <span class="shortcut-binding-label">${item.label}</span>
          <span class="shortcut-binding-value ${item.isAssigned ? "assigned" : "missing"}">
            ${item.shortcut || "未割り当て"}
          </span>
        </div>
      `,
    )
    .join("");
}

async function openShortcutSettingsPage() {
  try {
    await chrome.tabs.create({ url: SHORTCUTS_URL });
    return true;
  } catch {
    try {
      window.open(SHORTCUTS_URL, "_blank", "noopener");
      return true;
    } catch {
      return false;
    }
  }
}

async function handleSave() {
  const payload = {
    profileLabel: elements.profileLabelInput.value.trim(),
    duplicateWindowSeconds: Math.max(
      0,
      Number(elements.duplicateSecondsInput.value || 0),
    ),
    includeHeaderOnCopy: elements.includeHeaderSelect.value === "true",
    shortcutTaskNameMode: elements.shortcutTaskNameModeSelect.value,
  };

  await saveSettings(payload);
  elements.saveStatus.textContent = "保存しました。";
}

async function handleOpenShortcutSettings() {
  const opened = await openShortcutSettingsPage();
  if (opened) {
    elements.shortcutBindingsStatus.textContent = `ショートカット設定を開きました。変更先: ${SHORTCUTS_URL}`;
    return;
  }

  elements.shortcutBindingsStatus.textContent = `この環境では自動で開けませんでした。${SHORTCUTS_URL} を開いて設定してください。`;
}

elements.saveButton.addEventListener("click", handleSave);
elements.openShortcutSettingsButton?.addEventListener(
  "click",
  handleOpenShortcutSettings,
);
elements.closeButton.addEventListener("click", () => window.close());

init();
