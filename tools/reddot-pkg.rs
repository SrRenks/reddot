//! Rust port of installer/pkg.py: argv construction and read-only package queries.
//! No install command is run by the binary. The installer keeps calling Python
//! until the remaining modules move.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const FAMILIES: [&str; 5] = ["arch", "debian", "fedora", "suse", "gentoo"];
const ROOT_DEFAULT: &str = "sudo";
const PORTAGE_DIR: &str = "/etc/portage";
const GENTOO_TESTING: [&str; 2] = ["app-shells/zoxide", "app-admin/keepassxc"];

struct Config {
    root: String,
    os_release: PathBuf,
}

impl Default for Config {
    fn default() -> Self {
        Self { root: ROOT_DEFAULT.into(), os_release: PathBuf::from("/etc/os-release") }
    }
}

fn require(family: &str) -> Result<(), String> {
    if FAMILIES.contains(&family) {
        Ok(())
    } else {
        Err(format!("unknown family {family:?}, expected one of {FAMILIES:?}"))
    }
}

fn os_release(path: &Path) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    if let Ok(text) = fs::read_to_string(path) {
        for line in text.lines() {
            if line.starts_with('#') {
                continue;
            }
            if let Some((key, value)) = line.split_once('=') {
                out.insert(key.into(), value.trim().trim_matches(['"', '\'']).into());
            }
        }
    }
    out
}

fn which(bin: &str) -> Option<PathBuf> {
    env::var_os("PATH").and_then(|paths| {
        env::split_paths(&paths).map(|d| d.join(bin)).find(|p| p.is_file())
    })
}

fn aur_helper() -> Option<String> {
    ["yay", "paru"].iter().find(|h| which(h).is_some()).map(|s| (*s).to_string())
}

fn install_argv(names: &[String], family: &str, aur: bool, root: &str) -> Result<Vec<String>, String> {
    require(family)?;
    let mut argv = if family == "arch" {
        if aur {
            let helper = aur_helper().ok_or("no AUR helper on PATH, run ensure_aur_helper_steps first")?;
            vec![helper, "-S".into(), "--needed".into(), "--noconfirm".into()]
        } else {
            vec!["pacman".into(), "-S".into(), "--needed".into(), "--noconfirm".into()]
        }
    } else if family == "debian" {
        vec!["apt-get".into(), "install".into(), "-y".into()]
    } else if family == "fedora" {
        vec!["dnf".into(), "install".into(), "-y".into()]
    } else if family == "gentoo" {
        vec!["emerge".into(), "--noreplace".into()]
    } else {
        vec!["zypper".into(), "--non-interactive".into(), "install".into()]
    };
    let _ = root;
    argv.extend(names.iter().cloned());
    Ok(argv)
}

fn obs_target(path: &Path) -> String {
    let data = os_release(path);
    let ident = data.get("ID").cloned().unwrap_or_default().to_lowercase();
    let version = data.get("VERSION_ID").cloned().unwrap_or_default();
    let dotted = version.split('.').count() == 2
        && version.split('.').all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_digit()));
    if ident.contains("leap") || dotted {
        format!("openSUSE_Leap_{version}")
    } else {
        "openSUSE_Tumbleweed".into()
    }
}

fn ubuntu_like(path: &Path) -> bool {
    let data = os_release(path);
    let mut ids = vec![data.get("ID").cloned().unwrap_or_default().to_lowercase()];
    ids.extend(
        data.get("ID_LIKE")
            .cloned()
            .unwrap_or_default()
            .to_lowercase()
            .split_whitespace()
            .map(str::to_string),
    );
    ids.iter().any(|id| id == "ubuntu")
}

fn repo_steps(repo: &str, family: &str, cfg: &Config) -> Result<Vec<Vec<String>>, String> {
    if repo.starts_with("copr:") && family == "fedora" {
        let owner = &repo[5..];
        return Ok(vec![
            vec!["sh".into(), "-c".into(), "dnf install -y dnf-plugins-core 2>/dev/null; dnf install -y dnf5-plugins 2>/dev/null; true".into()],
            vec!["dnf".into(), "copr".into(), "enable".into(), "-y".into(), owner.into()],
        ]);
    }
    if repo.starts_with("ppa:") && family == "debian" {
        if !ubuntu_like(&cfg.os_release) {
            return Ok(Vec::new());
        }
        return Ok(vec![
            vec!["apt-get".into(), "install".into(), "-y".into(), "software-properties-common".into()],
            vec!["add-apt-repository".into(), "-y".into(), repo.into()],
            vec!["apt-get".into(), "update".into()],
        ]);
    }
    if repo.starts_with("overlay:") && family == "gentoo" {
        let name = &repo[8..];
        return Ok(vec![
            vec!["emerge".into(), "--noreplace".into(), "app-eselect/eselect-repository".into()],
            vec!["sh".into(), "-c".into(), format!("portageq get_repo_path / {name} >/dev/null 2>&1 || eselect repository enable {name}")],
            vec!["emerge".into(), "--sync".into(), name.into()],
        ]);
    }
    if repo.starts_with("obs:") && family == "suse" {
        let project = &repo[4..];
        let url = format!(
            "https://download.opensuse.org/repositories/{}/{}/",
            project.replace(':', ":/"),
            obs_target(&cfg.os_release)
        );
        let alias = project.replace(':', "_");
        return Ok(vec![
            vec!["zypper".into(), "--non-interactive".into(), "addrepo".into(), url, alias],
            vec!["zypper".into(), "--non-interactive".into(), "--gpg-auto-import-keys".into(), "refresh".into()],
        ]);
    }
    Err(format!("cannot enable repo {repo:?} on family {family:?}"))
}

fn refresh_argv(family: &str, root: &str) -> Result<Vec<String>, String> {
    require(family)?;
    let base: Vec<&str> = match family {
        "arch" => vec!["pacman", "-Syu", "--noconfirm"],
        "debian" => vec!["apt-get", "update"],
        "fedora" => vec!["dnf", "makecache"],
        "gentoo" => vec!["emerge", "--sync"],
        _ => vec!["zypper", "--non-interactive", "refresh"],
    };
    let mut out = vec![root.to_string()];
    out.extend(base.into_iter().map(str::to_string));
    Ok(out)
}

fn shell_quote(text: &str) -> String {
    if text.chars().all(|c| c.is_ascii_alphanumeric() || "-_./:".contains(c)) {
        text.into()
    } else {
        format!("'{}'", text.replace('\'', "'\\''"))
    }
}

fn aur_steps(cfg: &Config) -> Vec<Vec<String>> {
    if aur_helper().is_some() {
        return Vec::new();
    }
    let dir = env::temp_dir().join("reddot-yay-build");
    let q = shell_quote(&dir.to_string_lossy());
    vec![
        vec![cfg.root.clone(), "pacman".into(), "-S".into(), "--needed".into(), "--noconfirm".into(), "git".into(), "base-devel".into()],
        vec!["sh".into(), "-c".into(), format!("rm -rf {q} && git clone https://aur.archlinux.org/yay-bin.git {q}")],
        vec!["sh".into(), "-c".into(), format!("cd {q} && makepkg -si --noconfirm")],
    ]
}

fn gentoo_extra(trigger: &str) -> (Vec<&'static str>, Vec<&'static str>) {
    match trigger {
        "overlay:hyproverlay" => (
            vec!["*/*::hyproverlay", "dev-libs/wayland", "dev-libs/wayland-protocols", "dev-util/wayland-scanner"],
            vec![],
        ),
        "gui-wm/hyprland" => (vec![], vec!["gui-wm/hyprland LUA_SINGLE_TARGET: lua5-4"]),
        "gui-apps/hypridle" => (vec!["dev-cpp/sdbus-c++"], vec![]),
        "gui-apps/quickshell" => (vec![], vec!["gui-apps/quickshell -crash-handler"]),
        "dev-qt/qtmultimedia" => (vec![], vec!["dev-qt/qtmultimedia qml ffmpeg"]),
        "media-sound/cava" => (vec![], vec!["media-sound/cava pipewire"]),
        "x11-terms/ghostty" => (vec![], vec!["x11-terms/ghostty wayland"]),
        "app-admin/keepassxc" => (vec![], vec!["sys-libs/zlib minizip"]),
        _ => (vec![], vec![]),
    }
}

fn portage_lines(atoms: &[(String, Option<String>)]) -> (Vec<String>, Vec<String>) {
    let mut values: Vec<String> = atoms.iter().filter_map(|(_, repo)| repo.clone()).collect();
    values.sort();
    values.dedup();
    let mut keywords = Vec::new();
    let mut use_flags = Vec::new();
    for trigger in values.iter().map(String::as_str).chain(atoms.iter().map(|(a, _)| a.as_str())) {
        let (kw, use_) = gentoo_extra(trigger);
        keywords.extend(kw.into_iter().map(str::to_string));
        use_flags.extend(use_.into_iter().map(str::to_string));
    }
    for (atom, repo) in atoms {
        if GENTOO_TESTING.contains(&atom.as_str()) || repo.as_deref() == Some("overlay:guru") {
            keywords.push(atom.clone());
        }
    }
    (keywords.into_iter().map(|k| format!("{k} ~amd64")).collect(), use_flags)
}

fn portage_config_steps(atoms: &[(String, Option<String>)]) -> Vec<Vec<String>> {
    let (keywords, use_flags) = portage_lines(atoms);
    let mut steps = Vec::new();
    for (sub, lines) in [("package.accept_keywords", keywords), ("package.use", use_flags)] {
        if lines.is_empty() {
            continue;
        }
        let d = format!("{PORTAGE_DIR}/{sub}");
        let body = lines.join("\\n");
        steps.push(vec!["sh".into(), "-c".into(), format!("mkdir -p {d} && printf '{body}\\n' > {d}/reddot")]);
    }
    steps
}

fn privileged(argv: &[String], family: &str, root: &str) -> Result<Vec<String>, String> {
    require(family)?;
    let mut out = vec![root.to_string()];
    out.extend(argv.iter().cloned());
    Ok(out)
}

fn is_installed(name: &str, family: &str) -> bool {
    let (program, args): (&str, Vec<&str>) = match family {
        "arch" => ("pacman", vec!["-Qq", name]),
        "debian" => ("dpkg-query", vec!["-W", "-f=${Status}", name]),
        "gentoo" => ("portageq", vec!["has_version", "/", name]),
        _ => ("rpm", vec!["-q", name]),
    };
    Command::new(program)
        .args(args)
        .output()
        .map(|out| {
            if family == "debian" {
                String::from_utf8_lossy(&out.stdout).contains("install ok installed")
            } else {
                out.status.success()
            }
        })
        .unwrap_or(false)
}

fn json_string(s: &str) -> String {
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

fn json_argv(argv: &[String]) -> String {
    let body: Vec<String> = argv.iter().map(|s| json_string(s)).collect();
    format!("[{}]", body.join(","))
}

fn json_steps(steps: &[Vec<String>]) -> String {
    let body: Vec<String> = steps.iter().map(|s| json_argv(s)).collect();
    format!("[{}]", body.join(","))
}

fn parse_atoms(value: &str) -> Vec<(String, Option<String>)> {
    value
        .split(',')
        .filter(|item| !item.is_empty())
        .map(|item| match item.split_once('=') {
            Some((atom, repo)) if !repo.is_empty() => (atom.into(), Some(repo.into())),
            _ => (item.into(), None),
        })
        .collect()
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut cfg = Config::default();
    let mut family = String::new();
    let mut aur = false;
    let mut repo = String::new();
    let mut atoms = String::new();
    let mut values: Vec<String> = Vec::new();
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--family" => { i += 1; family = args.get(i).cloned().unwrap_or_default(); }
            "--aur" => aur = true,
            "--repo" => { i += 1; repo = args.get(i).cloned().unwrap_or_default(); }
            "--atoms" => { i += 1; atoms = args.get(i).cloned().unwrap_or_default(); }
            "--root" => { i += 1; cfg.root = args.get(i).cloned().unwrap_or_else(|| ROOT_DEFAULT.into()); }
            "--os-release" => { i += 1; cfg.os_release = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            _ if !args[i].starts_with("--") => values.push(args[i].clone()),
            _ => {}
        }
        i += 1;
    }
    let mode = args.first().map(String::as_str).unwrap_or("");
    let result = match mode {
        "install" => install_argv(&values, &family, aur, &cfg.root).map(|a| json_argv(&a)),
        "refresh" => refresh_argv(&family, &cfg.root).map(|a| json_argv(&a)),
        "repo" => repo_steps(&repo, &family, &cfg).map(|s| json_steps(&s)),
        "aur-steps" => Ok(json_steps(&aur_steps(&cfg))),
        "portage-lines" => {
            let (kw, use_) = portage_lines(&parse_atoms(&atoms));
            Ok(format!("[{},{}]", json_argv(&kw), json_argv(&use_)))
        }
        "portage-config" => Ok(json_steps(&portage_config_steps(&parse_atoms(&atoms)))),
        "privileged" => privileged(&values, &family, &cfg.root).map(|a| json_argv(&a)),
        "installed" => {
            let name = values.first().cloned().unwrap_or_default();
            Ok(if is_installed(&name, &family) { "true".into() } else { "false".into() })
        }
        _ => Err("usage: install|refresh|repo|aur-steps|portage-lines|portage-config|privileged|installed".into()),
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
    fn obs_targets() {
        let path = env::temp_dir().join(format!("osr-pkg-{}", std::process::id()));
        fs::write(&path, "ID=\"opensuse-leap\"\nVERSION_ID=\"15.6\"\n").unwrap();
        assert_eq!(obs_target(&path), "openSUSE_Leap_15.6");
        fs::write(&path, "ID=\"opensuse-tumbleweed\"\nVERSION_ID=\"20260626\"\n").unwrap();
        assert_eq!(obs_target(&path), "openSUSE_Tumbleweed");
        let _ = fs::remove_file(path);
    }

    #[test]
    fn portage_shape() {
        let atoms = vec![
            ("gui-wm/hyprland".into(), Some("overlay:hyproverlay".into())),
            ("gui-apps/quickshell".into(), Some("overlay:guru".into())),
            ("app-shells/fish".into(), None),
        ];
        let (kw, use_) = portage_lines(&atoms);
        assert!(kw.contains(&"*/*::hyproverlay ~amd64".into()));
        assert!(use_.contains(&"gui-wm/hyprland LUA_SINGLE_TARGET: lua5-4".into()));
    }
}
