import { useEffect, useReducer, useRef, useState } from "react";

const API = import.meta.env.VITE_API_URL ?? "http://localhost:8080";

interface Item {
  id: number;
  key: string;
  value: string;
  created_at: string;
}

type Modal =
  | { type: "none" }
  | { type: "add" }
  | { type: "edit"; item: Item };

type State = {
  items: Item[];
  loading: boolean;
  error: string | null;
  modal: Modal;
  saving: boolean;
};

type Action =
  | { type: "FETCH_START" }
  | { type: "FETCH_OK"; items: Item[] }
  | { type: "FETCH_ERR"; error: string }
  | { type: "OPEN_ADD" }
  | { type: "OPEN_EDIT"; item: Item }
  | { type: "CLOSE_MODAL" }
  | { type: "SAVE_START" }
  | { type: "SAVE_OK"; item: Item }
  | { type: "DELETE_OK"; id: number }
  | { type: "CLEAR_ERROR" };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case "FETCH_START":
      return { ...state, loading: true, error: null };
    case "FETCH_OK":
      return { ...state, loading: false, items: action.items };
    case "FETCH_ERR":
      return { ...state, loading: false, error: action.error };
    case "OPEN_ADD":
      return { ...state, modal: { type: "add" } };
    case "OPEN_EDIT":
      return { ...state, modal: { type: "edit", item: action.item } };
    case "CLOSE_MODAL":
      return { ...state, modal: { type: "none" } };
    case "SAVE_START":
      return { ...state, saving: true, error: null };
    case "SAVE_OK": {
      const exists = state.items.some((i) => i.id === action.item.id);
      const items = exists
        ? state.items.map((i) => (i.id === action.item.id ? action.item : i))
        : [...state.items, action.item];
      return { ...state, saving: false, modal: { type: "none" }, items };
    }
    case "DELETE_OK":
      return { ...state, items: state.items.filter((i) => i.id !== action.id) };
    case "CLEAR_ERROR":
      return { ...state, error: null };
  }
}

const initial: State = {
  items: [],
  loading: true,
  error: null,
  modal: { type: "none" },
  saving: false,
};

export default function KeyValueStore() {
  const [state, dispatch] = useReducer(reducer, initial);
  const keyRef = useRef<HTMLInputElement>(null);
  const [formKey, setFormKey] = useState("");
  const [formValue, setFormValue] = useState("");

  async function fetchItems() {
    dispatch({ type: "FETCH_START" });
    try {
      const res = await fetch(`${API}/items`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      dispatch({ type: "FETCH_OK", items: await res.json() });
    } catch (e) {
      dispatch({ type: "FETCH_ERR", error: String(e) });
    }
  }

  useEffect(() => { fetchItems(); }, []);

  useEffect(() => {
    if (state.modal.type === "none") return;
    if (state.modal.type === "add") {
      setFormKey("");
      setFormValue("");
    } else {
      setFormKey(state.modal.item.key);
      setFormValue(state.modal.item.value);
    }
    setTimeout(() => keyRef.current?.focus(), 50);
  }, [state.modal.type]);

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    if (!formKey.trim() || !formValue.trim()) return;
    dispatch({ type: "SAVE_START" });
    try {
      const isEdit = state.modal.type === "edit";
      const url = isEdit && state.modal.type === "edit"
        ? `${API}/items/${state.modal.item.id}`
        : `${API}/items`;
      const res = await fetch(url, {
        method: isEdit ? "PATCH" : "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: formKey.trim(), value: formValue.trim() }),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      dispatch({ type: "SAVE_OK", item: await res.json() });
    } catch (e) {
      dispatch({ type: "FETCH_ERR", error: String(e) });
    }
  }

  async function handleDelete(id: number) {
    try {
      const res = await fetch(`${API}/items/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      dispatch({ type: "DELETE_OK", id });
    } catch (e) {
      dispatch({ type: "FETCH_ERR", error: String(e) });
    }
  }

  const modalOpen = state.modal.type !== "none";
  const modalTitle = state.modal.type === "edit" ? "Edit item" : "Add item";

  return (
    <div style={s.page}>
      <div style={s.container}>
        <div style={s.header}>
          <h1 style={s.heading}>Key / Value Store</h1>
          <button style={s.btnPrimary} onClick={() => dispatch({ type: "OPEN_ADD" })}>
            + Add
          </button>
        </div>

        {state.error && (
          <div style={s.error}>
            {state.error}
            <button style={s.errorClose} onClick={() => dispatch({ type: "CLEAR_ERROR" })}>✕</button>
          </div>
        )}

        <div style={s.tableWrapper}>
          {state.loading ? (
            <div style={s.empty}>Loading…</div>
          ) : (
            <table style={s.table}>
              <thead>
                <tr>
                  <th style={{ ...s.th, width: 56 }}>ID</th>
                  <th style={s.th}>Key</th>
                  <th style={s.th}>Value</th>
                  <th style={{ ...s.th, width: 100 }} />
                </tr>
              </thead>
              <tbody>
                {state.items.length === 0 ? (
                  <tr>
                    <td colSpan={4} style={s.emptyCell}>
                      No entries yet — click <strong>+ Add</strong> to create one.
                    </td>
                  </tr>
                ) : (
                  state.items.map((item) => (
                    <tr key={item.id} style={s.row}>
                      <td style={{ ...s.td, ...s.tdMuted }}>{item.id}</td>
                      <td style={{ ...s.td, ...s.tdKey }}>{item.key}</td>
                      <td style={s.td}>{item.value}</td>
                      <td style={{ ...s.td, ...s.tdActions }}>
                        <button
                          style={s.btnRowEdit}
                          onClick={() => dispatch({ type: "OPEN_EDIT", item })}
                          title="Edit"
                        >
                          Edit
                        </button>
                        <button
                          style={s.btnRowDelete}
                          onClick={() => handleDelete(item.id)}
                          title="Delete"
                        >
                          Delete
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          )}
        </div>
      </div>

      {modalOpen && (
        <div style={s.overlay} onClick={() => dispatch({ type: "CLOSE_MODAL" })}>
          <div style={s.modal} onClick={(e) => e.stopPropagation()}>
            <h2 style={s.modalTitle}>{modalTitle}</h2>
            <form onSubmit={handleSave} style={s.form}>
              <div style={s.formRow}>
                <label style={s.label}>Key</label>
                <input
                  ref={keyRef}
                  style={s.input}
                  value={formKey}
                  onChange={(e) => setFormKey(e.target.value)}
                  placeholder="e.g. color"
                  required
                />
              </div>
              <div style={s.formRow}>
                <label style={s.label}>Value</label>
                <input
                  style={s.input}
                  value={formValue}
                  onChange={(e) => setFormValue(e.target.value)}
                  placeholder="e.g. blue"
                  required
                />
              </div>
              <div style={s.formActions}>
                <button type="submit" style={s.btnPrimary} disabled={state.saving}>
                  {state.saving ? "Saving…" : "Save"}
                </button>
                <button
                  type="button"
                  style={s.btnSecondary}
                  onClick={() => dispatch({ type: "CLOSE_MODAL" })}
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

const s: Record<string, React.CSSProperties> = {
  page: {
    minHeight: "100vh",
    background: "#f5f5f5",
    display: "flex",
    justifyContent: "center",
    padding: "48px 24px",
  },
  container: {
    width: "100%",
    maxWidth: 760,
    display: "flex",
    flexDirection: "column",
    gap: 20,
  },
  header: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
  },
  heading: {
    fontSize: 26,
    fontWeight: 700,
    letterSpacing: "-0.4px",
  },
  tableWrapper: {
    background: "#fff",
    borderRadius: 10,
    border: "1px solid #e5e7eb",
    overflow: "hidden",
    boxShadow: "0 1px 3px rgba(0,0,0,0.06)",
  },
  table: {
    width: "100%",
    borderCollapse: "collapse",
    fontSize: 15,
  },
  th: {
    textAlign: "left",
    padding: "11px 16px",
    background: "#f9fafb",
    borderBottom: "1px solid #e5e7eb",
    fontWeight: 600,
    fontSize: 12,
    color: "#6b7280",
    textTransform: "uppercase",
    letterSpacing: "0.05em",
  },
  row: { transition: "background 0.1s" },
  td: {
    padding: "12px 16px",
    borderBottom: "1px solid #f3f4f6",
    verticalAlign: "middle",
  },
  tdMuted: { color: "#9ca3af", fontSize: 13 },
  tdKey: { fontWeight: 600, fontFamily: "ui-monospace, monospace", fontSize: 14 },
  tdActions: { display: "flex", gap: 8, justifyContent: "flex-end" },
  emptyCell: { padding: "36px 16px", textAlign: "center", color: "#9ca3af", fontSize: 14 },
  empty: { padding: "36px 16px", textAlign: "center", color: "#9ca3af", fontSize: 14 },
  btnPrimary: {
    padding: "9px 18px",
    background: "#2563eb",
    color: "#fff",
    border: "none",
    borderRadius: 7,
    fontSize: 14,
    fontWeight: 600,
    cursor: "pointer",
  },
  btnSecondary: {
    padding: "9px 18px",
    background: "#f3f4f6",
    color: "#374151",
    border: "1px solid #e5e7eb",
    borderRadius: 7,
    fontSize: 14,
    fontWeight: 600,
    cursor: "pointer",
  },
  btnRowEdit: {
    padding: "5px 12px",
    background: "#f3f4f6",
    color: "#374151",
    border: "1px solid #e5e7eb",
    borderRadius: 5,
    fontSize: 13,
    fontWeight: 500,
    cursor: "pointer",
  },
  btnRowDelete: {
    padding: "5px 12px",
    background: "#fff",
    color: "#dc2626",
    border: "1px solid #fecaca",
    borderRadius: 5,
    fontSize: 13,
    fontWeight: 500,
    cursor: "pointer",
  },
  overlay: {
    position: "fixed",
    inset: 0,
    background: "rgba(0,0,0,0.35)",
    display: "flex",
    alignItems: "center",
    justifyContent: "center",
    zIndex: 100,
  },
  modal: {
    background: "#fff",
    borderRadius: 12,
    padding: 28,
    width: "100%",
    maxWidth: 440,
    boxShadow: "0 20px 40px rgba(0,0,0,0.15)",
    display: "flex",
    flexDirection: "column",
    gap: 20,
  },
  modalTitle: { fontSize: 18, fontWeight: 700, margin: 0 },
  form: { display: "flex", flexDirection: "column", gap: 14 },
  formRow: { display: "flex", flexDirection: "column", gap: 6 },
  label: { fontSize: 13, fontWeight: 600, color: "#374151" },
  input: {
    padding: "9px 12px",
    border: "1px solid #d1d5db",
    borderRadius: 6,
    fontSize: 15,
    outline: "none",
  },
  formActions: { display: "flex", gap: 10, paddingTop: 4 },
  error: {
    background: "#fef2f2",
    border: "1px solid #fecaca",
    color: "#dc2626",
    borderRadius: 8,
    padding: "12px 16px",
    fontSize: 14,
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
  },
  errorClose: { background: "none", border: "none", cursor: "pointer", color: "#dc2626", fontSize: 16 },
};
