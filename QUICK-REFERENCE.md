# Quick Reference Card

## 🚨 GPU Hardware Profile Not Visible?

**Quick Fix:**
```bash
./scripts/fix-hardware-profile.sh
```

**Why This Happens:**
- RHOAI 3.0 uses **different API versions** for different purposes:
  - `dashboard.opendatahub.io/v1` → Workbenches (notebooks) ❌ for models
  - `infrastructure.opendatahub.io/v1alpha1` → Models ✅

**Symptoms:**
- ✅ Profile shows in Settings → Hardware Profiles
- ❌ Profile NOT in dropdown when deploying model

**Solution:**
The fix script will:
1. Delete old API version profiles
2. Create new profile with correct API version
3. Add required annotations for UI discovery

**Manual Check:**
```bash
# Check API version
oc get hardwareprofile -n redhat-ods-applications -o yaml | grep apiVersion

# Should see: infrastructure.opendatahub.io/v1alpha1
```

## 📚 Full Documentation

See `docs/HARDWARE-PROFILE-TROUBLESHOOTING.md` for:
- Root cause analysis
- Manual fix steps
- Required fields for UI discovery
- Common mistakes
- Debugging commands

## 🎯 Key Takeaway

**Always use `infrastructure.opendatahub.io/v1alpha1` for model deployment hardware profiles!**

---

## Other Common Issues

### macOS Security Warning
```bash
xattr -d com.apple.quarantine openshift-install
chmod +x openshift-install
```

### Check Cluster Status
```bash
oc whoami --show-console
oc get nodes
oc get datasciencecluster -n redhat-ods-applications
```

### Check MaaS Status
```bash
oc get pods -n maas-api
oc get gateway -n maas-api
oc get authpolicy -n maas-api
```

### Restart RHOAI Components
```bash
# Restart model controller
oc delete pod -n redhat-ods-applications -l app=odh-model-controller

# Restart Kuadrant operator
oc delete pod -n kuadrant-system -l control-plane=controller-manager
```

### Check GPU Nodes
```bash
oc get nodes -l nvidia.com/gpu.present=true
oc describe node <gpu-node-name> | grep -A 5 "Allocated resources"
```

### View Operator Logs
```bash
# RHOAI operator
oc logs -n redhat-ods-operator -l name=rhods-operator --tail=50

# GPU operator
oc logs -n nvidia-gpu-operator -l app=gpu-operator --tail=50

# RHCL operator
oc logs -n kuadrant-system -l control-plane=controller-manager --tail=50
```

## 🔗 Quick Links

- **Main README**: `README.md`
- **Detailed Docs**: `docs/README.md`
- **Troubleshooting**: `docs/TROUBLESHOOTING.md`
- **Hardware Profile Issues**: `docs/HARDWARE-PROFILE-TROUBLESHOOTING.md`
- **MaaS Demo**: `demo/README.md`
- **MaaS Verification**: `demo/VERIFICATION.md`

## 🛠️ Useful Scripts

| Script | Purpose |
|--------|---------|
| `./rhoai-toolkit.sh` | Full setup (OpenShift + RHOAI + GPU + MaaS) |
| `./rhoai-toolkit.sh` → Option 5 | Configure Kubeconfig (login, switch clusters) |
| `./rhoai-toolkit.sh` → 3 → 7 | Deploy LlamaStack Demo UI (chatbot frontend) |
| `./scripts/fix-hardware-profile.sh` | Fix GPU profile visibility |
| `./scripts/setup-maas.sh` | Set up MaaS infrastructure |
| `./scripts/create-gpu-machineset.sh` | Add GPU worker nodes |
| `./scripts/cleanup-all.sh` | Clean up failed installations |
| `./demo/setup-demo-model.sh` | Deploy demo model with MaaS |
| `./demo/generate-maas-token.sh` | Generate MaaS API token |
| `./demo/test-maas-api.sh` | Test MaaS API |

## 🤖 LlamaStack Demo UI

Deploy a chatbot frontend to test LlamaStack + MCP:

```bash
./rhoai-toolkit.sh
# Select: 3) RHOAI Management
# Select: 7) Deploy LlamaStack Demo UI
```

The script auto-detects LlamaStack and MCP services, builds the container, and deploys with a Route.

See `demo/llamastack-demo/README.md` for configuration options.

## 🔐 Kubeconfig Management

Quickly login or switch clusters:

```bash
./rhoai-toolkit.sh
# Select: 5) Configure Kubeconfig
```

Options:
- Login with token (paste `oc login` command)
- Login with username/password
- Set KUBECONFIG from existing file
- Create new kubeconfig in workspace
- Test connection

## 📞 Getting Help

1. Check `docs/TROUBLESHOOTING.md` first
2. Check `docs/HARDWARE-PROFILE-TROUBLESHOOTING.md` for profile issues
3. Review CAI guide: `CAI's guide to RHOAI 3.0.txt`
4. Check script logs in your terminal
5. Use `oc describe` and `oc logs` for debugging

## 🎓 Learning Resources

- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai_self-managed/3.0)
- [MaaS Billing Documentation](https://opendatahub-io.github.io/maas-billing/latest/quickstart/)
- [OpenShift AI Bootstrap Examples](https://github.com/tsailiming/openshift-ai-bootstrap)
- [CAI's RHOAI 3.0 Guide](CAI's%20guide%20to%20RHOAI%203.0.txt)

