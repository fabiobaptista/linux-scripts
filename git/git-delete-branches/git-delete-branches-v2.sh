#!/usr/bin/env bash

#============================================================
# Git Branch Delete - Enhanced UI
# Version: 2.0.0
# Dependencies: gum, git
# Description: Interactive script to safely delete Git branches
#              with modern TUI using gum
#============================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#============================================================
# CONSTANTS & CONFIGURATION
#============================================================

# Versão do script
readonly VERSION="2.0.0"

# Branches protegidas (nunca podem ser deletadas)
readonly PROTECTED_BRANCHES=("main" "master" "development" "develop" "staging" "production")

# Padrões de exclusão passados via CLI
declare -a EXCLUDE_PATTERNS=("$@")

# Configurações de cores (gum style)
readonly COLOR_PRIMARY="#7D56F4"
readonly COLOR_SUCCESS="#02BA84"
readonly COLOR_ERROR="#D62828"
readonly COLOR_WARNING="#F77F00"
readonly COLOR_INFO="#0077B6"

# Limites de performance
readonly MAX_COMMITS_PREVIEW=20
readonly MAX_FILES_PREVIEW=10

# Branch base para comparação (detecta automaticamente)
BASE_BRANCH=""

#============================================================
# DEPENDENCY CHECK
#============================================================

check_dependencies() {
  local missing_deps=()

  # Verificar gum
  if ! command -v gum &> /dev/null; then
    missing_deps+=("gum")
  fi

  # Verificar git
  if ! command -v git &> /dev/null; then
    missing_deps+=("git")
  fi

  # Se houver dependências faltando, mostrar erro e sair
  if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "❌ Dependências faltando: ${missing_deps[*]}"
    echo ""
    echo "Instale o gum:"
    echo "  • Ubuntu/Debian:"
    echo "    sudo mkdir -p /etc/apt/keyrings"
    echo "    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg"
    echo "    echo \"deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *\" | sudo tee /etc/apt/sources.list.d/charm.list"
    echo "    sudo apt update && sudo apt install gum"
    echo ""
    echo "  • macOS:"
    echo "    brew install gum"
    echo ""
    echo "  • Binário:"
    echo "    https://github.com/charmbracelet/gum/releases"
    echo ""
    exit 1
  fi
}

# Detectar branch base (main ou master)
detect_base_branch() {
  if git show-ref --verify --quiet refs/heads/main; then
    BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master; then
    BASE_BRANCH="master"
  else
    # Usar branch atual como fallback
    BASE_BRANCH=$(git branch --show-current)
  fi

  echo "$BASE_BRANCH"
}

# Verificar se está em um repositório git
check_git_repo() {
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    if command -v gum &> /dev/null; then
      gum style \
        --foreground="$COLOR_ERROR" \
        --border="rounded" \
        --padding="1 2" \
        "❌ Erro: Não está em um repositório Git"
    else
      echo "❌ Erro: Não está em um repositório Git"
    fi
    exit 1
  fi
}

#============================================================
# ENTRY POINT (parcial - apenas para Story S1)
#============================================================

main() {
  # Verificar se está em repositório git
  check_git_repo

  # Verificar dependências
  check_dependencies

  # Detectar branch base
  BASE_BRANCH=$(detect_base_branch)

  # Testar se tudo funcionou
  if command -v gum &> /dev/null; then
    gum style \
      --foreground="$COLOR_SUCCESS" \
      --border="rounded" \
      --padding="1 2" \
      "✅ Inicialização concluída com sucesso!

Branch base detectada: $BASE_BRANCH
Branches protegidas: ${PROTECTED_BRANCHES[*]}
Padrões de exclusão: ${EXCLUDE_PATTERNS[*]:-nenhum}

Versão: $VERSION"
  else
    echo "✅ Inicialização OK - Branch base: $BASE_BRANCH"
  fi
}

# Executar
main "$@"
