//! Rust port of the rendering half of installer/tui.py.
//! Input/raw-terminal handling is a separate phase. Output is deterministic for a
//! fixed width, which is what the parity test compares.

use std::env;

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

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut width = 80usize;
    let mut i = 0;
    while i < args.len() {
        if args[i] == "--width" { i += 1; width = args.get(i).and_then(|s| s.parse().ok()).unwrap_or(80); }
        i += 1;
    }
    let style = Style { color: env::var_os("NO_COLOR").is_none() };
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
