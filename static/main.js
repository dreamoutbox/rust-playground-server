const DEFAULT_CODE = `fn main() {
    println!("Hello from Firecracker microVM!");

    let numbers = [1, 2, 3, 4, 5];
    let sum: i32 = numbers.iter().sum();
    println!("Sum of numbers: {sum}");
}
`;

const fallback = document.getElementById("code-fallback");
fallback.value = DEFAULT_CODE;

let editorView = null;

// Strip ANSI escape codes from compiler and terminal output
function stripAnsi(text) {
    return text.replace(/[\u001b\u009b][[()#;?]*(?:[0-9]{1,4}(?:;[0-9]{0,4})*)?[0-9A-ORZcf-nqry=><]/g, '');
}

function getCode() {
    if (editorView) {
        return editorView.state.doc.toString();
    }
    return fallback.value;
}

function setCode(code) {
    if (editorView) {
        editorView.dispatch({
            changes: { from: 0, to: editorView.state.doc.length, insert: code }
        });
    } else {
        fallback.value = code;
    }
}

// Initialize CodeMirror 6 via CDN, falling back to textarea on failure
async function initEditor() {
    try {
        const { basicSetup, EditorView } = await import("https://esm.sh/codemirror@6.0.1");
        const { rust } = await import("https://esm.sh/@codemirror/lang-rust@6.0.1");
        const { oneDark } = await import("https://esm.sh/@codemirror/theme-one-dark@6.1.2");

        fallback.style.display = "none";
        editorView = new EditorView({
            doc: DEFAULT_CODE,
            extensions: [
                basicSetup,
                rust(),
                oneDark,
                EditorView.theme({
                    "&": { height: "100%", background: "#0f141c" },
                    ".cm-gutters": { backgroundColor: "#0f141c", borderRight: "1px solid #1e2633", color: "#4f5e73" },
                    ".cm-content": { caretColor: "#38bdf8" },
                    "&.cm-focused .cm-cursor": { borderLeftColor: "#38bdf8" },
                    "&.cm-focused .cm-selectionBackground, ::selection": { backgroundColor: "#1d3557" },
                    ".cm-activeLine": { backgroundColor: "#141c26" }
                })
            ],
            parent: document.getElementById("editor-container")
        });
    } catch (err) {
        console.warn("CDN CodeMirror load failed; using enhanced textarea fallback", err);
        fallback.style.display = "block";
    }
}

initEditor();

// Drag-to-resize logic for left editor & right output panel
const mainContainer = document.querySelector("main");
const resizer = document.getElementById("resizer");
const outputPanel = document.getElementById("output-panel");

let isDragging = false;

resizer.addEventListener("mousedown", (e) => {
    isDragging = true;
    resizer.classList.add("dragging");
    document.body.style.cursor = "col-resize";
    document.body.style.userSelect = "none";
    e.preventDefault();
});

window.addEventListener("mousemove", (e) => {
    if (!isDragging) return;
    const containerRect = mainContainer.getBoundingClientRect();
    const newWidth = containerRect.right - e.clientX;
    const minWidth = 200;
    const maxWidth = containerRect.width - 200;
    if (newWidth >= minWidth && newWidth <= maxWidth) {
        outputPanel.style.width = `${newWidth}px`;
        outputPanel.style.flex = "none";
    }
});

window.addEventListener("mouseup", () => {
    if (isDragging) {
        isDragging = false;
        resizer.classList.remove("dragging");
        document.body.style.cursor = "";
        document.body.style.userSelect = "";
    }
});

// Touch support for resizing
resizer.addEventListener("touchstart", () => {
    isDragging = true;
    resizer.classList.add("dragging");
    document.body.style.userSelect = "none";
}, { passive: true });

window.addEventListener("touchmove", (e) => {
    if (!isDragging || !e.touches[0]) return;
    const containerRect = mainContainer.getBoundingClientRect();
    const touch = e.touches[0];
    const newWidth = containerRect.right - touch.clientX;
    const minWidth = 150;
    const maxWidth = containerRect.width - 150;
    if (newWidth >= minWidth && newWidth <= maxWidth) {
        outputPanel.style.width = `${newWidth}px`;
        outputPanel.style.flex = "none";
    }
}, { passive: true });

window.addEventListener("touchend", () => {
    if (isDragging) {
        isDragging = false;
        resizer.classList.remove("dragging");
        document.body.style.userSelect = "";
    }
});

// Run execution logic
const btnRun = document.getElementById("btn-run");
const btnReset = document.getElementById("btn-reset");
const runSpinner = document.getElementById("run-spinner");
const runLabel = document.getElementById("run-label");
const outputContent = document.getElementById("output-content");
const execStatus = document.getElementById("exec-status");
const execTime = document.getElementById("exec-time");

async function executeCode() {
    if (btnRun.disabled) return;

    const code = getCode();
    btnRun.disabled = true;
    runSpinner.style.display = "inline-block";
    runLabel.textContent = "Running...";
    execStatus.className = "status-badge running";
    execStatus.textContent = "Executing in microVM...";
    execTime.style.display = "none";
    outputContent.textContent = "Booting isolated Firecracker microVM & compiling...";

    try {
        const res = await fetch("/run", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ code })
        });

        if (!res.ok) {
            throw new Error(`HTTP error ${res.status}`);
        }

        const data = await res.json();
        execTime.style.display = "inline";
        execTime.textContent = `${(data.elapsed_ms / 1000).toFixed(2)}s`;

        if (data.error) {
            execStatus.className = "status-badge error";
            execStatus.textContent = "Error";
            outputContent.textContent = stripAnsi(data.error);
        } else {
            execStatus.className = "status-badge success";
            execStatus.textContent = "Success";
            outputContent.textContent = stripAnsi(data.stdout || "(program produced no output)");
        }
    } catch (err) {
        execStatus.className = "status-badge error";
        execStatus.textContent = "Network Error";
        outputContent.textContent = `Failed to contact playground server: ${err.message}`;
    } finally {
        btnRun.disabled = false;
        runSpinner.style.display = "none";
        runLabel.textContent = "Run";
    }
}

btnRun.addEventListener("click", executeCode);
btnReset.addEventListener("click", () => setCode(DEFAULT_CODE));

// Keyboard shortcut: Ctrl+Enter or Cmd+Enter
window.addEventListener("keydown", (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === "Enter") {
        e.preventDefault();
        executeCode();
    }
});
