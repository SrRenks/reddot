//! Rust port of installer/fallbacks.py: ordered shell/argv steps for packages
//! without a native package. Nothing is executed by this binary.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const ZIG_VERSION: &str = "0.15.2";
const CARGO_PREP: &str = "if ! command -v cargo >/dev/null 2>&1 || [ \"$(cargo --version 2>/dev/null | awk '{split($2,v,\".\"); print v[1]*100+v[2]}')\" -lt 188 ]; then curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; fi; if [ -f \"$HOME/.cargo/env\" ]; then . \"$HOME/.cargo/env\"; fi";

fn home() -> PathBuf {
    env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}
fn font_dir() -> PathBuf { home().join(".local/share/fonts") }
fn icon_dir() -> PathBuf { home().join(".local/share/icons") }
fn bin_dir() -> PathBuf { home().join(".local/bin") }
fn build_dir() -> PathBuf { home().join(".cache/reddot/build") }

fn quote(text: &str) -> String {
    if text.is_empty() {
        return "''".into();
    }
    if text.chars().all(|c| c.is_ascii_alphanumeric() || "_@%+=:,./-".contains(c)) {
        text.into()
    } else {
        format!("'{}'", text.replace('\'', "'\\''"))
    }
}

fn clone_step(desc: &str, url: &str, name: &str, extra: &str) -> Step {
    let dest = quote(&build_dir().join(name).to_string_lossy());
    Step::Shell(desc.into(), format!(
        "mkdir -p {} && rm -rf {dest} && git clone {extra}{} {dest}",
        quote(&build_dir().to_string_lossy()),
        quote(url)
    ))
}
fn in_build(name: &str, cmd: &str) -> String {
    format!("cd {} && {cmd}", quote(&build_dir().join(name).to_string_lossy()))
}

#[derive(Clone, Debug, PartialEq)]
enum Step {
    Run(String, Vec<String>),
    Shell(String, String),
}

impl Step {
    fn desc(&self) -> &str {
        match self { Step::Run(d, _) | Step::Shell(d, _) => d }
    }
    fn to_json(&self) -> String {
        let d = json(&self.desc());
        match self {
            Step::Run(_, argv) => format!("{{\"desc\":{d},\"run\":{}}}", argv_json(argv)),
            Step::Shell(_, shell) => format!("{{\"desc\":{d},\"shell\":{}}}", json(shell)),
        }
    }
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
fn argv_json(argv: &[String]) -> String {
    format!("[{}]", argv.iter().map(|s| json(s)).collect::<Vec<_>>().join(","))
}

fn debian_backports() -> Option<String> {
    let text = fs::read_to_string("/etc/os-release").ok()?;
    let id = text.lines().find_map(|l| l.strip_prefix("ID=")).unwrap_or("").trim_matches(['"', '\'']);
    if id != "debian" { return None; }
    let code = text.lines().find_map(|l| l.strip_prefix("VERSION_CODENAME=")).unwrap_or("").trim_matches(['"', '\'']);
    if code.is_empty() { return None; }
    let needle = format!("{code}-backports");
    let mut files = vec![PathBuf::from("/etc/apt/sources.list")];
    if let Ok(entries) = fs::read_dir("/etc/apt/sources.list.d") {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.extension().and_then(|e| e.to_str()).map_or(false, |e| e == "list" || e == "sources") {
                files.push(p);
            }
        }
    }
    files.iter().any(|p| fs::read_to_string(p).map(|t| t.contains(&needle)).unwrap_or(false)).then(|| needle)
}
fn pm_install(family: &str, root: &str, pkgs: &[&str]) -> Vec<String> {
    let mut out = vec![root.to_string()];
    let mut base: Vec<String> = match family {
        "arch" => vec!["pacman", "-S", "--needed", "--noconfirm"],
        "debian" => vec!["apt-get", "install", "-y"],
        "fedora" => vec!["dnf", "install", "-y"],
        "gentoo" => vec!["emerge", "--noreplace"],
        _ => vec!["zypper", "--non-interactive", "install"],
    }.into_iter().map(str::to_string).collect();
    if family == "debian" {
        if let Some(release) = debian_backports() { base.push("-t".into()); base.push(release); }
    }
    out.extend(base);
    out.extend(pkgs.iter().map(|s| s.to_string()));
    out
}

fn swww_deps(family: &str, root: &str) -> Step {
    let deps = match family {
        "arch" => vec!["base-devel", "pkgconf", "lz4", "wayland", "wayland-protocols"],
        "debian" => vec!["build-essential", "pkg-config", "liblz4-dev", "libwayland-dev", "wayland-protocols", "libxkbcommon-dev"],
        "fedora" => vec!["gcc", "pkgconf-pkg-config", "lz4-devel", "wayland-devel", "wayland-protocols-devel", "libxkbcommon-devel"],
        "suse" => vec!["gcc", "pkg-config", "liblz4-devel", "wayland-devel", "wayland-protocols-devel", "libxkbcommon-devel"],
        "gentoo" => vec!["app-arch/lz4", "dev-libs/wayland", "dev-libs/wayland-protocols", "x11-libs/libxkbcommon"],
        _ => vec!["build-essential", "pkg-config", "liblz4-dev", "libwayland-dev", "wayland-protocols", "libxkbcommon-dev"],
    };
    Step::Run("install the C toolchain, pkg-config and the liblz4 headers swww links against".into(), pm_install(family, root, &deps))
}
fn dotool_deps(family: &str, root: &str) -> Step {
    let deps = match family {
        "arch" => vec!["go", "scdoc", "libxkbcommon"],
        "debian" => vec!["golang", "scdoc", "libxkbcommon-dev"],
        "fedora" => vec!["golang", "scdoc", "libxkbcommon-devel"],
        "suse" => vec!["go", "scdoc", "libxkbcommon-devel"],
        "gentoo" => vec!["dev-lang/go", "app-text/scdoc", "x11-libs/libxkbcommon"],
        _ => vec!["golang", "scdoc", "libxkbcommon-dev"],
    };
    Step::Run("install go, scdoc and the libxkbcommon headers dotool builds against".into(), pm_install(family, root, &deps))
}

fn zig_ensure() -> Step {
    let name = format!("zig-$(uname -m)-linux-{ZIG_VERSION}");
    let url = format!("https://ziglang.org/download/{ZIG_VERSION}/{name}.tar.xz");
    Step::Shell(
        format!("make sure the Zig {} ghostty pins is here (PATH zig wins, else official tarball)", ZIG_VERSION),
        format!(
            "v=$(zig version 2>/dev/null || true); if [ \"$v\" != \"{ZIG_VERSION}\" ]; then a=\"$(mktemp --suffix=.tar.xz)\" && curl -fsSL -o \"$a\" {} && mkdir -p \"$HOME/.local/share\" \"$HOME/.local/bin\" && rm -rf \"$HOME/.local/share/{name}\" && tar -xf \"$a\" -C \"$HOME/.local/share\" && rm -f \"$a\" && ln -sf \"$HOME/.local/share/{name}/zig\" \"$HOME/.local/bin/zig\"; fi",
            quote(&url)
        ),
    )
}

fn cargo_steps(id: &str, family: &str, root: &str) -> Vec<Step> {
    if id == "swww" {
        let release = build_dir().join("swww/target/release");
        let bin = quote(&bin_dir().to_string_lossy());
        return vec![
            swww_deps(family, root),
            clone_step("no swww crate on crates.io, clone the source from github", "https://github.com/LGFae/swww", "swww", ""),
            Step::Shell("make sure cargo is here, then build swww and swww-daemon (release)".into(), format!("{CARGO_PREP}; {}", in_build("swww", "cargo build --release"))),
            Step::Shell("install both swww binaries into ~/.local/bin, no root needed".into(), format!(
                "mkdir -p {bin} && install -m755 {} {} {bin}",
                quote(&release.join("swww").to_string_lossy()),
                quote(&release.join("swww-daemon").to_string_lossy())
            )),
        ];
    }
    vec![Step::Shell(
        format!("make sure cargo is here, then build {id} from crates.io"),
        format!("{CARGO_PREP}; cargo install {}", quote(id)),
    )]
}

fn ghostty_steps(family: &str, root: &str) -> Vec<Step> {
    if family == "fedora" {
        return vec![
            Step::Shell("add the fyralabs Terra repo, a third-party repo that ships ghostty for fedora".into(),
                format!("{root} dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release")),
            Step::Run("install ghostty from Terra".into(), vec![root.into(), "dnf".into(), "install".into(), "-y".into(), "ghostty".into()]),
        ];
    }
    vec![
        zig_ensure(),
        clone_step("no ghostty package here, clone the source (the build needs the exact Zig it pins)", "https://github.com/ghostty-org/ghostty", "ghostty", "--depth 1 "),
        Step::Shell("compile a release build with Zig".into(), format!("export PATH=\"$HOME/.local/bin:$PATH\"; {}", in_build("ghostty", "zig build -Doptimize=ReleaseFast"))),
        Step::Shell("install ghostty into /usr".into(), in_build("ghostty", &format!("{root} env \"PATH=$HOME/.local/bin:$PATH\" zig build -p /usr -Doptimize=ReleaseFast"))),
    ]
}

fn dotool_steps(family: &str, root: &str) -> Vec<Step> {
    let rule = "KERNEL==\"uinput\", SUBSYSTEM==\"misc\", GROUP=\"input\", MODE=\"0660\", OPTIONS+=\"static_node=uinput\"";
    vec![
        dotool_deps(family, root),
        clone_step("no dotool package off arch, clone it from sourcehut", "https://git.sr.ht/~geb/dotool", "dotool", ""),
        Step::Shell("build the binaries (needs go, libxkbcommon-dev and scdoc)".into(), in_build("dotool", "./build.sh")),
        Step::Shell("install dotool, dotoolc and dotoold plus the man page".into(), in_build("dotool", &format!("{root} ./build.sh install"))),
        Step::Shell("load the uinput module now and keep it loading on every boot".into(), format!("{root} modprobe uinput && echo uinput | {root} tee /etc/modules-load.d/uinput.conf")),
        Step::Shell("let the input group reach /dev/uinput at 0660, which cures the EACCES the 0620 rule leaves".into(), format!("printf '%s\\n' '{rule}' | {root} tee /etc/udev/rules.d/99-uinput.rules")),
        Step::Shell("create the input group if it is missing and add you to it".into(), format!("{root} groupadd -f input && {root} usermod -aG input \"$(id -un)\"")),
        Step::Run("reload udev so the new rule takes effect".into(), vec![root.into(), "udevadm".into(), "control".into(), "--reload".into()]),
        Step::Run("re-trigger udev for /dev/uinput".into(), vec![root.into(), "udevadm".into(), "trigger".into()]),
    ]
}

fn fetch_unpack(url: &str, dest: &Path) -> String {
    format!("a=\"$(mktemp --suffix=.tar.xz)\" && curl -fsSL -o \"$a\" {} && tar -xf \"$a\" -C {} && rm -f \"$a\"", quote(url), quote(&dest.to_string_lossy()))
}
fn nerdfont_steps() -> Vec<Step> {
    vec![
        Step::Run("make sure the user font dir exists".into(), vec!["mkdir".into(), "-p".into(), font_dir().to_string_lossy().into()]),
        Step::Shell("download the patched JetBrainsMono Nerd Font to a private temp file and unpack it".into(), fetch_unpack("https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz", &font_dir())),
        Step::Run("rebuild the font cache so the glyphs show up".into(), vec!["fc-cache".into(), "-f".into()]),
    ]
}
fn github_steps() -> Vec<Step> {
    vec![
        Step::Run("make sure the user icon dir exists".into(), vec!["mkdir".into(), "-p".into(), icon_dir().to_string_lossy().into()]),
        Step::Shell("download the Bibata-Modern-Classic cursor theme to a private temp file and extract it".into(), fetch_unpack("https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz", &icon_dir())),
    ]
}
fn flatpak_steps(app: &str, family: &str, root: &str) -> Vec<Step> {
    let flatpak = if family == "gentoo" { "sys-apps/flatpak" } else { "flatpak" };
    vec![
        Step::Run("make sure flatpak itself is installed".into(), pm_install(family, root, &[flatpak])),
        Step::Run("add the flathub remote for this user if it is not there already".into(), vec!["flatpak".into(), "--user".into(), "remote-add".into(), "--if-not-exists".into(), "flathub".into(), "https://flathub.org/repo/flathub.flatpakrepo".into()]),
        Step::Run(format!("install {app} from flathub for this user, no root needed"), vec!["flatpak".into(), "--user".into(), "install".into(), "-y".into(), "flathub".into(), app.into()]),
    ]
}
fn curl_steps() -> Vec<Step> {
    vec![Step::Shell("run rishot's own installer".into(), "curl -fsSL https://raw.githubusercontent.com/Gakuseei/rishot/main/install.sh | sh".into())]
}

fn steps_for(fallback: &str, id: &str, app: &str, family: &str, root: &str) -> Vec<Step> {
    match fallback {
        "cargo" => cargo_steps(id, family, root),
        "ghostty" => ghostty_steps(family, root),
        "dotool" => dotool_steps(family, root),
        "nerdfont" => nerdfont_steps(),
        "github" => github_steps(),
        "flatpak" => flatpak_steps(app, family, root),
        "curl" => curl_steps(),
        _ => Vec::new(),
    }
}

fn present(fallback: &str, id: &str, app: &str) -> bool {
    match fallback {
        "cargo" | "ghostty" | "dotool" | "curl" => which(id),
        "nerdfont" => fs::read_dir(font_dir()).map(|d| d.filter_map(Result::ok).any(|e| e.file_name().to_string_lossy().starts_with("JetBrainsMono"))).unwrap_or(false),
        "github" => icon_dir().join("Bibata-Modern-Classic").is_dir(),
        "flatpak" => Command::new("flatpak").args(["info", "--user", app]).output().map(|o| o.status.success()).unwrap_or(false),
        _ => false,
    }
}
fn which(bin: &str) -> bool {
    env::var_os("PATH").map(|paths| env::split_paths(&paths).any(|d| d.join(bin).is_file())).unwrap_or(false)
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mode = args.first().map(String::as_str).unwrap_or("");
    let mut fallback = String::new();
    let mut id = String::new();
    let mut app = String::new();
    let mut family = String::new();
    let mut root = "sudo".to_string();
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--fallback" => { i += 1; fallback = args.get(i).cloned().unwrap_or_default(); }
            "--id" => { i += 1; id = args.get(i).cloned().unwrap_or_default(); }
            "--app" => { i += 1; app = args.get(i).cloned().unwrap_or_default(); }
            "--family" => { i += 1; family = args.get(i).cloned().unwrap_or_default(); }
            "--root" => { i += 1; root = args.get(i).cloned().unwrap_or_else(|| "sudo".into()); }
            _ => {}
        }
        i += 1;
    }
    let steps = steps_for(&fallback, &id, &app, &family, &root);
    if mode == "present" {
        println!("{}", if present(&fallback, &id, &app) { "true" } else { "false" });
        return;
    }
    if mode != "steps" {
        eprintln!("usage: reddot-fallbacks steps --fallback ID --id PKG --family FAMILY [--app APP] [--root CMD]");
        std::process::exit(2);
    }
    let body: Vec<String> = steps.iter().map(Step::to_json).collect();
    println!("[{}]", body.join(","));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ghostty_branches() {
        let fed = ghostty_steps("fedora", "sudo");
        assert!(fed.iter().any(|s| matches!(s, Step::Shell(_, x) if x.contains("terra"))));
        let deb = ghostty_steps("debian", "sudo");
        assert!(deb.iter().any(|s| matches!(s, Step::Shell(_, x) if x.contains("ziglang.org"))));
    }

    #[test]
    fn every_handler_produces_steps() {
        for (fb, id, app) in [("cargo", "matugen", ""), ("ghostty", "ghostty", ""), ("dotool", "dotool", ""), ("nerdfont", "font", ""), ("github", "cursor", ""), ("flatpak", "app", "com.example.App"), ("curl", "rishot", "")] {
            assert!(!steps_for(fb, id, app, "debian", "sudo").is_empty(), "{fb}");
        }
        assert!(steps_for("nope", "", "", "debian", "sudo").is_empty());
    }

    #[test]
    fn flatpak_is_user_scoped() {
        let steps = flatpak_steps("com.example.App", "debian", "sudo");
        for step in steps {
            if let Step::Run(_, argv) = step {
                if argv.first().map(String::as_str) == Some("flatpak") {
                    assert!(argv.contains(&"--user".into()));
                }
            }
        }
    }
}
