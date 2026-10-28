//! First Rust installer entry point: quickstart/dry-run integration of the core
//! binaries. The interactive wizard and real apply path are not wired yet.

use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::io::{BufRead, BufReader, Write};
use std::process::Command;

fn ask(prompt: &str, default: &str) -> String {
    let Ok(mut tty) = fs::OpenOptions::new().read(true).write(true).open("/dev/tty") else { return default.into() };
    let _ = write!(tty, "{prompt} [{default}] ");
    let _ = tty.flush();
    let mut line = String::new();
    if BufReader::new(tty).read_line(&mut line).is_err() { return default.into(); }
    let answer = line.trim().to_string();
    if answer.is_empty() { default.into() } else { answer }
}

fn quoted(chunk: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut rest = chunk;
    while let Some(a) = rest.find('"') {
        let after = &rest[a + 1..];
        let Some(b) = after.find('"') else { break };
        out.push(after[..b].to_string());
        rest = &after[b + 1..];
    }
    out
}
fn fallback_triples(plan: &str) -> Vec<(String, String, String)> {
    let Some(start) = plan.find("\"fallbacks\":[") else { return Vec::new() };
    let rest = &plan[start + 13..];
    let Some(end) = rest.find(']') else { return Vec::new() };
    let body = &rest[..end];
    let mut out = Vec::new();
    for part in body.split("],[") {
        let vals = quoted(part);
        if vals.len() >= 2 {
            out.push((vals[0].clone(), vals[1].clone(), vals.get(2).cloned().unwrap_or_default()));
        }
    }
    out
}

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
    let mut uninstall = false;
    let mut sddm = false; let mut grub = false; let mut brave = false; let mut fish = true;
    let mut no_deps = false;
    let mut apply = false;
    let mut full = false;
    let mut custom = false;
    let mut aur = "yay".to_string();
    let mut optional = String::new();
    let mut family_override = String::new();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--source" => { i+=1; source=PathBuf::from(args.get(i).cloned().unwrap_or_default()); },
            "--config-root" => { i+=1; config_root=PathBuf::from(args.get(i).cloned().unwrap_or_default()); },
            "--bin-dir" => { i+=1; bin_dir=PathBuf::from(args.get(i).cloned().unwrap_or_default()); },
            "--dry-run" => dry=true,
            "--quickstart" => quick=true,
            "--no-deps" => no_deps=true,
            "--apply" => apply=true,
            "--reinstall" => apply=true,
            "--uninstall" => uninstall=true,
            "--sddm" => sddm=true, "--grub" => grub=true, "--brave" => brave=true, "--no-fish" => fish=false,
            "--full" => full=true,
            "--custom" => custom=true,
            "--optional" => { i+=1; optional=args.get(i).cloned().unwrap_or_default(); },
            "--family" => { i+=1; family_override=args.get(i).cloned().unwrap_or_default(); },
            "--aur" => { i+=1; aur=args.get(i).cloned().unwrap_or_else(|| "yay".into()); },
            _ => {}
        }
        i += 1;
    }
    let bin = |name: &str| bin_dir.join(name);
    if uninstall {
        if !dry && !apply { eprintln!("reddot-install: pass --apply explicitly or use --dry-run"); std::process::exit(2); }
        let root_arg = config_root.to_string_lossy().into_owned();
        let mut args = vec!["uninstall", "--config-root", &root_arg];
        if apply { args.push("--apply"); }
        match run(&bin("reddot-deploy"), &args) {
            Ok(out) => print!("{out}"),
            Err(e) => { eprintln!("{e}"); std::process::exit(1); }
        }
        if apply {
            let wall = config_root.join("hypr/scripts/wallcolors");
            if wall.exists() {
                let _ = run(&wall, &["--apps", "off"]);
            }
            let link = env::var_os("HOME").map(PathBuf::from).unwrap_or_default().join(".local/bin/reddot");
            if link.is_symlink() { let _ = fs::remove_file(&link); }
        }
        println!("reddot-install: uninstall {} complete", if apply { "apply" } else { "dry-run" });
        return;
    }
    if !dry && !apply { eprintln!("reddot-install: pass --apply explicitly or use --dry-run"); std::process::exit(2); }
    let bin = |name: &str| bin_dir.join(name);
    let detect = match run(&bin("reddot-detect"), &[]) { Ok(v) => v, Err(e) => { eprintln!("{e}"); std::process::exit(1); } };
    let detected_family = field(&detect, "family");
    let family = if family_override.is_empty() { detected_family } else { family_override };
    let init = field(&detect, "init");
    if !quick {
        if !full {
            let choice = ask("Install profile: 1 Quick, 2 Full, 3 Custom", "1");
            if choice.trim() == "2" { full = true; }
            if choice.trim() == "3" { custom = true; }
        }
        if family == "arch" {
            let helper = ask("AUR helper: yay, paru or none", &aur);
            if helper == "yay" || helper == "paru" || helper == "none" { aur = helper; }
        }
        if full || custom {
            if let Ok(ids) = run(&bin("reddot-plan"), &["--manifest", &source.parent().unwrap_or(Path::new(".")).join("installer/packages.json").to_string_lossy(), "--list-full"]) {
                let list: Vec<String> = quoted(&ids);
                if !list.is_empty() {
                    println!("Full apps: {}", list.iter().enumerate().map(|(i, s)| format!("{}={s}", i + 1)).collect::<Vec<_>>().join(", "));
                    let pick = ask(if custom { "Optional apps (numbers, comma; empty = none)" } else { "Optional apps (numbers, comma; empty = all)" }, "");
                    if !pick.trim().is_empty() {
                        let mut chosen = Vec::new();
                        for n in pick.split(',') {
                            if let Ok(i) = n.trim().parse::<usize>() {
                                if i >= 1 && i <= list.len() { chosen.push(list[i - 1].clone()); }
                            }
                        }
                        optional = chosen.join(",");
                    }
                }
            }
        }
        sddm = ask("Install the torii SDDM theme? (y/N)", "n").to_lowercase().starts_with('y');
        if field(&detect, "bootloader") == "grub" {
            grub = ask("Install the GRUB theme? (y/N)", "n").to_lowercase().starts_with('y');
        }
        brave = ask("Install Brave and follow wallpaper colors? (y/N)", "n").to_lowercase().starts_with('y');
        fish = !ask("Set fish as login shell? (Y/n)", "y").to_lowercase().starts_with('n');
    }
    println!("reddot-install: family={family} init={init} dry-run={dry} profile={}", if full { "full" } else { "quick" });
    let detect = match run(&bin("reddot-detect"), &[]) { Ok(v) => v, Err(e) => { eprintln!("{e}"); std::process::exit(1); } };
    let family = field(&detect, "family");
    let init = field(&detect, "init");
    println!("reddot-install: family={family} init={init} dry-run");
    let plan = env::temp_dir().join(format!("reddot-plan-{}.json", std::process::id()));
    let manifest = source.parent().unwrap_or(Path::new(".")).join("installer/packages.json");
    let manifest_arg = manifest.to_string_lossy().into_owned();
    let profile = if custom { "custom" } else if full { "full" } else { "quick" };
    let mut pargs = vec!["--manifest", &manifest_arg, "--family", &family, "--profile", profile, "--aur", &aur];
    if !optional.is_empty() { pargs.extend(["--optional", &optional]); }
    let plan_out = match run(&bin("reddot-plan"), &pargs) {
        Ok(v) => v, Err(e) => { eprintln!("{e}"); std::process::exit(1); }
    };
    fs::write(&plan, &plan_out).unwrap_or_else(|e| { eprintln!("{e}"); std::process::exit(1); });
    let plan_arg = plan.to_string_lossy().into_owned();
    match run(&bin("reddot-report"), &["--plan", &plan_arg, "--family", &family]) {
        Ok(out) => print!("{out}"),
        Err(e) => eprintln!("{e}"),
    }
    let fallback_pairs = fallback_triples(&plan_out);
    let fallback_path = env::temp_dir().join(format!("reddot-fallbacks-{}.json", std::process::id()));
    if !fallback_pairs.is_empty() {
        let mut steps = Vec::new();
        for (id, handler, app) in &fallback_pairs {
            match run(&bin("reddot-fallbacks"), &["steps", "--fallback", handler.as_str(), "--id", id.as_str(), "--app", app.as_str(), "--family", &family]) {
                Ok(out) => {
                    let body = out.trim().trim_start_matches('[').trim_end_matches(']').to_string();
                    if !body.is_empty() { steps.push(body); }
                }
                Err(e) => eprintln!("{e}"),
            }
        }
        let _ = fs::write(&fallback_path, format!("[{}]", steps.join(",")));
    }
    if !no_deps {
        let root = "sudo";
        let mut args = vec!["--plan", &plan_arg, "--family", &family, "--root", root, "--services", "--init", &init];
        if !apply { args.push("--dry-run"); }
        let fb_arg = fallback_path.to_string_lossy().into_owned();
        if !fallback_pairs.is_empty() { args.extend(["--fallbacks-json", &fb_arg]); }
        match run(&bin("reddot-run"), &args) {
            Ok(out) => print!("{out}"),
            Err(e) => eprintln!("{e}"),
        }
    }
    let src_arg = source.to_string_lossy().into_owned();
    let root_arg = config_root.to_string_lossy().into_owned();
    if apply {
        let _ = run(&bin("reddot-deploy"), &["deploy", "--src", &src_arg, "--config-root", &root_arg, "--apply"]);
        if sddm {
            let installer = source.join("sddm/themes/torii/install.sh");
            if installer.exists() {
                let _ = Command::new("sh").arg(&installer).env("SUDO", "sudo").status();
            }
        }
        if grub {
            let _ = run(&bin("reddot-grub"), &["apply", "--source", &src_arg, "--root", "sudo", "--apply"]);
        }
        if fish {
            if let Some(sh) = ["/usr/bin/fish", "/usr/local/bin/fish"].iter().find(|p| Path::new(p).is_file()) {
                let user = env::var("USER").unwrap_or_default();
                let _ = Command::new("sudo").args(["chsh", "-s", sh, &user]).output();
            }
        }
        let _ = run(&bin("reddot-neutralize"), &["--src", &src_arg, "--config-root", &root_arg, "--apply"]);
    } else {
        for (b, args) in [
            ("reddot-deploy", vec!["deploy", "--src", &src_arg, "--config-root", &root_arg]),
            ("reddot-neutralize", vec!["--src", &src_arg, "--config-root", &root_arg]),
        ] {
            match run(&bin(b), &args) { Ok(out) => print!("{out}"), Err(e) => eprintln!("{e}") }
        }
    }
    for mode in ["wallpapers", "app-theme", "bridge", "link-cli"] {
        let starters = source.parent().unwrap_or(Path::new(".")).join("installer/starter-wallpapers");
        let starters_arg = starters.to_string_lossy().into_owned();
        let mut pargs = vec![mode, "--starters", &starters_arg, "--config-root", &root_arg];
        if !apply { pargs.push("--dry-run"); }
        match run(&bin("reddot-post"), &pargs) {
            Ok(out) => print!("{out}"),
            Err(e) => eprintln!("{e}"),
        }
    }
    if brave {
        let starters = source.parent().unwrap_or(Path::new(".")).join("installer/starter-wallpapers");
        let starters_arg = starters.to_string_lossy().into_owned();
        let mut pargs = vec!["brave", "--starters", &starters_arg, "--config-root", &root_arg];
        if !apply { pargs.push("--dry-run"); }
        let _ = run(&bin("reddot-post"), &pargs);
    }
    if apply {
        let updater = config_root.join("hypr/scripts/reddot-update");
        let updater_arg = updater.to_string_lossy().into_owned();
        let _ = run(&bin("reddot-post"), &["baseline", "--source", &src_arg, "--config-root", &root_arg, "--updater", &updater_arg]);
    }
    let mut fargs = vec!["--plan", &plan_arg, "--family", &family, "--final", "--init", &init];
    if !apply { fargs.push("--dry-run"); }
    match run(&bin("reddot-report"), &fargs) { Ok(out) => print!("{out}"), Err(e) => eprintln!("{e}") }
    let _ = fs::remove_file(&plan);
    let _ = fs::remove_file(&fallback_path);
    println!("reddot-install: quickstart {} complete", if apply { "apply" } else { "dry-run" });
}
