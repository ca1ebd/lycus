# Swap Configuration Specification

## Overview

Configure swap space on Lycus deployment to prevent OOM (Out Of Memory) kills that crash services and lose conversation context.

## Problem Statement

Low-memory VMs without swap will invoke the OOM killer when RAM is exhausted, resulting in:
- Immediate process termination (no graceful degradation)
- Loss of all in-memory conversation context (Claude remote sessions)
- Service downtime (gateway, agents)
- No warning or recovery opportunity

## Solution

Add a 4GB swap file with low swappiness (10) to provide emergency memory buffer without impacting normal performance.

## Implementation Steps

### 1. Create Swap File

```bash
# Allocate 4GB file
sudo fallocate -l 4G /swapfile

# Set secure permissions (root only)
sudo chmod 600 /swapfile

# Format as swap
sudo mkswap /swapfile

# Activate swap
sudo swapon /swapfile
```

### 2. Make Persistent Across Reboots

```bash
# Add to /etc/fstab
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### 3. Configure Swappiness

```bash
# Set swappiness to 10 (only swap under real memory pressure)
sudo sysctl vm.swappiness=10

# Make persistent
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
```

### 4. Verify

```bash
# Check swap is active
free -h

# Should show:
# Swap:          4.0Gi          0B       4.0Gi

# Verify swappiness
cat /proc/sys/vm/swappiness
# Should output: 10
```

## Configuration Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| **Swap Size** | 4GB | ~100% of RAM (4GB VM), provides adequate emergency buffer |
| **Swappiness** | 10 | Only swap under real pressure, not proactively (default is 60) |
| **File Location** | `/swapfile` | Standard location, easy to identify and manage |
| **Permissions** | 600 (root only) | Security best practice for swap files |

## Expected Behavior

- **Normal operation:** Swap unused (0B used), no performance impact
- **Memory pressure:** System swaps to disk instead of killing processes
- **High memory usage:** Services slow down but remain alive
- **Recovery:** Time to notice issue and take action (vs instant kill)

## Trade-offs

### With Swap (This Approach)
✓ No OOM kills  
✓ Services stay alive under pressure  
✓ Conversation context preserved  
✓ Time to react to memory issues  
✗ Slight performance degradation when swap is actively used  

### Without Swap (Current Production Issue)
✓ Slightly faster under normal conditions  
✗ Instant process kills when memory exhausted  
✗ Complete loss of conversation context  
✗ No warning or recovery opportunity  
✗ Service downtime  

## Validation Criteria

After implementation, verify:

1. **Swap is active and configured:**
   ```bash
   swapon --show
   # Should output /swapfile with 4G size
   ```

2. **Persistent across reboots:**
   ```bash
   grep swapfile /etc/fstab
   # Should output: /swapfile none swap sw 0 0
   ```

3. **Swappiness is set:**
   ```bash
   sysctl vm.swappiness
   # Should output: vm.swappiness = 10
   ```

4. **No OOM kills after heavy memory load:**
   ```bash
   # Simulate memory pressure (test in staging)
   stress-ng --vm 1 --vm-bytes 3G --timeout 60s
   
   # Check for OOM kills
   sudo journalctl --since "5 minutes ago" | grep -i oom
   # Should be empty (no kills)
   ```

## Deployment Notes

- **Requires:** Root/sudo access
- **Downtime:** None (applied live)
- **Reboot required:** No
- **Disk space:** 4GB on root filesystem
- **Automation:** Can be added to provisioning scripts or Ansible playbooks

## Monitoring

After deployment, monitor:

```bash
# Regular swap usage checks
watch -n 5 'free -h | grep Swap'

# Alert if swap usage exceeds 50% (indicates sustained memory pressure)
# This means you need more RAM or to optimize memory usage
```

## Future Improvements

Consider if swap usage becomes regular (>1GB sustained):

1. Upgrade VM to more RAM
2. Optimize memory-hungry processes
3. Implement memory limits on services (systemd MemoryMax)
4. Add monitoring/alerting for memory pressure

## References

- Production incident: July 28, 2025 00:01:05 - OOM killer terminated Claude gateway (688MB process)
- Linux kernel OOM killer: https://www.kernel.org/doc/gorman/html/understand/understand016.html
- Swappiness tuning: https://wiki.archlinux.org/title/Swap#Swappiness
