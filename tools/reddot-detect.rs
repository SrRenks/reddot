//! Rust port of the read-only detection helpers in reddot_install.py.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const FAMILIES: [(&str, &[&str]); 5] = [
    ("arch", &["arch", "cachyos", "endeavouros", "manjaro", "garuda", "artix", "arcolinux", "archcraft", "rebornos", "athena", "blackarch", "archbang", "crystal", "snigdha", "parabola", "obarun", "arch32", "hyperbola", "steamos", "omarchy", "xerolinux", "archman", "biglinux", "ctlos", "tromjaro", "bluestar", "arkane", "blendos", "acreetionos", "mabox"]),
    ("debian", &["debian", "ubuntu", "linuxmint", "pop", "elementary", "zorin", "raspbian"]),
    ("fedora", &["fedora", "nobara", "rhel", "centos", "rocky", "almalinux"]),
    ("suse", &["suse", "opensuse", "sles", "sled", "tumbleweed", "leap"]),
    ("gentoo", &["gentoo", "funtoo", "calculate", "pentoo", "redcore"]),
];

fn os_release(path: &Path) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    if let Ok(text) = fs::read_to_string(path) {
        for line in text.lines() {
            if line.starts_with('#') { continue; }
            if let Some((k, v)) = line.split_once('=') {
                out.insert(k.into(), v.trim().trim_matches(['"', '\'']).into());
            }
        }
    }
    out
}
fn family(data: &BTreeMap<String, String>) -> String {
    let mut ids = vec![data.get("ID").cloned().unwrap_or_default().to_lowercase()];
    ids.extend(data.get("ID_LIKE").cloned().unwrap_or_default().to_lowercase().split_whitespace().map(str::to_string));
    for id in ids {
        for (name, tokens) in FAMILIES {
            if tokens.contains(&id.as_str()) { return name.into(); }
        }
    }
    "unknown".into()
}
fn which(bin: &str) -> Option<PathBuf> {
    env::var_os("PATH").and_then(|paths| env::split_paths(&paths).map(|d| d.join(bin)).find(|p| p.is_file()))
}
fn compositor() -> String {
    if env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some() { "Hyprland".into() }
    else if env::var_os("NIRI_SOCKET").is_some() { "Niri".into() }
    else { env::var("XDG_CURRENT_DESKTOP").unwrap_or_else(|_| "Unknown".into()) }
}
fn bootloader() -> String {
    if Path::new("/boot/grub/grub.cfg").is_file() || which("grub-mkconfig").is_some() { "grub".into() }
    else if Path::new("/boot/loader/entries").is_dir() || which("bootctl").is_some() { "systemd-boot".into() }
    else if Path::new("/boot/limine.conf").is_file() || Path::new("/boot/limine/limine.conf").is_file() || which("limine").is_some() { "limine".into() }
    else { "other".into() }
}
fn has_display_manager() -> bool {
    Path::new("/etc/systemd/system/display-manager.service").exists()
        || ["sddm", "gdm", "lightdm", "ly", "greetd"].iter().any(|dm| which(dm).is_some())
}
fn active(unit: &str) -> bool {
    Command::new("systemctl").args(["is-active", "--quiet", unit]).status().map(|s| s.success()).unwrap_or(false)
}
fn root_cmd() -> String {
    if which("sudo").is_none() && which("doas").is_some() { "doas".into() } else { "sudo".into() }
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
fn main() {
    let data = os_release(Path::new("/etc/os-release"));
    let fam = family(&data);
    let pm = match fam.as_str() {
        "arch" => "pacman", "debian" => "apt-get", "fedora" => "dnf",
        "suse" => "zypper", "gentoo" => "emerge", _ => "Unknown",
    };
    let pretty = data.get("PRETTY_NAME").or_else(|| data.get("NAME")).cloned().unwrap_or_else(|| "unknown".into());
    let init = if Path::new("/run/systemd/system").is_dir() { "systemd" }
        else if Path::new("/run/openrc").exists() { "openrc" }
        else if Path::new("/run/runit").exists() { "runit" }
        else if Path::new("/run/s6-rc").exists() { "s6" }
        else if Path::new("/run/dinit").exists() { "dinit" }
        else { "unknown" };
    let immutable = data.get("ID").map(|s| s.to_lowercase() == "steamos").unwrap_or(false);
    let mut out = BTreeMap::new();
    out.insert("family", json(&fam));
    out.insert("pretty", json(&pretty));
    out.insert("pm", json(pm));
    out.insert("compositor", json(&compositor()));
    out.insert("bootloader", json(&bootloader()));
    out.insert("hasDisplayManager", if has_display_manager() { "true".into() } else { "false".into() });
    out.insert("rootCmd", json(&root_cmd()));
    out.insert("init", json(init));
    out.insert("immutable", if immutable { "true".into() } else { "false".into() });
    out.insert("aurHelper", match ["yay", "paru"].iter().find(|h| which(h).is_some()) {
        Some(h) => json(h), None => "null".into(),
    });
    out.insert("networkdOrIwd", if active("systemd-networkd") || active("iwd") { "true".into() } else { "false".into() });
    let body: Vec<String> = out.iter().map(|(k, v)| format!("\"{k}\":{v}")).collect();
    println!("{{{}}}", body.join(","));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn family_tokens() {
        let data = [("ID".into(), "Snigdha".into())].into_iter().collect();
        assert_eq!(family(&data), "arch");
    }

    #[test]
    fn root_command_is_known() {
        assert!(root_cmd() == "sudo" || root_cmd() == "doas");
    }
}
