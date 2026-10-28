//! Rust port of installer/distro.py.
//!
//! Pure decision logic: distro family detection, native-name lookup, AUR/repo
//! rules and the ordered package plan. No package manager is run here.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

const FAMILIES: [&str; 5] = ["arch", "debian", "fedora", "suse", "gentoo"];
const FAMILY_TOKENS: [(&str, &[&str]); 5] = [
    (
        "arch",
        &[
            "arch", "cachyos", "endeavouros", "manjaro", "garuda", "artix", "arcolinux",
            "archcraft", "rebornos", "athena", "blackarch", "archbang", "crystal", "snigdha",
            "parabola", "obarun", "arch32", "hyperbola", "steamos", "omarchy", "xerolinux",
            "archman", "biglinux", "ctlos", "tromjaro", "bluestar", "arkane", "blendos",
            "acreetionos", "mabox",
        ],
    ),
    ("debian", &["debian", "ubuntu", "linuxmint", "pop", "elementary", "zorin", "raspbian"]),
    ("fedora", &["fedora", "nobara", "rhel", "centos", "rocky", "almalinux"]),
    ("suse", &["suse", "opensuse", "sles", "sled", "tumbleweed", "leap"]),
    ("gentoo", &["gentoo", "funtoo", "calculate", "pentoo", "redcore"]),
];

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
    fn as_str(&self) -> Option<&str> {
        match self {
            Json::String(s) => Some(s),
            _ => None,
        }
    }
    fn as_bool(&self) -> Option<bool> {
        match self {
            Json::Bool(v) => Some(*v),
            _ => None,
        }
    }
    fn as_array(&self) -> Option<&[Json]> {
        match self {
            Json::Array(a) => Some(a),
            _ => None,
        }
    }
    fn get(&self, key: &str) -> Option<&Json> {
        match self {
            Json::Object(m) => m.get(key),
            _ => None,
        }
    }
}

struct Parser<'a> {
    b: &'a [u8],
    i: usize,
}
impl<'a> Parser<'a> {
    fn parse(text: &'a str) -> Result<Json, String> {
        let mut p = Self { b: text.as_bytes(), i: 0 };
        let value = p.value()?;
        p.ws();
        if p.i != p.b.len() {
            return Err("trailing JSON".into());
        }
        Ok(value)
    }
    fn ws(&mut self) {
        while self.i < self.b.len() && self.b[self.i].is_ascii_whitespace() {
            self.i += 1;
        }
    }
    fn value(&mut self) -> Result<Json, String> {
        self.ws();
        match *self.b.get(self.i).ok_or("end")? {
            b'n' => { self.lit(b"null")?; Ok(Json::Null) }
            b't' => { self.lit(b"true")?; Ok(Json::Bool(true)) }
            b'f' => { self.lit(b"false")?; Ok(Json::Bool(false)) }
            b'"' => Ok(Json::String(self.string()?)),
            b'[' => self.array(),
            b'{' => self.object(),
            b'-' | b'0'..=b'9' => self.number(),
            c => Err(format!("bad JSON byte {c}")),
        }
    }
    fn lit(&mut self, want: &[u8]) -> Result<(), String> {
        if self.b.get(self.i..self.i + want.len()) == Some(want) {
            self.i += want.len();
            Ok(())
        } else {
            Err("literal".into())
        }
    }
    fn string(&mut self) -> Result<String, String> {
        if self.b.get(self.i) != Some(&b'"') {
            return Err("string".into());
        }
        self.i += 1;
        let mut out = String::new();
        loop {
            let c = *self.b.get(self.i).ok_or("string end")?;
            self.i += 1;
            match c {
                b'"' => return Ok(out),
                b'\\' => {
                    let e = *self.b.get(self.i).ok_or("escape")?;
                    self.i += 1;
                    match e {
                        b'"' => out.push('"'),
                        b'\\' => out.push('\\'),
                        b'/' => out.push('/'),
                        b'n' => out.push('\n'),
                        b'r' => out.push('\r'),
                        b't' => out.push('\t'),
                        b'b' => out.push('\u{8}'),
                        b'f' => out.push('\u{c}'),
                        b'u' => {
                            let mut n = 0u32;
                            for _ in 0..4 {
                                let h = *self.b.get(self.i).ok_or("unicode")?;
                                self.i += 1;
                                n = (n << 4)
                                    + match h {
                                        b'0'..=b'9' => (h - b'0') as u32,
                                        b'a'..=b'f' => (h - b'a' + 10) as u32,
                                        b'A'..=b'F' => (h - b'A' + 10) as u32,
                                        _ => return Err("unicode".into()),
                                    };
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
        self.i += 1;
        let mut out = Vec::new();
        self.ws();
        if self.b.get(self.i) == Some(&b']') {
            self.i += 1;
            return Ok(Json::Array(out));
        }
        loop {
            out.push(self.value()?);
            self.ws();
            match self.b.get(self.i) {
                Some(b',') => self.i += 1,
                Some(b']') => {
                    self.i += 1;
                    return Ok(Json::Array(out));
                }
                _ => return Err("array".into()),
            }
        }
    }
    fn object(&mut self) -> Result<Json, String> {
        self.i += 1;
        let mut out = BTreeMap::new();
        self.ws();
        if self.b.get(self.i) == Some(&b'}') {
            self.i += 1;
            return Ok(Json::Object(out));
        }
        loop {
            let key = self.string()?;
            self.ws();
            if self.b.get(self.i) != Some(&b':') {
                return Err("colon".into());
            }
            self.i += 1;
            out.insert(key, self.value()?);
            self.ws();
            match self.b.get(self.i) {
                Some(b',') => {
                    self.i += 1;
                    self.ws();
                }
                Some(b'}') => {
                    self.i += 1;
                    return Ok(Json::Object(out));
                }
                _ => return Err("object".into()),
            }
        }
    }
    fn number(&mut self) -> Result<Json, String> {
        let start = self.i;
        while self.i < self.b.len()
            && matches!(self.b[self.i], b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9')
        {
            self.i += 1;
        }
        let text = std::str::from_utf8(&self.b[start..self.i]).map_err(|_| "number")?;
        Ok(Json::Number(text.parse::<f64>().map_err(|_| "number")?))
    }
}

fn escape(text: &str) -> String {
    let mut out = String::new();
    for c in text.chars() {
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
    out
}

fn to_json(value: &Json, out: &mut String) {
    match value {
        Json::Null => out.push_str("null"),
        Json::Bool(v) => out.push_str(if *v { "true" } else { "false" }),
        Json::Number(v) => {
            if v.fract() == 0.0 {
                out.push_str(&format!("{v:.0}"));
            } else {
                out.push_str(&v.to_string());
            }
        }
        Json::String(s) => {
            out.push('"');
            out.push_str(&escape(s));
            out.push('"');
        }
        Json::Array(a) => {
            out.push('[');
            for (i, v) in a.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                to_json(v, out);
            }
            out.push(']');
        }
        Json::Object(m) => {
            out.push('{');
            for (i, (k, v)) in m.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                out.push('"');
                out.push_str(&escape(k));
                out.push_str("\":");
                to_json(v, out);
            }
            out.push('}');
        }
    }
}

fn json_string(value: &Json) -> String {
    let mut out = String::new();
    to_json(value, &mut out);
    out
}

fn string(value: &str) -> Json {
    Json::String(value.into())
}

fn os_release(path: &Path) -> BTreeMap<String, String> {
    let mut out = BTreeMap::new();
    if let Ok(text) = fs::read_to_string(path) {
        for line in text.lines() {
            if line.starts_with('#') {
                continue;
            }
            if let Some((key, value)) = line.split_once('=') {
                out.insert(
                    key.to_string(),
                    value.trim().trim_matches(['"', '\'']).to_string(),
                );
            }
        }
    }
    out
}

fn family_from_os_release(data: &BTreeMap<String, String>) -> String {
    let mut ids = vec![data.get("ID").cloned().unwrap_or_default().to_lowercase()];
    ids.extend(
        data.get("ID_LIKE")
            .cloned()
            .unwrap_or_default()
            .to_lowercase()
            .split_whitespace()
            .map(str::to_string),
    );
    for token in ids {
        for (family, names) in FAMILY_TOKENS {
            if names.contains(&token.as_str()) {
                return family.into();
            }
        }
    }
    "unknown".into()
}

fn native_name(pkg: &Json, family: &str) -> Option<String> {
    pkg.get("names")?.get(family)?.as_str().map(str::to_string)
}

fn is_aur(pkg: &Json, family: &str) -> bool {
    family == "arch" && pkg.get("aur").and_then(Json::as_bool) == Some(true) && native_name(pkg, family).is_some()
}

fn repo_for(pkg: &Json, family: &str) -> Option<String> {
    pkg.get("repo")?.get(family)?.as_str().map(str::to_string)
}

fn resolve(pkg: &Json, family: &str, aur_choice: &str) -> (String, Option<String>) {
    if family == "arch" && is_aur(pkg, family) && aur_choice == "none" {
        if let Some(fallback) = pkg.get("fallback").and_then(Json::as_str) {
            return ("fallback".into(), Some(fallback.into()));
        }
    }
    if let Some(name) = native_name(pkg, family) {
        return ("native".into(), Some(name));
    }
    if let Some(fallback) = pkg.get("fallback").and_then(Json::as_str) {
        return ("fallback".into(), Some(fallback.into()));
    }
    ("skip".into(), None)
}

fn plan(manifest: &Json, family: &str, groups: &[String], aur_choice: &str) -> Result<Vec<Json>, String> {
    let packages = manifest.get("packages").and_then(Json::as_array).ok_or("manifest has no packages")?;
    let mut rows = Vec::new();
    for pkg in packages {
        let group = pkg.get("group").and_then(Json::as_str).unwrap_or("");
        if !groups.iter().any(|g| g == group) {
            continue;
        }
        let id = pkg.get("id").and_then(Json::as_str).ok_or("package without id")?;
        let (action, target) = resolve(pkg, family, aur_choice);
        let mut row = BTreeMap::new();
        row.insert("id".into(), string(id));
        row.insert("action".into(), string(&action));
        row.insert("target".into(), target.map(|s| string(&s)).unwrap_or(Json::Null));
        row.insert("aur".into(), Json::Bool(is_aur(pkg, family)));
        row.insert("repo".into(), repo_for(pkg, family).map(|s| string(&s)).unwrap_or(Json::Null));
        row.insert("desc".into(), string(pkg.get("desc").and_then(Json::as_str).unwrap_or("")));
        row.insert("required".into(), Json::Bool(pkg.get("required").and_then(Json::as_bool).unwrap_or(false)));
        row.insert("group".into(), string(group));
        rows.push(Json::Object(row));
    }
    Ok(rows)
}

fn manifest_path() -> PathBuf {
    if let Some(path) = env::var_os("REDDOT_PACKAGES") {
        return PathBuf::from(path);
    }
    if let Ok(exe) = env::current_exe() {
        let candidate = exe.parent().unwrap_or(Path::new(".")).join("../installer/packages.json");
        if candidate.is_file() {
            return candidate;
        }
    }
    PathBuf::from("installer/packages.json")
}

fn usage() -> String {
    "usage: reddot-distro detect [--os-release PATH] | plan --family FAMILY [--groups core,user] [--aur yay|paru|none] [--manifest PATH]".into()
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut mode = "";
    let mut family = "unknown".to_string();
    let mut osr = PathBuf::from("/etc/os-release");
    let mut groups = vec!["core".to_string()];
    let mut aur_choice = "yay".to_string();
    let mut manifest = manifest_path();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "detect" | "plan" => mode = if args[i] == "detect" { "detect" } else { "plan" },
            "--family" => {
                i += 1;
                family = args.get(i).cloned().unwrap_or_default();
            }
            "--os-release" => {
                i += 1;
                osr = PathBuf::from(args.get(i).cloned().unwrap_or_default());
            }
            "--groups" => {
                i += 1;
                groups = args
                    .get(i)
                    .map(|s| s.split(',').filter(|g| !g.is_empty()).map(str::to_string).collect())
                    .unwrap_or_else(|| vec!["core".into()]);
            }
            "--aur" => {
                i += 1;
                aur_choice = args.get(i).cloned().unwrap_or_else(|| "yay".into());
            }
            "--manifest" => {
                i += 1;
                manifest = PathBuf::from(args.get(i).cloned().unwrap_or_default());
            }
            _ => {}
        }
        i += 1;
    }
    if mode.is_empty() {
        eprintln!("{}", usage());
        std::process::exit(2);
    }
    let data = os_release(&osr);
    let detected = family_from_os_release(&data);
    if mode == "detect" {
        let mut out = BTreeMap::new();
        out.insert("family".into(), string(&detected));
        out.insert(
            "pretty".into(),
            string(data.get("PRETTY_NAME").or_else(|| data.get("NAME")).map(String::as_str).unwrap_or("unknown")),
        );
        println!("{}", json_string(&Json::Object(out)));
        return;
    }
    if !FAMILIES.contains(&family.as_str()) {
        eprintln!("unknown family {family:?}, expected one of {FAMILIES:?}");
        std::process::exit(2);
    }
    let text = match fs::read_to_string(&manifest) {
        Ok(text) => text,
        Err(err) => {
            eprintln!("read {}: {err}", manifest.display());
            std::process::exit(1);
        }
    };
    let manifest = match Parser::parse(&text) {
        Ok(value) => value,
        Err(err) => {
            eprintln!("parse {}: {err}", manifest.display());
            std::process::exit(1);
        }
    };
    match plan(&manifest, &family, &groups, &aur_choice) {
        Ok(rows) => println!("{}", json_string(&Json::Array(rows))),
        Err(err) => {
            eprintln!("{err}");
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn os_release_quotes() {
        let path = env::temp_dir().join(format!("osr-{}-{}", std::process::id(), 1));
        fs::write(&path, "NAME='Gentoo'\nID='gentoo'\n").unwrap();
        let data = os_release(&path);
        assert_eq!(data.get("ID").map(String::as_str), Some("gentoo"));
        assert_eq!(family_from_os_release(&data), "gentoo");
        let _ = fs::remove_file(path);
    }

    #[test]
    fn family_tokens() {
        let data = [("ID", "Snigdha")].into_iter().map(|(k, v)| (k.into(), v.into())).collect();
        assert_eq!(family_from_os_release(&data), "arch");
    }

    #[test]
    fn native_and_aur() {
        let pkg = Parser::parse(r#"{"names":{"arch":"dotool","debian":null},"aur":true,"fallback":"dotool"}"#).unwrap();
        assert_eq!(native_name(&pkg, "arch").as_deref(), Some("dotool"));
        assert!(is_aur(&pkg, "arch"));
        assert!(!is_aur(&pkg, "debian"));
        assert_eq!(resolve(&pkg, "debian", "yay"), ("fallback".into(), Some("dotool".into())));
        assert_eq!(resolve(&pkg, "arch", "none"), ("fallback".into(), Some("dotool".into())));
    }
}
