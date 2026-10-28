//! Rust port of reddot_install post-install helpers: wallpapers, app-theme flag,
//! awww bridge, reddot CLI link and Brave GTK seed.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::os::unix::fs::symlink;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, PartialEq)]
enum Json { Null, Bool(bool), Number(f64), String(String), Array(Vec<Json>), Object(BTreeMap<String, Json>) }
impl Json {}
struct P<'a> { b: &'a [u8], i: usize }
impl<'a> P<'a> {
    fn parse(t: &'a str) -> Result<Json, String> { let mut p = Self { b: t.as_bytes(), i: 0 }; let v = p.value()?; p.ws(); if p.i != p.b.len() { return Err("trailing".into()); } Ok(v) }
    fn ws(&mut self) { while self.i < self.b.len() && self.b[self.i].is_ascii_whitespace() { self.i += 1; } }
    fn value(&mut self) -> Result<Json, String> {
        self.ws();
        match *self.b.get(self.i).ok_or("end")? {
            b'n' => { self.lit(b"null")?; Ok(Json::Null) }, b't' => { self.lit(b"true")?; Ok(Json::Bool(true)) }, b'f' => { self.lit(b"false")?; Ok(Json::Bool(false)) },
            b'"' => Ok(Json::String(self.string()?)), b'[' => self.array(), b'{' => self.object(), b'-' | b'0'..=b'9' => self.number(), c => Err(format!("json {c}")),
        }
    }
    fn lit(&mut self, w: &[u8]) -> Result<(), String> { if self.b.get(self.i..self.i + w.len()) == Some(w) { self.i += w.len(); Ok(()) } else { Err("literal".into()) } }
    fn string(&mut self) -> Result<String, String> {
        if self.b.get(self.i) != Some(&b'"') { return Err("string".into()); } self.i += 1; let mut o = String::new();
        loop { let c = *self.b.get(self.i).ok_or("str")?; self.i += 1; match c {
            b'"' => return Ok(o), b'\\' => { let e = *self.b.get(self.i).ok_or("esc")?; self.i += 1; match e { b'"' => o.push('"'), b'\\' => o.push('\\'), b'/' => o.push('/'), b'n' => o.push('\n'), b'r' => o.push('\r'), b't' => o.push('\t'), b'b' => o.push('\u{8}'), b'f' => o.push('\u{c}'), b'u' => { let mut n = 0u32; for _ in 0..4 { let h = *self.b.get(self.i).ok_or("u")?; self.i += 1; n = (n << 4) + match h { b'0'..=b'9' => (h-b'0') as u32, b'a'..=b'f' => (h-b'a'+10) as u32, b'A'..=b'F' => (h-b'A'+10) as u32, _ => return Err("u".into()) }; } o.push(char::from_u32(n).ok_or("u")?); }, _ => return Err("esc".into()) } }, c if c < 0x20 => return Err("ctl".into()), c => o.push(c as char) } }
    }
    fn array(&mut self) -> Result<Json, String> { self.i += 1; let mut a = Vec::new(); self.ws(); if self.b.get(self.i) == Some(&b']') { self.i += 1; return Ok(Json::Array(a)); } loop { a.push(self.value()?); self.ws(); match self.b.get(self.i) { Some(b',') => self.i += 1, Some(b']') => { self.i += 1; return Ok(Json::Array(a)); }, _ => return Err("arr".into()) } } }
    fn object(&mut self) -> Result<Json, String> { self.i += 1; let mut m = BTreeMap::new(); self.ws(); if self.b.get(self.i) == Some(&b'}') { self.i += 1; return Ok(Json::Object(m)); } loop { let k = self.string()?; self.ws(); if self.b.get(self.i) != Some(&b':') { return Err("colon".into()); } self.i += 1; m.insert(k, self.value()?); self.ws(); match self.b.get(self.i) { Some(b',') => { self.i += 1; self.ws(); }, Some(b'}') => { self.i += 1; return Ok(Json::Object(m)); }, _ => return Err("obj".into()) } } }
    fn number(&mut self) -> Result<Json, String> { let s = self.i; while self.i < self.b.len() && matches!(self.b[self.i], b'-'|b'+'|b'.'|b'e'|b'E'|b'0'..=b'9') { self.i += 1; } Ok(Json::Number(std::str::from_utf8(&self.b[s..self.i]).map_err(|_| "n")?.parse().map_err(|_| "n")?)) }
}
fn esc(s: &str) -> String { let mut o = String::from("\""); for c in s.chars() { match c { '"' => o.push_str("\\\""), '\\' => o.push_str("\\\\"), '\n' => o.push_str("\\n"), '\r' => o.push_str("\\r"), '\t' => o.push_str("\\t"), c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)), c => o.push(c) } } o.push('"'); o }
fn write_json(v: &Json, pretty: bool, depth: usize, o: &mut String) {
    match v { Json::Null => o.push_str("null"), Json::Bool(b) => o.push_str(if *b {"true"} else {"false"}), Json::Number(n) => { if n.fract()==0.0 { o.push_str(&format!("{n:.0}")); } else { o.push_str(&n.to_string()); } }, Json::String(s) => o.push_str(&esc(s)), Json::Array(a) => { o.push('['); for (i,x) in a.iter().enumerate() { if i>0 { o.push(','); } write_json(x,pretty,depth+1,o); } o.push(']'); }, Json::Object(m) => { o.push('{'); for (i,(k,x)) in m.iter().enumerate() { if i>0 { o.push(','); } if pretty { o.push('\n'); o.push_str(&"  ".repeat(depth+1)); } o.push_str(&esc(k)); o.push(':'); if pretty { o.push(' '); } write_json(x,pretty,depth+1,o); } if pretty && !m.is_empty() { o.push('\n'); o.push_str(&"  ".repeat(depth)); } o.push('}'); } }
}
fn json_to(v: &Json, pretty: bool) -> String { let mut s = String::new(); write_json(v, pretty, 0, &mut s); s }
fn home() -> PathBuf { env::var_os("HOME").map(PathBuf::from).unwrap_or_default() }
fn state() -> PathBuf { env::var_os("XDG_STATE_HOME").map(PathBuf::from).unwrap_or_else(|| home().join(".local/state")).join("reddot") }
fn which(bin: &str) -> Option<PathBuf> { env::var_os("PATH").and_then(|p| env::split_paths(&p).map(|d| d.join(bin)).find(|p| p.is_file())) }
fn has_ext(p: &Path) -> bool { matches!(p.extension().and_then(|s| s.to_str()).map(|s| s.to_lowercase()).as_deref(), Some("jpg"|"jpeg"|"png")) }

fn seed_wallpapers(starters: &Path, dry: bool) -> Result<bool, String> {
    let wp = home().join("reddot/wallpapers");
    if dry { println!("  would seed wallpapers -> ~/reddot/wallpapers"); return Ok(true); }
    fs::create_dir_all(wp.join("downloads")).map_err(|e| e.to_string())?;
    fs::create_dir_all(home().join(".cache/reddot")).map_err(|e| e.to_string())?;
    let has = fs::read_dir(&wp).map(|d| d.filter_map(Result::ok).any(|e| e.path().is_file() && has_ext(&e.path()))).unwrap_or(false);
    if has { return Ok(true); }
    if !starters.is_dir() { return Ok(true); }
    let mut files: Vec<PathBuf> = fs::read_dir(starters).map_err(|e| e.to_string())?.filter_map(Result::ok).map(|e| e.path()).filter(|p| p.is_file() && has_ext(p)).collect();
    files.sort();
    for src in files { if let Some(name) = src.file_name() { fs::copy(&src, wp.join(name)).map_err(|e| e.to_string())?; } }
    Ok(true)
}
fn seed_app_theme(dry: bool) -> Result<bool, String> {
    let path = state().join("flags.json");
    if dry { println!("  would turn on the app theme in {}", path.display()); return Ok(true); }
    let mut data = if path.is_file() { fs::read_to_string(&path).ok().and_then(|t| P::parse(&t).ok()).unwrap_or_else(|| Json::Object(BTreeMap::new())) } else { Json::Object(BTreeMap::new()) };
    if let Json::Object(m) = &mut data { m.insert("appTheme".into(), Json::Bool(true)); }
    if let Some(parent) = path.parent() { fs::create_dir_all(parent).map_err(|e| e.to_string())?; }
    fs::write(&path, json_to(&data, true) + "\n").map_err(|e| e.to_string())?;
    Ok(true)
}
fn bridge(dry: bool) -> Result<bool, String> {
    if dry { println!("  would bridge: awww -> swww"); return Ok(false); }
    if which("awww").is_some() { return Ok(false); }
    let Some(swww) = which("swww") else { return Ok(false); };
    let bindir = home().join(".local/bin");
    fs::create_dir_all(&bindir).map_err(|e| e.to_string())?;
    let mut pairs = vec![("awww", swww)];
    if let Some(d) = which("swww-daemon") { pairs.push(("awww-daemon", d)); }
    for (name, target) in pairs {
        let link = bindir.join(name);
        if link.is_symlink() || link.exists() { fs::remove_file(&link).map_err(|e| e.to_string())?; }
        symlink(&target, &link).map_err(|e| e.to_string())?;
    }
    Ok(true)
}
fn link_cli(config_root: &Path, dry: bool) -> Result<bool, String> {
    let target = config_root.join("hypr/scripts/reddot");
    let link = home().join(".local/bin/reddot");
    if dry { println!("  would link: reddot -> {}", target.display()); return Ok(false); }
    if !target.exists() { return Ok(false); }
    fs::create_dir_all(link.parent().unwrap_or(Path::new("."))).map_err(|e| e.to_string())?;
    if link.is_symlink() || link.exists() { fs::remove_file(&link).map_err(|e| e.to_string())?; }
    symlink(&target, &link).map_err(|e| e.to_string())?;
    Ok(true)
}
fn brave(dry: bool) -> Result<bool, String> {
    let native = home().join(".config/BraveSoftware/Brave-Browser");
    let flat = home().join(".var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser");
    let base = if which("brave").is_some() { native } else if [PathBuf::from("/var/lib/flatpak"), home().join(".local/share/flatpak")].iter().any(|r| r.join("app/com.brave.Browser").exists()) { flat } else { return Ok(true); };
    if dry { println!("  would point Brave at GTK colors in {}", base.display()); return Ok(true); }
    if base.exists() { return Ok(false); }
    fs::create_dir_all(base.join("Default")).map_err(|e| e.to_string())?;
    fs::write(base.join("Default/Preferences"), "{\"extensions\":{\"theme\":{\"system_theme\":1}}}\n").map_err(|e| e.to_string())?;
    Ok(true)
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mode = args.first().map(String::as_str).unwrap_or("");
    let mut starters = PathBuf::from("installer/starter-wallpapers");
    let mut config_root = home().join(".config");
    let mut dry = false;
    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--starters" => { i += 1; starters = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--config-root" => { i += 1; config_root = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--dry-run" => dry = true,
            _ => {}
        }
        i += 1;
    }
    let result = match mode {
        "wallpapers" => seed_wallpapers(&starters, dry).map(|_| "ok".to_string()),
        "app-theme" => seed_app_theme(dry).map(|_| "ok".to_string()),
        "bridge" => bridge(dry).map(|_| "ok".to_string()),
        "link-cli" => link_cli(&config_root, dry).map(|_| "ok".to_string()),
        "brave" => brave(dry).map(|_| "ok".to_string()),
        _ => Err("usage: wallpapers|app-theme|bridge|link-cli|brave".into()),
    };
    match result { Ok(out) => println!("{out}"), Err(e) => { eprintln!("{e}"); std::process::exit(1); } }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn json_round_trip() { let v = P::parse("{\"a\":true,\"b\":\"x\"}").unwrap(); assert_eq!(json_to(&v, false), "{\"a\":true,\"b\":\"x\"}"); }
    #[test]
    fn extensions() { assert!(has_ext(Path::new("x.PNG"))); assert!(!has_ext(Path::new("x.webp"))); }
}
