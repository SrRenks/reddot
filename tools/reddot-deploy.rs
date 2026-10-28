//! Rust port of the ownership/deploy core in installer/deploy.py.
//! It plans or applies the deploy-set copy, markers, backups, preserved files and
//! uninstall. Content neutralization is a separate phase.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};

const MARKER: &str = ".reddot-managed";
const DEPLOY_SET: [(&str, &str, &str); 7] = [
    ("hypr", "hypr", "hypr"),
    ("quickshell", "quickshell", "quickshell"),
    ("ghostty", "ghostty", "ghostty"),
    ("fish", "fish", "fish"),
    ("fastfetch", "fastfetch", "fastfetch"),
    ("kdeglobals", "kde/kdeglobals", "kdeglobals"),
    ("session", "systemd/user/hyprland-session.target", "systemd/user/hyprland-session.target"),
];
const COPY_IGNORE: [&str; 4] = ["test_*.py", "__pycache__", "*.pyc", "hypridle.conf"];
const PRESERVED: [&str; 11] = [
    "hypr/modules/decoration.lua",
    "hypr/modules/binds.lua",
    "hypr/modules/monitors.lua",
    "hypr/modules/input.lua",
    "hypr/modules/env.lua",
    "hypr/modules/autostart.lua",
    "hypr/modules/animations.lua",
    "hypr/modules/stash-apps.lua",
    "hypr/modules/spaces.lua",
    "hypr/hypridle.conf",
    "fish/config.fish",
];

fn wildcard(part: &str, pattern: &str) -> bool {
    let p = pattern.as_bytes();
    let s = part.as_bytes();
    let (mut pi, mut si) = (0usize, 0usize);
    let (mut star, mut mark) = (None, 0usize);
    while si < s.len() {
        if pi < p.len() && (p[pi] == b'?' || p[pi] == s[si]) {
            pi += 1;
            si += 1;
        } else if pi < p.len() && p[pi] == b'*' {
            star = Some(pi);
            pi += 1;
            mark = si;
        } else if let Some(st) = star {
            pi = st + 1;
            mark += 1;
            si = mark;
        } else {
            return false;
        }
    }
    while pi < p.len() && p[pi] == b'*' {
        pi += 1;
    }
    pi == p.len()
}

fn ignored(name: &str) -> bool {
    COPY_IGNORE.iter().any(|pat| wildcard(name, pat))
}

fn marker_for(dest: &Path) -> PathBuf {
    let is_dir = dest.is_dir() && !dest.is_symlink();
    if is_dir {
        dest.join(MARKER)
    } else {
        dest.with_file_name(format!("{}{MARKER}", dest.file_name().and_then(|s| s.to_str()).unwrap_or("dest")))
    }
}

fn is_managed(dest: &Path) -> bool {
    marker_for(dest).is_file()
}

fn remove(path: &Path) -> Result<(), String> {
    if path.is_dir() && !path.is_symlink() {
        fs::remove_dir_all(path).map_err(|e| e.to_string())
    } else if path.exists() || path.is_symlink() {
        fs::remove_file(path).map_err(|e| e.to_string())
    } else {
        Ok(())
    }
}

fn copy_tree(src: &Path, dest: &Path) -> Result<(), String> {
    if let Some(parent) = dest.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    if src.is_dir() {
        fs::create_dir_all(dest).map_err(|e| e.to_string())?;
        for entry in fs::read_dir(src).map_err(|e| e.to_string())? {
            let entry = entry.map_err(|e| e.to_string())?;
            let name = entry.file_name().to_string_lossy().into_owned();
            if ignored(&name) {
                continue;
            }
            let from = entry.path();
            let to = dest.join(&name);
            if entry.file_type().map_err(|e| e.to_string())?.is_dir() {
                copy_tree(&from, &to)?;
            } else {
                fs::copy(&from, &to).map_err(|e| e.to_string())?;
                if let Ok(meta) = fs::metadata(&from) {
                    let _ = fs::set_permissions(&to, fs::Permissions::from_mode(meta.permissions().mode()));
                }
            }
        }
        Ok(())
    } else {
        fs::copy(src, dest).map_err(|e| e.to_string())?;
        Ok(())
    }
}

fn prune_empty(start: &Path, stop: &Path) {
    let mut d = start.to_path_buf();
    while d != stop && d.starts_with(stop) {
        if fs::remove_dir(&d).is_err() {
            break;
        }
        match d.parent() {
            Some(parent) => d = parent.to_path_buf(),
            None => break,
        }
    }
}

fn backup(target: &Path, apply: bool) -> Result<Option<String>, String> {
    if !target.exists() && !target.is_symlink() {
        return Ok(None);
    }
    let mut bak = target.with_file_name(format!("{}.bak", target.file_name().and_then(|s| s.to_str()).unwrap_or("dest")));
    let mut n = 1;
    while bak.exists() || bak.is_symlink() {
        bak = target.with_file_name(format!("{}.bak.{n}", target.file_name().and_then(|s| s.to_str()).unwrap_or("dest")));
        n += 1;
    }
    if apply {
        fs::rename(target, &bak).map_err(|e| e.to_string())?;
    }
    Ok(Some(bak.to_string_lossy().into_owned()))
}

fn json(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}
fn arr(items: &[String]) -> String {
    format!("[{}]", items.iter().map(|s| json(s)).collect::<Vec<_>>().join(","))
}
fn action_json(fields: &[(&str, &str)]) -> String {
    let body: Vec<String> = fields.iter().map(|(k, v)| format!("\"{k}\":{}", json(v))).collect();
    format!("{{{}}}", body.join(","))
}

fn detect(config_root: &Path) -> Vec<(String, String, bool, bool, String)> {
    DEPLOY_SET.iter().map(|(name, _, dest_rel)| {
        let dest = config_root.join(dest_rel);
        let exists = dest.exists() || dest.is_symlink();
        let managed = if exists { is_managed(&dest) } else { false };
        let status = if !exists { "absent" } else if managed { "managed" } else { "foreign" };
        ((*name).into(), dest.to_string_lossy().into_owned(), exists, managed, status.into())
    }).collect()
}

fn deploy(src: &Path, config_root: &Path, apply: bool) -> Result<Vec<String>, String> {
    let mut actions = Vec::new();
    for (name, src_rel, dest_rel) in DEPLOY_SET {
        let src_path = src.join(src_rel);
        let dest = config_root.join(dest_rel);
        if !src_path.exists() {
            actions.push(action_json(&[
                ("item", name), ("action", "skip"), ("reason", "missing in source"), ("src", &src_path.to_string_lossy()),
            ]));
            continue;
        }
        let exists = dest.exists() || dest.is_symlink();
        let managed = exists && is_managed(&dest);
        let bak = if exists && !managed { backup(&dest, false)? } else { None };
        let keep: Vec<String> = if managed {
            PRESERVED.iter()
                .filter(|rel| rel.starts_with(&format!("{dest_rel}/")) && config_root.join(rel).is_file())
                .map(|s| (*s).to_string())
                .collect()
        } else { Vec::new() };
        let src_text = src_path.to_string_lossy().into_owned();
        let dest_text = dest.to_string_lossy().into_owned();
        let bak_str = bak.unwrap_or_default();
        let keep_json = arr(&keep);
        let body = format!(
            "{{\"item\":{},\"action\":{},\"src\":{},\"dest\":{},\"backup\":{},\"managed\":{},\"preserved\":{}}}",
            json(name),
            json(if managed { "replace" } else { "deploy" }),
            json(&src_text), json(&dest_text),
            if bak_str.is_empty() { "null".into() } else { json(&bak_str) },
            managed, keep_json
        );
        actions.push(body);
        if !apply { continue; }
        let saved: BTreeMap<String, Vec<u8>> = keep.iter().filter_map(|rel| {
            fs::read(config_root.join(rel)).ok().map(|data| (rel.clone(), data))
        }).collect();
        if managed {
            remove(&dest)?;
        } else {
            backup(&dest, true)?;
        }
        copy_tree(&src_path, &dest)?;
        for (rel, data) in saved {
            let path = config_root.join(rel);
            if let Some(parent) = path.parent() { fs::create_dir_all(parent).map_err(|e| e.to_string())?; }
            fs::write(path, data).map_err(|e| e.to_string())?;
        }
        let marker = marker_for(&dest);
        if let Some(parent) = marker.parent() { fs::create_dir_all(parent).map_err(|e| e.to_string())?; }
        fs::write(marker, "").map_err(|e| e.to_string())?;
    }
    Ok(actions)
}

fn uninstall(config_root: &Path, apply: bool) -> Result<Vec<String>, String> {
    let mut actions = Vec::new();
    for (name, _, dest_rel) in DEPLOY_SET {
        let dest = config_root.join(dest_rel);
        if !dest.exists() && !dest.is_symlink() { continue; }
        if !is_managed(&dest) {
            actions.push(action_json(&[("item", name), ("action", "skip"), ("reason", "not reddot-managed"), ("dest", &dest.to_string_lossy())]));
            continue;
        }
        let bak = dest.with_file_name(format!("{}.bak", dest.file_name().and_then(|s| s.to_str()).unwrap_or("dest")));
        let restore = if bak.exists() || bak.is_symlink() { Some(bak.to_string_lossy().into_owned()) } else { None };
        let body = format!(
            "{{\"item\":{},\"action\":\"remove\",\"dest\":{},\"restored\":{}}}",
            json(name), json(&dest.to_string_lossy()),
            restore.as_deref().map(json).unwrap_or_else(|| "null".into())
        );
        actions.push(body);
        if apply {
            let marker = marker_for(&dest);
            if marker.exists() { let _ = fs::remove_file(marker); }
            remove(&dest)?;
            if let Some(bak) = restore {
                fs::rename(bak, &dest).map_err(|e| e.to_string())?;
            } else {
                prune_empty(dest.parent().unwrap_or(config_root), config_root);
            }
        }
    }
    Ok(actions)
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mode = args.first().map(String::as_str).unwrap_or("");
    let mut src = PathBuf::from("configs");
    let mut root = PathBuf::from(env::var_os("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from(env::var_os("HOME").unwrap_or_default())).join(".config"));
    let mut apply = false;
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--src" => { i += 1; src = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--config-root" => { i += 1; root = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--apply" => apply = true,
            _ => {}
        }
        i += 1;
    }
    let result = match mode {
        "deploy" => deploy(&src, &root, apply).map(|a| format!("[{}]", a.join(","))),
        "uninstall" => uninstall(&root, apply).map(|a| format!("[{}]", a.join(","))),
        "detect" => {
            let rows: Vec<String> = detect(&root).into_iter().map(|(name, path, exists, managed, status)| {
                format!("{{\"name\":{},\"path\":{},\"exists\":{exists},\"managed\":{managed},\"status\":{}}}", json(&name), json(&path), json(&status))
            }).collect();
            Ok(format!("[{}]", rows.join(",")))
        }
        _ => Err("usage: reddot-deploy deploy|uninstall|detect [--src DIR] [--config-root DIR] [--apply]".into()),
    };
    match result {
        Ok(out) => println!("{out}"),
        Err(err) => { eprintln!("{err}"); std::process::exit(1); }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn wildcard_ignores() {
        assert!(ignored("test_tool.py"));
        assert!(ignored("__pycache__"));
        assert!(ignored("x.pyc"));
        assert!(!ignored("tool.py"));
    }

    #[test]
    fn marker_paths() {
        let tmp = env::temp_dir().join(format!("deploy-marker-{}", std::process::id()));
        let _ = fs::create_dir_all(&tmp);
        assert!(marker_for(&tmp).ends_with(MARKER));
        let _ = fs::remove_dir_all(tmp);
    }
}
