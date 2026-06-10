#!/usr/bin/env python3
"""
Exports a plugin directory into a .pck file for deployment.

Usage:
    python3 export_plugin_pck.py plugins/dnd --output dnd.pck

The .pck preserves res:// paths so the main application can load it
with ProjectSettings.load_resource_pack().
"""

import argparse
import struct
import os
import hashlib


def pack_files(source_dir: str, res_prefix: str, output_path: str):
    """
    Create a Godot .pck file from a directory.
    All files will be mapped to res://<res_prefix>/filename.
    """
    files_to_pack = []
    for root, dirs, files in os.walk(source_dir):
        for fname in files:
            # Skip .uid files and import files
            if fname.endswith(('.uid', '.import')):
                continue
            full_path = os.path.join(root, fname)
            rel_path = os.path.relpath(full_path, source_dir)
            res_path = f"res://{res_prefix}/{rel_path}".replace("\\", "/")
            files_to_pack.append((full_path, res_path))

    if not files_to_pack:
        print("No files found to pack.")
        return

    print(f"Packing {len(files_to_pack)} file(s) into {output_path}:")
    for _, res_path in files_to_pack:
        print(f"  {res_path}")

    with open(output_path, 'wb') as f:
        # PCK header
        f.write(b'GDPC')                          # Magic
        f.write(struct.pack('<I', 2))             # Pack format version
        f.write(struct.pack('<I', 4))             # Godot major
        f.write(struct.pack('<I', 0))             # Godot minor
        f.write(struct.pack('<I', 0))             # Godot patch
        # Flags (Godot 4 encryption flags)
        f.write(struct.pack('<I', 0))
        # File offset (filled later)
        files_base_offset_pos = f.tell()
        f.write(struct.pack('<Q', 0))             # files base offset placeholder
        # Reserved
        for _ in range(16):
            f.write(struct.pack('<I', 0))

        # File count
        f.write(struct.pack('<I', len(files_to_pack)))

        # Build file entries (path, offset, size, md5)
        file_entries = []
        for full_path, res_path in files_to_pack:
            file_data = open(full_path, 'rb').read()
            md5 = hashlib.md5(file_data).digest()
            file_entries.append({
                'res_path': res_path,
                'data': file_data,
                'size': len(file_data),
                'md5': md5,
            })

        # Write file table (path + placeholder offset + size + md5)
        entry_offset_positions = []
        for entry in file_entries:
            path_bytes = entry['res_path'].encode('utf-8')
            # Path length (padded to 4-byte alignment)
            path_len = len(path_bytes)
            padded_len = (path_len + 3) & ~3
            f.write(struct.pack('<I', padded_len))
            f.write(path_bytes)
            f.write(b'\x00' * (padded_len - path_len))
            # Offset placeholder
            entry_offset_positions.append(f.tell())
            f.write(struct.pack('<Q', 0))
            # Size
            f.write(struct.pack('<Q', entry['size']))
            # MD5
            f.write(entry['md5'])

        # Write file data and fill offsets
        for i, entry in enumerate(file_entries):
            # Align to 64 bytes
            pos = f.tell()
            align = (64 - (pos % 64)) % 64
            f.write(b'\x00' * align)

            offset = f.tell()
            f.write(entry['data'])

            # Go back and fill offset
            current = f.tell()
            f.seek(entry_offset_positions[i])
            f.write(struct.pack('<Q', offset))
            f.seek(current)

    print(f"Done: {output_path} ({os.path.getsize(output_path)} bytes)")


def main():
    parser = argparse.ArgumentParser(description="Export a Godot plugin as a .pck file")
    parser.add_argument("plugin_dir", help="Path to the plugin directory (e.g., plugins/dnd)")
    parser.add_argument("--output", "-o", help="Output .pck filename", default=None)
    parser.add_argument("--prefix", "-p", help="res:// prefix (default: plugins/<dirname>)", default=None)
    args = parser.parse_args()

    plugin_dir = args.plugin_dir.rstrip("/\\")
    dirname = os.path.basename(plugin_dir)

    prefix = args.prefix or f"plugins/{dirname}"
    output = args.output or f"{dirname}.pck"

    if not os.path.isdir(plugin_dir):
        print(f"Error: {plugin_dir} is not a directory")
        return

    pack_files(plugin_dir, prefix, output)


if __name__ == "__main__":
    main()
