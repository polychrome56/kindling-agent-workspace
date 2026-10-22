#!/usr/bin/env python3
"""从现有编译数据库或 CMake/Ninja 导出本机索引参数；不执行构建。"""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path


def load_build(build):
    database = build / "compile_commands.json"
    if database.is_file():
        return json.loads(database.read_text())
    if not (build / "build.ninja").is_file():
        raise ValueError(f"没有 compile_commands.json 或 build.ninja：{build}")
    if not shutil.which("ninja"):
        raise ValueError("需要 ninja 才能从已有 Ninja 构建导出；也可用 --extra-db 导入 JSON")
    rules = "\n".join(p.read_text() for p in [build / "build.ninja", build / "CMakeFiles/rules.ninja"] if p.is_file())
    names = list(dict.fromkeys(re.findall(r"^rule ((?:C|CXX)_COMPILER[^\s]*)$", rules, re.M)))
    if not names:
        raise ValueError(f"未发现 CMake C/C++ 编译规则：{build}；请导入真实编译数据库")
    result = subprocess.run(["ninja", "-t", "compdb", "-x", *names], cwd=build, check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def discover(root):
    projects = [root / "kindling/probe"] + [p / "kindling/probe" for p in sorted(root.iterdir()) if p.is_dir() and not p.name.startswith(".")]
    found = []
    for project in projects:
        for name in ["cmake-build-release", "build", "cmake-build-debug"]:
            build = project / name
            if (build / "build.ninja").is_file() or (build / "compile_commands.json").is_file():
                found.append(build)
                break
    if len(found) > 1:
        raise ValueError("发现多个业务版本，请用 --build-dir 明确选择：" + ", ".join(str(p) for p in found))
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--build-dir", type=Path, action="append", default=[], help="已有 CMake/Ninja 构建目录，可重复")
    parser.add_argument("--extra-db", type=Path, action="append", default=[], help="补入 BPF、Lua 等真实编译数据库，可重复")
    parser.add_argument("--output", type=Path, help="默认工作区根 compile_commands.json（不提交）")
    args = parser.parse_args()
    root = args.workspace.resolve()
    output = (args.output or root / "compile_commands.json").resolve()
    if output.exists() and not args.build_dir and not args.extra_db:
        print(f"保留已有编译数据库：{output}；用 --build-dir/--extra-db 明确刷新")
        return
    builds = [p.resolve() for p in args.build_dir] or discover(root)
    if not builds and not args.extra_db:
        print("没有发现已配置的业务构建目录；技能可用，C/C++ 引用索引需准备编译数据库。")
        return
    entries = []
    for build in builds:
        entries.extend(load_build(build))
    for database in args.extra_db:
        entries.extend(json.loads(database.read_text()))
    commands = {}
    folders = set()
    for entry in entries:
        directory = Path(entry["directory"])
        if not directory.is_absolute():
            raise ValueError("编译数据库 directory 必须为绝对路径，请先按其来源构建目录转换")
        source = Path(entry["file"])
        source = (source if source.is_absolute() else directory / source).resolve()
        if not source.is_relative_to(root) or source.suffix.lower() not in {".c", ".cc", ".cpp", ".cxx", ".m", ".mm"}:
            continue
        relative = source.relative_to(root)
        if any(part in {"_deps", "vendor", "node_modules", ".git"} for part in relative.parts):
            continue
        # One deterministic compilation configuration per file. Separate raw/non-raw variants explicitly.
        commands.setdefault(str(source), dict(entry, file=str(source), directory=str(directory)))
        for i, part in enumerate(relative.parts):
            if part == "agent-libs":
                folders.add(Path(*relative.parts[:i + 1]))
                break
            if part == "kindling":
                project = Path(*relative.parts[:i + 1])
                for child in ["probe", "collector"]:
                    if (root / project / child).is_dir():
                        folders.add(project / child)
                break
    if not commands:
        raise ValueError("没有工作区内的 C/C++ 编译条目，拒绝覆盖数据库")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(list(commands.values()), ensure_ascii=False, indent=2) + "\n")
    report = {"entries": len(commands), "source_folders": sorted(str(p) for p in folders),
              "bpf_probe": any(p.endswith("/bpf/probe.c") for p in commands),
              "chisel": any("/chisel/" in p for p in commands)}
    runtime = root / ".local/codex"
    runtime.mkdir(parents=True, exist_ok=True)
    (runtime / "coverage.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    local_project = root / ".serena/project.local.yml"
    if folders and not local_project.exists():
        local_project.parent.mkdir(parents=True, exist_ok=True)
        # JSON strings are also valid YAML; no third-party YAML dependency needed here.
        local_project.write_text("# 本机生成，不提交。按实际业务版本调整。\nls_workspace_folders:\n" + "".join("  - " + json.dumps(str(p), ensure_ascii=False) + "\n" for p in sorted(folders)))
    print(f"已导出 {len(commands)} 个文件的编译命令：{output}")
    print("覆盖：BPF probe.c=" + str(report["bpf_probe"]) + "，Lua/chisel=" + str(report["chisel"]))
    if not report["bpf_probe"] or not report["chisel"]:
        print("缺失部分不能声称已索引；可用 --extra-db 导入真实编译命令，或定向补查。")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        raise SystemExit(f"导出失败：{exc}")
