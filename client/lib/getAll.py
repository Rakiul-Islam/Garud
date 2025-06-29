import os
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext

class DirectoryExporter:
    def __init__(self, root):
        self.root = root
        self.root.title("Directory Content Exporter")
        self.root.geometry("1000x800")

        self.current_dir = os.getcwd()
        self.output_file = "output.txt"
        self.ignore_files = [
            "firebase_options.dart", "getAll.py", "output.txt",
            "blocs/getAll.py", "blocs/output.py"
        ]

        self.selected_items = set()
        self.tree_items = {}
        self.checkbox_vars = {}

        self.notebook = ttk.Notebook(root)
        self.notebook.pack(fill=tk.BOTH, expand=True)

        self.selection_frame = ttk.Frame(self.notebook)
        self.review_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.selection_frame, text="File Selection")
        self.notebook.add(self.review_frame, text="Review & Export")
        self.notebook.bind("<<NotebookTabChanged>>", self.on_tab_changed)

        self.create_selection_ui()
        self.create_review_ui()
        self.populate_tree()

    def create_selection_ui(self):
        top = ttk.Frame(self.selection_frame)
        top.pack(fill=tk.X, padx=10, pady=5)

        ttk.Label(top, text="Directory:").pack(side=tk.LEFT)
        self.dir_entry = ttk.Entry(top, width=60)
        self.dir_entry.pack(side=tk.LEFT, padx=5)
        self.dir_entry.insert(0, self.current_dir)
        ttk.Button(top, text="Browse", command=self.browse_directory).pack(side=tk.LEFT)
        ttk.Button(top, text="Refresh", command=self.refresh_tree).pack(side=tk.LEFT, padx=5)

        self.tree = ttk.Treeview(self.selection_frame, show="tree")
        self.tree.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        self.tree.bind("<ButtonRelease-1>", self.on_tree_click)

        bottom = ttk.Frame(self.selection_frame)
        bottom.pack(fill=tk.X, padx=10, pady=5)
        ttk.Button(bottom, text="Select All", command=self.select_all).pack(side=tk.LEFT)
        ttk.Button(bottom, text="Deselect All", command=self.deselect_all).pack(side=tk.LEFT, padx=5)
        ttk.Button(bottom, text="Expand All", command=self.expand_all).pack(side=tk.LEFT, padx=5)
        ttk.Button(bottom, text="Collapse All", command=self.collapse_all).pack(side=tk.LEFT, padx=5)
        ttk.Button(bottom, text="Next: Review", command=self.show_review).pack(side=tk.RIGHT)

    def create_review_ui(self):
        frame = ttk.Frame(self.review_frame)
        frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)

        # Tree and preview area
        upper = ttk.PanedWindow(frame, orient=tk.VERTICAL)
        upper.pack(fill=tk.BOTH, expand=True)

        # Review Tree
        review_container = ttk.Labelframe(upper, text="Selected Files")
        self.review_tree = ttk.Treeview(review_container, show="tree")
        self.review_tree.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        upper.add(review_container, weight=1)

        # Line Count Preview
        preview_container = ttk.Labelframe(upper, text="Line Count Summary")
        self.preview_text = scrolledtext.ScrolledText(preview_container, wrap=tk.WORD, height=4)
        self.preview_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)
        upper.add(preview_container, weight=1)

        # Full Output Area
        output_container = ttk.Labelframe(frame, text="Full Output (Generated)")
        output_container.pack(fill=tk.BOTH, expand=True, pady=(10, 5))

        self.full_output_text = scrolledtext.ScrolledText(output_container, wrap=tk.WORD, height=15)
        self.full_output_text.pack(fill=tk.BOTH, expand=True, padx=5, pady=5)

        # Copy Button
        ttk.Button(output_container, text="Copy to Clipboard", command=self.copy_output).pack(anchor=tk.E, padx=5, pady=5)

        # Buttons
        bottom = ttk.Frame(frame)
        bottom.pack(fill=tk.X, pady=5)
        ttk.Button(bottom, text="Back", command=self.show_selection).pack(side=tk.LEFT)
        ttk.Button(bottom, text="Export to File", command=self.export_to_file).pack(side=tk.RIGHT)

    def browse_directory(self):
        folder = filedialog.askdirectory(initialdir=self.current_dir)
        if folder:
            self.current_dir = folder
            self.dir_entry.delete(0, tk.END)
            self.dir_entry.insert(0, folder)
            self.refresh_tree()

    def refresh_tree(self):
        for item in self.tree.get_children():
            self.tree.delete(item)
        self.tree_items.clear()
        self.checkbox_vars.clear()
        self.selected_items.clear()
        self.populate_tree()

    def populate_tree(self):
        base = self.current_dir
        root_name = os.path.basename(base) or base
        root_id = self.tree.insert("", "end", text="[ ] " + root_name, open=True)
        self.tree_items[base] = root_id
        self.checkbox_vars[root_id] = (tk.BooleanVar(value=False), base)
        self.add_children(base, root_id)

    def add_children(self, path, parent):
        try:
            for entry in sorted(os.listdir(path)):
                full_path = os.path.join(path, entry)
                rel_path = os.path.relpath(full_path, self.current_dir).replace("\\", "/")
                if rel_path in self.ignore_files:
                    continue
                text = "[ ] " + entry
                node_id = self.tree.insert(parent, "end", text=text, open=False)
                self.tree_items[full_path] = node_id
                self.checkbox_vars[node_id] = (tk.BooleanVar(value=False), full_path)
                if os.path.isdir(full_path):
                    self.add_children(full_path, node_id)
        except Exception:
            pass

    def on_tree_click(self, event):
        item = self.tree.identify_row(event.y)
        region = self.tree.identify("region", event.x, event.y)
        if item and region == "tree":
            if item in self.checkbox_vars:
                self.toggle_checkbox(item)

    def toggle_checkbox(self, item_id):
        var, path = self.checkbox_vars[item_id]
        new_val = not var.get()
        var.set(new_val)
        self.update_text(item_id, new_val)
        if new_val:
            self.selected_items.add(path)
        else:
            self.selected_items.discard(path)
        if os.path.isdir(path):
            self.toggle_children(item_id, new_val)

    def update_text(self, item_id, checked):
        text = self.tree.item(item_id, "text")
        label = text[4:] if text.startswith("[ ] ") or text.startswith("[x] ") else text
        new_text = ("[x] " if checked else "[ ] ") + label
        self.tree.item(item_id, text=new_text)

    def toggle_children(self, parent_id, state):
        for child_id in self.tree.get_children(parent_id):
            if child_id in self.checkbox_vars:
                var, path = self.checkbox_vars[child_id]
                var.set(state)
                self.update_text(child_id, state)
                if state:
                    self.selected_items.add(path)
                else:
                    self.selected_items.discard(path)
                if os.path.isdir(path):
                    self.toggle_children(child_id, state)

    def select_all(self):
        for item_id, (var, path) in self.checkbox_vars.items():
            var.set(True)
            self.update_text(item_id, True)
            self.selected_items.add(path)

    def deselect_all(self):
        for item_id, (var, path) in self.checkbox_vars.items():
            var.set(False)
            self.update_text(item_id, False)
            self.selected_items.discard(path)

    def expand_all(self):
        def expand_recursive(item_id):
            self.tree.item(item_id, open=True)
            for child_id in self.tree.get_children(item_id):
                expand_recursive(child_id)

        for root_item in self.tree.get_children():
            expand_recursive(root_item)

    def collapse_all(self):
        def collapse_recursive(item_id):
            self.tree.item(item_id, open=False)
            for child_id in self.tree.get_children(item_id):
                collapse_recursive(child_id)

        for root_item in self.tree.get_children():
            collapse_recursive(root_item)

    def show_selection(self):
        self.notebook.select(0)

    def show_review(self):
        self.notebook.select(1)

    def on_tab_changed(self, event):
        if self.notebook.index("current") == 1:
            self.update_review()

    def update_review(self):
        for item in self.review_tree.get_children():
            self.review_tree.delete(item)
        for path in sorted(self.selected_items):
            rel = os.path.relpath(path, self.current_dir).replace("\\", "/")
            self.review_tree.insert("", "end", text=rel)
        self.update_preview()

    def update_preview(self):
        self.preview_text.config(state=tk.NORMAL)
        self.preview_text.delete("1.0", tk.END)

        total_lines = 0
        file_count = 0
        output_buffer = []

        for path in sorted(self.selected_items):
            if os.path.isfile(path):
                rel_path = os.path.relpath(path, self.current_dir).replace("\\", "/")
                if rel_path in self.ignore_files:
                    continue
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                        total_lines += len(lines)
                        file_count += 1
                        output_buffer.append(f"// {rel_path} :\n")
                        output_buffer.extend(lines)
                        output_buffer.append("\n\n")
                except Exception as e:
                    output_buffer.append(f"// {rel_path} :\n[Error reading file: {e}]\n\n")

        self.preview_text.insert(tk.END, f"Total selected files: {file_count}\n")
        self.preview_text.insert(tk.END, f"Total lines to be exported: {total_lines}\n")
        self.preview_text.config(state=tk.DISABLED)

        # Set full output
        self.full_output_text.config(state=tk.NORMAL)
        self.full_output_text.delete("1.0", tk.END)
        self.full_output_text.insert(tk.END, "".join(output_buffer))
        self.full_output_text.config(state=tk.DISABLED)

    def copy_output(self):
        content = self.full_output_text.get("1.0", tk.END).strip()
        self.root.clipboard_clear()
        self.root.clipboard_append(content)
        messagebox.showinfo("Copied", "Full output copied to clipboard.")

    def export_to_file(self):
        if not self.selected_items:
            messagebox.showwarning("No files", "No files selected for export.")
            return

        file_path = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Text files", "*.txt"), ("All files", "*.*")],
            initialfile=self.output_file
        )

        if not file_path:
            return

        try:
            with open(file_path, "w", encoding="utf-8") as out:
                out.write(f"// Export from: {self.current_dir}\n\n")
                count = 0
                for path in sorted(self.selected_items):
                    if os.path.isfile(path):
                        rel_path = os.path.relpath(path, self.current_dir).replace("\\", "/")
                        if rel_path in self.ignore_files:
                            continue
                        out.write(f"// {rel_path} :\n")
                        try:
                            with open(path, "r", encoding="utf-8") as f:
                                out.write(f.read().strip() + "\n\n\n\n")
                                count += 1
                        except Exception as e:
                            out.write(f"[Error reading file: {e}]\n\n")
                out.write(f"// Exported {count} files\n")
            messagebox.showinfo("Export Complete", f"Successfully exported to:\n{file_path}")
        except Exception as e:
            messagebox.showerror("Export Failed", str(e))


if __name__ == "__main__":
    root = tk.Tk()
    app = DirectoryExporter(root)
    root.mainloop()
