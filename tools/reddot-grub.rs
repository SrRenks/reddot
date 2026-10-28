//! Rust port of installer/grub_theme.py. Theme-only steps; boot entries are never
//! changed.

use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

const THEME: &str = "torii";
const GRUB_ROOT: &str = "/boot/grub";
const THEME_DEST: &str = "/boot/grub/themes/torii";
const THEME_TXT: &str = "/boot/grub/themes/torii/theme.txt";
const GRUB_DEFAULT: &str = "/etc/default/grub";
const GRUB_BACKUP: &str = "/etc/default/grub.reddot-bak";
const GRUB_CFG: &str = "/boot/grub/grub.cfg";

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

#[derive(Clone, Debug, PartialEq)]
struct Action {
    desc: String,
    cmd: Vec<String>,
    ok: Option<bool>,
    detail: Option<String>,
}

fn plan(source: &Path, root: &str) -> Vec<Action> {
    let theme_src = source.join("grub/themes").join(THEME);
    vec![
        Action {
            desc: format!("Copy the torii GRUB theme to {THEME_DEST}"),
            cmd: vec![root.into(), "sh".into(), "-c".into(), format!(
                "mkdir -p {}/themes && cp -rT {} {}",
                quote(GRUB_ROOT), quote(&theme_src.to_string_lossy()), quote(THEME_DEST)
            )],
            ok: None, detail: None,
        },
        Action {
            desc: format!("Back up {GRUB_DEFAULT} and set GRUB_THEME"),
            cmd: vec![root.into(), "sh".into(), "-c".into(), format!(
                "cp -n {} {} 2>/dev/null || true; if grep -q \"^GRUB_THEME=\" {} 2>/dev/null; then sed -i 's|^GRUB_THEME=.*|GRUB_THEME=\"{THEME_TXT}\"|' {}; else printf '\\nGRUB_THEME=\"{THEME_TXT}\"\\n' >> {}; fi",
                quote(GRUB_DEFAULT), quote(GRUB_BACKUP), quote(GRUB_DEFAULT), quote(GRUB_DEFAULT), quote(GRUB_DEFAULT)
            )],
            ok: None, detail: None,
        },
        Action {
            desc: format!("Regenerate {GRUB_CFG}"),
            cmd: vec![root.into(), "grub-mkconfig".into(), "-o".into(), GRUB_CFG.into()],
            ok: None, detail: None,
        },
    ]
}

fn printable(cmd: &[String]) -> String {
    cmd.iter().map(|s| quote(s)).collect::<Vec<_>>().join(" ")
}

fn run(cmd: &[String]) -> (bool, String) {
    match Command::new(&cmd[0]).args(&cmd[1..]).status() {
        Ok(status) if status.success() => (true, String::new()),
        Ok(status) => (false, format!("exit {}: {}", status.code().unwrap_or(-1), printable(cmd))),
        Err(err) => (false, format!("{err}: {}", printable(cmd))),
    }
}

fn apply(source: &Path, root: &str, dry: bool) -> Vec<Action> {
    let mut actions = plan(source, root);
    if dry {
        return actions;
    }
    if !Path::new(GRUB_ROOT).is_dir() || !Path::new(GRUB_DEFAULT).is_file() {
        let missing = if !Path::new(GRUB_ROOT).is_dir() { GRUB_ROOT } else { GRUB_DEFAULT };
        for action in &mut actions {
            action.ok = Some(false);
            action.detail = Some(format!("{missing} not found, not a standard GRUB install"));
        }
        return actions;
    }
    for action in &mut actions {
        let (ok, detail) = run(&action.cmd);
        action.ok = Some(ok);
        action.detail = Some(detail);
    }
    actions
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
fn actions_json(actions: &[Action], include_status: bool) -> String {
    let body: Vec<String> = actions.iter().map(|a| {
        let mut fields = vec![format!("\"desc\":{}", json(&a.desc)), format!("\"cmd\":{}", argv_json(&a.cmd))];
        if include_status {
            fields.push(format!("\"ok\":{}", if a.ok == Some(true) { "true" } else { "false" }));
            fields.push(format!("\"detail\":{}", json(a.detail.as_deref().unwrap_or(""))));
        }
        format!("{{{}}}", fields.join(","))
    }).collect();
    format!("[{}]", body.join(","))
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mode = args.first().map(String::as_str).unwrap_or("plan");
    let mut source = PathBuf::from("configs");
    let mut root = "sudo".to_string();
    let mut dry = false;
    let mut live = false;
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--source" => { i += 1; source = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--root" => { i += 1; root = args.get(i).cloned().unwrap_or_else(|| "sudo".into()); }
            "--dry" => dry = true,
            "--apply" => live = true,
            _ => {}
        }
        i += 1;
    }
    if live {
        let actions = apply(&source, &root, false);
        println!("{}", actions_json(&actions, true));
        return;
    }
    let actions = apply(&source, &root, true);
    if mode == "plan" || dry || mode == "apply" {
        println!("{}", actions_json(&actions, false));
        return;
    }
    eprintln!("usage: reddot-grub plan --source DIR [--root CMD]");
    std::process::exit(2);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn three_actions() {
        let actions = plan(Path::new("configs"), "sudo");
        assert_eq!(actions.len(), 3);
        assert!(actions.iter().all(|a| !a.cmd.is_empty()));
        assert!(actions[0].cmd.iter().any(|x| x.contains("cp -rT")));
    }

    #[test]
    fn root_choice() {
        let actions = plan(Path::new("configs"), "doas");
        assert!(actions.iter().all(|a| a.cmd[0] == "doas"));
    }
}
