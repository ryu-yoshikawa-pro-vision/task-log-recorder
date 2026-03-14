import { describe, expect, test } from "vitest";

import {
  buildFingerprint,
  escapeHtml,
  filterLogsByDate,
  getAvailableDateOptions,
  isDuplicate,
  logsToTsv,
  paginate,
} from "../chrome-extension/lib/utils.js";

describe("utils", () => {
  test("buildFingerprint normalizes empty values", () => {
    expect(
      buildFingerprint({
        event_type: "START",
        task_name: "",
        memo: null,
        page_url: undefined,
      }),
    ).toBe(
      JSON.stringify({
        event_type: "START",
        task_name: "",
        memo: "",
        page_url: "",
      }),
    );
  });

  test("isDuplicate only returns true inside the configured window", () => {
    expect(isDuplicate("same", "same", 1000, 4000, 5)).toBe(true);
    expect(isDuplicate("same", "same", 1000, 7001, 5)).toBe(false);
    expect(isDuplicate("same", "other", 1000, 4000, 5)).toBe(false);
    expect(isDuplicate(null, "same", 1000, 4000, 5)).toBe(false);
  });

  test("logsToTsv escapes tabs and line breaks", () => {
    expect(
      logsToTsv(
        [
          {
            recorded_at_local: "2026/03/14 10:00:00",
            event_type: "START",
            task_name: "task\tname",
            memo: "memo\nline",
            page_title: "title",
            page_url: "https://example.com",
          },
        ],
        true,
      ),
    ).toBe(
      [
        "記録時刻\t種別\tタスク\tメモ\tページタイトル\tURL",
        "2026/03/14 10:00:00\t開始\ttask name\tmemo line\ttitle\thttps://example.com",
      ].join("\n"),
    );
  });

  test("filterLogsByDate returns matching logs in ascending order", () => {
    const logs = [
      {
        recorded_at_iso: "2026-03-14T12:00:00.000Z",
        created_at_epoch: 200,
      },
      {
        recorded_at_iso: "2026-03-13T12:00:00.000Z",
        created_at_epoch: 100,
      },
      {
        recorded_at_iso: "2026-03-14T09:00:00.000Z",
        created_at_epoch: 150,
      },
    ];

    expect(filterLogsByDate(logs, "2026-03-14")).toEqual([
      {
        recorded_at_iso: "2026-03-14T09:00:00.000Z",
        created_at_epoch: 150,
      },
      {
        recorded_at_iso: "2026-03-14T12:00:00.000Z",
        created_at_epoch: 200,
      },
    ]);
  });

  test("getAvailableDateOptions counts logs per day and sorts latest first", () => {
    expect(
      getAvailableDateOptions([
        { recorded_at_iso: "2026-03-13T12:00:00.000Z" },
        { recorded_at_iso: "2026-03-14T09:00:00.000Z" },
        { recorded_at_iso: "2026-03-14T12:00:00.000Z" },
      ]),
    ).toEqual([
      {
        value: "2026-03-14",
        count: 2,
        label: "2026/03/14 (2件)",
      },
      {
        value: "2026-03-13",
        count: 1,
        label: "2026/03/13 (1件)",
      },
    ]);
  });

  test("paginate clamps page numbers and returns page metadata", () => {
    expect(paginate([1, 2, 3, 4, 5], 3, 2)).toEqual({
      page: 3,
      totalPages: 3,
      totalItems: 5,
      items: [5],
    });

    expect(paginate([1, 2, 3], 0, 2)).toEqual({
      page: 1,
      totalPages: 2,
      totalItems: 3,
      items: [1, 2],
    });
  });

  test("escapeHtml escapes reserved characters", () => {
    expect(escapeHtml(`<tag attr="a&b">'quoted'</tag>`)).toBe(
      "&lt;tag attr=&quot;a&amp;b&quot;&gt;&#39;quoted&#39;&lt;/tag&gt;",
    );
  });
});
