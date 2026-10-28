//! Rust port of installer/deploy.py neutralize(): make deployed configs portable.
//! Plans by default; writes only with --apply.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const MON_AUTO: &str = "hl.monitor({\n    output   = \"\",\n    mode     = \"preferred\",\n    position = \"auto\",\n    scale    = 1,\n})\n";
const ENV_BASE: &str = "hl.env(\"XCURSOR_THEME\",   \"Bibata-Modern-Ice\")\nhl.env(\"XCURSOR_SIZE\",    \"24\")\nhl.env(\"HYPRCURSOR_SIZE\", \"24\")\n\nhl.env(\"ELECTRON_OZONE_PLATFORM_HINT\", \"auto\")\n\nhl.env(\"QT_QPA_PLATFORMTHEME\", \"kde\")\n";
const ENV_NVIDIA: &str = "\nhl.env(\"LIBVA_DRIVER_NAME\",         \"nvidia\")\nhl.env(\"__GLX_VENDOR_LIBRARY_NAME\", \"nvidia\")\nhl.env(\"__GL_GSYNC_ALLOWED\",        \"0\")\nhl.env(\"__GL_VRR_ALLOWED\",          \"0\")\n";
const GRUB_EXCLUDED: [&str; 3] = ["grub/install-torii.sh", "grub/probe-sda4.sh", "grub/10_reddot"];
const STATIC: [(&str, &str); 8] = [
    ("primary", "#e60012"), ("dim", "#8a8a8a"), ("on_primary_container", "#ff8090"),
    ("surface_container", "#181818"), ("surface_container_high", "#222222"),
    ("subtle", "#b8b8b8"), ("outline", "#303030"), ("bright", "#ffffff"),
];

fn home() -> PathBuf {
    env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

fn read(path: &Path) -> Result<String, String> {
    fs::read_to_string(path).map_err(|e| format!("read {}: {e}", path.display()))
}
fn write(path: &Path, text: &str) -> Result<(), String> {
    if let Some(parent) = path.parent() { fs::create_dir_all(parent).map_err(|e| e.to_string())?; }
    fs::write(path, text).map_err(|e| e.to_string())
}
fn json(s: &str) -> String {
    let mut out = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""), '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"), '\r' => out.push_str("\\r"), '\t' => out.push_str("\\t"),
            c if (c as u32) < 0x20 => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"'); out
}
fn arr(items: &[String]) -> String { format!("[{}]", items.iter().map(|s| json(s)).collect::<Vec<_>>().join(",")) }

fn pristine(rel: &str, root: &Path, src: &Path) -> bool {
    let live = root.join(rel);
    let source = src.join(rel);
    match (fs::read(live), fs::read(source)) { (Ok(a), Ok(b)) => a == b, _ => false }
}
fn has_nvidia() -> bool {
    let root = Path::new("/sys/bus/pci/devices");
    let Ok(entries) = fs::read_dir(root) else { return false };
    for entry in entries.flatten() {
        let dev = entry.path();
        let boot = fs::read_to_string(dev.join("boot_vga")).unwrap_or_default();
        let vendor = fs::read_to_string(dev.join("vendor")).unwrap_or_default();
        if boot.trim() == "1" && vendor.trim() == "0x10de" { return true; }
    }
    false
}
fn strip_fish(text: &str) -> (String, Vec<String>) {
    let mut out = Vec::new();
    let mut removed = Vec::new();
    for line in text.lines() {
        if line.trim().starts_with("source /usr/share/cachyos-fish-config") {
            removed.push("cachyos source".into());
            continue;
        }
        out.push(line.to_string());
    }
    let joined = out.join("\n");
    let mut cleaned = joined.trim_matches('\n').to_string();
    while cleaned.contains("\n\n\n") { cleaned = cleaned.replace("\n\n\n", "\n\n"); }
    (if cleaned.is_empty() { String::new() } else { cleaned + "\n" }, removed)
}
fn seq(hex: &str) -> Result<String, ()> {
    if hex.len() != 7 || !hex.starts_with('#') { return Err(()); }
    let parse = |i: usize| u8::from_str_radix(&hex[i..i + 2], 16).map_err(|_| ());
    Ok(format!("{};{};{}", parse(1)?, parse(3)?, parse(5)?))
}
fn parse_flat_json(text: &str) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    let mut chars = text.char_indices().peekable();
    let mut at = 0;
    while at < text.len() {
        let rest = &text[at..];
        let Some(key_start) = rest.find('"') else { break };
        let key_start = at + key_start + 1;
        let Some(key_end_rel) = text[key_start..].find('"') else { break };
        let key_end = key_start + key_end_rel;
        let key = &text[key_start..key_end];
        let Some(colon_rel) = text[key_end + 1..].find(':') else { break };
        let mut val_at = key_end + 1 + colon_rel + 1;
        while val_at < text.len() && text.as_bytes()[val_at].is_ascii_whitespace() { val_at += 1; }
        if text.as_bytes().get(val_at) != Some(&b'"') { at = val_at + 1; continue; }
        let val_start = val_at + 1;
        let Some(val_end_rel) = text[val_start..].find('"') else { break };
        let val_end = val_start + val_end_rel;
        out.insert(key.into(), text[val_start..val_end].into());
        at = val_end + 1;
        let _ = &mut chars;
    }
    out
}
fn palette() -> (BTreeMap<String, String>, &'static str) {
    let cache = home().join(".cache/reddot/colors.json");
    if let Ok(text) = fs::read_to_string(cache) {
        let data = parse_flat_json(&text);
        if STATIC.iter().all(|(k, _)| data.contains_key(*k))
            && STATIC.iter().all(|(_, k)| seq(k).is_ok()) && data.values().all(|v| seq(v).is_ok()) {
            return (data, "cache");
        }
    }
    (STATIC.iter().map(|(k, v)| (k.to_string(), v.to_string())).collect(), "default")
}
fn render_fastfetch(ff: &Path, p: &BTreeMap<String, String>, apply: bool) -> Result<bool, String> {
    let tmpl = ff.join("config.jsonc.in");
    if !tmpl.is_file() { return Ok(false); }
    let get = |key: &str| p.get(key).cloned().unwrap_or_default();
    let repl = [
        ("__LANTERN__", ff.join("lantern.txt").to_string_lossy().into_owned()),
        ("__KEYS__", seq(&get("primary")).unwrap_or_default()),
        ("__SEP__", seq(&get("dim")).unwrap_or_default()),
        ("__LOGO1__", seq(&get("primary")).unwrap_or_default()),
        ("__LOGO2__", seq(&get("on_primary_container")).unwrap_or_default()),
        ("__LOGO3__", seq(&get("surface_container")).unwrap_or_default()),
        ("__LOGO4__", seq(&get("surface_container_high")).unwrap_or_default()),
        ("__LOGO5__", seq(&get("subtle")).unwrap_or_default()),
        ("__LOGO6__", seq(&get("outline")).unwrap_or_default()),
        ("__LOGO7__", seq(&get("bright")).unwrap_or_default()),
    ];
    if apply {
        let mut out = read(&tmpl)?;
        for (key, val) in repl { out = out.replace(key, &val); }
        write(&ff.join("config.jsonc"), &out)?;
    }
    Ok(true)
}

fn neutralize(src: &Path, root: &Path, apply: bool) -> Result<Vec<String>, String> {
    let mut actions = Vec::new();
    let mon = root.join("hypr/modules/monitors.lua");
    if pristine("hypr/modules/monitors.lua", root, src) {
        let example = mon.with_file_name("monitors.lua.example");
        let save = !example.exists();
        let action = format!(
            "{{\"step\":\"monitors\",\"path\":{},\"example\":{},\"wrote\":\"single auto monitor\"}}",
            json(&mon.to_string_lossy()),
            if save { json(&example.to_string_lossy()) } else { "null".into() }
        );
        if apply {
            if save { fs::copy(&mon, &example).map_err(|e| e.to_string())?; }
            write(&mon, MON_AUTO)?;
        }
        actions.push(action);
    }
    let env_path = root.join("hypr/modules/env.lua");
    if pristine("hypr/modules/env.lua", root, src) {
        let nvidia = has_nvidia();
        actions.push(format!(
            "{{\"step\":\"env\",\"path\":{},\"nvidia\":{},\"wrote\":{}}}",
            json(&env_path.to_string_lossy()), nvidia,
            json(if nvidia { "base env + nvidia" } else { "base env, nvidia dropped" })
        ));
        if apply { write(&env_path, &(ENV_BASE.to_string() + if nvidia { ENV_NVIDIA } else { "" }))?; }
    }
    let idle = root.join("hypr/hypridle.conf");
    let idle_example = idle.with_file_name("hypridle.conf.example");
    if !idle.is_file() && idle_example.is_file() {
        actions.push(format!(
            "{{\"step\":\"hypridle-seed\",\"path\":{},\"wrote\":\"from hypridle.conf.example\"}}",
            json(&idle.to_string_lossy())
        ));
        if apply { fs::copy(&idle_example, &idle).map_err(|e| e.to_string())?; }
    }
    if idle.is_file() {
        let text = read(&idle)?;
        let count = text.matches("/home/erik").count();
        let home = home().to_string_lossy().into_owned();
        actions.push(format!(
            "{{\"step\":\"hypridle\",\"path\":{},\"replaced\":{},\"home\":{}}}",
            json(&idle.to_string_lossy()), count, json(&home)
        ));
        if apply && count > 0 { write(&idle, &text.replace("/home/erik", &home))?; }
    }
    let fish = root.join("fish/config.fish");
    if fish.is_file() && pristine("fish/config.fish", root, src) {
        let (cleaned, removed) = strip_fish(&read(&fish)?);
        actions.push(format!(
            "{{\"step\":\"fish\",\"path\":{},\"stripped\":{}}}",
            json(&fish.to_string_lossy()), arr(&removed)
        ));
        if apply && !removed.is_empty() { write(&fish, &cleaned)?; }
    }
    let ff = root.join("fastfetch");
    if ff.join("config.jsonc.in").is_file() {
        let (pal, source) = palette();
        let rendered = render_fastfetch(&ff, &pal, apply)?;
        actions.push(format!(
            "{{\"step\":\"fastfetch\",\"path\":{},\"palette\":{},\"rendered\":{}}}",
            json(&ff.join("config.jsonc").to_string_lossy()), json(source), rendered
        ));
    }
    let files: Vec<String> = GRUB_EXCLUDED.iter().map(|s| (*s).to_string()).collect();
    actions.push(format!(
        "{{\"step\":\"grub-excluded\",\"files\":{},\"note\":\"personal bootloader entries, never deployed\"}}",
        arr(&files)
    ));
    Ok(actions)
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut src = PathBuf::from("configs");
    let mut root = PathBuf::from(".");
    let mut apply = false;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--src" => { i += 1; src = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--config-root" => { i += 1; root = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--apply" => apply = true,
            _ => {}
        }
        i += 1;
    }
    match neutralize(&src, &root, apply) {
        Ok(actions) => println!("[{}]", actions.join(",")),
        Err(err) => { eprintln!("{err}"); std::process::exit(1); }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fish_strip() {
        let (out, removed) = strip_fish("source /usr/share/cachyos-fish-config\n\n\n\ntorii-greeting\n");
        assert_eq!(out, "torii-greeting\n");
        assert_eq!(removed, vec!["cachyos source"]);
    }

    #[test]
    fn ansi_seq() {
        assert_eq!(seq("#e60012").unwrap(), "230;0;18");
        assert!(seq("bad").is_err());
    }

    #[test]
    fn flat_json() {
        let data = parse_flat_json("{\"primary\":\"#ff0000\",\"dim\":\"#00ff00\"}");
        assert_eq!(data.get("primary").map(String::as_str), Some("#ff0000"));
    }
}
