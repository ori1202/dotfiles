//! Port of workspace_slot.py abbreviation rules.

use regex::Regex;
use std::sync::LazyLock;

const MAX_LEN: usize = 48;

static ALNUM_RUNS: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"[0-9]+|[A-Za-z]+").expect("regex"));

static CAMEL_GAP: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"([a-z])([A-Z])").expect("regex"));

fn sigil_from_chunk(p: &str) -> String {
    let segs: Vec<&str> = ALNUM_RUNS.find_iter(p).map(|m| m.as_str()).collect();
    if segs.is_empty() {
        return p.chars().next().map(|c| c.to_uppercase().to_string()).unwrap_or_default();
    }
    let mut out = String::new();
    for seg in segs {
        if seg.chars().all(|c| c.is_ascii_digit()) {
            out.push_str(seg);
        } else if seg.chars().all(|c| c.is_ascii_alphabetic() && c.is_ascii_uppercase()) {
            if seg.len() <= 4 {
                out.push_str(seg);
            } else {
                out.push(seg.chars().next().unwrap_or(' '));
            }
        } else if let Some(c) = seg.chars().next() {
            if c.is_alphabetic() {
                out.push(c.to_ascii_uppercase());
            } else {
                out.push(c);
            }
        }
    }
    out
}

fn abbrev_delimited(s: &str, delim: char) -> Option<String> {
    let parts: Vec<String> = s
        .split(delim)
        .map(|p| p.trim().to_string())
        .filter(|p| !p.is_empty())
        .collect();
    if parts.len() < 2 {
        return None;
    }
    let first = &parts[0];
    let mut it = first.chars();
    let fc = it.next()?;
    if fc.is_lowercase() {
        let rest_after_first: String = it.collect();
        let mut out = String::new();
        out.push(fc);
        for m in ALNUM_RUNS.find_iter(&rest_after_first) {
            let seg = m.as_str();
            if seg.chars().all(|c| c.is_ascii_digit()) {
                out.push_str(seg);
            }
        }
        for p in &parts[1..] {
            out.push_str(p);
        }
        return Some(out);
    }
    Some(parts.iter().map(|p| sigil_from_chunk(p)).collect())
}

fn from_alnum_runs_whole(s: &str) -> Option<String> {
    let bumped = CAMEL_GAP.replace_all(s, "${1} ${2}");
    let segs: Vec<&str> = ALNUM_RUNS
        .find_iter(bumped.as_ref())
        .map(|m| m.as_str())
        .collect();
    if segs.len() < 2 {
        return None;
    }
    let mut out = String::new();
    for seg in segs {
        if seg.chars().all(|c| c.is_ascii_digit()) {
            out.push_str(seg);
        } else if seg.chars().all(|c| c.is_ascii_alphabetic() && c.is_ascii_uppercase()) {
            if seg.len() <= 4 {
                out.push_str(seg);
            } else {
                out.push(seg.chars().next().unwrap_or(' '));
            }
        } else if let Some(c) = seg.chars().next() {
            if c.is_alphabetic() {
                if c.is_uppercase() {
                    out.push(c);
                } else {
                    out.push(c.to_ascii_lowercase());
                }
            } else {
                out.push(c);
            }
        }
    }
    Some(out)
}

pub fn abbreviate_title(title: &str) -> String {
    let s = title.trim();
    if s.is_empty() {
        return String::new();
    }
    if s.contains('-') {
        if let Some(got) = abbrev_delimited(s, '-') {
            return got;
        }
    }
    if s.contains(' ') {
        if let Some(got) = abbrev_delimited(s, ' ') {
            return got;
        }
    }
    if let Some(got) = from_alnum_runs_whole(s) {
        return got;
    }
    let alpha: String = s.chars().filter(|c| c.is_alphanumeric()).collect();
    if alpha.len() >= 4 {
        let all_lower = alpha
            .chars()
            .all(|c| !c.is_alphabetic() || c.is_lowercase());
        if all_lower {
            let mid = (alpha.len() + 1) / 2;
            let mut r = String::new();
            if let Some(c) = alpha.chars().next() {
                r.push(c);
            }
            r.push_str(&alpha[mid..]);
            return r;
        }
    }
    let caps: String = s.chars().filter(|c| c.is_uppercase()).collect();
    if caps.len() == 1 && s.len() > 1 {
        let take = 4.min(s.len());
        return s[..take].to_string();
    }
    s.to_string()
}

pub fn truncate_label(s: &str) -> String {
    if s.len() <= MAX_LEN {
        s.to_string()
    } else {
        let mut t: String = s.chars().take(MAX_LEN - 1).collect();
        t.push('…');
        t
    }
}
