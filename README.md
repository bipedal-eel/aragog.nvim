# 🕸️ Aragog.nvim

# TODO freebie-gpt cannot replace human writing

**Aragog** is your faithful eight-legged assistant — a Neovim plugin for fast, intuitive navigation between files, workspaces, and projects.
Inspired by the vast, intelligent web of Aragog and his kin, this plugin lets you spin your own dev ecosystem, jumping from one **Burrow** to another inside your sprawling **Colony**.

> "The spiders fled before me. But Aragog remained."  
> — _Rubeus Hagrid (probably talking about your workflow)_

---

## 🧠 TL;DR

- Organize related workspaces into **Colonies**
- Each **Colony** is made up of individual **Burrows** (workspaces)
- Track and jump to important files (called **Threads**) within a **Burrow**
- (TODO do people need to know this? also atm its json) Persist entire configurations with **Clutches** (a serialized representation of your workspace web)

---

## 🕷️ Why Aragog?

TODO GPT being good at markteting but also at making shit up:

Most project/file nav plugins are like little garden spiders.  
**Aragog** is the king of the Forbidden Forest.

- ⏱️ **Blazingly fast** file jumps within and across projects
- 🧭 **Workspace-level awareness** — not just open files
- 💾 **Persistent layouts** you can re-enter like you never left
- 🌐 **Fully scriptable + Lua-native**
- 🕸️ Built on a web of smart, flexible metaphors

---

## 🌐 Key Concepts

| Concept    | Description                                                   |
| ---------- | ------------------------------------------------------------- |
| **Colony** | A collection of related workspaces (projects)                 |
| **Burrow** | A single workspace within a Colony                            |
| **Thread** | A target file or destination within a Burrow                  |
| **Clutch** | A persisted snapshot of a Colony, including Threads & Burrows |

---

## 📦 Installation

TODO

---

## 🔍 Example Usage

TODO

---

## 🚧 Roadmap

- [ ] Detecting .vscode/\*.workspaces as Colony
- [ ] Fuzzy finder integration (Telescope and or fzf-lua)
- [ ] UI for visualizing Burrows
- [ ] Nesting
- [ ] Logging
