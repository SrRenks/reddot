//! Rust replacement for configs/hypr/scripts/reddot-update.py.
//!
//! The update engine keeps a pristine clone, copies deployed code, and merges
//! protected files against their recorded base sha. It prints exactly one JSON
//! object so the QML updater and the `reddot update` CLI can use it unchanged.
//!
//! No crates: git supplies clone/fetch/show/merge-file, and the small JSON reader
//! and writer below covers the manifest and package files.

use std::collections::{BTreeMap, HashSet};
use std::env;
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Output};
use std::time::{SystemTime, UNIX_EPOCH};

const DEFAULT_REMOTE: &str = "https://github.com/SrRenks/reddot.git";
const DEFAULT_BRANCH: &str = "e14g7";

const PROTECTED: [&str; 11] = [
    "hypr/modules/decoration.lua",
    "hypr/modules/binds.lua",
    "hypr/modules/monitors.lua",
    "hypr/modules/input.lua",
    "hypr/modules/env.lua",
    "hypr/modules/autostart.lua",
    "hypr/modules/animations.lua",
    "hypr/modules/stash-apps.lua",
    "hypr/modules/spaces.lua",
    "hypr/hypridle.conf",
    "fish/config.fish",
];

const DEPLOY_SET: [(&str, &str); 7] = [
    ("hypr", "hypr"),
    ("quickshell", "quickshell"),
    ("ghostty", "ghostty"),
    ("fish", "fish"),
    ("fastfetch", "fastfetch"),
    ("kde/kdeglobals", "kdeglobals"),
    (
        "systemd/user/hyprland-session.target",
        "systemd/user/hyprland-session.target",
    ),
];

const COPY_IGNORE: [&str; 4] = ["test_*.py", "__pycache__", "*.pyc", "hypridle.conf"];

// ── JSON ─────────────────────────────────────────────────────────────────────

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
            Json::Array(v) => Some(v),
            _ => None,
        }
    }

    fn get(&self, key: &str) -> Option<&Json> {
        match self {
            Json::Object(map) => map.get(key),
            _ => None,
        }
    }
}

struct JsonParser<'a> {
    bytes: &'a [u8],
    at: usize,
}

impl<'a> JsonParser<'a> {
    fn new(text: &'a str) -> Self {
        Self {
            bytes: text.as_bytes(),
            at: 0,
        }
    }

    fn parse(mut self) -> Result<Json, String> {
        let value = self.value()?;
        self.ws();
        if self.at != self.bytes.len() {
            return Err("trailing JSON data".into());
        }
        Ok(value)
    }

    fn ws(&mut self) {
        while self.at < self.bytes.len() && self.bytes[self.at].is_ascii_whitespace() {
            self.at += 1;
        }
    }

    fn value(&mut self) -> Result<Json, String> {
        self.ws();
        let c = *self.bytes.get(self.at).ok_or("unexpected end of JSON")?;
        match c {
            b'n' => {
                self.literal(b"null")?;
                Ok(Json::Null)
            }
            b't' => {
                self.literal(b"true")?;
                Ok(Json::Bool(true))
            }
            b'f' => {
                self.literal(b"false")?;
                Ok(Json::Bool(false))
            }
            b'"' => Ok(Json::String(self.string()?)),
            b'[' => self.array(),
            b'{' => self.object(),
            b'-' | b'0'..=b'9' => self.number(),
            _ => Err(format!("unexpected JSON byte {c}")),
        }
    }

    fn literal(&mut self, want: &[u8]) -> Result<(), String> {
        if self.bytes.get(self.at..self.at + want.len()) == Some(want) {
            self.at += want.len();
            Ok(())
        } else {
            Err("bad JSON literal".into())
        }
    }

    fn string(&mut self) -> Result<String, String> {
        if self.bytes.get(self.at) != Some(&b'"') {
            return Err("expected string".into());
        }
        self.at += 1;
        let mut out = String::new();
        loop {
            let c = *self.bytes.get(self.at).ok_or("unterminated string")?;
            self.at += 1;
            match c {
                b'"' => return Ok(out),
                b'\\' => {
                    let esc = *self.bytes.get(self.at).ok_or("unterminated escape")?;
                    self.at += 1;
                    match esc {
                        b'"' => out.push('"'),
                        b'\\' => out.push('\\'),
                        b'/' => out.push('/'),
                        b'b' => out.push('\u{0008}'),
                        b'f' => out.push('\u{000c}'),
                        b'n' => out.push('\n'),
                        b'r' => out.push('\r'),
                        b't' => out.push('\t'),
                        b'u' => {
                            let hi = self.hex4()?;
                            let ch = if (0xD800..=0xDBFF).contains(&hi) {
                                if self.bytes.get(self.at..self.at + 2) != Some(b"\\u") {
                                    return Err("lone high surrogate".into());
                                }
                                self.at += 2;
                                let lo = self.hex4()?;
                                0x10000 + ((hi - 0xD800) << 10) + (lo - 0xDC00)
                            } else {
                                hi
                            };
                            out.push(char::from_u32(ch).ok_or("bad unicode escape")?);
                        }
                        _ => return Err("bad escape".into()),
                    }
                }
                c if c < 0x20 => return Err("control character in string".into()),
                c => out.push(c as char),
            }
        }
    }

    fn hex4(&mut self) -> Result<u32, String> {
        let mut value = 0u32;
        for _ in 0..4 {
            let c = *self.bytes.get(self.at).ok_or("short unicode escape")?;
            self.at += 1;
            value = (value << 4)
                + match c {
                    b'0'..=b'9' => (c - b'0') as u32,
                    b'a'..=b'f' => (c - b'a' + 10) as u32,
                    b'A'..=b'F' => (c - b'A' + 10) as u32,
                    _ => return Err("bad unicode escape".into()),
                };
        }
        Ok(value)
    }

    fn array(&mut self) -> Result<Json, String> {
        self.at += 1;
        let mut out = Vec::new();
        self.ws();
        if self.bytes.get(self.at) == Some(&b']') {
            self.at += 1;
            return Ok(Json::Array(out));
        }
        loop {
            out.push(self.value()?);
            self.ws();
            match self.bytes.get(self.at) {
                Some(b',') => self.at += 1,
                Some(b']') => {
                    self.at += 1;
                    return Ok(Json::Array(out));
                }
                _ => return Err("bad JSON array".into()),
            }
        }
    }

    fn object(&mut self) -> Result<Json, String> {
        self.at += 1;
        let mut out = BTreeMap::new();
        self.ws();
        if self.bytes.get(self.at) == Some(&b'}') {
            self.at += 1;
            return Ok(Json::Object(out));
        }
        loop {
            let key = self.string()?;
            self.ws();
            if self.bytes.get(self.at) != Some(&b':') {
                return Err("expected colon".into());
            }
            self.at += 1;
            out.insert(key, self.value()?);
            self.ws();
            match self.bytes.get(self.at) {
                Some(b',') => {
                    self.at += 1;
                    self.ws();
                }
                Some(b'}') => {
                    self.at += 1;
                    return Ok(Json::Object(out));
                }
                _ => return Err("bad JSON object".into()),
            }
        }
    }

    fn number(&mut self) -> Result<Json, String> {
        let start = self.at;
        while self.at < self.bytes.len()
            && matches!(
                self.bytes[self.at],
                b'-' | b'+' | b'.' | b'e' | b'E' | b'0'..=b'9'
            )
        {
            self.at += 1;
        }
        let text = std::str::from_utf8(&self.bytes[start..self.at]).map_err(|_| "bad number")?;
        let value = text.parse::<f64>().map_err(|_| "bad number")?;
        Ok(Json::Number(value))
    }
}

fn json_escape(text: &str) -> String {
    let mut out = String::with_capacity(text.len() + 2);
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

fn json_write(value: &Json, pretty: bool, depth: usize, out: &mut String) {
    match value {
        Json::Null => out.push_str("null"),
        Json::Bool(v) => out.push_str(if *v { "true" } else { "false" }),
        Json::Number(v) => {
            if v.fract() == 0.0 {
                out.push_str(&format!("{:.0}", v));
            } else {
                out.push_str(&v.to_string());
            }
        }
        Json::String(s) => {
            out.push('"');
            out.push_str(&json_escape(s));
            out.push('"');
        }
        Json::Array(items) => {
            out.push('[');
            for (i, item) in items.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                json_write(item, pretty, depth + 1, out);
            }
            out.push(']');
        }
        Json::Object(map) => {
            out.push('{');
            for (i, (key, item)) in map.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                if pretty {
                    out.push('\n');
                    out.push_str(&"  ".repeat(depth + 1));
                }
                out.push('"');
                out.push_str(&json_escape(key));
                out.push_str("\":");
                if pretty {
                    out.push(' ');
                }
                json_write(item, pretty, depth + 1, out);
            }
            if pretty && !map.is_empty() {
                out.push('\n');
                out.push_str(&"  ".repeat(depth));
            }
            out.push('}');
        }
    }
}

fn json_to_string(value: &Json, pretty: bool) -> String {
    let mut out = String::new();
    json_write(value, pretty, 0, &mut out);
    out
}

fn parse_json(text: &str) -> Result<Json, String> {
    JsonParser::new(text).parse()
}

// ── Paths and files ──────────────────────────────────────────────────────────

fn home() -> PathBuf {
    env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn data_dir() -> PathBuf {
    let base = env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".local/share"));
    base.join("reddot-update")
}

fn manifest_path() -> PathBuf {
    let base = env::var_os("XDG_STATE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".local/state"));
    base.join("reddot").join("update.json")
}

fn atomic_write_bytes(path: &Path, data: &[u8]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("create {}: {e}", parent.display()))?;
    }
    let mode = if data.starts_with(b"#!") {
        0o755
    } else if path.exists() {
        fs::metadata(path)
            .map(|m| m.permissions().mode() & 0o777)
            .unwrap_or(0o644)
    } else {
        0o644
    };
    let mut n = 0u32;
    let tmp = loop {
        let candidate = path.with_file_name(format!(
            ".tmp-{}-{}-{}{}",
            std::process::id(),
            n,
            path.file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("update"),
            if n == 0 { "" } else { ".tmp" }
        ));
        if !candidate.exists() {
            break candidate;
        }
        n += 1;
    };
    {
        let mut file = fs::File::create(&tmp).map_err(|e| format!("create temp: {e}"))?;
        file.write_all(data)
            .map_err(|e| format!("write temp: {e}"))?;
    }
    fs::set_permissions(&tmp, fs::Permissions::from_mode(mode))
        .map_err(|e| format!("chmod temp: {e}"))?;
    fs::rename(&tmp, path).map_err(|e| {
        let _ = fs::remove_file(&tmp);
        format!("rename temp: {e}")
    })
}

// ── Process helpers ─────────────────────────────────────────────────────────

fn output_text(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).trim().to_string()
}

fn git_output(repo: &Path, args: &[&str]) -> Result<Output, String> {
    Command::new("git")
        .arg("-C")
        .arg(repo)
        .args(args)
        .output()
        .map_err(|e| format!("git: {e}"))
}

fn git(repo: &Path, args: &[&str]) -> Result<String, String> {
    let out = git_output(repo, args)?;
    if !out.status.success() {
        return Err(output_text(&out));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

fn in_git_worktree(path: &Path) -> bool {
    Command::new("git")
        .arg("-C")
        .arg(path)
        .args(["rev-parse", "--is-inside-work-tree"])
        .output()
        .map(|out| out.status.success() && String::from_utf8_lossy(&out.stdout).trim() == "true")
        .unwrap_or(false)
}

fn is_devmode(config_root: &Path) -> bool {
    for name in ["hypr", "quickshell"] {
        let sub = config_root.join(name);
        if fs::symlink_metadata(&sub)
            .map(|m| m.file_type().is_symlink())
            .unwrap_or(false)
        {
            if let Ok(target) = sub.canonicalize() {
                if in_git_worktree(&target) {
                    return true;
                }
            }
        }
    }
    false
}

// ── Manifest ────────────────────────────────────────────────────────────────

#[derive(Clone, Debug, Default)]
struct Manifest {
    synced_sha: Option<String>,
    modules: BTreeMap<String, String>,
}

fn load_manifest() -> Result<Manifest, String> {
    let path = manifest_path();
    if !path.exists() {
        return Ok(Manifest::default());
    }
    let text = fs::read_to_string(&path).map_err(|e| format!("read manifest: {e}"))?;
    let value = parse_json(&text).map_err(|e| format!("manifest JSON: {e}"))?;
    let obj = match value {
        Json::Object(obj) => obj,
        _ => return Err("manifest is not an object".into()),
    };
    let synced_sha = match obj.get("syncedSha") {
        Some(Json::String(s)) => Some(s.clone()),
        Some(Json::Null) | None => None,
        _ => return Err("manifest syncedSha is not a string".into()),
    };
    let mut modules = BTreeMap::new();
    if let Some(Json::Object(map)) = obj.get("modules") {
        for (key, val) in map {
            if let Json::String(sha) = val {
                modules.insert(key.clone(), sha.clone());
            }
        }
    }
    Ok(Manifest {
        synced_sha,
        modules,
    })
}

fn save_manifest(manifest: &Manifest) -> Result<(), String> {
    let mut modules = BTreeMap::new();
    for (key, value) in &manifest.modules {
        modules.insert(key.clone(), Json::String(value.clone()));
    }
    let mut root = BTreeMap::new();
    root.insert(
        "syncedSha".into(),
        manifest
            .synced_sha
            .clone()
            .map(Json::String)
            .unwrap_or(Json::Null),
    );
    root.insert("modules".into(), Json::Object(modules));
    atomic_write_bytes(
        &manifest_path(),
        json_to_string(&Json::Object(root), true).as_bytes(),
    )
}

// ── Config helpers ──────────────────────────────────────────────────────────

fn wildcard(part: &str, pattern: &str) -> bool {
    let p = pattern.as_bytes();
    let s = part.as_bytes();
    let (mut pi, mut si) = (0usize, 0usize);
    let (mut star, mut mark) = (None, 0usize);
    while si < s.len() {
        if pi < p.len() && (p[pi] == b'?' || p[pi] == s[si]) {
            pi += 1;
            si += 1;
        } else if pi < p.len() && p[pi] == b'*' {
            star = Some(pi);
            pi += 1;
            mark = si;
        } else if let Some(st) = star {
            pi = st + 1;
            mark += 1;
            si = mark;
        } else {
            return false;
        }
    }
    while pi < p.len() && p[pi] == b'*' {
        pi += 1;
    }
    pi == p.len()
}

fn deploy_dest(rel: &str) -> Option<String> {
    if rel
        .split('/')
        .any(|part| COPY_IGNORE.iter().any(|pat| wildcard(part, pat)))
    {
        return None;
    }
    for (src, dest) in DEPLOY_SET {
        if rel == src || rel.starts_with(&format!("{src}/")) {
            return Some(format!("{dest}{}", &rel[src.len()..]));
        }
    }
    None
}

fn module_name(rel: &str) -> String {
    Path::new(rel)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or(rel)
        .trim_end_matches(".lua")
        .trim_end_matches(".conf")
        .trim_end_matches(".fish")
        .to_string()
}

// ── Update engine ───────────────────────────────────────────────────────────

fn ensure_clone(remote: &str, do_fetch: bool) -> Result<PathBuf, String> {
    let clone = data_dir();
    if clone.join(".git").exists() {
        if do_fetch {
            let current = git(&clone, &["remote", "get-url", "origin"]).unwrap_or_default();
            if !current.trim().is_empty() && current.trim() != remote {
                git(&clone, &["remote", "set-url", "origin", remote])?;
            }
            git(&clone, &["fetch", "origin", DEFAULT_BRANCH])?;
        }
        return Ok(clone);
    }
    if let Some(parent) = clone.parent() {
        fs::create_dir_all(parent).map_err(|e| format!("create data dir: {e}"))?;
    }
    let out = Command::new("git")
        .args(["clone", "--quiet", remote])
        .arg(&clone)
        .output()
        .map_err(|e| format!("git clone: {e}"))?;
    if !out.status.success() {
        return Err(output_text(&out));
    }
    Ok(clone)
}

fn origin_head(clone: &Path) -> Result<String, String> {
    git(clone, &["rev-parse", &format!("origin/{DEFAULT_BRANCH}")]).map(|s| s.trim().into())
}

fn commit_date(clone: &Path, sha: &str) -> Result<String, String> {
    git(clone, &["show", "-s", "--format=%cs", sha]).map(|s| s.trim().into())
}

fn short_sha(clone: &Path, sha: &str) -> Result<String, String> {
    git(clone, &["rev-parse", "--short", sha]).map(|s| s.trim().into())
}

fn behind_count(clone: &Path, base: Option<&str>, head: &str) -> usize {
    let Some(base) = base else { return 0 };
    git(clone, &["rev-list", "--count", &format!("{base}..{head}")])
        .ok()
        .and_then(|s| s.trim().parse::<usize>().ok())
        .unwrap_or(0)
}

fn extract_changelog(clone: &Path, base: Option<&str>, head: &str) -> Vec<String> {
    let Some(base) = base else { return Vec::new() };
    let body = git(
        clone,
        &["log", "--format=%B%x00", &format!("{base}..{head}")],
    )
    .unwrap_or_default();
    let mut out = Vec::new();
    for commit in body.split('\0') {
        for line in commit.lines() {
            let trimmed = line.trim();
            if let Some(rest) = trimmed
                .strip_prefix("changelog:")
                .or_else(|| trimmed.strip_prefix("Changelog:"))
            {
                let text = rest.trim();
                if !text.is_empty() {
                    out.push(text.to_string());
                }
            }
        }
    }
    out
}

fn tracked_config_files(clone: &Path, reference: &str) -> Result<Vec<String>, String> {
    let out = git(
        clone,
        &["ls-tree", "-r", "--name-only", reference, "configs/"],
    )?;
    Ok(out
        .lines()
        .map(str::trim)
        .filter_map(|line| line.strip_prefix("configs/"))
        .map(str::to_string)
        .collect())
}

fn show_at(clone: &Path, sha: &str, rel: &str) -> Option<Vec<u8>> {
    let spec = format!("{sha}:configs/{rel}");
    let out = git_output(clone, &["show", &spec]).ok()?;
    if out.status.success() {
        Some(out.stdout)
    } else {
        None
    }
}

fn merge_file(theirs: &[u8], base: &[u8], new: &[u8]) -> Result<(Vec<u8>, bool), String> {
    let dir = env::temp_dir().join(format!(
        "reddot-merge-{}-{}",
        std::process::id(),
        rand_suffix()
    ));
    fs::create_dir_all(&dir).map_err(|e| format!("merge temp: {e}"))?;
    let tp = dir.join("theirs");
    let bp = dir.join("base");
    let np = dir.join("new");
    let result = (|| {
        fs::write(&tp, theirs).map_err(|e| format!("merge theirs: {e}"))?;
        fs::write(&bp, base).map_err(|e| format!("merge base: {e}"))?;
        fs::write(&np, new).map_err(|e| format!("merge new: {e}"))?;
        Command::new("git")
            .args(["merge-file", "-p"])
            .arg(&tp)
            .arg(&bp)
            .arg(&np)
            .output()
            .map_err(|e| format!("git merge-file: {e}"))
    })();
    let _ = fs::remove_dir_all(&dir);
    let output = result?;
    Ok((output.stdout, output.status.success()))
}

fn rand_suffix() -> u128 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0)
}

fn backup_protected(config_root: &Path) -> Result<Option<PathBuf>, String> {
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let dest_root = data_dir()
        .parent()
        .unwrap_or(Path::new("."))
        .join("reddot-update-backup")
        .join(stamp.to_string());
    let mut made = false;
    for rel in PROTECTED {
        let live = config_root.join(rel);
        if !live.exists() {
            continue;
        }
        let dest = dest_root.join(rel);
        if let Some(parent) = dest.parent() {
            fs::create_dir_all(parent).map_err(|e| format!("backup dir: {e}"))?;
        }
        fs::copy(&live, &dest).map_err(|e| format!("backup {}: {e}", live.display()))?;
        made = true;
    }
    Ok(if made { Some(dest_root) } else { None })
}

fn reconcile_protected(
    clone: &Path,
    config_root: &Path,
    manifest: &Manifest,
    head: &str,
    apply: bool,
    take: &HashSet<String>,
) -> Result<(Vec<Json>, Vec<String>, BTreeMap<String, String>), String> {
    let mut rows = Vec::new();
    let mut conflicts = Vec::new();
    let mut updates = BTreeMap::new();
    for rel in PROTECTED {
        let Some(base_sha) = manifest.modules.get(rel) else {
            continue;
        };
        let Some(new) = show_at(clone, head, rel) else {
            continue;
        };
        let Some(base) = show_at(clone, base_sha, rel) else {
            continue;
        };
        let row = |state: &str| {
            let mut map = BTreeMap::new();
            map.insert("name".into(), Json::String(module_name(rel)));
            map.insert("path".into(), Json::String(rel.into()));
            map.insert("state".into(), Json::String(state.into()));
            Json::Object(map)
        };
        if new == base {
            rows.push(row("clean"));
            continue;
        }
        let live_path = config_root.join(rel);
        let theirs = fs::read(&live_path).unwrap_or_else(|_| base.clone());
        if theirs == base {
            if apply {
                atomic_write_bytes(&live_path, &new)?;
                updates.insert(rel.to_string(), head.to_string());
            }
            rows.push(row("update"));
            continue;
        }
        let (merged, clean) = merge_file(&theirs, &base, &new)?;
        if clean {
            if apply {
                atomic_write_bytes(&live_path, &merged)?;
                updates.insert(rel.to_string(), head.to_string());
            }
            rows.push(row("merged"));
        } else if take.contains(rel) {
            if apply {
                atomic_write_bytes(&live_path, &new)?;
                updates.insert(rel.to_string(), head.to_string());
            }
            rows.push(row("update"));
        } else {
            rows.push(row("conflict"));
            conflicts.push(rel.to_string());
        }
    }
    Ok((rows, conflicts, updates))
}

fn sync_code(clone: &Path, config_root: &Path, head: &str, apply: bool) -> Result<bool, String> {
    let protected: HashSet<&str> = PROTECTED.iter().copied().collect();
    let mut changed = false;
    for rel in tracked_config_files(clone, head)? {
        let Some(dest) = deploy_dest(&rel) else {
            continue;
        };
        if protected.contains(rel.as_str()) {
            continue;
        }
        let Some(new) = show_at(clone, head, &rel) else {
            continue;
        };
        let live = config_root.join(dest);
        let current = fs::read(&live).ok();
        if current.as_deref() == Some(new.as_slice()) {
            continue;
        }
        changed = true;
        if apply {
            atomic_write_bytes(&live, &new)?;
        }
    }
    Ok(changed)
}

fn migrate_hypridle(config_root: &Path) -> Result<(), String> {
    let path = config_root.join("hypr/hypridle.conf");
    if !path.is_file() {
        return Ok(());
    }
    let text = fs::read_to_string(&path).map_err(|e| format!("read hypridle: {e}"))?;
    let mut out = String::new();
    let mut changed = false;
    for line in text.lines() {
        let trimmed = line.trim_end_matches([' ', '\t']);
        let migrated = trimmed
            .strip_suffix("hyprctl dispatch dpms on")
            .map(|prefix| format!("{prefix}hyprctl dispatch \"hl.dsp.dpms({{ action = 'on' }})\""))
            .or_else(|| {
                trimmed
                    .strip_suffix("hyprctl dispatch dpms off")
                    .map(|prefix| {
                        format!("{prefix}hyprctl dispatch \"hl.dsp.dpms({{ action = 'off' }})\"")
                    })
            });
        if let Some(migrated) = migrated {
            out.push_str(&migrated);
            changed = true;
        } else {
            out.push_str(line);
        }
        out.push('\n');
    }
    if !text.ends_with('\n') && out.ends_with('\n') {
        out.pop();
    }
    if changed {
        atomic_write_bytes(&path, out.as_bytes())?;
    }
    Ok(())
}

fn baseline_modules(manifest: &mut Manifest, head: &str) {
    for rel in PROTECTED {
        manifest.modules.insert(rel.into(), head.into());
    }
}

fn baseline(config_root: &Path, sha: Option<&str>) -> Result<Json, String> {
    let Some(sha) = sha else {
        return Ok(error_result("error", "baseline needs --sha"));
    };
    if is_devmode(config_root) {
        let mut map = BTreeMap::new();
        map.insert("status".into(), Json::String("devmode".into()));
        map.insert("syncedSha".into(), Json::String(String::new()));
        return Ok(Json::Object(map));
    }
    if manifest_path().exists() {
        let mut map = BTreeMap::new();
        map.insert("status".into(), Json::String("kept".into()));
        map.insert("syncedSha".into(), Json::String(String::new()));
        return Ok(Json::Object(map));
    }
    let mut manifest = Manifest {
        synced_sha: Some(sha.into()),
        modules: BTreeMap::new(),
    };
    baseline_modules(&mut manifest, sha);
    save_manifest(&manifest)?;
    let mut map = BTreeMap::new();
    map.insert("status".into(), Json::String("baselined".into()));
    map.insert("syncedSha".into(), Json::String(sha.into()));
    Ok(Json::Object(map))
}

// ── Dependency checks ───────────────────────────────────────────────────────

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

fn detect_family() -> String {
    let data = os_release(Path::new("/etc/os-release"));
    let mut ids = vec![data.get("ID").cloned().unwrap_or_default().to_lowercase()];
    ids.extend(
        data.get("ID_LIKE")
            .cloned()
            .unwrap_or_default()
            .to_lowercase()
            .split_whitespace()
            .map(str::to_string),
    );
    let families: [(&str, &[&str]); 5] = [
        (
            "arch",
            &[
                "arch",
                "cachyos",
                "endeavouros",
                "manjaro",
                "garuda",
                "artix",
                "arcolinux",
                "archcraft",
                "rebornos",
                "athena",
                "blackarch",
                "archbang",
                "crystal",
                "snigdha",
                "parabola",
                "obarun",
                "arch32",
                "hyperbola",
                "steamos",
                "omarchy",
                "xerolinux",
                "archman",
                "biglinux",
                "ctlos",
                "tromjaro",
                "bluestar",
                "arkane",
                "blendos",
                "acreetionos",
                "mabox",
            ],
        ),
        (
            "debian",
            &[
                "debian",
                "ubuntu",
                "linuxmint",
                "pop",
                "elementary",
                "zorin",
                "raspbian",
            ],
        ),
        (
            "fedora",
            &["fedora", "nobara", "rhel", "centos", "rocky", "almalinux"],
        ),
        (
            "suse",
            &["suse", "opensuse", "sles", "sled", "tumbleweed", "leap"],
        ),
        (
            "gentoo",
            &["gentoo", "funtoo", "calculate", "pentoo", "redcore"],
        ),
    ];
    for token in ids {
        for (family, names) in families {
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

fn manifest_at(clone: &Path, sha: &str) -> Option<Json> {
    let out = git_output(clone, &["show", &format!("{sha}:installer/packages.json")]).ok()?;
    if !out.status.success() {
        return None;
    }
    parse_json(&String::from_utf8_lossy(&out.stdout)).ok()
}

fn pkg_installed(name: &str, family: &str) -> bool {
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

fn detect_missing_deps(clone: &Path, head: &str) -> Vec<Json> {
    let family = detect_family();
    let Some(manifest) = manifest_at(clone, head) else {
        return Vec::new();
    };
    if family == "unknown" {
        return Vec::new();
    }
    let mut rows = Vec::new();
    let Some(packages) = manifest.get("packages").and_then(Json::as_array) else {
        return rows;
    };
    for pkg in packages {
        if pkg.get("group").and_then(Json::as_str) != Some("core") {
            continue;
        }
        let Some(name) = native_name(pkg, &family) else {
            continue;
        };
        if pkg_installed(&name, &family) {
            continue;
        }
        let mut row = BTreeMap::new();
        row.insert(
            "id".into(),
            Json::String(pkg.get("id").and_then(Json::as_str).unwrap_or("").into()),
        );
        row.insert("name".into(), Json::String(name));
        row.insert(
            "desc".into(),
            Json::String(pkg.get("desc").and_then(Json::as_str).unwrap_or("").into()),
        );
        row.insert(
            "group".into(),
            Json::String(pkg.get("group").and_then(Json::as_str).unwrap_or("").into()),
        );
        rows.push(Json::Object(row));
    }
    rows
}

fn native_install_argv(family: &str, names: &[String]) -> Vec<String> {
    let mut argv: Vec<String> = match family {
        "arch" => vec![
            "pacman".into(),
            "-S".into(),
            "--needed".into(),
            "--noconfirm".into(),
        ],
        "debian" => vec![
            "env".into(),
            "DEBIAN_FRONTEND=noninteractive".into(),
            "apt-get".into(),
            "install".into(),
            "-y".into(),
        ],
        "fedora" => vec!["dnf".into(), "install".into(), "-y".into()],
        "gentoo" => vec!["emerge".into(), "--noreplace".into()],
        _ => vec![
            "zypper".into(),
            "--non-interactive".into(),
            "install".into(),
        ],
    };
    argv.extend(names.iter().cloned());
    argv
}

fn manual_hint(pkg: &Json, family: &str, fallbacks: &Json) -> String {
    let name = native_name(pkg, family);
    if family == "arch" && pkg.get("aur").and_then(Json::as_bool) == Some(true) {
        if let Some(name) = name {
            let helper = ["yay", "paru"]
                .iter()
                .find(|bin| which(bin).is_some())
                .copied()
                .unwrap_or("yay");
            return format!("AUR package, install it yourself: {helper} -S {name}");
        }
    }
    if family == "gentoo" {
        if let Some(name) = name {
            return format!("compiles from source, run it in a terminal: emerge -av {name}");
        }
    }
    let key = pkg.get("fallback").and_then(Json::as_str).unwrap_or("");
    let hint = fallbacks
        .get(key)
        .and_then(Json::as_str)
        .unwrap_or("install it manually");
    format!("no native package on this system, {hint}")
}

fn which(bin: &str) -> Option<PathBuf> {
    env::var_os("PATH").and_then(|paths| {
        env::split_paths(&paths)
            .map(|dir| dir.join(bin))
            .find(|path| path.is_file())
    })
}

fn native_install_reason(result: Option<&Output>, os_error: &str) -> String {
    if !os_error.is_empty() {
        return os_error.into();
    }
    if let Some(result) = result {
        if [126, 127].contains(&result.status.code().unwrap_or(0)) {
            return "the password prompt was cancelled".into();
        }
        let err = String::from_utf8_lossy(&result.stderr);
        if let Some(line) = err.lines().last() {
            if !line.trim().is_empty() {
                return line.trim().into();
            }
        }
    }
    "install failed".into()
}

fn install_missing_deps(clone: &Path, head: &str, ids: &HashSet<String>) -> Vec<Json> {
    let family = detect_family();
    let Some(manifest) = manifest_at(clone, head) else {
        return ids
            .iter()
            .map(|id| {
                let mut row = BTreeMap::new();
                row.insert("id".into(), Json::String(id.clone()));
                row.insert(
                    "error".into(),
                    Json::String("couldn't read the package manifest".into()),
                );
                Json::Object(row)
            })
            .collect();
    };
    if family == "unknown" {
        return ids
            .iter()
            .map(|id| {
                let mut row = BTreeMap::new();
                row.insert("id".into(), Json::String(id.clone()));
                row.insert(
                    "error".into(),
                    Json::String("couldn't read the package manifest".into()),
                );
                Json::Object(row)
            })
            .collect();
    }
    let empty = Json::Object(BTreeMap::new());
    let fallbacks = manifest.get("fallbacks").unwrap_or(&empty);
    let packages = manifest
        .get("packages")
        .and_then(Json::as_array)
        .unwrap_or(&[]);
    let by_id: BTreeMap<&str, &Json> = packages
        .iter()
        .filter_map(|pkg| pkg.get("id").and_then(Json::as_str).map(|id| (id, pkg)))
        .collect();
    let mut failures = Vec::new();
    let mut repo: Vec<(String, String)> = Vec::new();
    for id in ids {
        let Some(pkg) = by_id.get(id.as_str()) else {
            let mut row = BTreeMap::new();
            row.insert("id".into(), Json::String(id.clone()));
            row.insert("error".into(), Json::String("unknown package".into()));
            failures.push(Json::Object(row));
            continue;
        };
        let name = native_name(pkg, &family);
        let aur = pkg.get("aur").and_then(Json::as_bool) == Some(true);
        if name.is_none() || (family == "arch" && aur) || family == "gentoo" {
            let mut row = BTreeMap::new();
            row.insert("id".into(), Json::String(id.clone()));
            row.insert(
                "error".into(),
                Json::String(manual_hint(pkg, &family, fallbacks)),
            );
            failures.push(Json::Object(row));
            continue;
        }
        repo.push((id.clone(), name.unwrap()));
    }
    if !repo.is_empty() {
        let names: Vec<String> = repo.iter().map(|(_, name)| name.clone()).collect();
        let argv = native_install_argv(&family, &names);
        let result = Command::new("pkexec").args(&argv).output();
        let (output, os_error) = match result {
            Ok(output) => (Some(output), String::new()),
            Err(err) => (None, err.to_string()),
        };
        for (id, name) in repo {
            if !pkg_installed(&name, &family) {
                let mut row = BTreeMap::new();
                row.insert("id".into(), Json::String(id));
                row.insert(
                    "error".into(),
                    Json::String(native_install_reason(output.as_ref(), &os_error)),
                );
                failures.push(Json::Object(row));
            }
        }
    }
    failures
}

// ── Result assembly ────────────────────────────────────────────────────────

#[allow(clippy::too_many_arguments)]
fn result_map(
    status: &str,
    behind: usize,
    from_date: &str,
    to_date: &str,
    version: &str,
    changelog: Vec<Json>,
    code_changed: bool,
    modules: Vec<Json>,
    conflicts: Vec<Json>,
    missing: Vec<Json>,
    dep_failures: Vec<Json>,
    applied: bool,
    restart: bool,
    error: Option<&str>,
) -> Json {
    let mut map = BTreeMap::new();
    map.insert("status".into(), Json::String(status.into()));
    map.insert("behind".into(), Json::Number(behind as f64));
    map.insert("fromDate".into(), Json::String(from_date.into()));
    map.insert("toDate".into(), Json::String(to_date.into()));
    map.insert("version".into(), Json::String(version.into()));
    map.insert("changelog".into(), Json::Array(changelog));
    map.insert("codeChanged".into(), Json::Bool(code_changed));
    map.insert("modules".into(), Json::Array(modules));
    map.insert("conflicts".into(), Json::Array(conflicts));
    map.insert("missingDeps".into(), Json::Array(missing));
    map.insert("depFailures".into(), Json::Array(dep_failures));
    map.insert("applied".into(), Json::Bool(applied));
    map.insert("restartNeeded".into(), Json::Bool(restart));
    map.insert(
        "error".into(),
        error.map(|s| Json::String(s.into())).unwrap_or(Json::Null),
    );
    Json::Object(map)
}

fn error_result(status: &str, message: &str) -> Json {
    result_map(
        status,
        0,
        "",
        "",
        "",
        Vec::new(),
        false,
        Vec::new(),
        Vec::new(),
        Vec::new(),
        Vec::new(),
        false,
        false,
        Some(message),
    )
}

fn devmode_result() -> Json {
    result_map(
        "devmode",
        0,
        "",
        "",
        "",
        Vec::new(),
        false,
        Vec::new(),
        Vec::new(),
        Vec::new(),
        Vec::new(),
        false,
        false,
        None,
    )
}

fn classify_git_failure(stderr: &str) -> String {
    let offline = [
        "could not resolve",
        "couldn't resolve",
        "network",
        "timed out",
        "connection",
        "unable to access",
        "failed to connect",
    ]
    .iter()
    .any(|needle| stderr.to_lowercase().contains(needle));
    if offline {
        "offline".into()
    } else if !data_dir().join(".git").exists() {
        "noclone".into()
    } else {
        "error".into()
    }
}

fn run(
    mode: &str,
    remote: &str,
    config_root: &Path,
    take: &HashSet<String>,
    install_ids: &HashSet<String>,
) -> Result<Json, String> {
    if is_devmode(config_root) {
        return Ok(devmode_result());
    }
    let apply = mode == "apply";
    let clone = match ensure_clone(remote, true) {
        Ok(clone) => clone,
        Err(err) => {
            return Ok(error_result(
                &classify_git_failure(&err),
                if err.is_empty() { "git failed" } else { &err },
            ))
        }
    };
    let mut manifest = load_manifest()?;
    let head = origin_head(&clone)?;
    let base = manifest.synced_sha.clone();
    let first_run = base.is_none();
    let changelog = extract_changelog(&clone, base.as_deref(), &head)
        .into_iter()
        .map(Json::String)
        .collect();
    let behind = behind_count(&clone, base.as_deref(), &head);
    let from_date = if let Some(base) = base.as_deref() {
        commit_date(&clone, base)?
    } else {
        commit_date(&clone, &head)?
    };
    let to_date = commit_date(&clone, &head)?;
    let version = format!("{} {}", short_sha(&clone, &head)?, to_date);

    let dep_failures = if apply && !install_ids.is_empty() {
        install_missing_deps(&clone, &head, install_ids)
    } else {
        Vec::new()
    };
    let missing = detect_missing_deps(&clone, &head);

    if first_run {
        let code_changed = sync_code(&clone, config_root, &head, apply)?;
        let rows = PROTECTED
            .iter()
            .map(|rel| {
                let mut row = BTreeMap::new();
                row.insert("name".into(), Json::String(module_name(rel)));
                row.insert("path".into(), Json::String((*rel).into()));
                row.insert("state".into(), Json::String("clean".into()));
                Json::Object(row)
            })
            .collect();
        if apply {
            migrate_hypridle(config_root)?;
            baseline_modules(&mut manifest, &head);
            manifest.synced_sha = Some(head.clone());
            save_manifest(&manifest)?;
        }
        return Ok(result_map(
            "ok",
            behind,
            &from_date,
            &to_date,
            &version,
            changelog,
            code_changed,
            rows,
            Vec::new(),
            missing,
            dep_failures,
            apply,
            code_changed,
            None,
        ));
    }

    if apply {
        let _ = backup_protected(config_root)?;
    }
    let (rows, conflicts, updates) =
        reconcile_protected(&clone, config_root, &manifest, &head, apply, take)?;
    let code_changed = sync_code(&clone, config_root, &head, apply)?;
    if apply {
        migrate_hypridle(config_root)?;
        for (rel, sha) in updates {
            manifest.modules.insert(rel, sha);
        }
        manifest.synced_sha = Some(head.clone());
        save_manifest(&manifest)?;
    }
    let protected_changed = rows.iter().any(|row| {
        matches!(
            row.get("state").and_then(Json::as_str),
            Some("update" | "merged")
        )
    });
    let conflicts_json = conflicts.into_iter().map(Json::String).collect();
    Ok(result_map(
        "ok",
        behind,
        &from_date,
        &to_date,
        &version,
        changelog,
        code_changed,
        rows,
        conflicts_json,
        missing,
        dep_failures,
        apply,
        code_changed || protected_changed,
        None,
    ))
}

// ── Argument parsing ────────────────────────────────────────────────────────

struct Args {
    mode: String,
    remote: String,
    config_root: PathBuf,
    take: HashSet<String>,
    install_ids: HashSet<String>,
    sha: Option<String>,
}

fn take_value<'a>(argv: &'a [String], i: usize, flag: &str) -> Result<&'a str, String> {
    argv.get(i)
        .map(String::as_str)
        .ok_or_else(|| format!("{flag} expects a value"))
}

fn parse_args(argv: &[String]) -> Result<Args, String> {
    let mut args = Args {
        mode: "check".into(),
        remote: DEFAULT_REMOTE.into(),
        config_root: home().join(".config"),
        take: HashSet::new(),
        install_ids: HashSet::new(),
        sha: None,
    };
    let mut i = 0;
    while i < argv.len() {
        let arg = argv[i].as_str();
        match arg {
            "check" | "apply" | "baseline" => args.mode = arg.into(),
            "--sha" => {
                i += 1;
                args.sha = Some(take_value(argv, i, "--sha")?.into());
            }
            "--remote" => {
                i += 1;
                args.remote = take_value(argv, i, "--remote")?.into();
            }
            "--config-root" => {
                i += 1;
                let value = take_value(argv, i, "--config-root")?;
                args.config_root = if let Some(rest) = value.strip_prefix("~/") {
                    home().join(rest)
                } else {
                    PathBuf::from(value)
                };
            }
            "--take" => {
                i += 1;
                for item in take_value(argv, i, "--take")?.split(',') {
                    if !item.trim().is_empty() {
                        args.take.insert(item.trim().into());
                    }
                }
            }
            "--install-deps" => {
                i += 1;
                for item in take_value(argv, i, "--install-deps")?.split(',') {
                    if !item.trim().is_empty() {
                        args.install_ids.insert(item.trim().into());
                    }
                }
            }
            _ => {}
        }
        i += 1;
    }
    Ok(args)
}

fn main() {
    let argv: Vec<String> = env::args().skip(1).collect();
    let result = match parse_args(&argv) {
        Err(err) => error_result("error", &err),
        Ok(args) => {
            if args.mode == "baseline" {
                baseline(&args.config_root, args.sha.as_deref())
                    .unwrap_or_else(|err| error_result("error", &err))
            } else {
                run(
                    &args.mode,
                    &args.remote,
                    &args.config_root,
                    &args.take,
                    &args.install_ids,
                )
                .unwrap_or_else(|err| error_result("error", &err))
            }
        }
    };
    println!("{}", json_to_string(&result, false));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn json_round_trip_manifest() {
        let text = r#"{"syncedSha":"abc","modules":{"hypr/modules/binds.lua":"def"}}"#;
        let value = parse_json(text).unwrap();
        assert_eq!(value.get("syncedSha").and_then(Json::as_str), Some("abc"));
        assert_eq!(
            value
                .get("modules")
                .and_then(|m| m.get("hypr/modules/binds.lua"))
                .and_then(Json::as_str),
            Some("def")
        );
    }

    #[test]
    fn deploy_set_and_ignores() {
        assert_eq!(
            deploy_dest("hypr/modules/binds.lua").as_deref(),
            Some("hypr/modules/binds.lua")
        );
        assert_eq!(deploy_dest("kde/kdeglobals").as_deref(), Some("kdeglobals"));
        assert_eq!(deploy_dest("hypr/scripts/test_tool.py"), None);
        assert_eq!(deploy_dest("sddm/themes/torii/Main.qml"), None);
    }

    #[test]
    fn args_reject_missing_value() {
        let argv = vec!["check".into(), "--remote".into()];
        assert!(parse_args(&argv).is_err());
    }

    #[test]
    fn changelog_suffix() {
        assert!(wildcard("test_tool.py", "test_*.py"));
        assert!(wildcard("__pycache__", "__pycache__"));
    }
}
