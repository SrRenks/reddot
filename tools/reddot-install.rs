//! First Rust installer entry point: quickstart/dry-run integration of the core
//! binaries. The interactive wizard and real apply path are not wired yet.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

fn field(text: &str, key: &str) -> String {
    let needle = format!("\"{key}\":\"");
    let Some(start) = text.find(&needle) else { return String::new() };
    let rest = &text[start + needle.len()..];
    rest.split('"').next().unwrap_or("").to_string()
}
fn run(bin: &Path, args: &[&str]) -> Result<String, String> {
    let out = Command::new(bin).args(args).output().map_err(|e| format!("{}: {e}", bin.display()))?;
    if !out.status.success() {
        return Err(format!("{} failed: {}", bin.display(), String::from_utf8_lossy(&out.stderr).trim()));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut source = PathBuf::from("configs");
    let mut config_root = env::var_os("XDG_CONFIG_HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from(env::var_os("HOME").unwrap_or_default())).join(".config");
    let mut bin_dir = env::var_os("HOME").map(PathBuf::from).unwrap_or_default().join(".local/bin");
    let mut dry = false;
    let mut quick = false;
    let mut no_deps = false;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--source" => { i+=1; source=PathBuf::from(args.get(i).cloned().unwrap_or_default()); },
            "--config-root" => { i+=1; config_root=PathBuf::from(args.get(i).cloned().unwrap_or_default()); },
            "--bin-dir" => { i+=1; bin_dir=PathBuf::from(args.get(i).cloned().unwrap_or_default()); },
            "--dry-run" => dry=true,
            "--quickstart" => quick=true,
            "--no-deps" => no_deps=true,
            _ => {}
        }
        i += 1;
    }
    if !quick { eprintln!("reddot-install: interactive wizard not wired yet; use --quickstart"); std::process::exit(2); }
    if !dry { eprintln!("reddot-install: apply path not wired yet; use --dry-run"); std::process::exit(2); }
    let bin = |name: &str| bin_dir.join(name);
    let detect = match run(&bin("reddot-detect"), &[]) { Ok(v) => v, Err(e) => { eprintln!("{e}"); std::process::exit(1); } };
    let family = field(&detect, "family");
    let init = field(&detect, "init");
    println!("reddot-install: family={family} init={init} dry-run");
    let plan = env::temp_dir().join(format!("reddot-plan-{}.json", std::process::id()));
    let manifest = source.parent().unwrap_or(Path::new(".")).join("installer/packages.json");
    let manifest_arg = manifest.to_string_lossy().into_owned();
    let profile = "quick";
    let plan_out = match run(&bin("reddot-plan"), &["--manifest", &manifest_arg, "--family", &family, "--profile", profile]) {
        Ok(v) => v, Err(e) => { eprintln!("{e}"); std::process::exit(1); }
    };
    fs::write(&plan, plan_out).unwrap_or_else(|e| { eprintln!("{e}"); std::process::exit(1); });
    let plan_arg = plan.to_string_lossy().into_owned();
    match run(&bin("reddot-report"), &["--plan", &plan_arg, "--family", &family]) {
        Ok(out) => print!("{out}"),
        Err(e) => eprintln!("{e}"),
    }
    if !no_deps {
        let root = "sudo";
        match run(&bin("reddot-run"), &["--plan", &plan_arg, "--family", &family, "--root", root, "--dry-run", "--services", "--init", &init]) {
            Ok(out) => print!("{out}"),
            Err(e) => eprintln!("{e}"),
        }
    }
    let src_arg = source.to_string_lossy().into_owned();
    let root_arg = config_root.to_string_lossy().into_owned();
    for (b, args) in [
        ("reddot-deploy", vec!["deploy", "--src", &src_arg, "--config-root", &root_arg]),
        ("reddot-neutralize", vec!["--src", &src_arg, "--config-root", &root_arg]),
    ] {
        match run(&bin(b), &args) { Ok(out) => print!("{out}"), Err(e) => eprintln!("{e}") }
    }
    for mode in ["wallpapers", "app-theme", "bridge", "link-cli", "brave"] {
        let starters = source.parent().unwrap_or(Path::new(".")).join("installer/starter-wallpapers");
        let starters_arg = starters.to_string_lossy().into_owned();
        match run(&bin("reddot-post"), &[mode, "--starters", &starters_arg, "--config-root", &root_arg, "--dry-run"]) {
            Ok(out) => print!("{out}"),
            Err(e) => eprintln!("{e}"),
        }
    }
    let _ = fs::remove_file(&plan);
    println!("reddot-install: quickstart dry-run complete");
}
