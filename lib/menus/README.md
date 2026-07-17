# Modular Menu System

Each file exports menu display + handler functions.
`rhoai-toolkit.sh` sources these and runs `main_menu_loop`.

## Structure

| File | Purpose |
|------|---------|
| `commands.sh` | Flat command-mode registry (`./rhoai-toolkit.sh <cmd>`) |
| `day2.sh` | Day 2 operations (CSR approval, kubeadmin removal) |
| `display.sh` | Banner, all menu displays, print helpers |
| `gpu.sh` | GPU & ClusterPolicy management menu |
| `install.sh` | Installation menu handlers |
| `kubeconfig.sh` | Kubeconfig management menu |
| `mcp.sh` | MCP server management menu |
| `models.sh` | Model storage & deployment interactive wrappers |
| `rhoai-management.sh` | RHOAI Management top-level menu + submenus |
| `troubleshooting.sh` | Troubleshooting & fixes menu |
| `workshop.sh` | Workshop setup menu |

## Command Mode

`./rhoai-toolkit.sh <command> [args]` bypasses the menu system entirely.
Commands are registered in `commands.sh`.
