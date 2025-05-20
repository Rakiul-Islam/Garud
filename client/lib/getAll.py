import os

output_file = "output.txt"
current_dir = os.getcwd()

# List of relative file paths to ignore
ignoreFiles = ["firebase_options.dart", "getAll.py", "output.txt"]

with open(output_file, 'w', encoding='utf-8') as out:
    for root, dirs, files in os.walk(current_dir):
        for file in files:
            file_path = os.path.join(root, file)
            relative_path = os.path.relpath(file_path, current_dir).replace("\\", "/")  # Normalize for Windows

            if relative_path in ignoreFiles:
                continue

            out.write(f"// {relative_path} :\n")
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                    out.write(content.strip() + "\n\n\n\n")
            except Exception as e:
                out.write(f"[Error reading file: {e}]\n\n")

print(f"Filtered file contents saved to {output_file}")
