# Linux User, Group & Directory Permission Guide

A concise operational guide for creating `sudo` administrators with SSH password authentication and configuring group-isolated shared directories (`2770` SGID + default POSIX ACLs) on Linux (Ubuntu/Debian & CentOS/RHEL).

```text
[Admin / Sudo Setup]
  newuser ──> (usermod -aG sudo/wheel) ──> [Full Sudo Privileges + SSH Password Login]

[Group-Isolated Shared Directory (/data/shared)]
  root:devgroup (chmod 2770 + default ACLs)
   ├── User (root)        ──> rwx (Full control)
   ├── Group (devgroup)   ──> rwx + SGID + default ACL (Read / Write / Execute & auto-inherit group)
   └── Others             ──> --- (Zero access)
```

---

## 1. Create a New `sudo` User with Password Login

### 1.1 Create the User & Set a Password

Choose the command matching your Linux distribution (using `newuser` as an example):

#### Option A: Ubuntu / Debian (Interactive)
```bash
sudo adduser newuser
```
> Automatically creates `/home/newuser`, sets the default login shell, and prompts interactively for the user's password.

#### Option B: CentOS / RHEL / General Linux
```bash
# 1. Create user with home directory (-m) and bash shell (-s /bin/bash)
sudo useradd -m -s /bin/bash newuser

# 2. Set password for the new user
sudo passwd newuser
```

### 1.2 Grant `sudo` Privileges

Add the user to the system administrator group:

- **Ubuntu / Debian** (`sudo` group):
  ```bash
  sudo usermod -aG sudo newuser
  ```
- **CentOS / RHEL / Fedora / AlmaLinux** (`wheel` group):
  ```bash
  sudo usermod -aG wheel newuser
  ```

### 1.3 Enable SSH Password Authentication (If Connecting Remotely)

Many cloud images disable SSH password logins by default. To allow password login over SSH:

1. Edit `/etc/ssh/sshd_config` (and check any override files in `/etc/ssh/sshd_config.d/`):
   ```bash
   sudo nano /etc/ssh/sshd_config
   ```
2. Ensure `PasswordAuthentication` is set to `yes`:
   ```text
   PasswordAuthentication yes
   ```
3. Restart the SSH daemon:
   - **Ubuntu / Debian**:
     ```bash
     sudo systemctl restart ssh
     ```
   - **CentOS / RHEL**:
     ```bash
     sudo systemctl restart sshd
     ```

### 1.4 Verify `sudo` Access

```bash
# Switch to the new user
su - newuser

# Test privilege escalation
sudo whoami
# Expected output: root
```

---

## 2. Create a Group-Isolated Shared Directory

Restrict a target directory (e.g., `/data/shared`) so that **only** members of a specific group (e.g., `devgroup`) can read, write, and execute files inside it.

### 2.1 Create the Group & Add Users

```bash
# 1. Create the new group
sudo groupadd devgroup

# 2. Add existing users to the group (-aG appends without removing existing groups)
sudo usermod -aG devgroup username1
sudo usermod -aG devgroup username2
```

> **Important**: Added users must **log out and log back in** (or run `newgrp devgroup` in their current shell) for the new group membership to take effect.

### 2.2 Set Directory Ownership & `2770` (SGID) Permissions

```bash
# 1. Create the directory if it does not exist
sudo mkdir -p /data/shared

# 2. Set owner to root and group to devgroup (-R applies recursively)
sudo chown -R root:devgroup /data/shared

# 3. Apply 2770 permissions
sudo chmod -R 2770 /data/shared
```

#### Permission `2770` Breakdown

| Digit | Meaning | Effect on `/data/shared` |
| :--- | :--- | :--- |
| **`2`** | **SGID (`chmod g+s`)** | Any file or subdirectory created inside `/data/shared` automatically inherits `devgroup` as its group owner (instead of the creator's primary group). |
| **`7`** | **User (`rwx`)** | Directory owner (`root`) has read, write, and execute permissions. |
| **`7`** | **Group (`rwx`)** | Members of `devgroup` can list, create, modify, and execute files. |
| **`0`** | **Others (`---`)** | All users outside `devgroup` have zero access (cannot traverse, read, or write). |

### 2.3 Configure Default ACLs (Ensure New Files Are Group-Writable)

With standard `umask 022`, files created by a group member default to `644` (`rw-r--r--`), which prevents other members of `devgroup` from modifying them. Setting default POSIX ACLs ensures all newly created files and subdirectories automatically grant `rwx` to `devgroup` and `---` to others:

```bash
# Install ACL utilities if not already present (Ubuntu/Debian: sudo apt install -y acl)

# 1. Apply ACLs to existing files/directories
sudo setfacl -R -m g:devgroup:rwx,o::--- /data/shared

# 2. Apply default ACLs (-d) inherited by all future files and subdirectories
sudo setfacl -d -m g:devgroup:rwx,o::--- /data/shared
```

### 2.4 Verify Directory Permissions & ACLs

```bash
# Verify mode and SGID bit (should display drwxrws---+)
ls -ld /data/shared

# Inspect active and default ACL entries
getfacl /data/shared
```

---

## 3. Operational Cheat Sheet

```bash
# Check a user's UID, GID, and all group memberships
id <username>
groups <username>

# List all members of a specific group
getent group devgroup

# Remove a user from a supplementary group
sudo gpasswd -d <username> devgroup

# Delete a user and their home directory
sudo userdel -r <username>

# Delete a group
sudo groupdel devgroup
```
