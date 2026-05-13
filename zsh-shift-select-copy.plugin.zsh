#!/usr/bin/env zsh
# zsh-shift-select-copy
#
# Editor-like keyboard text selection with auto-copy for the Zsh command line.
# Select text with Shift+Arrow / Option+Shift+Arrow; selection is automatically
# placed on the system clipboard. Pure zsh, no native dependencies.
#
# Homepage: https://github.com/kcisoul/zsh-shift-select-copy
# Copyright (c) 2026 Myounggeun Yoo
# SPDX-License-Identifier: MIT

# ─── Clipboard backend detection ────────────────────────────────────────
# Detect once at load. Users can override by exporting ZSC_CLIPBOARD_CMD
# (e.g. `export ZSC_CLIPBOARD_CMD='pbcopy'`) before sourcing.

if [[ -z "${ZSC_CLIPBOARD_CMD-}" ]]; then
    if [[ "$OSTYPE" == darwin* ]] && (( ${+commands[pbcopy]} )); then
        typeset -g ZSC_CLIPBOARD_CMD='pbcopy'
    elif [[ -n "${WAYLAND_DISPLAY-}" ]] && (( ${+commands[wl-copy]} )); then
        typeset -g ZSC_CLIPBOARD_CMD='wl-copy'
    elif (( ${+commands[xclip]} )); then
        typeset -g ZSC_CLIPBOARD_CMD='xclip -selection clipboard -in'
    elif (( ${+commands[xsel]} )); then
        typeset -g ZSC_CLIPBOARD_CMD='xsel --clipboard --input'
    elif (( ${+commands[clip.exe]} )); then
        typeset -g ZSC_CLIPBOARD_CMD='clip.exe'
    else
        typeset -g ZSC_CLIPBOARD_CMD=''
    fi
fi

# Auto-copy on every selection change. Set to 0 to disable.
: ${ZSC_AUTO_COPY:=1}

# ─── Widgets ────────────────────────────────────────────────────────────

# Push the active region to the system clipboard.
function zsc::copy-region() {
    (( ZSC_AUTO_COPY )) || return 0
    [[ -z "$ZSC_CLIPBOARD_CMD" ]] && return 0
    (( REGION_ACTIVE )) || return 0
    local lo hi
    if (( MARK <= CURSOR )); then
        lo=$MARK; hi=$CURSOR
    else
        lo=$CURSOR; hi=$MARK
    fi
    (( lo == hi )) && return 0
    print -nr -- "${BUFFER[lo+1,hi]}" | eval "$ZSC_CLIPBOARD_CMD"
}

# Move cursor to end-of-buffer (avoids the default's history-cycling fallback).
function zsc::end-of-buffer() {
    CURSOR=${#BUFFER}
    zle end-of-line -w
}
zle -N zsc::end-of-buffer

function zsc::beginning-of-buffer() {
    CURSOR=0
    zle beginning-of-line -w
}
zle -N zsc::beginning-of-buffer

# Delete the selected region and return to the main keymap.
function zsc::kill-region() {
    zle kill-region -w
    zle -K main
}
zle -N zsc::kill-region

# Non-printable / unbound key while a selection is active: deactivate the
# region, switch back to main keymap, and re-feed the key so the user's
# normal binding fires (e.g. Ctrl+W → backward-kill-word).
function zsc::deselect-and-input() {
    zle deactivate-region -w
    zle -K main
    zle -U "$KEYS"
}
zle -N zsc::deselect-and-input

# Printable character while a selection is active: replace the selection
# (kill the region) then re-feed the typed character into the main keymap
# so it is inserted normally — text-editor type-to-replace behavior.
function zsc::replace-selection() {
    zle kill-region -w
    zle -K main
    zle -U "$KEYS"
}
zle -N zsc::replace-selection

# Dispatch a Shift+motion: enter shift-select keymap on first motion, run
# the underlying motion widget, then auto-copy the resulting selection.
function zsc::select-and-invoke() {
    if (( !REGION_ACTIVE )); then
        zle set-mark-command -w
        zle -K zsc-select
    fi
    zle ${WIDGET#zsc::} -w
    zsc::copy-region
}

# ─── Keymap setup ───────────────────────────────────────────────────────

function {
    emulate -L zsh

    bindkey -N zsc-select

    # In the shift-select keymap, any single key falls back to deselect.
    # Printable chars get overridden below to replace-selection.
    bindkey -M zsc-select -R '^@'-'^?' zsc::deselect-and-input
    bindkey -M zsc-select -R ' '-'~'   zsc::replace-selection

    local kcap seq seq_mac widget

    # Shift+arrow / Shift+Home/End: char and line motions.
    # Shift+Ctrl+arrow on Linux/WSL == Shift+Option+arrow on macOS: word motions.
    for kcap   seq          seq_mac    widget (
        kLFT   '^[[1;2D'    x          backward-char
        kRIT   '^[[1;2C'    x          forward-char
        kri    '^[[1;2A'    x          up-line
        kind   '^[[1;2B'    x          down-line
        kHOM   '^[[1;2H'    x          beginning-of-line
        kEND   '^[[1;2F'    x          end-of-line
        x      '^[[1;6D'    '^[[1;4D'  backward-word
        x      '^[[1;6C'    '^[[1;4C'  forward-word
        x      '^[[1;6H'    '^[[1;4H'  zsc::beginning-of-buffer
        x      '^[[1;6F'    '^[[1;4F'  zsc::end-of-buffer
    ); do
        [[ "$OSTYPE" == darwin* && "$seq_mac" != x ]] && seq=$seq_mac
        zle -N zsc::$widget zsc::select-and-invoke
        bindkey -M emacs       ${terminfo[$kcap]:-$seq} zsc::$widget
        bindkey -M zsc-select  ${terminfo[$kcap]:-$seq} zsc::$widget
    done

    # Inside the selection: Delete / Backspace kill the region.
    for kcap   seq        widget (
        kdch1  '^[[3~'    zsc::kill-region
        bs     '^?'       zsc::kill-region
    ); do
        bindkey -M zsc-select ${terminfo[$kcap]:-$seq} $widget
    done

    # Cursor motion without selection — pairs with the shift-select bindings
    # above so Opt+Arrow moves by word and Cmd+Arrow moves to line edge
    # (macOS), Ctrl+Arrow moves by word (Linux/WSL).
    if [[ "$OSTYPE" == darwin* ]]; then
        bindkey -M emacs '^[[1;3D' backward-word
        bindkey -M emacs '^[[1;3C' forward-word
        bindkey -M emacs '^[[1;9D' beginning-of-line
        bindkey -M emacs '^[[1;9C' end-of-line
    else
        bindkey -M emacs '^[[1;5D' backward-word
        bindkey -M emacs '^[[1;5C' forward-word
    fi
}
