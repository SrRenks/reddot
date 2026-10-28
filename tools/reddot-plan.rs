//! Rust port of reddot_install._build_plan: resolve the selected groups into
//! native, AUR, fallback and skipped batches. Read-only.

use std::collections::{BTreeMap, BTreeSet};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

const FAMILIES: [&str; 5] = ["arch", "debian", "fedora", "suse", "gentoo"];

#[derive(Clone, Debug, PartialEq)]
enum Json {
    Null,
    Bool(bool),
    Number(f64),
    String(String),
    Array(Vec<Json>),
    Object(BTreeMap<String, Json>),
}
impl Json {
    fn as_str(&self) -> Option<&str> { if let Json::String(s) = self { Some(s) } else { None } }
    fn as_bool(&self) -> Option<bool> { if let Json::Bool(v) = self { Some(*v) } else { None } }
    fn as_array(&self) -> Option<&[Json]> { if let Json::Array(a) = self { Some(a) } else { None } }
    fn get(&self, key: &str) -> Option<&Json> { if let Json::Object(m) = self { m.get(key) } else { None } }
}
struct P<'a> { b: &'a [u8], i: usize }
impl<'a> P<'a> {
    fn parse(text: &'a str) -> Result<Json, String> {
        let mut p = Self { b: text.as_bytes(), i: 0 };
        let v = p.value()?; p.ws();
        if p.i != p.b.len() { return Err("trailing JSON".into()); }
        Ok(v)
    }
    fn ws(&mut self) { while self.i < self.b.len() && self.b[self.i].is_ascii_whitespace() { self.i += 1; } }
    fn value(&mut self) -> Result<Json, String> {
        self.ws();
        match *self.b.get(self.i).ok_or("end")? {
            b'n' => { self.lit(b"null")?; Ok(Json::Null) }
            b't' => { self.lit(b"true")?; Ok(Json::Bool(true)) }
            b'f' => { self.lit(b"false")?; Ok(Json::Bool(false)) }
            b'"' => Ok(Json::String(self.string()?)),
            b'[' => self.array(), b'{' => self.object(),
            b'-' | b'0'..=b'9' => self.number(),
            c => Err(format!("JSON {c}")),
        }
    }
    fn lit(&mut self, w: &[u8]) -> Result<(), String> {
        if self.b.get(self.i..self.i + w.len()) == Some(w) { self.i += w.len(); Ok(()) } else { Err("literal".into()) }
    }
    fn string(&mut self) -> Result<String, String> {
        if self.b.get(self.i) != Some(&b'"') { return Err("string".into()); }
        self.i += 1; let mut out = String::new();
        loop {
            let c = *self.b.get(self.i).ok_or("string end")?; self.i += 1;
            match c {
                b'"' => return Ok(out),
                b'\\' => {
                    let e = *self.b.get(self.i).ok_or("escape")?; self.i += 1;
                    match e {
                        b'"' => out.push('"'), b'\\' => out.push('\\'), b'/' => out.push('/'),
                        b'n' => out.push('\n'), b'r' => out.push('\r'), b't' => out.push('\t'),
                        b'b' => out.push('\u{8}'), b'f' => out.push('\u{c}'),
                        b'u' => {
                            let mut n = 0u32;
                            for _ in 0..4 {
                                let h = *self.b.get(self.i).ok_or("unicode")?; self.i += 1;
                                n = (n << 4) + match h { b'0'..=b'9' => (h - b'0') as u32, b'a'..=b'f' => (h - b'a' + 10) as u32, b'A'..=b'F' => (h - b'A' + 10) as u32, _ => return Err("unicode".into()) };
                            }
                            out.push(char::from_u32(n).ok_or("unicode")?);
                        }
                        _ => return Err("escape".into()),
                    }
                }
                c if c < 0x20 => return Err("control".into()),
                c => out.push(c as char),
            }
        }
    }
    fn array(&mut self) -> Result<Json, String> {
        self.i += 1; let mut out = Vec::new(); self.ws();
        if self.b.get(self.i) == Some(&b']') { self.i += 1; return Ok(Json::Array(out)); }
        loop {
            out.push(self.value()?); self.ws();
            match self.b.get(self.i) { Some(b',') => self.i += 1, Some(b']') => { self.i += 1; return Ok(Json::Array(out)); }, _ => return Err("array".into()) }
        }
    }
    fn object(&mut self) -> Result<Json, String> {
        self.i += 1; let mut out = BTreeMap::new(); self.ws();
        if self.b.get(self.i) == Some(&b'}') { self.i += 1; return Ok(Json::Object(out)); }
        loop {
            let k = self.string()?; self.ws();
            if self.b.get(self.i) != Some(&b':') { return Err("colon".into()); }
            self.i += 1; out.insert(k, self.value()?); self.ws();
            match self.b.get(self.i) { Some(b',') => { self.i += 1; self.ws(); }, Some(b'}') => { self.i += 1; return Ok(Json::Object(out)); }, _ => return Err("object".into()) }
        }
    }
    fn number(&mut self) -> Result<Json, String> {
        let s = self.i;
        while self.i < self.b.len() && matches!(self.b[self.i], b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9') { self.i += 1; }
        Ok(Json::Number(std::str::from_utf8(&self.b[s..self.i]).map_err(|_| "num")?.parse().map_err(|_| "num")?))
    }
}
fn json(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() { match c { '"' => o.push_str("\\\""), '\\' => o.push_str("\\\\"), '\n' => o.push_str("\\n"), '\r' => o.push_str("\\r"), '\t' => o.push_str("\\t"), c if (c as u32) < 0x20 => o.push_str(&format!("\\u{:04x}", c as u32)), c => o.push(c) } }
    o.push('"'); o
}
fn arr(items: &[String]) -> String { format!("[{}]", items.iter().map(|s| json(s)).collect::<Vec<_>>().join(",")) }
fn which(bin: &str) -> bool { env::var_os("PATH").map(|p| env::split_paths(&p).any(|d| d.join(bin).is_file())).unwrap_or(false) }

fn is_installed(name: &str, family: &str) -> bool {
    let (prog, args): (&str, Vec<&str>) = match family {
        "arch" => ("pacman", vec!["-Qq", name]),
        "debian" => ("dpkg-query", vec!["-W", "-f=${Status}", name]),
        "gentoo" => ("portageq", vec!["has_version", "/", name]),
        _ => ("rpm", vec!["-q", name]),
    };
    Command::new(prog).args(args).output().map(|o| if family == "debian" { String::from_utf8_lossy(&o.stdout).contains("install ok installed") } else { o.status.success() }).unwrap_or(false)
}
fn present(fallback: &str, id: &str, app: &str) -> bool {
    let home = env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
    match fallback {
        "cargo" | "ghostty" | "dotool" | "curl" => which(id),
        "nerdfont" => fs::read_dir(home.join(".local/share/fonts")).map(|d| d.filter_map(Result::ok).any(|e| e.file_name().to_string_lossy().starts_with("JetBrainsMono"))).unwrap_or(false),
        "github" => home.join(".local/share/icons/Bibata-Modern-Classic").is_dir(),
        "flatpak" => !app.is_empty() && Command::new("flatpak").args(["info", "--user", app]).output().map(|o| o.status.success()).unwrap_or(false),
        _ => false,
    }
}
fn native(pkg: &Json, family: &str) -> Option<String> { pkg.get("names")?.get(family)?.as_str().map(str::to_string) }
fn is_aur(pkg: &Json, family: &str) -> bool { family == "arch" && pkg.get("aur").and_then(Json::as_bool) == Some(true) && native(pkg, family).is_some() }
fn repo(pkg: &Json, family: &str) -> Option<String> { pkg.get("repo")?.get(family)?.as_str().map(str::to_string) }

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut manifest_path = PathBuf::from("installer/packages.json");
    let mut family = String::new();
    let mut profile = "quick".to_string();
    let mut optional: BTreeSet<String> = BTreeSet::new();
    let mut aur_choice = "yay".to_string();
    let mut overlays = true;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--manifest" => { i += 1; manifest_path = PathBuf::from(args.get(i).cloned().unwrap_or_default()); }
            "--family" => { i += 1; family = args.get(i).cloned().unwrap_or_default(); }
            "--profile" => { i += 1; profile = args.get(i).cloned().unwrap_or_else(|| "quick".into()); }
            "--optional" => { i += 1; for id in args.get(i).map(|s| s.split(',').collect::<Vec<_>>()).unwrap_or_default() { if !id.is_empty() { optional.insert(id.into()); } } }
            "--aur" => { i += 1; aur_choice = args.get(i).cloned().unwrap_or_else(|| "yay".into()); }
            "--no-overlays" => overlays = false,
            _ => {}
        }
        i += 1;
    }
    if !FAMILIES.contains(&family.as_str()) { eprintln!("unknown family"); std::process::exit(2); }
    let text = fs::read_to_string(&manifest_path).unwrap_or_else(|e| { eprintln!("{e}"); std::process::exit(1); });
    let manifest = P::parse(&text).unwrap_or_else(|e| { eprintln!("{e}"); std::process::exit(1); });
    let packages = manifest.get("packages").and_then(Json::as_array).unwrap_or(&[]);
    let by_id: BTreeMap<&str, &Json> = packages.iter().filter_map(|p| p.get("id").and_then(Json::as_str).map(|id| (id, p))).collect();
    let groups: &[&str] = if profile == "quick" { &["core"] } else { &["core", "full"] };
    let mut repos: Vec<String> = Vec::new();
    let mut native_names: Vec<String> = Vec::new();
    let mut aur_names: Vec<String> = Vec::new();
    let mut fallbacks: Vec<(String, String, String)> = Vec::new();
    let mut skipped: Vec<String> = Vec::new();
    let mut optional_native: BTreeSet<String> = BTreeSet::new();
    let mut manual: Vec<String> = Vec::new();
    let mut atom_repos: BTreeMap<String, Option<String>> = BTreeMap::new();
    for pkg in packages {
        let group = pkg.get("group").and_then(Json::as_str).unwrap_or("");
        if !groups.contains(&group) { continue; }
        let id = pkg.get("id").and_then(Json::as_str).unwrap_or("");
        if profile != "quick" && group != "core" && !optional.contains(id) { continue; }
        let (action, target) = if family == "arch" && is_aur(pkg, &family) && aur_choice == "none" {
            match pkg.get("fallback").and_then(Json::as_str) { Some(f) => ("fallback".to_string(), Some(f.to_string())), None => ("skip".into(), None) }
        } else if let Some(name) = native(pkg, &family) {
            ("native".into(), Some(name))
        } else if let Some(f) = pkg.get("fallback").and_then(Json::as_str) {
            ("fallback".into(), Some(f.into()))
        } else {
            ("skip".into(), None)
        };
        if action == "skip" { continue; }
        let repo = repo(pkg, &family);
        if repo.as_deref().map(|r| r.starts_with("overlay:")).unwrap_or(false) && !overlays {
            if let Some(t) = target { manual.push(t); }
            continue;
        }
        if action == "fallback" {
            let handler = target.clone().unwrap_or_default();
            let app = pkg.get("flatpak_id").and_then(Json::as_str).unwrap_or("");
            if present(&handler, id, app) { skipped.push(id.into()); }
            else { fallbacks.push((id.into(), handler, String::new())); }
            continue;
        }
        let target = target.unwrap_or_default();
        if is_installed(&target, &family) { skipped.push(id.into()); continue; }
        if let Some(r) = &repo {
            if !repos.contains(r) { repos.push(r.clone()); }
        }
        if is_aur(pkg, &family) { aur_names.push(target.clone()); } else { native_names.push(target.clone()); }
        atom_repos.insert(target.clone(), repo);
        if !is_aur(pkg, &family) && pkg.get("required").and_then(Json::as_bool) != Some(true) { optional_native.insert(target); }
    }
    let atom_json: Vec<String> = atom_repos.iter().map(|(k, v)| format!("{}:{}", json(k), v.as_deref().map(json).unwrap_or_else(|| "null".into()))).collect();
    let fb_json: Vec<String> = fallbacks.iter().map(|(id, handler, _)| format!("[{},{}]", json(id), json(handler))).collect();
    println!("{{{}}}", vec![
        format!("\"repos\":{}", arr(&repos)),
        format!("\"native\":{}", arr(&native_names)),
        format!("\"aur\":{}", arr(&aur_names)),
        format!("\"fallbacks\":[{}]", fb_json.join(",")),
        format!("\"skipped\":{}", arr(&skipped)),
        format!("\"optionalNative\":{}", arr(&optional_native.into_iter().collect::<Vec<_>>())),
        format!("\"manual\":{}", arr(&manual)),
        format!("\"atomRepos\":{{{}}}", atom_json.join(",")),
    ].join(","));
    let _ = by_id;
    let _ = Path::new(".");
}
