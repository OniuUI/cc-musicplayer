# Bognesferga Radio Upgrade System

## Overview

The upgrade system allows you to update your Bognesferga Radio installation without losing your configuration or having to reinstall from scratch. It includes smart backup management and rollback capabilities.

## Quick Start

To upgrade your installation, simply run:
```
upgrade
```

## Features

### 🔄 Smart Version Management
- Automatically detects current and latest versions
- Compares versions to determine if upgrade is needed
- Supports force upgrades and downgrades

### 💾 Automatic Backups
- Creates timestamped backups before upgrades
- Preserves all files and configurations
- Organized backup directory structure

### 🛡️ Safe Upgrades
- Critical files are always updated
- Optional files can be selectively updated
- Rollback option if upgrades fail

### 📋 Comprehensive Logging
- Detailed upgrade logs with timestamps
- Error tracking and reporting
- Visual progress indicators

## Usage

### Main Menu Options

When you run `upgrade`, you'll see a menu with these options:

1. **Check for updates and upgrade** - Main upgrade process
2. **Manage backups and rollback** - Restore from previous versions
3. **View upgrade logs** - See detailed upgrade history
4. **Exit** - Return to system

### Upgrade Process

1. **Version Check**: System checks current vs latest version
2. **Backup Creation**: Automatic backup of current installation
3. **File Selection**: Choose which files to update
4. **Download & Install**: Updates selected files with progress tracking
5. **Verification**: Confirms successful installation

### File Categories

- **Critical Files**: Always updated (core system, UI, features)
- **Optional Files**: Your choice (themes, telemetry, config)

### Backup Management

Backups are stored in `musicplayer/backups/` with naming format:
```
v[version]_[date]_[time]
```

Examples:
- `v4.0_20231215_143022` - Version 4.0 backup from Dec 15, 2023 at 14:30:22
- `v4.1_20231220_091545` - Version 4.1 backup from Dec 20, 2023 at 09:15:45

## Safety Features

### Automatic Rollback
If critical files fail to update, the system offers automatic rollback to your previous version.

### Manual Rollback
You can manually restore any previous backup through the backup management menu.

### Error Handling
- Failed downloads are logged and reported
- Critical file failures trigger rollback prompts
- Network errors are handled gracefully

## File Structure

```
musicplayer/
├── backups/           # Version backups
│   ├── v4.0_20231215_143022/
│   └── v4.1_20231220_091545/
└── logs/
    └── upgrade.log    # Upgrade history and errors
```

## Troubleshooting

### Connection Issues
If you can't connect to the update server:
1. Check your internet connection
2. Verify ComputerCraft HTTP is enabled
3. Try again in a few minutes

### Failed Downloads
If files fail to download:
1. Check the upgrade logs for details
2. Try the upgrade again
3. Use rollback if needed

### Corrupted Installation
If the system becomes unstable:
1. Run `upgrade` and select backup management
2. Choose a recent backup to restore
3. Or reinstall using the original installer

## Advanced Usage

### Force Updates
The system allows force updates even when you're on the latest version. This is useful for:
- Reinstalling corrupted files
- Getting the latest fixes
- Testing purposes

### Selective Updates
You can choose which optional files to update, allowing you to:
- Keep custom configurations
- Skip unnecessary components
- Update only specific modules

### Log Analysis
Upgrade logs contain detailed information about:
- Download attempts and results
- File sizes and checksums
- Error messages and stack traces
- Timing information

## Version History

Each upgrade is logged with:
- Source version
- Target version
- Files updated
- Success/failure status
- Backup location
- Timestamp

## Best Practices

1. **Regular Backups**: The system creates automatic backups, but manual ones never hurt
2. **Test Upgrades**: Try upgrades in a test environment first if possible
3. **Monitor Logs**: Check upgrade logs for any warnings or errors
4. **Keep Backups**: Don't delete old backups unless space is limited
5. **Document Changes**: Note any custom modifications before upgrading

## Recovery Procedures

### Complete System Recovery
1. Run `upgrade`
2. Select "Manage backups and rollback"
3. Choose your most recent working backup
4. Confirm restoration

### Partial Recovery
If only some files are problematic:
1. Run `upgrade` with force update
2. Select only the problematic file categories
3. Let the system replace the corrupted files

### Emergency Recovery
If `upgrade` won't run:
1. Download the installer again
2. Run a fresh installation
3. Your logs and backups will be preserved

## Support

For issues with the upgrade system:
1. Check `musicplayer/logs/upgrade.log` for error details
2. Verify all backups in `musicplayer/backups/`
3. Try rolling back to a known good version
4. As a last resort, use the original installer

---

*The Bognesferga Radio Upgrade System - Making updates safe and simple!* 