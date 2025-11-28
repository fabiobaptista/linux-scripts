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
# GIT UTILITY FUNCTIONS
#============================================================

# Lista todas as branches locais (exceto protegidas e padrões de exclusão)
get_candidate_branches() {
  local all_excludes=("${PROTECTED_BRANCHES[@]}" "${EXCLUDE_PATTERNS[@]}")

  # Criar regex de exclusão
  local exclude_regex
  exclude_regex=$(printf "%s|" "${all_excludes[@]}")
  exclude_regex="${exclude_regex%|}"

  # Listar branches filtradas
  git branch --format="%(refname:short)" \
    | sed 's/^[ \t]*//;s/[ \t]*$//' \
    | grep -v -E "$exclude_regex" || true
}

# Obter informações completas sobre uma branch
get_branch_info() {
  local branch="$1"
  local base_branch="$2"

  # Autor e data do último commit
  local last_commit_info
  last_commit_info=$(git log -1 --format="%an|%ad|%ar" --date=format:"%Y-%m-%d %H:%M" "$branch" 2>/dev/null || echo "Unknown|Unknown|Unknown")

  local author last_date relative_date
  IFS='|' read -r author last_date relative_date <<< "$last_commit_info"

  # Data de criação da branch (primeiro commit)
  local creation_date
  creation_date=$(git log --reverse --format="%ad" --date=format:"%Y-%m-%d %H:%M" "$branch" 2>/dev/null | head -1 || echo "Unknown")

  # Commits à frente e atrás da base
  local ahead behind
  ahead=$(git rev-list --count "$base_branch".."$branch" 2>/dev/null || echo "0")
  behind=$(git rev-list --count "$branch".."$base_branch" 2>/dev/null || echo "0")

  # Status de merge
  local merge_status="Not merged"
  if git merge-base --is-ancestor "$branch" "$base_branch" 2>/dev/null; then
    merge_status="✓ Merged"
  fi

  # Arquivos modificados (últimos commits)
  local modified_files
  modified_files=$(git diff --name-only "$base_branch"..."$branch" 2>/dev/null | head -n "$MAX_FILES_PREVIEW" || echo "")

  # Retornar info (output para parsing)
  echo "AUTHOR=$author"
  echo "LAST_DATE=$last_date"
  echo "RELATIVE_DATE=$relative_date"
  echo "CREATION_DATE=$creation_date"
  echo "AHEAD=$ahead"
  echo "BEHIND=$behind"
  echo "MERGE_STATUS=$merge_status"
  echo "MODIFIED_FILES_START"
  echo "$modified_files"
  echo "MODIFIED_FILES_END"
}

# Gerar preview completo de uma branch para o gum
generate_branch_preview() {
  local branch="$1"
  local base_branch="$2"

  # Obter informações
  local info
  info=$(get_branch_info "$branch" "$base_branch")

  # Parse das informações
  local author last_date relative_date creation_date ahead behind merge_status modified_files
  local in_files=false
  modified_files=""

  while IFS= read -r line; do
    if [[ "$line" == "MODIFIED_FILES_START" ]]; then
      in_files=true
      continue
    elif [[ "$line" == "MODIFIED_FILES_END" ]]; then
      in_files=false
      continue
    fi

    if [[ "$in_files" == true ]]; then
      modified_files+="$line"$'\n'
    else
      case "$line" in
        AUTHOR=*) author="${line#AUTHOR=}" ;;
        LAST_DATE=*) last_date="${line#LAST_DATE=}" ;;
        RELATIVE_DATE=*) relative_date="${line#RELATIVE_DATE=}" ;;
        CREATION_DATE=*) creation_date="${line#CREATION_DATE=}" ;;
        AHEAD=*) ahead="${line#AHEAD=}" ;;
        BEHIND=*) behind="${line#BEHIND=}" ;;
        MERGE_STATUS=*) merge_status="${line#MERGE_STATUS=}" ;;
      esac
    fi
  done <<< "$info"

  # Gerar preview formatado
  if command -v gum &> /dev/null; then
    gum style \
      --foreground="$COLOR_PRIMARY" \
      --bold \
      "Branch: $branch"

    echo ""
    gum style --foreground="$COLOR_INFO" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    gum style --foreground="$COLOR_WARNING" "📅 Criada: $creation_date"
    gum style --foreground="$COLOR_WARNING" "👤 Último autor: $author"
    gum style --foreground="$COLOR_WARNING" "📝 Último commit: $last_date ($relative_date)"

    echo ""
    gum style --foreground="$COLOR_INFO" "📊 Status:"
    gum style "  • $ahead commits à frente de $base_branch"
    gum style "  • $behind commits atrás de $base_branch"
    gum style "  • Estado: $merge_status"

    echo ""

    # Arquivos modificados
    if [ -n "$modified_files" ]; then
      gum style --foreground="$COLOR_INFO" "📁 Arquivos modificados (últimos $MAX_FILES_PREVIEW):"
      echo "$modified_files" | while read -r file; do
        [ -n "$file" ] && gum style "  • $file"
      done
      echo ""
    fi

    # Commits recentes
    gum style --foreground="$COLOR_INFO" "📋 Commits recentes (últimos $MAX_COMMITS_PREVIEW):"
    git log --oneline --graph --max-count="$MAX_COMMITS_PREVIEW" --color=always "$branch" 2>/dev/null || echo "  (sem commits)"
  else
    # Fallback sem gum
    echo "Branch: $branch"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Criada: $creation_date"
    echo "Último autor: $author"
    echo "Último commit: $last_date ($relative_date)"
    echo ""
    echo "Status:"
    echo "  • $ahead commits à frente de $base_branch"
    echo "  • $behind commits atrás de $base_branch"
    echo "  • Estado: $merge_status"
  fi
}

#============================================================
# UI UTILITY FUNCTIONS
#============================================================

# Exibir tela de ajuda
show_help_screen() {
  clear

  if command -v gum &> /dev/null; then
    gum style \
      --border="rounded" \
      --border-foreground="$COLOR_PRIMARY" \
      --padding="1 2" \
      --width=60 \
      "$(cat <<EOF
          AJUDA - Git Branch Delete

$(gum style --bold --foreground="$COLOR_SUCCESS" "Navegação:")
  ↑↓        Mover entre opções
  SPACE     Selecionar/desselecionar
  ENTER     Confirmar seleção
  ESC       Voltar
  CTRL+C    Sair do script

$(gum style --bold --foreground="$COLOR_SUCCESS" "Branches Protegidas:")
$(printf '  • %s\n' "${PROTECTED_BRANCHES[@]}")

$(gum style --bold --foreground="$COLOR_SUCCESS" "Argumentos CLI:")
  ./git-delete-branches.sh [padrão1] [padrão2]

  Exemplo: ./git-delete-branches.sh 1234 hotfix
  (exclui branches contendo "1234" ou "hotfix")

$(gum style --bold --foreground="$COLOR_SUCCESS" "Instalação do gum:")
  Ubuntu/Debian:
    https://github.com/charmbracelet/gum#installation

  macOS:
    brew install gum

$(gum style --bold --foreground="$COLOR_INFO" "Versão: $VERSION")
EOF
)"

    echo ""
    gum confirm "Voltar ao menu?" --default=yes --affirmative="Sim" --negative="Não" || return
  else
    # Fallback sem gum
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          AJUDA - Git Branch Delete

Navegação:
  ↑↓        Mover entre opções
  SPACE     Selecionar/desselecionar
  ENTER     Confirmar seleção
  ESC       Voltar
  CTRL+C    Sair do script

Branches Protegidas:
$(printf '  • %s\n' "${PROTECTED_BRANCHES[@]}")

Argumentos CLI:
  ./git-delete-branches.sh [padrão1] [padrão2]

  Exemplo: ./git-delete-branches.sh 1234 hotfix
  (exclui branches contendo "1234" ou "hotfix")

Instalação do gum:
  Ubuntu/Debian:
    https://github.com/charmbracelet/gum#installation

  macOS:
    brew install gum

Versão: $VERSION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
    echo ""
    read -p "Pressione ENTER para voltar..."
  fi
}

# Exibir banner inicial
show_banner() {
  if command -v gum &> /dev/null; then
    gum style \
      --foreground="$COLOR_PRIMARY" \
      --border="rounded" \
      --border-foreground="$COLOR_PRIMARY" \
      --padding="1 4" \
      --width=50 \
      --align="center" \
      "Git Branch Delete v$VERSION"
    echo ""
  else
    # Fallback sem gum
    cat <<EOF
╔════════════════════════════════════════════════╗
║     Git Branch Delete v$VERSION                 ║
╚════════════════════════════════════════════════╝
EOF
    echo ""
  fi
}

# Exibir mensagem contextual
show_context_message() {
  local message="$1"

  if command -v gum &> /dev/null; then
    gum style --foreground="$COLOR_INFO" --italic "$message"
    echo ""
  else
    # Fallback sem gum
    echo "ℹ️  $message"
    echo ""
  fi
}

#============================================================
# ENTRY POINT (parcial - para Stories S1-S3)
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

  # Testar funções UI (Story S3)
  echo ""
  echo "🧪 Testando funções UI..."
  echo ""

  # Testar show_banner
  echo "1️⃣ Testando show_banner():"
  show_banner

  # Testar show_context_message
  echo "2️⃣ Testando show_context_message():"
  show_context_message "Esta é uma mensagem contextual de teste"

  # Testar show_help_screen
  echo "3️⃣ Para testar show_help_screen(), execute:"
  echo "   bash git/git-delete-branches/git-delete-branches-v2.sh --help"
  echo ""

  # Testar funções Git (Story S2)
  echo "🧪 Testando funções Git Operations..."
  echo ""

  # Listar branches candidatas
  echo "📋 Branches candidatas para deleção:"
  local candidates
  candidates=$(get_candidate_branches)
  if [ -n "$candidates" ]; then
    echo "$candidates"

    # Testar get_branch_info e generate_branch_preview com a primeira branch
    local first_branch
    first_branch=$(echo "$candidates" | head -1)

    echo ""
    echo "📊 Preview da branch: $first_branch"
    echo ""
    generate_branch_preview "$first_branch" "$BASE_BRANCH"
  else
    echo "  (nenhuma branch disponível para deleção)"
  fi
}

# Executar
main "$@"
