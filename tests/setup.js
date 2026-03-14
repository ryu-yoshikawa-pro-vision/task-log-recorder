import { beforeEach } from "vitest";

const storageState = {
  data: {},
};

function cloneValue(value) {
  return structuredClone(value);
}

function resetChromeStorage(seed = {}) {
  storageState.data = cloneValue(seed);
}

function getChromeStorageSnapshot() {
  return cloneValue(storageState.data);
}

async function get(keys) {
  if (typeof keys === "undefined") {
    return getChromeStorageSnapshot();
  }

  if (typeof keys === "string") {
    return { [keys]: cloneValue(storageState.data[keys]) };
  }

  if (Array.isArray(keys)) {
    return Object.fromEntries(
      keys.map((key) => [key, cloneValue(storageState.data[key])]),
    );
  }

  if (keys && typeof keys === "object") {
    return Object.fromEntries(
      Object.entries(keys).map(([key, defaultValue]) => [
        key,
        key in storageState.data
          ? cloneValue(storageState.data[key])
          : cloneValue(defaultValue),
      ]),
    );
  }

  return {};
}

async function set(items) {
  for (const [key, value] of Object.entries(items)) {
    storageState.data[key] = cloneValue(value);
  }
}

async function remove(keys) {
  const keyList = Array.isArray(keys) ? keys : [keys];
  for (const key of keyList) {
    delete storageState.data[key];
  }
}

async function clear() {
  resetChromeStorage();
}

globalThis.chrome = {
  storage: {
    local: {
      get,
      set,
      remove,
      clear,
    },
  },
};

globalThis.__resetChromeStorage = resetChromeStorage;
globalThis.__getChromeStorageSnapshot = getChromeStorageSnapshot;

beforeEach(() => {
  resetChromeStorage();
});
