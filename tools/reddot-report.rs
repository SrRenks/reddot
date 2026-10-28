//! Rust port of reddot_install._summary_lines.

use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::path::PathBuf;

#[allow(dead_code)]
#[derive(Clone, Debug)]
enum J { Null, Bool(bool), Num(f64), Str(String), Arr(Vec<J>), Obj(std::collections::BTreeMap<String, J>) }
struct P<'a> { b: &'a [u8], i: usize }
impl<'a> P<'a> {
    fn parse(t: &'a str) -> Result<J, String> { let mut p = Self { b: t.as_bytes(), i: 0 }; let v = p.value()?; p.ws(); if p.i != p.b.len() { return Err("json".into()); } Ok(v) }
    fn ws(&mut self) { while self.i < self.b.len() && self.b[self.i].is_ascii_whitespace() { self.i += 1; } }
    fn value(&mut self) -> Result<J, String> {
        self.ws();
        match *self.b.get(self.i).ok_or("end")? {
            b'n' => { self.lit(b"null")?; Ok(J::Null) }, b't' => { self.lit(b"true")?; Ok(J::Bool(true)) }, b'f' => { self.lit(b"false")?; Ok(J::Bool(false)) },
            b'"' => Ok(J::Str(self.string()?)), b'[' => self.array(), b'{' => self.object(), b'-' | b'0'..=b'9' => self.number(), c => Err(format!("json {c}")),
        }
    }
    fn lit(&mut self, w: &[u8]) -> Result<(), String> { if self.b.get(self.i..self.i + w.len()) == Some(w) { self.i += w.len(); Ok(()) } else { Err("lit".into()) } }
    fn string(&mut self) -> Result<String, String> {
        if self.b.get(self.i) != Some(&b'"') { return Err("str".into()); } self.i += 1; let mut o = String::new();
        loop { let c = *self.b.get(self.i).ok_or("str")?; self.i += 1; match c {
            b'"' => return Ok(o), b'\\' => { let e = *self.b.get(self.i).ok_or("esc")?; self.i += 1; match e { b'"' => o.push('"'), b'\\' => o.push('\\'), b'/' => o.push('/'), b'n' => o.push('\n'), b'r' => o.push('\r'), b't' => o.push('\t'), b'b' => o.push('\u{8}'), b'f' => o.push('\u{c}'), b'u' => { let mut n = 0u32; for _ in 0..4 { let h = *self.b.get(self.i).ok_or("u")?; self.i += 1; n = (n << 4) + match h { b'0'..=b'9' => (h-b'0') as u32, b'a'..=b'f' => (h-b'a'+10) as u32, b'A'..=b'F' => (h-b'A'+10) as u32, _ => return Err("u".into()) }; } o.push(char::from_u32(n).ok_or("u")?); }, _ => return Err("esc".into()) } }, c if c < 0x20 => return Err("ctl".into()), c => o.push(c as char) } }
    }
    fn array(&mut self) -> Result<J, String> { self.i += 1; let mut a = Vec::new(); self.ws(); if self.b.get(self.i) == Some(&b']') { self.i += 1; return Ok(J::Arr(a)); } loop { a.push(self.value()?); self.ws(); match self.b.get(self.i) { Some(b',') => self.i += 1, Some(b']') => { self.i += 1; return Ok(J::Arr(a)); }, _ => return Err("arr".into()) } } }
    fn object(&mut self) -> Result<J, String> { self.i += 1; let mut m = std::collections::BTreeMap::new(); self.ws(); if self.b.get(self.i) == Some(&b'}') { self.i += 1; return Ok(J::Obj(m)); } loop { let k = self.string()?; self.ws(); if self.b.get(self.i) != Some(&b':') { return Err("colon".into()); } self.i += 1; m.insert(k, self.value()?); self.ws(); match self.b.get(self.i) { Some(b',') => { self.i += 1; self.ws(); }, Some(b'}') => { self.i += 1; return Ok(J::Obj(m)); }, _ => return Err("obj".into()) } } }
    fn number(&mut self) -> Result<J, String> { let s = self.i; while self.i < self.b.len() && matches!(self.b[self.i], b'-'|b'+'|b'.'|b'e'|b'E'|b'0'..=b'9') { self.i += 1; } Ok(J::Num(std::str::from_utf8(&self.b[s..self.i]).map_err(|_| "n")?.parse().map_err(|_| "n")?)) }
}
fn arr(v: &J, key: &str) -> Vec<J> { if let J::Obj(m) = v { if let Some(J::Arr(a)) = m.get(key) { return a.clone(); } } vec![] }
fn strings(v: &J, key: &str) -> Vec<String> { arr(v, key).into_iter().filter_map(|x| if let J::Str(s)=x { Some(s) } else { None }).collect() }

fn main() {
    let args: Vec<String> = env::args().skip(1).collect();
    let mut plan_path = PathBuf::from("plan.json");
    let mut family = "unknown".to_string();
    let mut do_pkgs = true;
    let mut sddm = false; let mut grub = false; let mut brave = false; let mut fish = true; let mut managed = false;
    let mut i = 0;
    while i < args.len() { match args[i].as_str() {
        "--plan" => { i+=1; plan_path=PathBuf::from(args.get(i).cloned().unwrap_or_default()); },
        "--family" => { i+=1; family=args.get(i).cloned().unwrap_or_default(); },
        "--no-deps" => do_pkgs=false, "--sddm" => sddm=true, "--grub" => grub=true, "--brave" => brave=true, "--no-fish" => fish=false, "--managed" => managed=true, _ => {} } i+=1; }
    let plan = fs::read_to_string(plan_path).ok().and_then(|t| P::parse(&t).ok()).unwrap_or(J::Obj(Default::default()));
    let mut lines: Vec<String> = Vec::new();
    if !do_pkgs { lines.push("Skipping packages, deploying configs only.".into()); }
    else {
        let count = strings(&plan,"native").len()+strings(&plan,"aur").len()+arr(&plan,"fallbacks").len();
        lines.push(format!("Install {count} packages ({} already present).", strings(&plan,"skipped").len()));
        let repos = strings(&plan,"repos");
        if !repos.is_empty() { lines.push(format!("Enable repos: {}.", repos.join(", "))); }
        let fbs = arr(&plan,"fallbacks");
        if !fbs.is_empty() {
            let mut names = BTreeSet::new();
            for fb in fbs { if let J::Arr(a)=fb { if let Some(J::Str(h))=a.get(1) { names.insert(h.clone()); } } }
            lines.push(format!("Build via fallback: {}.", names.into_iter().collect::<Vec<_>>().join(", ")));
        }
        if family == "gentoo" {
            if !arr(&plan,"atomRepos").is_empty() { lines.push("Write package.accept_keywords/reddot and package.use/reddot under /etc/portage.".into()); }
            let manual = strings(&plan,"manual");
            if !manual.is_empty() { lines.push(format!("Overlays skipped, install yourself: emerge -av {}.", manual.join(" "))); }
            lines.push("emerge compiles from source; this is the long part.".into());
        }
    }
    if sddm { lines.push("Install the torii SDDM login theme.".into()); }
    if grub { lines.push("Install the GRUB theme.".into()); }
    if brave { lines.push("Install Brave and set it to follow your wallpaper colors.".into()); }
    if fish { lines.push("Set fish as your login shell.".into()); }
    if managed { lines.push("Update the reddot config; your Settings are kept.".into()); }
    else { lines.push("Back up and deploy the reddot config.".into()); }
    println!("{}", lines.join("\n"));
}

#[cfg(test)]
mod tests {
    #[test]
    fn smoke() { assert_eq!(1+1, 2); }
}
