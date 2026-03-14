import {
  appendLog,
  getLastFingerprint,
  getLogs,
  getSettings,
  getShortcutStatus,
  removeLogById,
  setLastFingerprint,
  setLastTaskName,
  updateLog,
} from "./lib/storage.js";
import {
  buildFingerprint,
  createId,
  escapeHtml,
  EVENT_LABELS,
  EVENT_OPTIONS,
  filterLogsByDate,
  formatShort,
  getAvailableDateOptions,
  getDatePart,
  isDuplicate,
  logsToTsv,
  paginate,
  sortLogsDesc,
  toLocalString,
  trimTo,
} from "./lib/utils.js";

const HISTORY_PAGE_SIZE = 10;

const state = {
  currentTab: null,
  settings: null,
  logs: [],
  previewText: "",
  activeTab: "record",
  historyPage: 1,
  selectedDate: "",
  editingLogId: null,
};

const elements = {
  pageTitle: document.getElementById("pageTitle"),
  pageUrl: document.getElementById("pageUrl"),
  refreshTabButton: document.getElementById("refreshTabButton"),
  openOptionsButton: document.getElementById("openOptionsButton"),
  taskNameInput: document.getElementById("taskNameInput"),
  memoInput: document.getElementById("memoInput"),
  startButton: document.getElementById("startButton"),
  breakButton: document.getElementById("breakButton"),
  endDayButton: document.getElementById("endDayButton"),
  clearFormButton: document.getElementById("clearFormButton"),
  recentLogs: document.getElementById("recentLogs"),
  statusBadge: document.getElementById("statusBadge"),
  shortcutStatus: document.getElementById("shortcutStatus"),
  historyPrevButton: document.getElementById("historyPrevButton"),
  historyNextButton: document.getElementById("historyNextButton"),
  historyPageLabel: document.getElementById("historyPageLabel"),
  totalLogsMetric: document.getElementById("totalLogsMetric"),
  latestDateMetric: document.getElementById("latestDateMetric"),
  historyRangeMetric: document.getElementById("historyRangeMetric"),
  exportDateSelect: document.getElementById("exportDateSelect"),
  selectLatestDateButton: document.getElementById("selectLatestDateButton"),
  buildTsvButton: document.getElementById("buildTsvButton"),
  copyTsvButton: document.getElementById("copyTsvButton"),
  exportSummary: document.getElementById("exportSummary"),
  tsvPreview: document.getElementById("tsvPreview"),
  tabButtons: [...document.querySelectorAll(".tab-button")],
  tabPanels: [...document.querySelectorAll(".tab-panel")],
  editModal: document.getElementById("editModal"),
  closeEditModalButton: document.getElementById("closeEditModalButton"),
  editEventTypeSelect: document.getElementById("editEventTypeSelect"),
  editTaskNameInput: document.getElementById("editTaskNameInput"),
  editMemoInput: document.getElementById("editMemoInput"),
  editPageTitleInput: document.getElementById("editPageTitleInput"),
  editPageUrlInput: document.getElementById("editPageUrlInput"),
  deleteEditLogButton: document.getElementById("deleteEditLogButton"),
  cancelEditButton: document.getElementById("cancelEditButton"),
  saveEditButton: document.getElementById("saveEditButton"),
  snackbar: document.getElementById("snackbar"),
};

async function init() {
  hydrateEventOptions();
  state.settings = await getSettings();
  state.logs = await getLogs();
  await loadCurrentTab({ fillTaskTitle: true, forceFillTask: true });
  await loadShortcutStatus();
  renderAll({ silentPreview: true });
}

function hydrateEventOptions() {
  elements.editEventTypeSelect.innerHTML = EVENT_OPTIONS.map(
    (option) => `<option value="${option.value}">${option.label}</option>`,
  ).join("");
}

async function loadCurrentTab({
  fillTaskTitle = false,
  forceFillTask = false,
} = {}) {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  state.currentTab = tab || null;
  elements.pageTitle.textContent = tab?.title || "取得できません";
  elements.pageUrl.textContent = tab?.url || "取得できません";

  if (fillTaskTitle) {
    const nextValue = tab?.title || "";
    if (forceFillTask || !elements.taskNameInput.value.trim()) {
      elements.taskNameInput.value = nextValue;
    }
  }
}

async function loadShortcutStatus() {
  const status = await getShortcutStatus();
  elements.shortcutStatus.textContent =
    status || "ショートカット結果はここに表示されます。";
}

function clearRecordForm() {
  elements.taskNameInput.value = state.currentTab?.title || "";
  elements.memoInput.value = "";
}

function setStatus(message, kind = "neutral", options = {}) {
  const { snackbar = false } = options;
  elements.statusBadge.textContent = message;
  elements.statusBadge.className = `status-badge ${kind}`;

  if (snackbar) {
    showSnackbar(message, kind);
  }
}

function showSnackbar(message, kind = "neutral") {
  if (!elements.snackbar) {
    return;
  }

  if (state.snackbarTimer) {
    window.clearTimeout(state.snackbarTimer);
    state.snackbarTimer = null;
  }

  elements.snackbar.textContent = message;
  elements.snackbar.className = `snackbar ${kind}`;
  elements.snackbar.classList.remove("hidden");
  window.requestAnimationFrame(() => {
    elements.snackbar.classList.add("show");
  });

  state.snackbarTimer = window.setTimeout(() => {
    elements.snackbar.classList.remove("show");
    window.setTimeout(() => {
      elements.snackbar.classList.add("hidden");
    }, 180);
    state.snackbarTimer = null;
  }, 2200);
}

function getDisplayTaskName(logLike) {
  const raw = (logLike?.task_name || logLike?.page_title || "未入力").trim();
  return trimTo(raw || "未入力", 28);
}

function getEventActionLabel(eventType) {
  return EVENT_LABELS[eventType] || eventType;
}

function buildRecordedMessage(logLike) {
  return `「${getDisplayTaskName(logLike)}」を${getEventActionLabel(logLike.event_type)}として記録しました`;
}

function buildDeletedMessage(logLike) {
  return `「${getDisplayTaskName(logLike)}」を削除しました`;
}

function buildSavedMessage(logLike) {
  return `「${getDisplayTaskName(logLike)}」を保存しました`;
}

function setActiveTab(tabName) {
  state.activeTab = tabName;
  for (const button of elements.tabButtons) {
    button.classList.toggle("active", button.dataset.tab === tabName);
  }
  for (const panel of elements.tabPanels) {
    panel.classList.toggle("active", panel.id === `tab-${tabName}`);
  }
}

async function handleRecord(eventType) {
  try {
    await loadCurrentTab();
    const now = Date.now();
    const payload = {
      record_id: createId(),
      recorded_at_iso: new Date(now).toISOString(),
      recorded_at_local: toLocalString(now),
      event_type: eventType,
      task_name: elements.taskNameInput.value.trim(),
      memo: elements.memoInput.value.trim(),
      page_title: state.currentTab?.title || "タイトル取得不可",
      page_url: state.currentTab?.url || "URL取得不可",
      profile_label: state.settings.profileLabel || "",
      created_at_epoch: now,
      source: "popup",
    };

    const fingerprint = buildFingerprint(payload);
    const last = await getLastFingerprint();
    const duplicated = isDuplicate(
      last?.fingerprint,
      fingerprint,
      last?.created_at_epoch,
      now,
      state.settings.duplicateWindowSeconds,
    );

    if (duplicated) {
      setStatus("重複のため未記録", "warn", { snackbar: true });
      return;
    }

    state.logs = await appendLog(payload);
    await setLastFingerprint({ fingerprint, created_at_epoch: now });
    if (payload.task_name) {
      await setLastTaskName(payload.task_name);
    }

    if (eventType !== "BREAK") {
      elements.memoInput.value = "";
    }

    renderAll({ silentPreview: true });
    setStatus(buildRecordedMessage(payload), "ok", { snackbar: true });
  } catch (error) {
    setStatus(`失敗: ${error?.message || String(error)}`, "warn", {
      snackbar: true,
    });
  }
}

function renderAll({ silentPreview = false } = {}) {
  renderHistory();
  renderExportDateOptions();
  rebuildPreviewIfNeeded({ silent: silentPreview });
}

function renderHistory() {
  const sortedLogs = sortLogsDesc(state.logs);
  const pageData = paginate(sortedLogs, state.historyPage, HISTORY_PAGE_SIZE);
  state.historyPage = pageData.page;

  elements.totalLogsMetric.textContent = String(pageData.totalItems);
  elements.latestDateMetric.textContent = sortedLogs[0]
    ? getDatePart(sortedLogs[0].recorded_at_iso)
    : "-";
  const startNumber =
    pageData.totalItems === 0 ? 0 : (pageData.page - 1) * HISTORY_PAGE_SIZE + 1;
  const endNumber =
    pageData.totalItems === 0 ? 0 : startNumber + pageData.items.length - 1;
  elements.historyRangeMetric.textContent = `${startNumber} - ${endNumber}`;
  elements.historyPageLabel.textContent = `${pageData.page} / ${pageData.totalPages}`;
  elements.historyPrevButton.disabled = pageData.page <= 1;
  elements.historyNextButton.disabled = pageData.page >= pageData.totalPages;

  if (!pageData.items.length) {
    elements.recentLogs.className = "list-stack empty-state";
    elements.recentLogs.textContent = "まだ記録はありません。";
    return;
  }

  elements.recentLogs.className = "list-stack";
  elements.recentLogs.innerHTML = "";

  for (const log of pageData.items) {
    const item = document.createElement("article");
    item.className = "log-item";
    item.innerHTML = `
      <div class="log-top">
        <div class="log-copy">
          <p class="log-title">${escapeHtml(formatShort(log))}</p>
          <p class="log-sub">${escapeHtml(trimTo(log.memo || "メモなし", 100))}</p>
        </div>
        <div class="log-actions">
          <button class="ghost-button small" data-edit-id="${log.record_id}">編集</button>
          <button class="ghost-button small" data-delete-id="${log.record_id}">削除</button>
        </div>
      </div>
      <div class="log-tags">
        <span class="tag-pill">${escapeHtml(EVENT_LABELS[log.event_type] || log.event_type)}</span>
        ${log.task_name ? `<span class="tag-pill soft">${escapeHtml(trimTo(log.task_name, 28))}</span>` : ""}
      </div>
      <p class="log-page mono">${escapeHtml(trimTo(log.page_url, 180))}</p>
    `;
    elements.recentLogs.appendChild(item);
  }
}

function renderExportDateOptions() {
  const options = getAvailableDateOptions(state.logs);
  const previousValue = state.selectedDate;

  if (!options.length) {
    state.selectedDate = "";
    elements.exportDateSelect.innerHTML =
      '<option value="">ログがありません</option>';
    elements.exportDateSelect.disabled = true;
    elements.selectLatestDateButton.disabled = true;
    elements.exportSummary.textContent = "まだ抽出できるログがありません。";
    elements.tsvPreview.value = "";
    state.previewText = "";
    return;
  }

  elements.exportDateSelect.disabled = false;
  elements.selectLatestDateButton.disabled = false;
  const selectedValue = options.some((option) => option.value === previousValue)
    ? previousValue
    : options[0].value;
  state.selectedDate = selectedValue;
  elements.exportDateSelect.innerHTML = options
    .map(
      (option) =>
        `<option value="${option.value}" ${option.value === selectedValue ? "selected" : ""}>${option.label}</option>`,
    )
    .join("");
}

function buildPreview({ silent = false } = {}) {
  const dateValue = elements.exportDateSelect.value;
  state.selectedDate = dateValue;
  const matched = filterLogsByDate(state.logs, dateValue);
  const includeHeader = Boolean(state.settings.includeHeaderOnCopy);
  const tsv = logsToTsv(matched, includeHeader);
  state.previewText = tsv;
  elements.tsvPreview.value = tsv;
  elements.exportSummary.textContent = dateValue
    ? `${dateValue} のログ ${matched.length} 件を抽出しました。`
    : "日付を選んでください。";

  if (!silent) {
    setStatus(
      matched.length ? "抽出しました" : "対象なし",
      matched.length ? "ok" : "neutral",
      { snackbar: true },
    );
  }
}

function rebuildPreviewIfNeeded({ silent = true } = {}) {
  if (state.selectedDate) {
    buildPreview({ silent });
  }
}

async function copyPreview() {
  if (!state.previewText) {
    buildPreview();
  }
  const text = state.previewText || "";
  if (!text) {
    setStatus("コピー対象なし", "warn", { snackbar: true });
    return;
  }

  try {
    await navigator.clipboard.writeText(text);
    setStatus("コピーしました", "ok", { snackbar: true });
  } catch {
    elements.tsvPreview.focus();
    elements.tsvPreview.select();
    setStatus("プレビューを選択しました", "neutral", { snackbar: true });
  }
}

function getEditingLog() {
  return state.logs.find((log) => log.record_id === state.editingLogId) || null;
}

function openEditModal(recordId) {
  const log = state.logs.find((item) => item.record_id === recordId);
  if (!log) {
    return;
  }

  state.editingLogId = recordId;
  elements.editEventTypeSelect.value = log.event_type;
  elements.editTaskNameInput.value = log.task_name || "";
  elements.editMemoInput.value = log.memo || "";
  elements.editPageTitleInput.value = log.page_title || "";
  elements.editPageUrlInput.value = log.page_url || "";
  elements.editModal.classList.remove("hidden");
}

function closeEditModal() {
  state.editingLogId = null;
  elements.editModal.classList.add("hidden");
}

async function saveEditedLog() {
  const original = getEditingLog();
  if (!original) {
    return;
  }

  const updated = {
    ...original,
    event_type: elements.editEventTypeSelect.value,
    task_name: elements.editTaskNameInput.value.trim(),
    memo: elements.editMemoInput.value.trim(),
    page_title: elements.editPageTitleInput.value.trim(),
    page_url: elements.editPageUrlInput.value.trim(),
  };

  state.logs = await updateLog(updated);
  closeEditModal();
  renderAll({ silentPreview: true });
  setStatus(buildSavedMessage(updated), "ok", { snackbar: true });
}

async function deleteEditedLog() {
  if (!state.editingLogId) {
    return;
  }
  const targetLog = getEditingLog();
  if (!targetLog) {
    return;
  }
  state.logs = await removeLogById(state.editingLogId);
  closeEditModal();
  renderAll({ silentPreview: true });
  setStatus(buildDeletedMessage(targetLog), "ok", { snackbar: true });
}

async function handleDelete(recordId) {
  const targetLog = state.logs.find((log) => log.record_id === recordId);
  state.logs = await removeLogById(recordId);
  renderAll({ silentPreview: true });
  setStatus(buildDeletedMessage(targetLog), "ok", { snackbar: true });
}

function bindEvents() {
  elements.tabButtons.forEach((button) => {
    button.addEventListener("click", () => setActiveTab(button.dataset.tab));
  });

  elements.refreshTabButton.addEventListener("click", async () => {
    await loadCurrentTab({ fillTaskTitle: true });
    setStatus("ページ情報を更新", "neutral", { snackbar: true });
  });

  elements.openOptionsButton.addEventListener("click", () => {
    chrome.runtime.openOptionsPage();
  });

  elements.startButton.addEventListener("click", () => handleRecord("START"));
  elements.breakButton.addEventListener("click", () => handleRecord("BREAK"));
  elements.endDayButton.addEventListener("click", () =>
    handleRecord("END_DAY"),
  );

  elements.clearFormButton.addEventListener("click", () => {
    clearRecordForm();
    setStatus("入力をクリア", "neutral", { snackbar: true });
  });

  elements.historyPrevButton.addEventListener("click", () => {
    state.historyPage -= 1;
    renderHistory();
  });
  elements.historyNextButton.addEventListener("click", () => {
    state.historyPage += 1;
    renderHistory();
  });

  elements.recentLogs.addEventListener("click", async (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }
    if (target.dataset.editId) {
      openEditModal(target.dataset.editId);
      return;
    }
    if (target.dataset.deleteId) {
      await handleDelete(target.dataset.deleteId);
    }
  });

  elements.exportDateSelect.addEventListener("change", () => {
    state.selectedDate = elements.exportDateSelect.value;
    buildPreview();
  });
  elements.selectLatestDateButton.addEventListener("click", () => {
    if (elements.exportDateSelect.options.length) {
      elements.exportDateSelect.selectedIndex = 0;
      state.selectedDate = elements.exportDateSelect.value;
      buildPreview();
    }
  });
  elements.buildTsvButton.addEventListener("click", () => buildPreview());
  elements.copyTsvButton.addEventListener("click", copyPreview);

  elements.closeEditModalButton.addEventListener("click", closeEditModal);
  elements.cancelEditButton.addEventListener("click", closeEditModal);
  elements.saveEditButton.addEventListener("click", saveEditedLog);
  elements.deleteEditLogButton.addEventListener("click", deleteEditedLog);
  elements.editModal.addEventListener("click", (event) => {
    if (event.target === elements.editModal) {
      closeEditModal();
    }
  });

  window.addEventListener("keydown", (event) => {
    if (
      event.key === "Escape" &&
      !elements.editModal.classList.contains("hidden")
    ) {
      closeEditModal();
    }
  });
}

bindEvents();
init();
