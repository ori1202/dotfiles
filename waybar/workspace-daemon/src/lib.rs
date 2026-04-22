//! Library root: shared Hyprland helpers, optional CFFI Waybar module (`libwaybar_hypr_ws.so`).

pub mod abbrev;
pub mod hypr_common;

use hypr_common::{build_tab_rows, ensure_hypr_env, hypr_state};
use hyprland::dispatch::{Dispatch, DispatchType, WorkspaceIdentifierWithSpecial};
use hyprland::event_listener::EventListener;
use serde::Deserialize;
use std::thread;
use std::time::Duration;
use waybar_cffi::{
    gtk::{
        glib,
        prelude::{ButtonExt, ContainerExt, LabelExt, WidgetExt},
        traits::StyleContextExt,
        Box as GtkBox, Button, Label, Orientation,
    },
    waybar_module, InitInfo, Module,
};

const DEFAULT_MAX_TABS: usize = 16;
const POLL_MS: u64 = 10000;

#[derive(Deserialize, Default)]
pub struct UserConfig {
    /// Maximum workspace tabs (matches former `custom/ws-*` slot count).
    #[serde(default = "default_max_tabs", rename = "max-tabs")]
    pub max_tabs: usize,
}

fn default_max_tabs() -> usize {
    DEFAULT_MAX_TABS
}

pub struct HyprWorkspaceTabs;

impl Module for HyprWorkspaceTabs {
    type Config = UserConfig;

    fn init(info: &InitInfo, config: UserConfig) -> Self {
        let max_tabs = config.max_tabs.max(1);
        let root = info.get_root_widget();
        let container = GtkBox::new(Orientation::Horizontal, 0);
        container.set_widget_name("hypr-workspace-tabs");
        root.add(&container);

        let (tx, rx) = async_channel::unbounded();

        thread::spawn({
            let tx = tx.clone();
            move || hypr_listener_loop(tx, max_tabs)
        });

        thread::spawn({
            let tx = tx.clone();
            move || loop {
                thread::sleep(Duration::from_millis(POLL_MS));
                push_rows(&tx, max_tabs);
            }
        });

        push_rows(&tx, max_tabs);

        let container = container.clone();
        let ctx = glib::MainContext::default();
        ctx.spawn_local(async move {
            while let Ok(rows) = rx.recv().await {
                while rx.try_recv().is_ok() {}
                rebuild_tabs(&container, rows);
            }
        });

        Self {}
    }
}

waybar_module!(HyprWorkspaceTabs);

fn push_rows(tx: &async_channel::Sender<Vec<hypr_common::TabRow>>, max: usize) {
    if ensure_hypr_env().is_err() {
        return;
    }
    match hypr_state() {
        Ok((active, list)) => {
            let rows = build_tab_rows(&active, &list, max);
            let _ = tx.send_blocking(rows);
        }
        Err(e) => {
            eprintln!("waybar-hypr-ws (cffi): hypr_state failed: {e}");
        }
    }
}

fn hypr_listener_loop(tx: async_channel::Sender<Vec<hypr_common::TabRow>>, max: usize) {
    loop {
        if ensure_hypr_env().is_err() {
            thread::sleep(Duration::from_secs(2));
            continue;
        }
        push_rows(&tx, max);
        let mut el = EventListener::new();
        let t = tx.clone();
        el.add_workspace_changed_handler(move |_| push_rows(&t, max));
        let t = tx.clone();
        el.add_active_window_changed_handler(move |_| push_rows(&t, max));
        let t = tx.clone();
        el.add_window_title_changed_handler(move |_| push_rows(&t, max));
        let t = tx.clone();
        el.add_window_opened_handler(move |_| push_rows(&t, max));
        let t = tx.clone();
        el.add_window_closed_handler(move |_| push_rows(&t, max));
        let t = tx.clone();
        el.add_window_moved_handler(move |_| push_rows(&t, max));
        let t = tx.clone();
        el.add_active_monitor_changed_handler(move |_| push_rows(&t, max));
        let t = tx.clone();
        el.add_workspace_renamed_handler(move |_| push_rows(&t, max));

        if let Err(e) = el.start_listener() {
            eprintln!("waybar-hypr-ws (cffi): EventListener: {e}");
            std::env::remove_var("HYPRLAND_INSTANCE_SIGNATURE");
            thread::sleep(Duration::from_secs(1));
        }
    }
}

fn rebuild_tabs(container: &GtkBox, rows: Vec<hypr_common::TabRow>) {
    for child in container.children() {
        container.remove(&child);
    }

    for row in rows {
        let label = Label::new(None);
        let esc = glib::markup_escape_text(&row.label);
        label.set_markup(&esc);

        let button = Button::new();
        button.add(&label);
        button.set_tooltip_text(Some(&row.tooltip));

        let style = button.style_context();
        style.add_class("workspace-tab");
        if row.active {
            style.add_class("workspace-tab-active");
        } else {
            style.remove_class("workspace-tab-active");
        }

        let wid = row.workspace_id;
        button.connect_clicked(move |_| {
            thread::spawn(move || {
                if ensure_hypr_env().is_err() {
                    return;
                }
                let _ = Dispatch::call(DispatchType::Workspace(
                    WorkspaceIdentifierWithSpecial::Id(wid),
                ));
            });
        });

        container.add(&button);
    }
    container.show_all();
}
