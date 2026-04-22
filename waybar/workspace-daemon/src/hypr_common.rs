//! Shared Hyprland queries and per-tab labels for the CLI daemon and the CFFI module.

use crate::abbrev::{abbreviate_title, truncate_label};
use hyprland::data::{Workspace as HLWorkspace, Workspaces};
use hyprland::prelude::*;
use std::fs;
use std::path::PathBuf;

pub const EMPTY: &str = "—";

#[derive(Debug, Clone)]
pub struct TabRow {
    pub workspace_id: i32,
    pub label: String,
    pub tooltip: String,
    pub active: bool,
}

/// Hyprland sockets live under $XDG_RUNTIME_DIR/hypr/<sig>/ (not always in the shell env).
pub fn discover_hypr_instance_sig() -> Option<String> {
    let uid = unsafe { libc::getuid() };
    let run_user = PathBuf::from(format!("/run/user/{uid}"));
    for base in [
        std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from),
        Some(run_user),
        Some(PathBuf::from("/tmp")),
    ]
    .into_iter()
    .flatten()
    {
        let hypr = base.join("hypr");
        let Ok(entries) = fs::read_dir(&hypr) else {
            continue;
        };
        for e in entries.flatten() {
            let p = e.path();
            if p.join(".socket.sock").exists() {
                return e.file_name().to_str().map(|s| s.to_string());
            }
        }
    }
    None
}

pub fn ensure_hypr_env() -> Result<(), String> {
    if std::env::var("HYPRLAND_INSTANCE_SIGNATURE").is_ok() {
        return Ok(());
    }
    let sig = discover_hypr_instance_sig().ok_or_else(|| {
        "HYPRLAND_INSTANCE_SIGNATURE is unset and no Hyprland .socket.sock was found under \
         $XDG_RUNTIME_DIR/hypr or /tmp/hypr. Run from a Hyprland session, or export the variable."
            .to_string()
    })?;
    std::env::set_var("HYPRLAND_INSTANCE_SIGNATURE", &sig);
    Ok(())
}

pub fn hypr_state() -> hyprland::Result<(HLWorkspace, Vec<HLWorkspace>)> {
    let active = HLWorkspace::get_active()?;
    let mut list = Workspaces::get()?.to_vec();
    list.retain(|w| !w.name.starts_with("special:"));
    list.sort_by(|a, b| a.id.cmp(&b.id).then_with(|| a.name.cmp(&b.name)));
    Ok((active, list))
}

pub fn build_tab_rows(active: &HLWorkspace, ws: &[HLWorkspace], max: usize) -> Vec<TabRow> {
    let active_id = active.id;
    let n = max.min(ws.len());
    let mut out = Vec::with_capacity(n);
    for i in 0..n {
        let w = &ws[i];
        let title = w.last_window_title.trim();
        let inner = if w.windows == 0 || title.is_empty() {
            EMPTY.to_string()
        } else {
            truncate_label(&abbreviate_title(title))
        };
        let label = if i > 0 {
            format!(" · {inner}")
        } else {
            inner
        };
        let tip = format!(
            "{}: {}",
            w.name,
            if title.is_empty() {
                "(no title)"
            } else {
                title
            }
        );
        out.push(TabRow {
            workspace_id: w.id,
            label,
            tooltip: tip,
            active: active_id == w.id,
        });
    }
    out
}
