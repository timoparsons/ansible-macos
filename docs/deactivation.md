# Machine Deactivation Checklist

**Run this BEFORE wiping or selling a Mac to free up license seats.**

License files location: `/Volumes/backup_proxmox/macos/licenses/`

## Critical Deactivations (Seat-Limited)

### 🔴 Adobe Creative Cloud (Required)

**Seats:** 2 active installations

1. Open Creative Cloud app
2. Click profile icon → Account
3. Click "Sign Out"
4. Confirm deactivation

**Verify:** Log into adobe.com → Account → Plans → Manage devices

---

### 🔴 DaVinci Resolve Studio (Required)

**Seats:** 2 active installations

1. Launch DaVinci Resolve
2. DaVinci Resolve Menu → License
3. Click "Deactivate"
4. Confirm deactivation
5. Activation key is now free for another machine

**Verify:** Blackmagic website account shows activation freed

---

### 🔴 CrossOver (Required)

**Seats:** Limited by license type

1. Launch CrossOver
2. Help → Deactivate License
3. Confirm deactivation

**Note:** Keep registration code in `/Volumes/backup_proxmox/macos/licenses/crossover/`

---

### 🟡 Carbon Copy Cloner (Recommended)

**Seats:** Unlimited, but good practice

1. Launch CCC
2. CCC Menu → Deactivate License
3. Confirm

**Note:** Not strictly required but keeps license registry clean

---

## Optional Deactivations (Unlimited Seats)

These don't require deactivation but signing out is good practice:

### Raycast Pro
1. Settings → Account → Sign Out

### Strongbox Pro
- No deactivation needed (lifetime license)

### Affinity Suite
- No deactivation needed (perpetual license, unlimited installs)

### Swinsian
- No deactivation needed

---

## Backup Before Wiping

### 1. Run Final Backup
```bash
# SSH keys (if not already backed up)
ansible-playbook playbooks/backup-ssh.yml -i inventory.ini --limit personal

# App settings
ansible-playbook playbooks/backup-apps.yml -i inventory.ini --limit personal

# Verify backups exist
ls -la /Volumes/backup_proxmox/macos/
```

### 2. Check for Additional License Files

Some apps store licenses in:
```bash
# Check these locations for license files
~/Library/Application Support/
~/Library/Preferences/
~/Library/Containers/
```

If you find license files you want to keep:
```bash
# Copy to licenses folder
cp ~/Library/Application\ Support/SomeApp/license.lic \
   /Volumes/backup_proxmox/macos/licenses/someapp/
```

### 3. Export Data Not Covered by Backups

- **Photos Library** - Export if not using iCloud Photos
- **Music Library** - If using Swinsian or local iTunes
- **Documents** - Ensure critical docs are backed up
- **Downloads** - Check for important files
- **Desktop** - Anything not automatically synced

---

## Final Verification Checklist

Before wiping, verify:

- [ ] Adobe CC signed out
- [ ] DaVinci Resolve Studio deactivated
- [ ] CrossOver deactivated
- [ ] Carbon Copy Cloner deactivated (optional)
- [ ] Raycast signed out (optional)
- [ ] Final backup completed
- [ ] License files copied if needed
- [ ] Important data exported
- [ ] Network volume unmounted

---

## After Wiping

To restore on a new machine:

1. Run bootstrap: `./scripts/bootstrap.sh`
2. Provision machine: `./scripts/setup.sh`
3. Apply licenses using [licenses.md](licenses.md)
4. App settings will auto-restore during provisioning

---

## Selling/Transferring Mac

If selling or giving away:

1. **Complete deactivation checklist above**
2. **Sign out of iCloud:**
   - System Settings → Apple ID → Sign Out
   - Uncheck "Keep a copy" for all data
3. **Sign out of Messages:** Messages → Preferences → iMessage → Sign Out
4. **Unpair Bluetooth devices**
5. **Erase Mac:** System Settings → General → Transfer or Reset → Erase All Content and Settings
6. **Remove from Find My:** iCloud.com → Find My → Remove device

---

## Emergency: Machine Died Without Deactivation

If a machine crashes and you can't deactivate:

### Adobe
- Log into adobe.com
- Account → Plans → Manage Devices
- Remove the dead machine remotely

### DaVinci Resolve
- Contact Blackmagic support to reset activation
- Provide proof of purchase

### CrossOver
- Contact CodeWeavers support
- May require proof of purchase

### Others
- Most unlimited-seat licenses don't require action
- Contact vendor support if needed
```

## 3. Create README in licenses folder (on network drive)

Create `/Volumes/backup_proxmox/macos/licenses/README.txt`:
```
macOS Application Licenses
==========================

This folder contains license keys and activation codes for macOS applications.

⚠️  SECURITY WARNING ⚠️
- NEVER commit these files to git
- NEVER share publicly
- Keep folder permissions restricted (chmod 700)
- Consider encrypting serial-numbers.txt

Structure:
----------
Each application has its own subfolder with:
- License key/activation code
- Account credentials (if applicable)
- Activation notes
- Deactivation instructions

See ansible-macos/docs/licenses.md for full activation instructions.
See ansible-macos/docs/deactivation.md for deactivation checklist.

Master List:
-----------
serial-numbers.txt contains all keys in one place for easy reference.

Before Deactivating a Mac:
--------------------------
1. See deactivation.md for checklist
2. Deactivate seat-limited licenses (Adobe, DaVinci, CrossOver)
3. Run final backup
4. Then wipe machine

Last Updated: [Date]