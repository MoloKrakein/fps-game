#!/usr/bin/env python3
"""
Godot 4 .tscn Scene Tree ASCII Parser for AI Agents
Extracts node hierarchies, Node Types, Attached GDScripts, and Instanced Scenes.
"""
import sys
import re
import os

def parse_tscn(filepath: str) -> None:
    if not os.path.exists(filepath):
        print(f"Error: File '{filepath}' not found.")
        return

    ext_resources = {}
    nodes = {}

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Parse external resources (scripts, packed sub-scenes)
    ext_res_pattern = re.compile(r'\[ext_resource\s+type="([^"]+)"\s+path="([^"]+)"\s+id="([^"]+)"\]')
    for match in ext_res_pattern.finditer(content):
        res_type, path, res_id = match.groups()
        ext_resources[res_id] = {"type": res_type, "path": path}

    # 2. Parse node definitions
    node_blocks = re.split(r'\n(?=\[node\s+)', content)

    for block in node_blocks:
        if not block.startswith('[node'):
            continue

        header_line = block.split('\n')[0]
        
        name_match = re.search(r'name="([^"]+)"', header_line)
        type_match = re.search(r'type="([^"]+)"', header_line)
        parent_match = re.search(r'parent="([^"]+)"', header_line)
        instance_match = re.search(r'instance=ExtResource\("([^"]+)"\)', header_line)

        if not name_match:
            continue

        node_name = name_match.group(1)
        node_type = type_match.group(1) if type_match else "Node"
        parent = parent_match.group(1) if parent_match else None
        instance_id = instance_match.group(1) if instance_match else None

        script_match = re.search(r'script\s*=\s*ExtResource\("([^"]+)"\)', block)
        script_id = script_match.group(1) if script_match else None

        script_path = ext_resources[script_id]["path"] if script_id in ext_resources else None
        instance_path = ext_resources[instance_id]["path"] if instance_id in ext_resources else None

        if parent is None:
            node_key = "."
        elif parent == ".":
            node_key = node_name
        else:
            node_key = f"{parent}/{node_name}"

        nodes[node_key] = {
            "name": node_name,
            "type": node_type,
            "parent": parent,
            "script": script_path,
            "instance": instance_path,
            "children": []
        }

    # 3. Build parent-child tree
    tree = []
    for key, node_info in nodes.items():
        p = node_info["parent"]
        if p is None:
            tree.append(node_info)
        else:
            parent_key = "." if p == "." else p
            if parent_key in nodes:
                nodes[parent_key]["children"].append(node_info)
            else:
                tree.append(node_info)

    # 4. Print ASCII representation
    def print_node(node, prefix="", is_last=True, is_root=False):
        connector = "" if is_root else ("└── " if is_last else "├── ")

        details = []
        if node["type"] != "Node":
            details.append(f"Type: {node['type']}")
        if node["instance"]:
            details.append(f"SubScene: {node['instance']}")
        if node["script"]:
            details.append(f"Script: {node['script']}")
        
        detail_str = f" [{', '.join(details)}]" if details else ""
        print(f"{prefix}{connector}{node['name']}{detail_str}")

        new_prefix = prefix + ("" if is_root else ("    " if is_last else "│   "))
        children = node["children"]
        for i, child in enumerate(children):
            print_node(child, new_prefix, i == len(children) - 1, is_root=False)

    for root_node in tree:
        print_node(root_node, is_root=True)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/parse_tscn.py <path_to_scene.tscn>")
    else:
        parse_tscn(sys.argv[1])
