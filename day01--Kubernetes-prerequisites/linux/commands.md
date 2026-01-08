📚 What You Need to Know

1.** File System Structure**

bash/           # Root directory
├── /bin        # Essential command binaries
├── /etc        # Configuration files
├── /home       # User home directories
├── /var        # Variable data (logs, temp files)
├── /tmp        # Temporary files
├── /usr        # User programs
└── /opt        # Optional software packages

Practice Commands:
bash                     # Navigate directories
cd /var/log              # Change directory
pwd                      # Print working directory
ls -la                   # List all files with details
ls -lh                   # List with human-readable sizes

# View file contents

cat /etc/os-release      # Display file content
less /var/log/syslog     # View large files (q to quit)
head -n 20 file.txt      # First 20 lines
tail -f /var/log/app.log # Follow log file (Ctrl+C to stop)

#Create and manage files

touch newfile.txt        # Create empty file
mkdir -p dir1/dir2       # Create nested directories
cp file.txt backup.txt   # Copy file
mv old.txt new.txt       # Move/rename file
rm file.txt              # Delete file
rm -rf directory/        # Delete directory recursively

2. **File Permissions**
Understanding permissions is crucial for Kubernetes security.
bash# Permission format: rwxrwxrwx
# r = read (4), w = write (2), x = execute (1)
# Three groups: owner | group | others

# Example: -rw-r--r--
# - = regular file
# rw- = owner can read/write
# r-- = group can read
# r-- = others can read

# View permissions
ls -l file.txt

# Change permissions
chmod 755 script.sh      # rwxr-xr-x (owner: all, group/others: read+execute)
chmod +x script.sh       # Add execute permission
chmod 644 file.txt       # rw-r--r-- (typical file permission)

# Change ownership
chown user:group file.txt
chown -R user:group directory/

# Common permission patterns
chmod 755 /scripts/      # Directories and executables
chmod 644 /config/       # Configuration files
chmod 600 /secrets/      # Sensitive files (owner only)

3.** Process Management**
bash# View processes
ps aux                   # All running processes
ps aux | grep nginx      # Find specific process
top                      # Interactive process viewer (q to quit)
htop                     # Better process viewer (if installed)

# Process information
ps aux | grep kube       # Find Kubernetes processes
pgrep -f kubelet         # Find process ID by name

# Manage processes
kill PID                 # Gracefully terminate process
kill -9 PID              # Force kill process
killall nginx            # Kill all nginx processes

# Background processes
command &                # Run in background
jobs                     # List background jobs
fg %1                    # Bring job to foreground
bg %1                    # Resume job in background
nohup command &          # Run process immune to hangups

4.** Networking Commands**
Essential for debugging Kubernetes networking issues.
bash# Check network interfaces
ip addr show             # Show IP addresses
ip a                     # Short form
ifconfig                 # Legacy command (if installed)

# Check connectivity
ping 8.8.8.8             # Test connectivity
ping -c 4 google.com     # Ping 4 times then stop

# DNS lookup
nslookup google.com      # DNS query
dig google.com           # Detailed DNS info
host google.com          # Simple DNS lookup

# Check open ports
netstat -tuln            # All listening ports (TCP/UDP)
ss -tuln                 # Modern replacement for netstat
lsof -i :8080            # Check what's using port 8080

# Network connections
netstat -an | grep ESTABLISHED
ss -an | grep ESTABLISHED

# Route table
ip route show            # Show routing table
route -n                 # Legacy command

# Test port connectivity
telnet hostname 80       # Test if port is open
nc -zv hostname 80       # Alternative using netcat
curl -I https://google.com  # HTTP request
wget -O- http://example.com # Download content

5.** System Information**
bash# System details
uname -a                 # Kernel and system info
hostnamectl              # Hostname and OS info
cat /etc/os-release      # OS version details

# CPU and memory
lscpu                    # CPU information
free -h                  # Memory usage (human-readable)
vmstat 1                 # Virtual memory stats every 1 sec

# Disk usage
df -h                    # Disk space usage
du -sh /var/log          # Size of specific directory
du -sh * | sort -h       # Size of all items, sorted

# System load
uptime                   # System uptime and load average
w                        # Who is logged in and load average

6.** Log Files**
Kubernetes troubleshooting often involves checking logs.
bash# Common log locations
/var/log/syslog          # System logs (Debian/Ubuntu)
/var/log/messages        # System logs (RHEL/CentOS)
/var/log/containers/     # Container logs
/var/log/pods/           # Pod logs

# View logs
tail -f /var/log/syslog  # Follow log in real-time
tail -n 100 /var/log/syslog  # Last 100 lines
grep ERROR /var/log/syslog   # Search for errors
journalctl -xe           # Systemd journal (last entries)
journalctl -u kubelet    # Logs for specific service
journalctl -f            # Follow journal logs

7. **Package Management**
bash# Ubuntu/Debian (APT)
sudo apt update          # Update package list
sudo apt upgrade         # Upgrade packages
sudo apt install nginx   # Install package
sudo apt remove nginx    # Remove package
apt search nginx         # Search for packages

# RHEL/CentOS/Amazon Linux (YUM/DNF)
sudo yum update          # Update packages
sudo yum install nginx   # Install package
sudo yum remove nginx    # Remove package

# Check installed packages
dpkg -l | grep docker    # Debian/Ubuntu
rpm -qa | grep docker    # RHEL/CentOS

8.** Text Processing**
Critical for parsing logs and config files.
bash# grep - search for patterns
grep "error" /var/log/syslog
grep -i "error" file.txt          # Case-insensitive
grep -r "TODO" /project           # Recursive search
grep -v "debug" app.log           # Exclude lines with "debug"

# awk - pattern scanning and processing
awk '{print $1}' file.txt         # Print first column
awk '$3 > 100' data.txt           # Print lines where 3rd column > 100
ps aux | awk '{print $2, $11}'    # Print PID and command

# sed - stream editor
sed 's/old/new/g' file.txt        # Replace old with new
sed -i 's/old/new/g' file.txt     # Edit file in place
sed -n '10,20p' file.txt          # Print lines 10-20

# cut - remove sections from lines
cut -d: -f1 /etc/passwd           # Get usernames
echo "a,b,c,d" | cut -d, -f2,4    # Get 2nd and 4th fields

# sort and uniq
sort file.txt                     # Sort lines
sort -n numbers.txt               # Sort numerically
sort file.txt | uniq              # Remove duplicates
sort file.txt | uniq -c           # Count occurrences

# wc - word count
wc -l file.txt                    # Count lines
wc -w file.txt                    # Count words

9.** Archive and Compression**
bash# tar - archive files
tar -czf archive.tar.gz /data     # Create compressed archive
tar -xzf archive.tar.gz           # Extract archive
tar -tzf archive.tar.gz           # List contents

# zip/unzip
zip archive.zip file1 file2
unzip archive.zip
unzip -l archive.zip              # List contents

# gzip/gunzip
gzip file.txt                     # Compress (creates file.txt.gz)
gunzip file.txt.gz                # Decompress

10. **User Management**
bash# View users
whoami                   # Current user
id                       # User and group IDs
who                      # Who is logged in
last                     # Login history

# Switch users
su - username            # Switch user
sudo command             # Run as superuser
sudo -i                  # Root shell

# User info
cat /etc/passwd          # User accounts
cat /etc/group           # Group information
groups username          # User's groups

🎯** Practice Exercises**
Exercise 1: File Management
bash# Create a project structure
mkdir -p ~/k8s-practice/{configs,logs,scripts}
cd ~/k8s-practice
touch configs/app.yaml
touch logs/app.log
touch scripts/deploy.sh
chmod +x scripts/deploy.sh
ls -lR
Exercise 2: Process Monitoring
bash# Monitor system resources
top
# Press 'M' to sort by memory
# Press 'P' to sort by CPU
# Press 'q' to quit

# Find memory-hungry processes
ps aux --sort=-%mem | head -10
Exercise 3: Log Analysis
bash# Simulate searching logs
echo "2024-01-08 10:00:00 INFO: Application started" >> app.log
echo "2024-01-08 10:05:00 ERROR: Connection timeout" >> app.log
echo "2024-01-08 10:10:00 INFO: Request processed" >> app.log

# Search for errors
grep ERROR app.log

# Count errors
grep -c ERROR app.log

# Show errors with context
grep -A 2 -B 2 ERROR app.log

🔗** Useful Resources**

https://ubuntu.com/tutorials/command-line-for-beginners
https://linuxjourney.com/
https://explainshell.com/