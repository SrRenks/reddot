//! Rust implementation of configs/hypr/scripts/wallcolors.py.
//!
//! Generates the pill palette, fastfetch config, Hyprland colors and Ghostty
//! palette from a wallpaper, and optionally applies the same palette to GTK.
//! The external programs are the same ones the Python script uses: magick,
//! matugen, gsettings, flatpak and gdbus.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::thread::sleep;
use std::time::Duration;

const IFACE: &str = "org.gnome.desktop.interface";
const MARK: &str = "/** reddot app theme, turn it off in Settings > Appearance */\n";
const REDDOT_THEMES: [&str; 4] = ["reddot-a", "reddot-b", "reddot-base", "reddot-base-dark"];
const FLATPAK_FS: [&str; 2] = ["xdg-config/gtk-4.0:ro", "xdg-data/themes:ro"];
const SURF_NAMES: [&str; 6] = [
    "surface",
    "surface_container_low",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "outline_variant",
];
const DARK_STEPS: [f64; 6] = [0.0, 0.022, 0.038, 0.065, 0.100, 0.225];
const LIGHT_STEPS: [f64; 6] = [0.0, -0.045, -0.075, -0.115, -0.160, -0.340];
const TEXT_KEYS: [&str; 7] = ["cream", "bright", "subtle", "dim", "faint", "icon_dim", "tick_rest"];
const DARK_TEXT: [(f64, f64); 7] = [
    (0.90, 0.05),
    (0.97, 0.03),
    (0.73, 0.07),
    (0.54, 0.06),
    (0.44, 0.05),
    (0.81, 0.07),
    (0.75, 0.08),
];
const LIGHT_TEXT: [(f64, f64); 7] = [
    (0.20, 0.18),
    (0.10, 0.20),
    (0.36, 0.14),
    (0.48, 0.10),
    (0.56, 0.08),
    (0.28, 0.12),
    (0.34, 0.12),
];

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
    fn get(&self, key: &str) -> Option<&Json> {
        match self {
            Json::Object(map) => map.get(key),
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
        match *self.b.get(self.i).ok_or("end of JSON")? {
            b'n' => {
                self.lit(b"null")?;
                Ok(Json::Null)
            }
            b't' => {
                self.lit(b"true")?;
                Ok(Json::Bool(true))
            }
            b'f' => {
                self.lit(b"false")?;
                Ok(Json::Bool(false))
            }
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
            Err("bad literal".into())
        }
    }
    fn string(&mut self) -> Result<String, String> {
        if self.b.get(self.i) != Some(&b'"') {
            return Err("expected string".into());
        }
        self.i += 1;
        let mut out = String::new();
        loop {
            let c = *self.b.get(self.i).ok_or("unterminated string")?;
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

fn escape(s: &str) -> String {
    let mut out = String::new();
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
    out
}

fn write_json(value: &Json, pretty: bool, depth: usize, out: &mut String) {
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
                write_json(v, pretty, depth + 1, out);
            }
            out.push(']');
        }
        Json::Object(m) => {
            out.push('{');
            for (i, (k, v)) in m.iter().enumerate() {
                if i > 0 {
                    out.push(',');
                }
                if pretty {
                    out.push('\n');
                    out.push_str(&"  ".repeat(depth + 1));
                }
                out.push('"');
                out.push_str(&escape(k));
                out.push_str("\":");
                if pretty {
                    out.push(' ');
                }
                write_json(v, pretty, depth + 1, out);
            }
            if pretty && !m.is_empty() {
                out.push('\n');
                out.push_str(&"  ".repeat(depth));
            }
            out.push('}');
        }
    }
}

fn json_string(value: &Json, pretty: bool) -> String {
    let mut out = String::new();
    write_json(value, pretty, 0, &mut out);
    out
}

fn object(entries: Vec<(&str, Json)>) -> Json {
    let mut map = BTreeMap::new();
    for (key, value) in entries {
        map.insert(key.into(), value);
    }
    Json::Object(map)
}

fn string(value: &str) -> Json {
    Json::String(value.into())
}

// ── Paths/flags ─────────────────────────────────────────────────────────────

fn home() -> PathBuf {
    env::var_os("HOME").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/"))
}

fn xdg(name: &str, fallback: &str) -> PathBuf {
    env::var_os(name).map(PathBuf::from).unwrap_or_else(|| home().join(fallback))
}

fn cache() -> PathBuf {
    home().join(".cache/reddot")
}

fn state() -> PathBuf {
    xdg("XDG_STATE_HOME", ".local/state").join("reddot")
}

fn gtk4() -> PathBuf {
    xdg("XDG_CONFIG_HOME", ".config").join("gtk-4.0")
}

fn gtk3() -> PathBuf {
    gtk4().parent().unwrap_or(Path::new(".")).join("gtk-3.0")
}

fn themes() -> PathBuf {
    xdg("XDG_DATA_HOME", ".local/share").join("themes")
}

fn overrides() -> PathBuf {
    xdg("XDG_DATA_HOME", ".local/share").join("flatpak/overrides/global")
}

fn fastfetch() -> PathBuf {
    home().join(".config/fastfetch")
}

fn flags() -> Json {
    fs::read_to_string(state().join("flags.json"))
        .ok()
        .and_then(|text| Parser::parse(&text).ok())
        .unwrap_or(Json::Null)
}

fn palette_mode() -> String {
    env::var("REDDOT_PALETTE")
        .ok()
        .or_else(|| flags().get("paletteMode").and_then(Json::as_str).map(str::to_string))
        .unwrap_or_else(|| "static".into())
}

// ── Color math ──────────────────────────────────────────────────────────────

fn rgb_to_hls(r: f64, g: f64, b: f64) -> (f64, f64, f64) {
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let l = (max + min) / 2.0;
    if (max - min).abs() < f64::EPSILON {
        return (0.0, l, 0.0);
    }
    let d = max - min;
    let s = if l > 0.5 { d / (2.0 - max - min) } else { d / (max + min) };
    let h = if max == r {
        ((g - b) / d) % 6.0
    } else if max == g {
        (b - r) / d + 2.0
    } else {
        (r - g) / d + 4.0
    };
    ((h / 6.0 + 1.0) % 1.0, l, s)
}

fn hls_to_rgb(h: f64, l: f64, s: f64) -> (f64, f64, f64) {
    if s <= 0.0 {
        return (l, l, l);
    }
    let q = if l < 0.5 { l * (1.0 + s) } else { l + s - l * s };
    let p = 2.0 * l - q;
    let hue = |mut t: f64| {
        if t < 0.0 {
            t += 1.0;
        }
        if t > 1.0 {
            t -= 1.0;
        }
        if t < 1.0 / 6.0 {
            p + (q - p) * 6.0 * t
        } else if t < 0.5 {
            q
        } else if t < 2.0 / 3.0 {
            p + (q - p) * (2.0 / 3.0 - t) * 6.0
        } else {
            p
        }
    };
    (hue(h + 1.0 / 3.0), hue(h), hue(h - 1.0 / 3.0))
}

fn tint(hue: f64, sat: f64, light: f64) -> String {
    let (r, g, b) = hls_to_rgb(hue.rem_euclid(1.0), light.clamp(0.0, 1.0), sat.clamp(0.0, 1.0));
    format!(
        "#{:02x}{:02x}{:02x}",
        (r * 255.0).round() as u8,
        (g * 255.0).round() as u8,
        (b * 255.0).round() as u8
    )
}

fn lerp(x: f64, x0: f64, x1: f64, y0: f64, y1: f64) -> f64 {
    let t = ((x - x0) / (x1 - x0)).clamp(0.0, 1.0);
    y0 + t * (y1 - y0)
}

// ── Palette generation ──────────────────────────────────────────────────────

struct Bucket {
    wsat: f64,
    best: Option<(f64, f64, f64)>,
}

fn analyze(wallpaper: &Path) -> (Option<(f64, f64)>, f64) {
    let out = Command::new("magick")
        .arg(wallpaper)
        .args(["-alpha", "off", "-resize", "200x200", "-colors", "48", "-format", "%c", "histogram:info:-"])
        .output()
        .ok()
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default();
    let mut buckets: BTreeMap<usize, Bucket> = BTreeMap::new();
    let mut total = 0u64;
    let mut lum = 0.0;
    let mut chroma = 0u64;
    for line in out.lines() {
        let Some(colon) = line.find(':') else { continue };
        let count: u64 = line[..colon].trim().parse().unwrap_or(0);
        let Some(hash) = line[colon..].find('#') else { continue };
        let start = colon + hash + 1;
        let Some(hex) = line.get(start..start + 6) else { continue };
        if !hex.chars().all(|c| c.is_ascii_hexdigit()) {
            continue;
        }
        let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(0) as f64 / 255.0;
        let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(0) as f64 / 255.0;
        let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(0) as f64 / 255.0;
        let (h, l, s) = rgb_to_hls(r, g, b);
        total += count;
        lum += count as f64 * l;
        if s < 0.15 || l < 0.05 || l > 0.92 {
            continue;
        }
        chroma += count;
        let idx = ((h * 360.0) as usize / 30) % 12;
        let entry = buckets.entry(idx).or_insert(Bucket { wsat: 0.0, best: None });
        entry.wsat += count as f64 * s;
        let score = count as f64 * s * if (0.12..0.55).contains(&l) { 1.0 } else { 0.4 };
        if entry.best.map(|b| score > b.0).unwrap_or(true) {
            entry.best = Some((score, h, s));
        }
    }
    let mean_l = if total > 0 { lum / total as f64 } else { 0.0 };
    if buckets.is_empty() || (chroma as f64) < total as f64 * 0.08 {
        return (None, mean_l);
    }
    let win = buckets.values().max_by(|a, b| a.wsat.partial_cmp(&b.wsat).unwrap()).unwrap();
    (win.best.map(|(_, h, s)| (h, s)), mean_l)
}

fn matugen(source: &str) -> Option<Json> {
    let out = Command::new("matugen")
        .args(["color", "hex", source, "-m", "dark", "-j", "hex"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    Parser::parse(&String::from_utf8_lossy(&out.stdout)).ok()
}

fn render_fastfetch(pill: &BTreeMap<String, String>) -> Result<(), String> {
    let ff = fastfetch();
    let tmpl = ff.join("config.jsonc.in");
    if !tmpl.is_file() {
        eprintln!("wallcolors: config.jsonc.in missing in ~/.config/fastfetch, skipping fastfetch recolour (apply the reddot update or re-run the installer)");
        return Ok(());
    }
    let seq = |h: &str| -> String {
        let mut out = Vec::new();
        for i in [1, 3, 5] {
            out.push(u8::from_str_radix(&h[i..i + 2], 16).unwrap_or(0).to_string());
        }
        out.join(";")
    };
    let mut replacements = BTreeMap::new();
    replacements.insert("__LANTERN__", ff.join("lantern.txt").to_string_lossy().into_owned());
    replacements.insert("__KEYS__", seq(&pill["primary"]));
    replacements.insert("__SEP__", seq(&pill["dim"]));
    replacements.insert("__LOGO1__", seq(&pill["primary"]));
    replacements.insert("__LOGO2__", seq(&pill["on_primary_container"]));
    replacements.insert("__LOGO3__", seq(&pill["surface_container"]));
    replacements.insert("__LOGO4__", seq(&pill["surface_container_high"]));
    replacements.insert("__LOGO5__", seq(&pill["subtle"]));
    replacements.insert("__LOGO6__", seq(&pill["outline"]));
    replacements.insert("__LOGO7__", seq(&pill["bright"]));
    let mut out = fs::read_to_string(&tmpl).map_err(|e| e.to_string())?;
    for (key, value) in replacements {
        out = out.replace(key, &value);
    }
    fs::write(ff.join("config.jsonc"), out).map_err(|e| e.to_string())
}

fn static_palette() -> BTreeMap<String, String> {
    let entries = [
        ("surface", "#0b0b0b"),
        ("surface_container_low", "#0d0d0d"),
        ("surface_container", "#151515"),
        ("surface_container_high", "#181818"),
        ("surface_container_highest", "#222222"),
        ("outline_variant", "#2a2a2a"),
        ("primary", "#e60012"),
        ("primary_container", "#7a0010"),
        ("on_primary_container", "#ffdada"),
        ("outline", "#3a3a3a"),
        ("cream", "#f2f2f2"),
        ("bright", "#ffffff"),
        ("subtle", "#b8b8b8"),
        ("dim", "#8a8a8a"),
        ("faint", "#707070"),
        ("icon_dim", "#d0d0d0"),
        ("tick_rest", "#c8c8c8"),
    ];
    entries.into_iter().map(|(k, v)| (k.to_string(), v.into())).collect()
}

fn static_ghostty() -> String {
    let colors = [
        "#151515", "#e60012", "#8a9a5b", "#d89a5b", "#6f8da0", "#b06a78", "#7fa89a", "#f2f2f2",
        "#303030", "#ff3344", "#a8b56e", "#f0b85e", "#8fa9bb", "#d08a96", "#9fc3b4", "#ffffff",
    ];
    let mut out = String::from(
        "background = #0b0b0b\nforeground = #f2f2f2\ncursor-color = #e60012\nselection-background = #303030\nselection-foreground = #ffffff\n",
    );
    for (i, color) in colors.iter().enumerate() {
        out.push_str(&format!("palette = {i}={color}\n"));
    }
    out
}

fn write_pill(pill: &BTreeMap<String, String>) {
    let map = pill.iter().map(|(k, v)| (k.clone(), string(v))).collect();
    let _ = write_text(&cache().join("colors.json"), (json_string(&Json::Object(map), true) + "\n").as_str());
    let _ = fs::create_dir_all(cache());
    let _ = render_fastfetch(pill);
}

fn write_static() {
    let pill = static_palette();
    let _ = fs::create_dir_all(cache());
    write_pill(&pill);
    if flags().get("appTheme").and_then(Json::as_bool) == Some(true) {
        let _ = sync_apps(&pill, true);
    }
    let _ = write_text(
        &cache().join("hypr-colors.lua"),
        "return {\n    active = \"#e60012\",\n    inactive = \"#2a2a2a\",\n}\n",
    );
    let _ = write_text(&cache().join("ghostty-colors"), &static_ghostty());
}

fn write_generated(hue: f64, sat: f64, mean_l: f64, chromatic: bool) {
    let light = mean_l >= 0.40;
    let surf_sat = if light { sat.min(0.26) } else { sat.clamp(if chromatic { 0.30 } else { 0.0 }, 0.45) };
    let acc_sat = if chromatic {
        if light { (sat + 0.18).min(0.85) } else { (sat.max(0.30) + 0.12).min(0.82) }
    } else {
        0.05
    };
    let (base, steps, text, acc_l, deep_l, glow_l) = if light {
        (
            lerp(mean_l, 0.40, 0.66, 0.80, 0.93),
            LIGHT_STEPS,
            LIGHT_TEXT,
            0.42,
            0.30,
            0.55,
        )
    } else {
        (
            lerp(mean_l, 0.0, 0.40, 0.045, 0.20),
            DARK_STEPS,
            DARK_TEXT,
            0.70,
            0.34,
            0.86,
        )
    };
    let mut pill = BTreeMap::new();
    for (name, step) in SURF_NAMES.iter().zip(steps) {
        pill.insert((*name).to_string(), tint(hue, surf_sat, base + step));
    }
    pill.insert("primary".into(), tint(hue, acc_sat, acc_l));
    pill.insert("primary_container".into(), tint(hue, (acc_sat + 0.08).min(0.9), deep_l));
    pill.insert("on_primary_container".into(), tint(hue, acc_sat.min(0.45), glow_l));
    pill.insert("outline".into(), tint(hue, surf_sat, base + if light { -0.35 } else { 0.35 }));
    for (key, (lit, st)) in TEXT_KEYS.iter().zip(text) {
        pill.insert((*key).to_string(), tint(hue, st, lit));
    }
    write_pill(&pill);
    if flags().get("appTheme").and_then(Json::as_bool) == Some(true) {
        let _ = sync_apps(&pill, true);
    }
    let Some(mat) = matugen(&tint(hue, sat, 0.45)) else { return };
    let Some(base16) = mat.get("base16") else { return };
    let mut b = BTreeMap::new();
    for i in 0..16 {
        let key = format!("base{i:02x}");
        if let Some(color) = base16.get(&key).and_then(|v| v.get("dark")).and_then(|v| v.get("color")).and_then(Json::as_str) {
            b.insert(key, color.to_string());
        }
    }
    let active = pill.get("primary").cloned().unwrap_or_default();
    let inactive = b.get("base01").cloned().unwrap_or_default();
    let _ = write_text(
        &cache().join("hypr-colors.lua"),
        &format!("return {{\n    active = \"{active}\",\n    inactive = \"{inactive}\",\n}}\n"),
    );
    let mut lines = vec![
        format!("background = {}", b.get("base00").cloned().unwrap_or_default()),
        format!("foreground = {}", b.get("base07").cloned().unwrap_or_default()),
        format!("cursor-color = {active}"),
        format!("selection-background = {}", b.get("base02").cloned().unwrap_or_default()),
        format!("selection-foreground = {}", b.get("base07").cloned().unwrap_or_default()),
    ];
    for i in 0..16 {
        if let Some(color) = b.get(&format!("base{i:02x}")) {
            lines.push(format!("palette = {i}={color}"));
        }
    }
    let _ = write_text(&cache().join("ghostty-colors"), &(lines.join("\n") + "\n"));
}

// ── GTK app theme ───────────────────────────────────────────────────────────

fn write_text(path: &Path, text: &str) -> Result<bool, String> {
    if fs::read_to_string(path).ok().as_deref() == Some(text) {
        return Ok(false);
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    fs::write(path, text).map_err(|e| e.to_string())?;
    Ok(true)
}

fn gget(key: &str) -> String {
    Command::new("gsettings")
        .args(["get", IFACE, key])
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().trim_matches('\'').to_string())
        .unwrap_or_default()
}

fn gset(key: &str, value: &str) {
    let _ = Command::new("gsettings").args(["set", IFACE, key, value]).output();
}

fn set_scheme(scheme: &str, force: bool) {
    if gget("color-scheme") == scheme {
        if !force {
            return;
        }
        gset("color-scheme", if scheme == "prefer-dark" { "prefer-light" } else { "prefer-dark" });
        sleep(Duration::from_millis(250));
    }
    gset("color-scheme", scheme);
}

fn notify(summary: &str, body: &str) -> bool {
    Command::new("gdbus")
        .args([
            "call", "--session", "--dest", "org.freedesktop.Notifications",
            "--object-path", "/org/freedesktop/Notifications", "--method",
            "org.freedesktop.Notifications.Notify", "reddot", "0", "", summary, body,
            "[]", "{}", "8000",
        ])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn flatpak_shares() -> Vec<String> {
    let mut shares = Vec::new();
    for file in [overrides(), PathBuf::from("/var/lib/flatpak/overrides/global")] {
        if let Ok(text) = fs::read_to_string(file) {
            for line in text.lines() {
                if let Some(rest) = line.strip_prefix("filesystems=") {
                    shares.extend(
                        rest.split(';')
                            .filter(|fs| !fs.is_empty())
                            .map(|fs| fs.trim_start_matches('!').split(':').next().unwrap_or("").to_string()),
                    );
                }
            }
        }
    }
    shares
}

fn lock_apps() -> Result<PathBuf, String> {
    let lock = state().join("apptheme.lock.d");
    fs::create_dir_all(state()).map_err(|e| e.to_string())?;
    for _ in 0..50 {
        match fs::create_dir(&lock) {
            Ok(()) => return Ok(lock),
            Err(_) => sleep(Duration::from_millis(100)),
        }
    }
    Err("apptheme lock timeout".into())
}

fn unlock_apps(lock: &Path) {
    let _ = fs::remove_dir_all(lock);
}

fn gtk_colors(p: &BTreeMap<String, String>, light: bool) -> String {
    let primary = &p["primary"];
    let bright = &p["bright"];
    let surface = &p["surface"];
    let mut named: BTreeMap<String, String> = BTreeMap::new();
    named.insert("accent_bg_color".into(), primary.clone());
    named.insert("accent_fg_color".into(), if light { bright.clone() } else { surface.clone() });
    named.insert("accent_color".into(), primary.clone());
    for (key, value) in [
        ("window_bg_color", "surface_container_low"),
        ("view_bg_color", "surface"),
        ("headerbar_bg_color", "surface_container"),
        ("headerbar_backdrop_color", "surface_container_low"),
        ("headerbar_border_color", "outline_variant"),
        ("sidebar_bg_color", "surface_container"),
        ("sidebar_backdrop_color", "surface_container_low"),
        ("secondary_sidebar_bg_color", "surface_container_low"),
        ("card_bg_color", "surface_container_high"),
        ("dialog_bg_color", "surface_container_high"),
        ("popover_bg_color", "surface_container_high"),
        ("thumbnail_bg_color", "surface_container_high"),
    ] {
        named.insert(key.into(), p.get(value).cloned().unwrap_or_default());
    }
    for part in ["window", "view", "headerbar", "sidebar", "secondary_sidebar", "card", "dialog", "popover", "thumbnail"] {
        named.insert(format!("{part}_fg_color"), p["cream"].clone());
    }
    named.iter().map(|(k, v)| format!("@define-color {k} {v};\n")).collect()
}

fn find_theme(name: &str) -> Option<PathBuf> {
    for root in [PathBuf::from("/usr/share/themes"), PathBuf::from("/usr/local/share/themes"), themes()] {
        let dir = root.join(name);
        if dir.join("gtk-3.0/gtk.css").is_file() {
            return Some(dir);
        }
    }
    None
}

fn copy_tree(src: &Path, dst: &Path) -> Result<(), String> {
    fs::create_dir_all(dst).map_err(|e| e.to_string())?;
    for entry in fs::read_dir(src).map_err(|e| e.to_string())? {
        let entry = entry.map_err(|e| e.to_string())?;
        let target = dst.join(entry.file_name());
        if entry.file_type().map_err(|e| e.to_string())?.is_dir() {
            copy_tree(&entry.path(), &target)?;
        } else {
            fs::copy(entry.path(), &target).map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

fn base_theme(light: bool) -> Option<String> {
    let src = find_theme(if light { "adw-gtk3" } else { "adw-gtk3-dark" })?;
    let dst = themes().join(if light { "reddot-base" } else { "reddot-base-dark" });
    let css = dst.join("gtk-3.0/gtk.css");
    let need_copy = !css.is_file()
        || src.join("gtk-3.0/gtk.css").metadata().ok().and_then(|m| m.modified().ok())
            > css.metadata().ok().and_then(|m| m.modified().ok());
    if need_copy {
        let _ = fs::remove_dir_all(&dst);
        copy_tree(&src, &dst).ok()?;
    }
    dst.file_name().and_then(|s| s.to_str()).map(str::to_string)
}

fn enable_apps() -> Result<(), String> {
    let mut backups = Vec::new();
    let mut dirs = vec![gtk4()];
    if find_theme("adw-gtk3-dark").is_some() {
        dirs.push(gtk3());
    }
    for dir in dirs {
        let css = dir.join("gtk.css");
        if css.is_file() && !fs::read_to_string(&css).map(|s| s.starts_with(MARK)).unwrap_or(false) {
            let mut target = dir.join("gtk.css.bak");
            let mut n = 1;
            while target.exists() {
                target = dir.join(format!("gtk.css.bak.{n}"));
                n += 1;
            }
            fs::rename(&css, &target).map_err(|e| e.to_string())?;
            backups.push(target.to_string_lossy().into_owned());
        }
    }
    let mut flatpak_added = Vec::new();
    if which("flatpak").is_some() {
        let have = flatpak_shares();
        for fs in FLATPAK_FS {
            let path = fs.trim_start_matches('!').split(':').next().unwrap_or("");
            if !have.iter().any(|h| h == path) {
                flatpak_added.push(fs.to_string());
            }
        }
        if !flatpak_added.is_empty() {
            let mut args = vec!["override", "--user"];
            let flags: Vec<String> = flatpak_added.iter().map(|fs| format!("--filesystem={fs}")).collect();
            args.extend(flags.iter().map(String::as_str));
            let _ = Command::new("flatpak").args(args).output();
        }
    }
    fs::create_dir_all(state()).map_err(|e| e.to_string())?;
    let value = object(vec![
        ("gtk-theme", string(&gget("gtk-theme"))),
        ("color-scheme", string(&gget("color-scheme"))),
        ("backups", Json::Array(backups.into_iter().map(|s| string(&s)).collect())),
        ("flatpak", Json::Array(flatpak_added.into_iter().map(|s| string(&s)).collect())),
        ("notified", Json::Bool(false)),
    ]);
    fs::write(state().join("apptheme.json"), json_string(&value, true) + "\n").map_err(|e| e.to_string())
}

fn remind_backups() -> Result<(), String> {
    let path = state().join("apptheme.json");
    let Ok(text) = fs::read_to_string(&path) else { return Ok(()) };
    let Ok(mut value) = Parser::parse(&text) else { return Ok(()) };
    let Json::Object(ref mut map) = value else { return Ok(()) };
    let backups = map.get("backups").and_then(|v| match v { Json::Array(a) => Some(a.clone()), _ => None }).unwrap_or_default();
    let notified = map.get("notified").and_then(Json::as_bool).unwrap_or(false);
    if backups.is_empty() || notified {
        return Ok(());
    }
    let names: Vec<String> = backups.iter().filter_map(|v| v.as_str()).map(|s| s.replace(&home().to_string_lossy().into_owned(), "~")).collect();
    if notify("App theme is on", &format!("Your own gtk.css was moved to {}. Turning App theme off puts it back.", names.join(", "))) {
        map.insert("notified".into(), Json::Bool(true));
        fs::write(path, json_string(&value, true) + "\n").map_err(|e| e.to_string())?;
    }
    Ok(())
}

fn apply_apps(p: &BTreeMap<String, String>) -> Result<(), String> {
    if !state().join("apptheme.json").is_file() {
        enable_apps()?;
    }
    let (r, g, b) = (
        u8::from_str_radix(&p["surface"][1..3], 16).unwrap_or(0) as f64 / 255.0,
        u8::from_str_radix(&p["surface"][3..5], 16).unwrap_or(0) as f64 / 255.0,
        u8::from_str_radix(&p["surface"][5..7], 16).unwrap_or(0) as f64 / 255.0,
    );
    let light = rgb_to_hls(r, g, b).1 > 0.5;
    let colors = gtk_colors(p, light);
    let root = format!(":root {{ --accent-bg-color: @accent_bg_color; --accent-fg-color: @accent_fg_color; --accent-color: {}; }}\n", p["primary"]);
    let mut changed = write_text(&gtk4().join("reddot.css"), &(colors.clone() + &root))?;
    if !gtk4().join("gtk.css").exists() {
        changed |= write_text(&gtk4().join("gtk.css"), &(MARK.to_string() + "@import url(\"reddot.css\");\n"))?;
    }
    if let Some(base) = base_theme(light) {
        let css3 = format!("{MARK}@import url(\"../../{base}/gtk-3.0/gtk.css\");\n{colors}");
        let current = gget("gtk-theme");
        let same = (current == "reddot-a" || current == "reddot-b")
            && fs::read_to_string(themes().join(&current).join("gtk-3.0/gtk.css")).map(|s| s == css3).unwrap_or(false);
        if !same {
            let target = if current == "reddot-a" { "reddot-b" } else { "reddot-a" };
            write_text(&themes().join(target).join("gtk-3.0/gtk.css"), &css3)?;
            write_text(
                &themes().join(target).join("gtk-4.0/gtk.css"),
                &format!("@import url(\"../../{base}/gtk-4.0/gtk.css\");\n"),
            )?;
            gset("gtk-theme", target);
            changed = true;
        }
    }
    set_scheme(if light { "prefer-light" } else { "prefer-dark" }, changed);
    remind_backups()
}

fn disable_apps() -> Result<(), String> {
    let path = state().join("apptheme.json");
    let state_value = fs::read_to_string(&path).ok().and_then(|text| Parser::parse(&text).ok());
    let css = gtk4().join("gtk.css");
    if css.is_file() && fs::read_to_string(&css).map(|s| s.starts_with(MARK)).unwrap_or(false) {
        let _ = fs::remove_file(&css);
    }
    let _ = fs::remove_file(gtk4().join("reddot.css"));
    if state_value.is_none() && !REDDOT_THEMES.contains(&gget("gtk-theme").as_str()) {
        return Ok(());
    }
    let mut value = state_value.unwrap_or_else(|| object(vec![]));
    if let Json::Object(ref mut map) = value {
        if let Some(Json::Array(backups)) = map.get("backups").cloned() {
            for backup in backups.iter().filter_map(Json::as_str) {
                let bak = PathBuf::from(backup);
                let live = bak.parent().unwrap_or(Path::new(".")).join("gtk.css");
                if bak.is_file() && !live.exists() {
                    let _ = fs::rename(&bak, &live);
                }
            }
        }
        let theme = map.get("gtk-theme").and_then(Json::as_str).unwrap_or("");
        let theme = if theme.is_empty() || theme == "Adwaita" || REDDOT_THEMES.contains(&theme) {
            if find_theme("adw-gtk3-dark").is_some() { "adw-gtk3-dark" } else { "Adwaita-dark" }
        } else {
            theme
        };
        gset("gtk-theme", theme);
        let scheme = map.get("color-scheme").and_then(Json::as_str).unwrap_or("");
        set_scheme(if scheme.is_empty() || scheme == "default" { "prefer-dark" } else { scheme }, true);
        if let Some(Json::Array(added)) = map.get("flatpak").cloned() {
            if !added.is_empty() {
                if let Ok(text) = fs::read_to_string(overrides()) {
                    let added: Vec<String> = added.iter().filter_map(Json::as_str).map(str::to_string).collect();
                    let mut lines = Vec::new();
                    for line in text.lines() {
                        if let Some(rest) = line.strip_prefix("filesystems=") {
                            let keep: Vec<&str> = rest.split(';').filter(|fs| !fs.is_empty() && !added.iter().any(|a| a == fs)).collect();
                            if keep.is_empty() {
                                continue;
                            }
                            lines.push(format!("filesystems={};", keep.join(";")));
                        } else {
                            lines.push(line.to_string());
                        }
                    }
                    if lines == ["[Context]"] {
                        let _ = fs::remove_file(overrides());
                    } else {
                        let _ = fs::write(overrides(), lines.join("\n") + "\n");
                    }
                }
            }
        }
    }
    for name in REDDOT_THEMES {
        let _ = fs::remove_dir_all(themes().join(name));
    }
    let _ = fs::remove_file(path);
    Ok(())
}

fn sync_apps(pill: &BTreeMap<String, String>, need_flag: bool) -> Result<(), String> {
    let lock = lock_apps()?;
    let result = (|| {
        if need_flag && flags().get("appTheme").and_then(Json::as_bool) != Some(true) {
            return Ok(());
        }
        let palette = if palette_mode() == "static" { static_palette() } else { pill.clone() };
        apply_apps(&palette)
    })();
    unlock_apps(&lock);
    result
}

fn which(bin: &str) -> Option<PathBuf> {
    env::var_os("PATH").and_then(|paths| {
        env::split_paths(&paths).map(|dir| dir.join(bin)).find(|p| p.is_file())
    })
}

// ── CLI ─────────────────────────────────────────────────────────────────────

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let code = match args.first().map(String::as_str) {
        None => 1,
        Some("--apps") => {
            if args.get(1).map(String::as_str) == Some("off") {
                if let Ok(lock) = lock_apps() {
                    let _ = disable_apps();
                    unlock_apps(&lock);
                }
            } else {
                let pill = fs::read_to_string(cache().join("colors.json"))
                    .ok()
                    .and_then(|text| Parser::parse(&text).ok())
                    .and_then(|v| match v { Json::Object(map) => Some(map.into_iter().filter_map(|(k, v)| v.as_str().map(|s| (k, s.to_string()))).collect()), _ => None })
                    .unwrap_or_else(static_palette);
                let _ = sync_apps(&pill, false);
            }
            0
        }
        Some("--static") => {
            write_static();
            0
        }
        Some("--hue") => {
            let hue = args.get(1).and_then(|s| s.parse::<f64>().ok()).unwrap_or(0.0).rem_euclid(360.0) / 360.0;
            let mode = args.get(2).map(String::as_str).unwrap_or("dark");
            let sat = args.get(3).and_then(|s| s.parse::<f64>().ok()).unwrap_or(0.5).clamp(0.0, 1.0);
            let mean_l = if mode == "light" { 0.85 } else { 0.12 };
            let chromatic = sat > 0.02;
            write_generated(hue, sat, mean_l, chromatic);
            0
        }
        Some(path) => {
            let path = PathBuf::from(path);
            if !path.is_file() {
                return;
            }
            let (hue_sat, mean_l) = analyze(&path);
            let chromatic = hue_sat.is_some();
            let (hue, sat) = hue_sat.unwrap_or((0.09, 0.0));
            write_generated(hue, sat, mean_l, chromatic);
            0
        }
    };
    std::process::exit(code);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hls_round_trip() {
        let (h, l, s) = rgb_to_hls(0.2, 0.4, 0.6);
        let (r, g, b) = hls_to_rgb(h, l, s);
        assert!((r - 0.2).abs() < 1e-6 && (g - 0.4).abs() < 1e-6 && (b - 0.6).abs() < 1e-6);
    }

    #[test]
    fn tint_static_accent() {
        assert_eq!(tint(0.0, 1.0, 0.5), "#ff0000");
    }

    #[test]
    fn deploy_paths_are_under_home() {
        assert!(fastfetch().ends_with(".config/fastfetch"));
    }
}
