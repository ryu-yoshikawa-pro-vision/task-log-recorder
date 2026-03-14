export const EVENT_LABELS = {
  START: "開始",
  BREAK: "休憩",
  END_DAY: "終了",
};

export const EVENT_OPTIONS = [
  { value: "START", label: "開始" },
  { value: "BREAK", label: "休憩" },
  { value: "END_DAY", label: "終了" },
];

export function createId() {
  if (globalThis.crypto?.randomUUID) {
    return crypto.randomUUID();
  }
  return `log_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

export function toLocalString(dateInput = new Date()) {
  const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
  return new Intl.DateTimeFormat(undefined, {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  }).format(date);
}

export function getTodayInputValue(dateInput = new Date()) {
  const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, "0");
  const day = `${date.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function getDatePart(dateInput) {
  const date = dateInput instanceof Date ? dateInput : new Date(dateInput);
  return getTodayInputValue(date);
}

export function formatDateLabel(dateValue) {
  if (!dateValue) {
    return "";
  }
  const [year, month, day] = dateValue.split("-");
  return `${year}/${month}/${day}`;
}

export function buildFingerprint({ event_type, task_name, memo, page_url }) {
  return JSON.stringify({
    event_type: event_type || "",
    task_name: task_name || "",
    memo: memo || "",
    page_url: page_url || "",
  });
}

export function isDuplicate(
  lastFingerprint,
  candidateFingerprint,
  lastTimestamp,
  nowTimestamp,
  duplicateWindowSeconds,
) {
  if (!lastFingerprint || !lastTimestamp) {
    return false;
  }
  const windowMs = Number(duplicateWindowSeconds || 0) * 1000;
  if (windowMs <= 0) {
    return false;
  }
  return (
    lastFingerprint === candidateFingerprint &&
    nowTimestamp - lastTimestamp <= windowMs
  );
}

export function formatShort(log) {
  const label = EVENT_LABELS[log.event_type] || log.event_type;
  const task = log.task_name || "（未入力）";
  return `${log.recorded_at_local} / ${label} / ${task}`;
}

export function escapeTsv(value) {
  return String(value ?? "")
    .replace(/\t/g, " ")
    .replace(/\r?\n/g, " ");
}

export function logsToTsv(logs, includeHeader = true) {
  const header = [
    "記録時刻",
    "種別",
    "タスク",
    "メモ",
    "ページタイトル",
    "URL",
  ];
  const rows = logs.map((log) => [
    log.recorded_at_local,
    EVENT_LABELS[log.event_type] || log.event_type,
    log.task_name || "",
    log.memo || "",
    log.page_title || "",
    log.page_url || "",
  ]);

  const lines = [];
  if (includeHeader) {
    lines.push(header.map(escapeTsv).join("\t"));
  }
  for (const row of rows) {
    lines.push(row.map(escapeTsv).join("\t"));
  }
  return lines.join("\n");
}

export function sortLogsDesc(logs) {
  return [...logs].sort((a, b) => b.created_at_epoch - a.created_at_epoch);
}

export function sortLogsAsc(logs) {
  return [...logs].sort((a, b) => a.created_at_epoch - b.created_at_epoch);
}

export function filterLogsByDate(logs, dateValue) {
  if (!dateValue) {
    return [];
  }
  return sortLogsAsc(
    logs.filter((log) => getDatePart(log.recorded_at_iso) === dateValue),
  );
}

export function getAvailableDateOptions(logs) {
  const counts = new Map();
  for (const log of logs) {
    const dateValue = getDatePart(log.recorded_at_iso);
    counts.set(dateValue, (counts.get(dateValue) || 0) + 1);
  }
  return [...counts.entries()]
    .sort((a, b) => String(b[0]).localeCompare(String(a[0])))
    .map(([value, count]) => ({
      value,
      count,
      label: `${formatDateLabel(value)} (${count}件)`,
    }));
}

export function paginate(items, page = 1, pageSize = 10) {
  const totalItems = items.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
  const safePage = Math.min(Math.max(1, page), totalPages);
  const start = (safePage - 1) * pageSize;
  return {
    page: safePage,
    totalPages,
    totalItems,
    items: items.slice(start, start + pageSize),
  };
}

export function trimTo(str, max = 80) {
  const text = String(str ?? "");
  return text.length > max ? `${text.slice(0, max - 1)}…` : text;
}

export function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
