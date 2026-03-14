import { getSettings, saveSettings } from "./lib/storage.js";

const elements = {
  profileLabelInput: document.getElementById("profileLabelInput"),
  duplicateSecondsInput: document.getElementById("duplicateSecondsInput"),
  includeHeaderSelect: document.getElementById("includeHeaderSelect"),
  shortcutUsesLastTaskSelect: document.getElementById(
    "shortcutUsesLastTaskSelect",
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
  elements.shortcutUsesLastTaskSelect.value = String(
    Boolean(settings.shortcutUsesLastTask),
  );
}

async function handleSave() {
  const payload = {
    profileLabel: elements.profileLabelInput.value.trim(),
    duplicateWindowSeconds: Math.max(
      0,
      Number(elements.duplicateSecondsInput.value || 0),
    ),
    includeHeaderOnCopy: elements.includeHeaderSelect.value === "true",
    shortcutUsesLastTask: elements.shortcutUsesLastTaskSelect.value === "true",
  };

  await saveSettings(payload);
  elements.saveStatus.textContent = "保存しました。";
}

elements.saveButton.addEventListener("click", handleSave);
elements.closeButton.addEventListener("click", () => window.close());

init();
