# License Management Guide

Application licenses are stored on the network drive at `/Volumes/backup_proxmox/macos/licenses/`.

⚠️ **NEVER commit license files to git!**

## License Storage Location
```
/Volumes/backup_proxmox/macos/licenses/
├── README.txt                          # Overview and warnings
├── serial-numbers.txt                  # Master list of all keys
├── adobe/
│   ├── account-info.txt                # Login credentials
│   └── notes.txt                       # Activation notes
├── affinity/
│   ├── designer-key.txt
│   ├── photo-key.txt
│   └── publisher-key.txt
├── crossover/
│   └── registration-code.txt
├── carbon-copy-cloner/
│   └── license.ccclicense              # Drag-and-drop file
├── davinci-resolve/
│   └── activation-key.txt
├── raycast/
│   └── account-info.txt
└── other/
    ├── app-name.txt
    └── ...
```

## Before Deactivating/Wiping Machine

**See [deactivation.md](deactivation.md) for full checklist.**

Critical deactivations before wiping:
1. Adobe Creative Cloud
2. DaVinci Resolve Studio
3. CrossOver
4. Any other seat-limited licenses

## Applying Licenses

### Adobe Creative Cloud

**Location:** `/Volumes/backup_proxmox/macos/licenses/adobe/`

1. Launch Creative Cloud app
2. Sign in with credentials from `account-info.txt`
3. Apps will auto-license when launched
4. **Before deactivating:** Creative Cloud → Account → Sign Out

### Affinity Suite (Designer, Photo, Publisher)

**Location:** `/Volumes/backup_proxmox/macos/licenses/affinity/`

For each app:
1. Launch Affinity [Designer/Photo/Publisher]
2. Help → About
3. Click "Enter Retail Key"
4. Paste key from corresponding `*-key.txt` file
5. Click "Verify"

**Before deactivating:** No deactivation needed (non-subscription, unlimited installs)

### Carbon Copy Cloner

**Location:** `/Volumes/backup_proxmox/macos/licenses/carbon-copy-cloner/`

**Method 1 (Drag & Drop):**
1. Launch CCC
2. CCC Menu → Enter License
3. Drag `license.ccclicense` onto the dialog window
4. License applies automatically

**Method 2 (Manual):**
1. CCC Menu → Enter License
2. Enter name and license key from file
3. Click "Validate"

**Before deactivating:** CCC Menu → Deactivate License

### CrossOver

**Location:** `/Volumes/backup_proxmox/macos/licenses/crossover/`

1. Launch CrossOver
2. Help → Enter Registration Code
3. Paste code from `registration-code.txt`
4. Click "Register"

**Before deactivating:** Help → Deactivate License

### DaVinci Resolve Studio

**Location:** `/Volumes/backup_proxmox/macos/licenses/davinci-resolve/`

1. Launch DaVinci Resolve
2. DaVinci Resolve → License
3. Click "Activate"
4. Enter activation key from `activation-key.txt`
5. Complete online activation

**Before deactivating:** Help → License → Deactivate (IMPORTANT: Seat-limited!)

### Raycast Pro

**Location:** `/Volumes/backup_proxmox/macos/licenses/raycast/`

1. Launch Raycast
2. Settings → Account (Cmd+,)
3. Click "Sign In"
4. Use GitHub/Google credentials from `account-info.txt`
5. Pro license auto-applies after sign-in

**Before deactivating:** Settings → Account → Sign Out

### Strongbox Pro

**Location:** `/Volumes/backup_proxmox/macos/licenses/strongbox/`

1. Launch Strongbox
2. Open any database
3. Strongbox Menu → Upgrade to Pro
4. Click "I already have a license"
5. Paste from `license-key.txt`

**Before deactivating:** No deactivation needed (lifetime license)

### Swinsian

**Location:** `/Volumes/backup_proxmox/macos/licenses/swinsian/`

1. Launch Swinsian
2. Swinsian → Registration
3. Enter details from `license-key.txt`
   - Name
   - License Key
4. Click "Register"

**Before deactivating:** No deactivation needed

### Other Applications

Check `/Volumes/backup_proxmox/macos/licenses/other/` for additional license files.

## Adding New License Information

When you purchase a new license:

1. Create folder: `/Volumes/backup_proxmox/macos/licenses/app-name/`
2. Save license key to `license-key.txt` or appropriate filename
3. Add activation notes if complex
4. Update `serial-numbers.txt` master list
5. Add section to this document with activation steps

## Security Notes

- Keep licenses folder permissions restricted: `chmod 700`
- Never share license files publicly
- Consider encrypting `serial-numbers.txt` with:
```bash
  # Encrypt
  openssl enc -aes-256-cbc -salt -in serial-numbers.txt -out serial-numbers.txt.enc
  
  # Decrypt
  openssl enc -d -aes-256-cbc -in serial-numbers.txt.enc -out serial-numbers.txt
```