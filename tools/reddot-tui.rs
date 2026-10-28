//! Rust port of the rendering half of installer/tui.py.
//! Input/raw-terminal handling is a separate phase. Output is deterministic for a
//! fixed width, which is what the parity test compares.

use std::env;
use std::fs::{File, OpenOptions};
use std::io::{Read, Write};
use std::process::Command;

#[derive(Clone, Copy)]
struct Rgb(u8, u8, u8);
const VERM: Rgb = Rgb(230, 0, 18);
const FLAME: Rgb = Rgb(255, 51, 68);
const CREAM: Rgb = Rgb(242, 242, 242);
const BRIGHT: Rgb = Rgb(255, 255, 255);
const DIM: Rgb = Rgb(138, 138, 138);
const FAINT: Rgb = Rgb(112, 112, 112);
const GREEN: Rgb = Rgb(120, 180, 120);
const DEEP: Rgb = Rgb(63, 69, 80);
const INK: Rgb = Rgb(51, 55, 63);
const SLATE: Rgb = Rgb(139, 145, 156);

const INTRO: &str = "▌";
const OUTRO: &str = "▌";
const BAR: &str = "▏";
const ACTIVE: &str = "◼";
const DONE: &str = "▫";
const CHECK_ON: &str = "■";
const CHECK_OFF: &str = "□";
const RADIO_ON: &str = "●";
const RADIO_OFF: &str = "○";
const LBRACKET: &str = "「";
const RBRACKET: &str = "」";

const TORII: [(Rgb, &str); 9] = [
    (DEEP, "      ╱▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔╲"),
    (DEEP, "   ▗▄████████████████████▄▖"),
    (INK, "      ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀"),
    (VERM, "        ███   ▐▌   ███"),
    (VERM, "    ▄▄▄▄███▄▄▄▄▄▄▄▄███▄▄▄▄"),
    (FLAME, "    ▀▀▀▀███▀▀▀▀▀▀▀▀███▀▀▀▀"),
    (VERM, "        ███        ███"),
    (VERM, "        ███        ███"),
    (SLATE, "       ▟███▙      ▟███▙"),
];

struct Style {
    color: bool,
}

impl Style {
    fn fg(&self, c: Rgb) -> String {
        if !self.color { return String::new(); }
        format!("\x1b[38;2;{};{};{}m", c.0, c.1, c.2)
    }
    fn reset(&self) -> &'static str {
        if self.color { "\x1b[0m" } else { "" }
    }
}

fn vis(text: &str) -> usize {
    text.chars().map(|c| if c == '「' || c == '」' { 2 } else { 1 }).sum()
}

fn clip(style: &Style, segments: &[(Rgb, &str)], width: usize) -> String {
    let mut parts = Vec::new();
    let mut used = 0;
    for (color, text) in segments {
        let mut kept = String::new();
        for ch in text.chars() {
            let cell = if ch == '「' || ch == '」' { 2 } else { 1 };
            if used + cell > width { break; }
            kept.push(ch);
            used += cell;
        }
        if !kept.is_empty() {
            parts.push(style.fg(*color) + &kept);
        }
        if used >= width { break; }
    }
    parts.join("") + style.reset()
}

fn wrap(text: &str, width: usize) -> Vec<String> {
    let words: Vec<&str> = text.split_whitespace().collect();
    if words.is_empty() { return vec![String::new()]; }
    let mut lines = Vec::new();
    let mut current = String::new();
    for word in words {
        let candidate = if current.is_empty() { word.to_string() } else { format!("{current} {word}") };
        if vis(&candidate) <= width {
            current = candidate;
        } else {
            if !current.is_empty() { lines.push(current); }
            current = word.to_string();
        }
    }
    lines.push(current);
    lines
}

fn header(style: &Style, marker: &str, marker_color: Rgb, title: &str, title_color: Rgb, width: usize) -> String {
    clip(style, &[(BRIGHT, "  "), (marker_color, marker), (BRIGHT, "  "), (title_color, title)], width)
}

fn gutter(style: &Style, segments: &[(Rgb, &str)], width: usize) -> String {
    let mut all = vec![(BRIGHT, "  "), (FAINT, BAR), (BRIGHT, "  ")];
    all.extend_from_slice(segments);
    clip(style, &all, width)
}
fn spacer(style: &Style, width: usize) -> String {
    clip(style, &[(BRIGHT, "  "), (FAINT, BAR)], width)
}
fn bottom(style: &Style, width: usize) -> String { clip(style, &[(BRIGHT, "  "), (VERM, OUTRO)], width) }

fn bracket_lines(style: &Style, value: &str, width: usize) -> Vec<String> {
    let inner = width.saturating_sub(9).max(8);
    let chunks = wrap(value, inner);
    chunks.iter().enumerate().map(|(i, chunk)| {
        let left = if i == 0 { LBRACKET } else { " " };
        let right = if i + 1 == chunks.len() { RBRACKET } else { "" };
        gutter(style, &[(CREAM, &format!("{left}{chunk}{right}"))], width)
    }).collect()
}

fn collapsed_block(style: &Style, title: &str, value: &str, width: usize) -> Vec<String> {
    let mut lines = vec![header(style, DONE, FAINT, title, CREAM, width)];
    lines.extend(bracket_lines(style, value, width));
    lines.push(spacer(style, width));
    lines
}

fn menu_block(style: &Style, title: &str, options: &[(&str, &str, bool)], idx: usize, checked: &[usize], multi: bool, width: usize) -> Vec<String> {
    let mut lines = vec![header(style, ACTIVE, FLAME, title, BRIGHT, width)];
    let label_width = options.iter().map(|(l, _, _)| vis(l)).max().unwrap_or(0);
    for (i, (label, desc, recommended)) in options.iter().enumerate() {
        let focused = i == idx;
        let selected = checked.contains(&i);
        let (seal, seal_color) = if multi {
            if selected { (CHECK_ON, FLAME) } else { (CHECK_OFF, FAINT) }
        } else if selected { (RADIO_ON, FLAME) } else { (RADIO_OFF, FAINT) };
        let label_color = if focused { BRIGHT } else if selected { CREAM } else { DIM };
        let mut segs: Vec<(Rgb, String)> = vec![(seal_color, seal.into()), (BRIGHT, " ".into()), (label_color, (*label).into())];
        if focused {
            let pad = " ".repeat(label_width.saturating_sub(vis(label)) + 4);
            if !desc.is_empty() {
                segs.push((BRIGHT, pad));
                segs.push((FAINT, (*desc).into()));
            }
            if *recommended {
                segs.push((BRIGHT, "   ".into()));
                segs.push((GREEN, "(Recommended)".into()));
            }
        }
        let borrowed: Vec<(Rgb, &str)> = segs.iter().map(|(c, s)| (*c, s.as_str())).collect();
        lines.push(gutter(style, &borrowed, width));
    }
    lines.push(bottom(style, width));
    lines
}

fn confirm_block(style: &Style, title: &str, summary: &[&str], idx: usize, width: usize) -> Vec<String> {
    let mut lines = vec![header(style, ACTIVE, FLAME, title, BRIGHT, width)];
    let inner = width.saturating_sub(5).max(8);
    for line in summary {
        for piece in wrap(line, inner) {
            lines.push(gutter(style, &[(CREAM, &piece)], width));
        }
    }
    lines.push(spacer(style, width));
    for (i, label) in ["Yes, continue", "No, cancel"].iter().enumerate() {
        let focused = i == idx;
        let (dot, color) = if focused { (RADIO_ON, FLAME) } else { (RADIO_OFF, FAINT) };
        let label_color = if focused { BRIGHT } else { DIM };
        lines.push(gutter(style, &[(color, dot), (BRIGHT, " "), (label_color, label)], width));
    }
    lines.push(bottom(style, width));
    lines
}

fn banner(style: &Style, width: usize) -> String {
    let mut lines: Vec<String> = TORII.iter().map(|(color, art)| clip(style, &[(BRIGHT, "  "), (*color, art)], width)).collect();
    lines.push(String::new());
    lines.push(clip(style, &[(BRIGHT, "  "), (FLAME, "reddot"), (BRIGHT, "   "), (DIM, "A black-and-red Hyprland rice")], width));
    lines.push(clip(style, &[(BRIGHT, "  "), (FAINT, "github.com/SrRenks/reddot")], width));
    lines.push(String::new());
    lines.push(header(style, INTRO, VERM, "reddot installer", CREAM, width));
    lines.push(spacer(style, width));
    lines.join("\n") + "\n"
}

fn detected(style: &Style, rows: &[(&str, &str, bool)], width: usize) -> String {
    let pad = rows.iter().map(|(l, _, _)| l.chars().count()).max().unwrap_or(0);
    let mut out = vec![header(style, DONE, FAINT, "Detected", CREAM, width)];
    for (label, value, _) in rows {
        let label = format!("{label:<pad$}   ");
        out.push(gutter(style, &[(DIM, &label), (CREAM, value)], width));
    }
    out.push(spacer(style, width));
    out.join("\n") + "\n"
}

fn info(style: &Style, lines: &[&str], width: usize) -> String {
    let inner = width.saturating_sub(5).max(8);
    let mut out = Vec::new();
    for line in lines {
        for piece in wrap(line, inner) {
            out.push(gutter(style, &[(DIM, &piece)], width));
        }
    }
    out.push(spacer(style, width));
    out.join("\n") + "\n"
}

fn outro(style: &Style, message: &str, width: usize) -> String {
    header(style, OUTRO, VERM, message, CREAM, width) + "\n"
}

fn closing(style: &Style, title: &str, tally: &str, steps: &[(&str, &str)], attention: &[(&str, &str)], notes: &[&str], width: usize) -> String {
    let mut out = vec![header(style, OUTRO, VERM, title, BRIGHT, width), spacer(style, width)];
    if !tally.is_empty() {
        out.push(gutter(style, &[(DIM, "packages   "), (CREAM, tally)], width));
        out.push(spacer(style, width));
    }
    if !steps.is_empty() {
        out.push(header(style, DONE, FLAME, "Next", CREAM, width));
        let keyw = steps.iter().map(|(k, _)| vis(k)).max().unwrap_or(0);
        for (i, (key, hint)) in steps.iter().enumerate() {
            let mut segs: Vec<(Rgb, String)> = vec![(FLAME, format!("{}  ", i + 1)), (BRIGHT, (*key).into())];
            if !hint.is_empty() {
                segs.push((BRIGHT, " ".repeat(keyw.saturating_sub(vis(key)) + 3)));
                segs.push((DIM, (*hint).into()));
            }
            let borrowed: Vec<(Rgb, &str)> = segs.iter().map(|(c, s)| (*c, s.as_str())).collect();
            out.push(gutter(style, &borrowed, width));
        }
        out.push(spacer(style, width));
    }
    for line in notes {
        out.push(gutter(style, &[(FAINT, line)], width));
    }
    if !notes.is_empty() { out.push(spacer(style, width)); }
    if !attention.is_empty() {
        let head = if attention.len() == 1 { "One step needs you" } else { "A few steps need you" };
        out.push(header(style, OUTRO, VERM, head, BRIGHT, width));
        let labw = attention.iter().map(|(l, _)| vis(l)).max().unwrap_or(0);
        for (label, cmd) in attention {
            let pad = labw.saturating_sub(vis(label)) + 3;
            if 7 + vis(label) + pad + vis(cmd) <= width {
                let dots = format!("{DONE} ");
                let padding = " ".repeat(pad);
                out.push(gutter(style, &[(FLAME, &dots), (CREAM, label), (BRIGHT, &padding), (BRIGHT, cmd)], width));
            } else {
                let dots = format!("{DONE} ");
                out.push(gutter(style, &[(FLAME, &dots), (CREAM, label)], width));
                for piece in wrap(cmd, width.saturating_sub(11).max(8)) {
                    out.push(gutter(style, &[(BRIGHT, "  "), (BRIGHT, &piece)], width));
                }
            }
        }
        out.push(spacer(style, width));
    }
    out.join("\n") + "\n"
}

fn sample(style: &Style, width: usize) -> String {
    let mut out = String::new();
    out.push_str(&banner(style, width));
    out.push_str(&detected(style, &[("OS", "CachyOS", true), ("Session", "Hyprland", true), ("Package manager", "pacman", true), ("AUR helper", "yay", true)], width));
    out.push_str(&info(style, &["A quiet note about this step."], width));
    for line in menu_block(style, "Install profile", &[("Quick", "Core defaults, no questions", true), ("Full", "Everything, the daily apps too", false), ("Custom", "Walk every choice yourself", false)], 0, &[0], false, width) { out.push_str(&line); out.push('\n'); }
    for line in collapsed_block(style, "Install profile", "Quick", width) { out.push_str(&line); out.push('\n'); }
    for line in confirm_block(style, "Ready", &["Install this?"], 0, width) { out.push_str(&line); out.push('\n'); }
    out.push_str(&closing(style, "Done", "12 packages", &[("restart", "the shell"), ("read", "docs/KEYBINDS.md")], &[("log in", "reboot")], &["Keep the installer log"], width));
    out.push_str(&outro(style, "Done", width));
    out
}

struct Terminal {
    tty: File,
    saved: String,
}

impl Terminal {
    fn open() -> Result<Self, String> {
        let tty = OpenOptions::new().read(true).write(true).open("/dev/tty")
            .map_err(|_| "no controlling terminal; use --quickstart".to_string())?;
        let saved = Command::new("stty").args(["-F", "/dev/tty", "-g"]).output()
            .ok().filter(|o| o.status.success())
            .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
            .filter(|s| !s.is_empty())
            .ok_or_else(|| "no controlling terminal; use --quickstart".to_string())?;
        let ok = Command::new("stty").args(["-F", "/dev/tty", "raw", "-echo", "min", "0", "time", "1"]).status()
            .map(|s| s.success()).unwrap_or(false);
        if !ok { return Err("cannot put the terminal in raw mode".into()); }
        let mut tty = tty;
        let _ = tty.write_all(b"\x1b[?25l");
        Ok(Self { tty, saved })
    }

    fn read_key(&mut self) -> String {
        let mut b = [0u8; 1];
        let n = self.tty.read(&mut b).unwrap_or(0);
        if n == 0 { return "eof".into(); }
        if b[0] == 0x1b {
            let mut nxt = [0u8; 1];
            let n = self.tty.read(&mut nxt).unwrap_or(0);
            if n == 0 { return "esc".into(); }
            if nxt[0] != b'[' { return "esc".into(); }
            let mut arrow = [0u8; 1];
            if self.tty.read(&mut arrow).unwrap_or(0) == 0 { return "esc".into(); }
            return match arrow[0] { b'A' => "up", b'B' => "down", b'C' => "right", b'D' => "left", _ => "esc" }.into();
        }
        match b[0] {
            b'\r' | b'\n' => "enter".into(),
            b' ' => "space".into(),
            0x03 => "ctrl-c".into(),
            c => char::from(c).to_string(),
        }
    }
}

impl Drop for Terminal {
    fn drop(&mut self) {
        let _ = self.tty.write_all(b"\x1b[?25h");
        let _ = Command::new("stty").args(["-F", "/dev/tty", &self.saved]).status();
    }
}

fn redraw(height: usize, lines: &[String]) {
    let mut out = std::io::stdout();
    if height > 0 { let _ = write!(out, "\x1b[{height}A\x1b[J"); }
    let _ = writeln!(out, "{}", lines.join("\n"));
    let _ = out.flush();
}

fn select_one(width: usize, title: &str, options: &[(&str, &str, bool)], default: usize) -> Result<usize, String> {
    if options.is_empty() { return Err("select_one needs at least one option".into()); }
    let style = Style { color: env::var_os("NO_COLOR").is_none() };
    let mut term = Terminal::open()?;
    let mut idx = default.min(options.len().saturating_sub(1));
    let mut height = 0;
    loop {
        let lines = menu_block(&style, title, options, idx, &[idx], false, width);
        redraw(height, &lines);
        height = lines.len();
        match term.read_key().as_str() {
            "up" | "k" => idx = (idx + options.len() - 1) % options.len(),
            "down" | "j" => idx = (idx + 1) % options.len(),
            "enter" => {
                redraw(height, &collapsed_block(&style, title, options[idx].0, width));
                return Ok(idx);
            }
            "ctrl-c" | "q" | "eof" => return Err("cancelled".into()),
            _ => {}
        }
    }
}

fn select_many(width: usize, title: &str, options: &[(&str, &str, bool)], preselect: &[usize]) -> Result<Vec<usize>, String> {
    if options.is_empty() { return Ok(Vec::new()); }
    let style = Style { color: env::var_os("NO_COLOR").is_none() };
    let mut term = Terminal::open()?;
    let mut idx = 0usize;
    let mut checked: Vec<usize> = preselect.to_vec();
    let mut height = 0;
    loop {
        let lines = menu_block(&style, title, options, idx, &checked, true, width);
        redraw(height, &lines);
        height = lines.len();
        match term.read_key().as_str() {
            "up" | "k" => idx = (idx + options.len() - 1) % options.len(),
            "down" | "j" => idx = (idx + 1) % options.len(),
            "space" => {
                if let Some(pos) = checked.iter().position(|x| *x == idx) { checked.remove(pos); }
                else { checked.push(idx); checked.sort(); }
            }
            "enter" => {
                let value = if checked.is_empty() { "none".into() } else {
                    checked.iter().map(|i| options[*i].0).collect::<Vec<_>>().join(", ")
                };
                redraw(height, &collapsed_block(&style, title, &value, width));
                return Ok(checked);
            }
            "ctrl-c" | "q" | "eof" => return Err("cancelled".into()),
            _ => {}
        }
    }
}

fn confirm(width: usize, title: &str, summary: &[&str]) -> Result<bool, String> {
    let style = Style { color: env::var_os("NO_COLOR").is_none() };
    let mut term = Terminal::open()?;
    let mut idx = 0usize;
    let mut height = 0;
    loop {
        let lines = confirm_block(&style, title, summary, idx, width);
        redraw(height, &lines);
        height = lines.len();
        match term.read_key().as_str() {
            "up" | "k" | "down" | "j" => idx ^= 1,
            "enter" => {
                redraw(height, &collapsed_block(&style, title, if idx == 0 { "Yes" } else { "No" }, width));
                return Ok(idx == 0);
            }
            "y" => {
                redraw(height, &collapsed_block(&style, title, "Yes", width));
                return Ok(true);
            }
            "n" | "q" | "esc" | "eof" => {
                redraw(height, &collapsed_block(&style, title, "No", width));
                return Ok(false);
            }
            "ctrl-c" => return Err("cancelled".into()),
            _ => {}
        }
    }
}

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut width = 80usize;
    let mut mode = "sample";
    let mut i = 0;
    while i < args.len() {
        if args[i] == "--width" {
            i += 1; width = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(80);
        } else if args[i] == "--demo" {
            mode = "demo";
        }
        i += 1;
    }
    let style = Style { color: env::var_os("NO_COLOR").is_none() };
    if mode == "demo" {
        let opts = [("Quick", "Core defaults, no questions", true), ("Full", "Everything, daily apps too", false)];
        let _ = select_one(width, "Install profile", &opts, 0);
        let apps = [("dolphin", "KDE file manager", false), ("zathura", "PDF viewer", false)];
        let _ = select_many(width, "Optional apps", &apps, &[]);
        let _ = confirm(width, "Ready", &["Install this?"]);
        return;
    }
    print!("{}", sample(&style, width));
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn width_and_brackets() {
        assert_eq!(vis("「x」"), 5);
        let style = Style { color: false };
        assert_eq!(clip(&style, &[(BRIGHT, "abcdef")], 4), "abcd");
    }

    #[test]
    fn wrap_words() {
        assert_eq!(wrap("a b c", 3), vec!["a b", "c"]);
        assert_eq!(wrap("", 10), vec![""]);
    }

    #[test]
    fn banner_marker() {
        let style = Style { color: false };
        assert!(banner(&style, 80).contains("reddot installer"));
    }
}
