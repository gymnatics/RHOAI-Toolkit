# Modular Menu System

Each file exports menu display + handler functions.
`rhoai-toolkit.sh` sources these and runs `main_menu_loop`.

## Structure

| File | Menu | Functions |
|------|------|-----------|
| `main.sh` | Main Menu | `show_main_menu`, `main_menu_loop` |
| `management.sh` | RHOAI Management | `show_rhoai_management_menu`, `rhoai_management_menu` |
| `models.sh` | Model Management | `show_model_management_submenu`, `model_management_submenu` |
| `services.sh` | AI Services | `show_ai_services_submenu`, `ai_services_submenu` |
| `demos.sh` | Demos | `show_demos_submenu`, `demos_submenu` |
| `gpu.sh` | GPU & ClusterPolicy | `show_gpu_clusterpolicy_menu`, `gpu_clusterpolicy_menu` |
| `troubleshooting.sh` | Troubleshooting | `show_troubleshooting_submenu`, `troubleshooting_submenu` |

## Command Mode

`./rhoai-toolkit.sh <command> [args]` bypasses the menu system entirely.
Commands are registered in `lib/menus/commands.sh`.
