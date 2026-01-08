## Git Version Control

### 1. Git Basics

**What is Git?**
- Distributed version control system
- Tracks changes in source code
- Enables collaboration
- Created by Linus Torvalds

**Git Configuration**
```bash
# Set user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Check configuration
git config --list

# Set default branch name
git config --global init.defaultBranch main

# Set default editor
git config --global core.editor "vim"
```

### 2. Repository Management

**Initialize Repository**
```bash
# Create new repository
git init

# Clone existing repository
git clone https://github.com/user/repo.git

# Clone specific branch
git clone -b develop https://github.com/user/repo.git
```

**Remote Repositories**
```bash
# Add remote
git remote add origin https://github.com/user/repo.git

# View remotes
git remote -v

# Change remote URL
git remote set-url origin https://github.com/user/new-repo.git

# Remove remote
git remote remove origin
```

### 3. Basic Git Workflow

**Working with Files**
```bash
# Check status
git status

# Add files to staging
git add filename.txt
git add .  # Add all files
git add *.yaml  # Add by pattern

# Commit changes
git commit -m "Add deployment configuration"

# Add and commit in one step
git commit -am "Update service definition"

# Amend last commit
git commit --amend -m "Updated commit message"
```

**Viewing History**
```bash
# View commit history
git log

# View compact history
git log --oneline

# View with graph
git log --oneline --graph --all

# View specific file history
git log -- filename.txt

# View changes in commits
git log -p

# View last n commits
git log -n 5
```

**Viewing Changes**
```bash
# Show unstaged changes
git diff

# Show staged changes
git diff --staged

# Show changes between commits
git diff commit1 commit2

# Show changes for specific file
git diff filename.txt
```

### 4. Branching and Merging

**Branch Management**
```bash
# List branches
git branch

# Create new branch
git branch feature-x

# Switch to branch
git checkout feature-x

# Create and switch in one step
git checkout -b feature-y

# Using modern switch command
git switch feature-x
git switch -c feature-y  # Create and switch

# Delete branch
git branch -d feature-x

# Force delete unmerged branch
git branch -D feature-x

# Rename branch
git branch -m old-name new-name
```

**Merging**
```bash
# Merge branch into current branch
git checkout main
git merge feature-x

# Merge with commit message
git merge feature-x -m "Merge feature X"

# Abort merge if conflicts
git merge --abort
```

**Resolving Conflicts**
```bash
# 1. Git shows conflicts in files
<<<<<<< HEAD
Current branch content
=======
Incoming branch content
>>>>>>> feature-x

# 2. Edit files to resolve conflicts

# 3. Mark as resolved
git add conflicted-file.txt

# 4. Complete merge
git commit
```

### 5. Advanced Git Operations

**Rebasing**
```bash
# Rebase current branch onto main
git rebase main

# Interactive rebase (last 3 commits)
git rebase -i HEAD~3

# Continue after resolving conflicts
git rebase --continue

# Abort rebase
git rebase --abort
```

**Stashing**
```bash
# Stash current changes
git stash

# Stash with message
git stash save "Work in progress on feature X"

# List stashes
git stash list

# Apply most recent stash
git stash apply

# Apply and remove stash
git stash pop

# Apply specific stash
git stash apply stash@{2}

# Delete stash
git stash drop stash@{0}

# Clear all stashes
git stash clear
```

**Cherry Picking**
```bash
# Apply specific commit to current branch
git cherry-pick commit-hash

# Cherry pick without committing
git cherry-pick -n commit-hash
```

**Resetting**
```bash
# Soft reset (keep changes staged)
git reset --soft HEAD~1

# Mixed reset (keep changes unstaged) - default
git reset HEAD~1

# Hard reset (discard changes)
git reset --hard HEAD~1

# Reset to specific commit
git reset --hard commit-hash
```

### 6. Remote Operations

**Fetching and Pulling**
```bash
# Fetch from remote (doesn't merge)
git fetch origin

# Pull from remote (fetch + merge)
git pull origin main

# Pull with rebase
git pull --rebase origin main
```

**Pushing**
```bash
# Push to remote
git push origin main

# Push new branch
git push -u origin feature-x

# Force push (use with caution)
git push --force origin main

# Safer force push
git push --force-with-lease origin main

# Delete remote branch
git push origin --delete feature-x
```

**Tags**
```bash
# Create lightweight tag
git tag v1.0.0

# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# List tags
git tag

# Push tags to remote
git push origin v1.0.0
git push origin --tags  # Push all tags

# Delete tag
git tag -d v1.0.0
git push origin --delete v1.0.0
```

### 7. Git Workflows

**Feature Branch Workflow**
```bash
# 1. Create feature branch
git checkout -b feature/user-authentication

# 2. Make changes and commit
git add .
git commit -m "Implement user login"

# 3. Push to remote
git push -u origin feature/user-authentication

# 4. Create pull request on GitHub/GitLab

# 5. After review, merge to main
git checkout main
git merge feature/user-authentication

# 6. Delete feature branch
git branch -d feature/user-authentication
git push origin --delete feature/user-authentication
```

**Gitflow Workflow**
```bash
# Main branches
main        # Production-ready code
develop     # Integration branch

# Supporting branches
feature/*   # New features
release/*   # Release preparation
hotfix/*    # Production fixes

# Example: Create feature
git checkout -b feature/new-api develop

# Complete feature
git checkout develop
git merge feature/new-api
git branch -d feature/new-api

# Create release
git checkout -b release/1.0.0 develop

# Finish release
git checkout main
git merge release/1.0.0
git tag -a v1.0.0
git checkout develop
git merge release/1.0.0
```

### 8. .gitignore File

**Common .gitignore patterns**
```gitignore
# Node.js
node_modules/
npm-debug.log
.env

# Python
__pycache__/
*.py[cod]
*.so
.Python
venv/
.env

# Java
*.class
*.jar
*.war
target/

# IDEs
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Kubernetes
*.kubeconfig

# Docker
.dockerignore

# Logs
*.log
logs/

# Secrets
secrets.yaml
*.pem
*.key
```

### 9. GitHub/GitLab Specific

**Pull Requests (GitHub) / Merge Requests (GitLab)**
```bash
# Via command line (using gh CLI)
gh pr create --title "Add user authentication" --body "Implements login functionality"

# View pull requests
gh pr list

# Checkout PR locally
gh pr checkout 123
```

**SSH Setup**
```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Start SSH agent
eval "$(ssh-agent -s)"

# Add key to agent
ssh-add ~/.ssh/id_ed25519

# Copy public key (add to GitHub/GitLab)
cat ~/.ssh/id_ed25519.pub

# Test connection
ssh -T git@github.com
```

**CI/CD Integration**
```yaml
# .github/workflows/deploy.yml
name: Deploy to Kubernetes
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up kubectl
        uses: azure/setup-kubectl@v1
        
      - name: Deploy to cluster
        run: |
          kubectl apply -f k8s/deployment.yaml
```

### 10. Best Practices

**Commit Messages**
```bash
# Good commit messages
git commit -m "Add user authentication feature"
git commit -m "Fix: Resolve memory leak in pod controller"
git commit -m "Refactor: Simplify database connection logic"
git commit -m "Docs: Update README with installation steps"

# Conventional Commits format
feat: Add new feature
fix: Bug fix
docs: Documentation changes
style: Code style changes
refactor: Code refactoring
test: Add or modify tests
chore: Maintenance tasks
```

**Branching Strategy**
```bash
# Branch naming conventions
feature/user-auth
bugfix/memory-leak
hotfix/security-patch
release/v1.2.0
```

**Common Git Commands Reference**
```bash
# Status and information
git status              # Show working tree status
git log                 # Show commit logs
git diff                # Show changes

# Basic workflow
git add .               # Stage all changes
git commit -m "msg"     # Commit staged changes
git push                # Push to remote

# Branching
git branch              # List branches
git checkout -b branch  # Create and switch to branch
git merge branch        # Merge branch

# Syncing
git fetch               # Download remote changes
git pull                # Fetch and merge
git push                # Upload local changes

# Undoing
git reset HEAD~1        # Undo last commit
git revert commit       # Create new commit that undoes changes
git checkout -- file    # Discard local changes

# Stashing
git stash               # Save work temporarily
git stash pop           # Restore stashed work

# Remote
git remote -v           # List remotes
git remote add name url # Add remote
```

---
