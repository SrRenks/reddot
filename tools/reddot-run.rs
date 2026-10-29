//! Package-phase runner: reads the plan JSON from reddot-plan and runs refresh,
//! repositories, Portage overrides, native and AUR batches. Dry-run prints the
//! exact commands; otherwise failures are collected, never raised.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;

#[allow(dead_code)]
#[derive(Clone, Debug)]
enum Json { Null, Bool(bool), Num(f64), Str(String), Arr(Vec<Json>), Obj(BTreeMap<String, Json>) }
struct P<'a> { b: &'a [u8], i: usize }
impl<'a> P<'a> {
    fn parse(t: &'a str) -> Result<Json, String> { let mut p = Self { b: t.as_bytes(), i: 0 }; let v = p.value()?; p.ws(); if p.i != p.b.len() { return Err("json".into()); } Ok(v) }
    fn ws(&mut self) { while self.i < self.b.len() && self.b[self.i].is_ascii_whitespace() { self.i += 1; } }
    fn value(&mut self) -> Result<Json, String> {
        self.ws();
        match *self.b.get(self.i).ok_or("end")? {
            b'n' => { self.lit(b"null")?; Ok(Json::Null) }, b't' => { self.lit(b"true")?; Ok(Json::Bool(true)) }, b'f' => { self.lit(b"false")?; Ok(Json::Bool(false)) },
            b'"' => Ok(Json::Str(self.string()?)), b'[' => self.array(), b'{' => self.object(), b'-' | b'0'..=b'9' => self.number(), c => Err(format!("json {c}")),
        }
    }
    fn lit(&mut self, w: &[u8]) -> Result<(), String> { if self.b.get(self.i..self.i + w.len()) == Some(w) { self.i += w.len(); Ok(()) } else { Err("lit".into()) } }
    fn string(&mut self) -> Result<String, String> {
        if self.b.get(self.i) != Some(&b'"') { return Err("str".into()); } self.i += 1; let mut o = String::new();
        loop { let c = *self.b.get(self.i).ok_or("str")?; self.i += 1; match c {
            b'"' => return Ok(o), b'\\' => { let e = *self.b.get(self.i).ok_or("esc")?; self.i += 1; match e { b'"' => o.push('"'), b'\\' => o.push('\\'), b'/' => o.push('/'), b'n' => o.push('\n'), b'r' => o.push('\r'), b't' => o.push('\t'), b'b' => o.push('\u{8}'), b'f' => o.push('\u{c}'), b'u' => { let mut n = 0u32; for _ in 0..4 { let h = *self.b.get(self.i).ok_or("u")?; self.i += 1; n = (n << 4) + match h { b'0'..=b'9' => (h-b'0') as u32, b'a'..=b'f' => (h-b'a'+10) as u32, b'A'..=b'F' => (h-b'A'+10) as u32, _ => return Err("u".into()) }; } o.push(char::from_u32(n).ok_or("u")?); }, _ => return Err("esc".into()) } }, c if c < 0x20 => return Err("ctl".into()), c => o.push(c as char) } }
    }
    fn array(&mut self) -> Result<Json, String> { self.i += 1; let mut a = Vec::new(); self.ws(); if self.b.get(self.i) == Some(&b']') { self.i += 1; return Ok(Json::Arr(a)); } loop { a.push(self.value()?); self.ws(); match self.b.get(self.i) { Some(b',') => self.i += 1, Some(b']') => { self.i += 1; return Ok(Json::Arr(a)); }, _ => return Err("arr".into()) } } }
    fn object(&mut self) -> Result<Json, String> { self.i += 1; let mut m = BTreeMap::new(); self.ws(); if self.b.get(self.i) == Some(&b'}') { self.i += 1; return Ok(Json::Obj(m)); } loop { let k = self.string()?; self.ws(); if self.b.get(self.i) != Some(&b':') { return Err("colon".into()); } self.i += 1; m.insert(k, self.value()?); self.ws(); match self.b.get(self.i) { Some(b',') => { self.i += 1; self.ws(); }, Some(b'}') => { self.i += 1; return Ok(Json::Obj(m)); }, _ => return Err("obj".into()) } } }
    fn number(&mut self) -> Result<Json, String> { let s = self.i; while self.i < self.b.len() && matches!(self.b[self.i], b'-'|b'+'|b'.'|b'e'|b'E'|b'0'..=b'9') { self.i += 1; } Ok(Json::Num(std::str::from_utf8(&self.b[s..self.i]).map_err(|_| "n")?.parse().map_err(|_| "n")?)) }
}
fn strings(v: &Json, key: &str) -> Vec<String> {
    match v { Json::Obj(m) => match m.get(key) { Some(Json::Arr(a)) => a.iter().filter_map(|x| if let Json::Str(s)=x { Some(s.clone()) } else { None }).collect(), _ => vec![], }, _ => vec![], }
}
fn quote(s: &str) -> String { if s.chars().all(|c| c.is_ascii_alphanumeric() || "_@%+=:,./-".contains(c)) { s.into() } else { format!("'{}'", s.replace('\'', "'\\''")) } }
fn print_cmd(argv: &[String]) { println!("  would run: {}", argv.iter().map(|s| quote(s)).collect::<Vec<_>>().join(" ")); }
fn execute(argv: &[String], dry: bool) -> Result<(), String> {
    if dry { print_cmd(argv); return Ok(()); }
    let status = Command::new(&argv[0]).args(&argv[1..]).status().map_err(|e| format!("{e}: {}", argv.join(" ")))?;
    if status.success() { Ok(()) } else { Err(format!("exit {}: {}", status.code().unwrap_or(-1), argv.join(" "))) }
}
fn apt_has_backports(needle: &str) -> bool {
    let mut files = vec![std::path::PathBuf::from("/etc/apt/sources.list")];
    if let Ok(entries) = fs::read_dir("/etc/apt/sources.list.d") {
        for entry in entries.flatten() {
            let p = entry.path();
            if p.extension().and_then(|e| e.to_str()).map_or(false, |e| e == "list" || e == "sources") {
                files.push(p);
            }
        }
    }
    files.iter().any(|p| fs::read_to_string(p).map(|t| t.contains(needle)).unwrap_or(false))
}
fn debian_backports() -> Option<String> {
    let text = fs::read_to_string("/etc/os-release").ok()?;
    let id = text.lines().find(|l| l.starts_with("ID=")).map(|l| l[3..].trim_matches(['"', '\''].as_ref())).unwrap_or("");
    if id != "debian" { return None; }
    let code = text.lines().find_map(|l| l.strip_prefix("VERSION_CODENAME=")).unwrap_or("").trim_matches(['"', '\''].as_ref());
    if code.is_empty() { return None; }
    let needle = format!("{code}-backports");
    apt_has_backports(&needle).then(|| needle)
}
fn batch(family: &str, names: &[String]) -> Vec<String> {
    if names.is_empty() { return Vec::new(); }
    let mut a = match family {
        "arch" => vec!["pacman".into(), "-S".into(), "--needed".into(), "--noconfirm".into()],
        "debian" => {
            let mut a = vec!["apt-get".into(), "install".into(), "-y".into()];
            if let Some(release) = debian_backports() { a.push("-t".into()); a.push(release); }
            a
        },
        "fedora" => vec!["dnf".into(), "install".into(), "-y".into()],
        "gentoo" => vec!["emerge".into(), "--noreplace".into()],
        _ => vec!["zypper".into(), "--non-interactive".into(), "install".into()],
    };
    a.extend(names.iter().cloned());
    a
}
fn suse_target() -> String {
    let text = fs::read_to_string("/etc/os-release").unwrap_or_default();
    let version = text.lines().find_map(|l| l.strip_prefix("VERSION_ID=")).unwrap_or("").trim_matches(['"', '\'']);
    if version.split('.').count() == 2 && version.split('.').all(|p| !p.is_empty() && p.chars().all(|c| c.is_ascii_digit())) {
        format!("openSUSE_Leap_{version}")
    } else {
        "openSUSE_Tumbleweed".into()
    }
}
fn repo_steps(repo: &str, family: &str) -> Vec<Vec<String>> {
    if repo.starts_with("copr:") && family == "fedora" {
        return vec![vec!["sh".into(), "-c".into(), "dnf install -y dnf-plugins-core 2>/dev/null; dnf install -y dnf5-plugins 2>/dev/null; true".into()], vec!["dnf".into(), "copr".into(), "enable".into(), "-y".into(), repo[5..].into()]];
    }
    if repo.starts_with("overlay:") && family == "gentoo" {
        let name = &repo[8..];
        return vec![vec!["emerge".into(), "--noreplace".into(), "app-eselect/eselect-repository".into()], vec!["sh".into(), "-c".into(), format!("portageq get_repo_path / {name} >/dev/null 2>&1 || eselect repository enable {name}")], vec!["emerge".into(), "--sync".into(), name.into()]];
    }
    if repo.starts_with("obs:") && family == "suse" {
        let project = &repo[4..];
        return vec![vec!["zypper".into(), "--non-interactive".into(), "addrepo".into(), format!("https://download.opensuse.org/repositories/{}/{}/", project.replace(':', ":/"), suse_target()), project.replace(':', "_")], vec!["zypper".into(), "--non-interactive".into(), "--gpg-auto-import-keys".into(), "refresh".into()]];
    }
    Vec::new()
}
fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut plan_path = PathBuf::new(); let mut family = String::new(); let mut root = "sudo".to_string(); let mut aur = String::new(); let mut dry = false;
    let mut init = "systemd".to_string(); let mut services = false;
    let mut fallbacks_path = PathBuf::new();
    let mut i = 0;
    while i < args.len() { match args[i].as_str() { "--plan" => { i+=1; plan_path=PathBuf::from(args.get(i).cloned().unwrap_or_default()); }, "--family" => { i+=1; family=args.get(i).cloned().unwrap_or_default(); }, "--root" => { i+=1; root=args.get(i).cloned().unwrap_or_else(||"sudo".into()); }, "--aur-helper" => { i+=1; aur=args.get(i).cloned().unwrap_or_default(); }, "--dry-run" => dry=true, "--init" => { i+=1; init=args.get(i).cloned().unwrap_or_else(||"systemd".into()); }, "--services" => services=true, "--fallbacks-json" => { i+=1; fallbacks_path=PathBuf::from(args.get(i).cloned().unwrap_or_default()); }, _ => {} } i+=1; }
    let mut failures = 0;
    let text = fs::read_to_string(&plan_path).unwrap_or_else(|e| { eprintln!("{e}"); std::process::exit(1); });
    let plan = P::parse(&text).unwrap_or_else(|e| { eprintln!("{e}"); std::process::exit(1); });
    let mut commands: Vec<Vec<String>> = Vec::new();
    let mut refresh = vec![root.clone()];
    refresh.extend(match family.as_str() { "arch" => vec!["pacman","-Syu","--noconfirm"], "debian" => vec!["apt-get","update"], "fedora" => vec!["dnf","makecache"], "gentoo" => vec!["emerge","--sync"], _ => vec!["zypper","--non-interactive","refresh"] }.into_iter().map(str::to_string));
    commands.push(refresh);
    for repo in strings(&plan, "repos") { for step in repo_steps(&repo, &family) { let mut s = vec![root.clone()]; s.extend(step); commands.push(s); } }
    let native = strings(&plan, "native");
    if !native.is_empty() { let mut s = vec![root.clone()]; s.extend(batch(&family, &native)); commands.push(s); }
    let aur_names = strings(&plan, "aur");
    if !aur_names.is_empty() {
        let found = ["yay","paru"].iter().find(|h| env::var_os("PATH").map(|p| env::split_paths(&p).any(|d| d.join(*h).is_file())).unwrap_or(false)).map(|s| s.to_string());
        let helper = if !aur.is_empty() && aur != "none" { aur.clone() } else { found.clone().unwrap_or_else(|| "yay".into()) };
        if found.is_none() && aur != "none" {
            commands.push(vec![root.clone(), "pacman".into(), "-S".into(), "--needed".into(), "--noconfirm".into(), "git".into(), "base-devel".into()]);
            commands.push(vec!["sh".into(), "-c".into(), "rm -rf /tmp/reddot-yay-build && git clone https://aur.archlinux.org/yay-bin.git /tmp/reddot-yay-build".into()]);
            commands.push(vec!["sh".into(), "-c".into(), "cd /tmp/reddot-yay-build && makepkg -si --noconfirm".into()]);
        }
        if aur != "none" {
            let mut s = vec![helper, "-S".into(), "--needed".into(), "--noconfirm".into()]; s.extend(aur_names); commands.push(s);
        }
    }
    if !fallbacks_path.as_os_str().is_empty() {
        let text = fs::read_to_string(&fallbacks_path).unwrap_or_else(|e| { eprintln!("{e}"); std::process::exit(1); });
        match P::parse(&text) {
            Ok(Json::Arr(steps)) => {
                for step in steps {
                    if let Json::Obj(map) = step {
                        let desc = match map.get("desc") { Some(Json::Str(s)) => s.clone(), _ => String::new() };
                        if let Some(Json::Arr(argv)) = map.get("run") {
                            let cmd: Vec<String> = argv.iter().filter_map(|v| if let Json::Str(s) = v { Some(s.clone()) } else { None }).collect();
                            if !dry { println!("  run: {desc}"); }
                            if let Err(e) = execute(&cmd, dry) { eprintln!("FAILED fallback {desc}: {e}"); failures += 1; }
                        } else if let Some(Json::Str(shell)) = map.get("shell") {
                            let cmd = vec!["sh".to_string(), "-c".to_string(), shell.clone()];
                            if !dry { println!("  shell: {desc}"); }
                            if let Err(e) = execute(&cmd, dry) { eprintln!("FAILED fallback {desc}: {e}"); failures += 1; }
                        }
                    }
                }
            }
            _ => { eprintln!("fallbacks JSON must be an array"); std::process::exit(1); }
        }
    }
    if services {
        if init == "systemd" {
            commands.push(vec![root.clone(), "systemctl".into(), "enable".into(), "--now".into(), "NetworkManager.service".into()]);
            commands.push(vec![root.clone(), "systemctl".into(), "enable".into(), "--now".into(), "bluetooth.service".into()]);
            if ["/usr/bin/hyprsunset", "/usr/local/bin/hyprsunset"].iter().any(|p| PathBuf::from(p).is_file()) {
                commands.push(vec!["systemctl".into(), "--user".into(), "enable".into(), "--now".into(), "hyprsunset.service".into()]);
            }
        } else if init == "openrc" {
            for name in ["NetworkManager", "bluetooth"] {
                commands.push(vec!["sh".into(), "-c".into(), format!("s={name}; [ -e /etc/init.d/$s ] || s={name}d; {root} rc-update add $s default && {root} rc-service $s start")]);
            }
        }
    }
    for cmd in &commands { if let Err(e) = execute(cmd, dry) { failures += 1; eprintln!("FAILED: {e}"); } }
    if failures > 0 { std::process::exit(1); }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn batch_shape() {
        assert_eq!(batch("arch", &["foo".into()]), vec!["pacman","-S","--needed","--noconfirm","foo"]);
        assert!(!batch("fedora", &["foo".into()]).contains(&"--skip-broken".into()));
    }
    #[test]
    fn quote_spaces() { assert_eq!(quote("a b"), "'a b'"); }
}
