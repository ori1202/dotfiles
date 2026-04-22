//! CLI: optional cache daemon + `focus` / `refresh` for legacy custom-module setups.

use hyprland::data::Workspace as HLWorkspace;
use hyprland::dispatch::{Dispatch, DispatchType, WorkspaceIdentifierWithSpecial};
use hyprland::event_listener::EventListener;
use serde_json::json;
use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::path::PathBuf;
use std::process::Command;
use std::sync::mpsc;
use std::sync::Mutex;
use std::thread;
use std::time::Duration;
use waybar_hypr_ws::hypr_common::{build_tab_rows, ensure_hypr_env, hypr_state, TabRow};

const SLOTS: usize = 16;
const WAYBAR_SIGNAL_NUM: i32 = 42;
const DEFAULT_POLL_MS: u64 = 10000;

static LAST_FINGERPRINT: Mutex<Option<u64>> = Mutex::new(None);
static LAST_HYPR_ERR_LOG: Mutex<Option<std::time::Instant>> = Mutex::new(None);

fn cache_dir() -> PathBuf {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".cache")))
        .unwrap_or_else(|| PathBuf::from("/tmp"));
    base.join("waybar-hypr-slots")
}

fn pids_comm_named(name: &str) -> Vec<libc::pid_t> {
    let mut out = Vec::new();
    let Ok(entries) = fs::read_dir("/proc") else {
        return out;
    };
    for e in entries.flatten() {
        let fname = e.file_name();
        let s = fname.to_string_lossy();
        if !s.chars().all(|c| c.is_ascii_digit()) {
            continue;
        }
        let comm_path = e.path().join("comm");
        let Ok(comm) = fs::read_to_string(&comm_path) else {
            continue;
        };
        if comm.trim_end() == name {
            if let Ok(pid) = s.parse::<libc::pid_t>() {
                out.push(pid);
            }
        }
    }
    out
}

fn signal_waybar(offset: i32) -> Vec<String> {
    let sig = libc::SIGRTMIN() + offset;
    let mut pids = pids_comm_named("waybar");
    if pids.is_empty() {
        let Ok(po) = Command::new("pidof").arg("waybar").output() else {
            return Vec::new();
        };
        if po.status.success() {
            pids = String::from_utf8_lossy(&po.stdout)
                .split_whitespace()
                .filter_map(|s| s.parse::<libc::pid_t>().ok())
                .collect();
        }
    }
    let mut seen = std::collections::HashSet::new();
    pids.retain(|p| seen.insert(*p));
    for pid in &pids {
        unsafe {
            libc::kill(*pid, sig);
        }
    }
    pids.iter().map(|p| p.to_string()).collect()
}

fn fingerprint(active_id: i32, ws: &[HLWorkspace]) -> u64 {
    let mut h = DefaultHasher::new();
    active_id.hash(&mut h);
    for w in ws {
        w.id.hash(&mut h);
        w.windows.hash(&mut h);
        w.last_window_title.hash(&mut h);
    }
    h.finish()
}

fn row_to_json(row: &TabRow) -> serde_json::Value {
    let mut classes = vec!["workspace-tab".to_string()];
    if row.active {
        classes.push("workspace-tab-active".to_string());
    }
    json!({
        "text": row.label,
        "tooltip": row.tooltip,
        "class": classes,
    })
}

fn write_slots_and_signal(active: &HLWorkspace, ws: &[HLWorkspace]) -> Vec<String> {
    let dir = cache_dir();
    let _ = fs::create_dir_all(&dir);
    let rows = build_tab_rows(active, ws, SLOTS);

    for i in 0..SLOTS {
        let path = dir.join(format!("{i}.json"));
        let json_val = if let Some(row) = rows.get(i) {
            row_to_json(row)
        } else {
            json!({"text": ""})
        };
        if let Ok(s) = serde_json::to_string(&json_val) {
            let _ = fs::write(&path, s);
        }
    }
    signal_waybar(WAYBAR_SIGNAL_NUM)
}

fn log_hypr_state_err_throttled(err: impl std::fmt::Display) {
    const HYPR_ERR_LOG_GAP: std::time::Duration = std::time::Duration::from_secs(30);
    let now = std::time::Instant::now();
    let mut slot = LAST_HYPR_ERR_LOG.lock().unwrap();
    if slot.map_or(true, |t| now.duration_since(t) >= HYPR_ERR_LOG_GAP) {
        eprintln!("waybar-hypr-ws: hypr_state failed (tabs will stay stale): {err}");
        *slot = Some(now);
    }
}

fn refresh_if_changed() {
    if ensure_hypr_env().is_err() {
        return;
    }
    let (active, list) = match hypr_state() {
        Ok(x) => x,
        Err(e) => {
            log_hypr_state_err_throttled(e);
            return;
        }
    };
    let fp = fingerprint(active.id, &list);
    let mut guard = LAST_FINGERPRINT.lock().unwrap();
    if *guard == Some(fp) {
        return;
    }
    *guard = Some(fp);
    drop(guard);
    write_slots_and_signal(&active, &list);
}

fn refresh_force_report(verbose: bool) -> Result<(), String> {
    ensure_hypr_env()?;
    let (active, list) = hypr_state().map_err(|e| e.to_string())?;
    let fp = fingerprint(active.id, &list);
    *LAST_FINGERPRINT.lock().unwrap() = Some(fp);
    let pids = write_slots_and_signal(&active, &list);
    if verbose {
        eprintln!(
            "waybar-hypr-ws: wrote {} slot file(s) under {}",
            SLOTS,
            cache_dir().display()
        );
        if pids.is_empty() {
            eprintln!("waybar-hypr-ws: no waybar PIDs from pidof (SIGRTMIN+{WAYBAR_SIGNAL_NUM} skipped)");
        } else {
            eprintln!(
                "waybar-hypr-ws: signaled waybar PIDs {} (SIGRTMIN+{WAYBAR_SIGNAL_NUM})",
                pids.join(" ")
            );
        }
    }
    Ok(())
}

fn spawn_hypr_event_poker(tx: mpsc::Sender<()>) {
    thread::spawn(move || loop {
        let mut el = EventListener::new();
        let t = tx.clone();
        el.add_workspace_changed_handler(move |_| {
            let _ = t.send(());
        });
        let t = tx.clone();
        el.add_active_window_changed_handler(move |_| {
            let _ = t.send(());
        });
        let t = tx.clone();
        el.add_window_title_changed_handler(move |_| {
            let _ = t.send(());
        });
        let t = tx.clone();
        el.add_window_opened_handler(move |_| {
            let _ = t.send(());
        });
        let t = tx.clone();
        el.add_window_closed_handler(move |_| {
            let _ = t.send(());
        });
        let t = tx.clone();
        el.add_window_moved_handler(move |_| {
            let _ = t.send(());
        });
        let t = tx.clone();
        el.add_active_monitor_changed_handler(move |_| {
            let _ = t.send(());
        });
        let t = tx.clone();
        el.add_workspace_renamed_handler(move |_| {
            let _ = t.send(());
        });

        if let Err(e) = el.start_listener() {
            eprintln!("waybar-hypr-ws: hyprland EventListener: {e}");
            std::env::remove_var("HYPRLAND_INSTANCE_SIGNATURE");
            thread::sleep(Duration::from_secs(1));
        }
    });
}

fn run_daemon() {
    loop {
        match ensure_hypr_env() {
            Ok(()) => break,
            Err(e) => {
                eprintln!("waybar-hypr-ws: {e}");
                eprintln!("waybar-hypr-ws: retrying in 2s…");
                thread::sleep(Duration::from_secs(2));
            }
        }
    }

    let _ = fs::create_dir_all(cache_dir());
    if let Err(e) = refresh_force_report(false) {
        eprintln!("waybar-hypr-ws: initial refresh failed: {e}");
    }

    let (tx, rx) = mpsc::channel::<()>();
    spawn_hypr_event_poker(tx.clone());

    let poll_ms = std::env::var("WAYBAR_HYPR_WS_POLL_MS")
        .ok()
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(DEFAULT_POLL_MS);
    if poll_ms > 0 {
        let tx_poll = tx.clone();
        thread::spawn(move || loop {
            thread::sleep(Duration::from_millis(poll_ms));
            let _ = tx_poll.send(());
        });
    }

    loop {
        let _ = rx.recv();
        while rx.try_recv().is_ok() {}
        thread::sleep(Duration::from_millis(50));
        while rx.try_recv().is_ok() {}
        refresh_if_changed();
    }
}

fn focus_slot(slot: usize) -> Result<(), String> {
    ensure_hypr_env()?;
    let (_, list) = hypr_state().map_err(|e| e.to_string())?;
    if slot >= list.len() {
        return Err(format!(
            "focus: slot {slot} out of range ({} workspaces)",
            list.len()
        ));
    }
    let id = list[slot].id;
    Dispatch::call(DispatchType::Workspace(WorkspaceIdentifierWithSpecial::Id(id)))
        .map_err(|e| e.to_string())?;
    let _ = refresh_force_report(false);
    Ok(())
}

fn print_usage() {
    eprintln!("usage: waybar-hypr-ws daemon | focus <n> | refresh");
}

fn main() {
    let mut args = std::env::args().skip(1);
    match args.next().as_deref() {
        Some("daemon") => run_daemon(),
        Some("focus") => {
            if let Some(s) = args.next() {
                if let Ok(i) = s.parse::<usize>() {
                    if let Err(e) = focus_slot(i) {
                        eprintln!("waybar-hypr-ws: {e}");
                        std::process::exit(1);
                    }
                    return;
                }
            }
            print_usage();
            std::process::exit(2);
        }
        Some("refresh") => {
            if let Err(e) = refresh_force_report(true) {
                eprintln!("waybar-hypr-ws: refresh failed: {e}");
                std::process::exit(1);
            }
        }
        _ => {
            print_usage();
            std::process::exit(2);
        }
    }
}
