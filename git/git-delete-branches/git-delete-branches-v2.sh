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
# ERROR HANDLING & VALIDATION
#============================================================

# Validar se branch existe
validate_branch_exists() {
  local branch="$1"

  if ! git show-ref --verify --quiet "refs/heads/$branch"; then
    if command -v gum &> /dev/null; then
      gum style \
        --foreground="$COLOR_ERROR" \
        "❌ Branch '$branch' não existe"
    else
      echo "❌ Branch '$branch' não existe"
    fi
    return 1
  fi

  return 0
}

# Validar se branch está protegida
validate_not_protected() {
  local branch="$1"

  for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [ "$branch" = "$protected" ]; then
      if command -v gum &> /dev/null; then
        gum style \
          --foreground="$COLOR_ERROR" \
          "❌ Branch '$branch' está protegida e não pode ser deletada"
      else
        echo "❌ Branch '$branch' está protegida e não pode ser deletada"
      fi
      return 1
    fi
  done

  return 0
}

# Prevenir exclusão da branch atual
check_current_branch() {
  local branch="$1"
  local current_branch
  current_branch=$(git branch --show-current)

  if [ "$branch" = "$current_branch" ]; then
    if command -v gum &> /dev/null; then
      gum style \
        --foreground="$COLOR_ERROR" \
        --border="rounded" \
        --padding="1 2" \
        "❌ Erro: Não é possível deletar a branch atual ($current_branch)

Mude para outra branch primeiro:
  git checkout main"
    else
      echo "❌ Erro: Não é possível deletar a branch atual ($current_branch)"
      echo ""
      echo "Mude para outra branch primeiro:"
      echo "  git checkout main"
    fi
    return 1
  fi

  return 0
}

# Executar comando git com tratamento de erro
safe_git_command() {
  local output
  local exit_code

  output=$(git "$@" 2>&1)
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    if command -v gum &> /dev/null; then
      gum style \
        --foreground="$COLOR_ERROR" \
        --border="rounded" \
        --padding="1 2" \
        "❌ Erro no comando git:

$output"
    else
      echo "❌ Erro no comando git: $output"
    fi
    return $exit_code
  fi

  echo "$output"
  return 0
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
# UI FUNCTIONS - Menu & Selection
#============================================================

# Menu principal
show_main_menu() {
  clear
  show_banner

  if command -v gum &> /dev/null; then
    local choice
    choice=$(gum choose \
      --header="$(gum style --bold 'Menu Principal')" \
      --header.foreground="$COLOR_PRIMARY" \
      --selected.foreground="$COLOR_SUCCESS" \
      "Deletar branches" \
      "Ver branches protegidas" \
      "Ajuda" \
      "Exit")

    echo "$choice"
  else
    # Fallback sem gum
    cat <<EOF
Menu Principal:
  1) Deletar branches
  2) Ver branches protegidas
  3) Ajuda
  4) Exit
EOF
    echo ""
    read -p "Escolha uma opção (1-4): " choice

    case "$choice" in
      1) echo "Deletar branches" ;;
      2) echo "Ver branches protegidas" ;;
      3) echo "Ajuda" ;;
      4) echo "Exit" ;;
      *) echo "" ;; # Cancelado
    esac
  fi
}

# Exibir branches protegidas
show_protected_branches() {
  clear

  if command -v gum &> /dev/null; then
    gum style \
      --border="rounded" \
      --border-foreground="$COLOR_WARNING" \
      --padding="1 2" \
      "$(cat <<EOF
$(gum style --bold --foreground="$COLOR_WARNING" "Branches Protegidas")

Estas branches NUNCA serão deletadas:

$(printf '  • %s\n' "${PROTECTED_BRANCHES[@]}")

$([ ${#EXCLUDE_PATTERNS[@]} -gt 0 ] && echo -e "\nPadrões de exclusão (CLI):\n$(printf '  • %s\n' "${EXCLUDE_PATTERNS[@]}")")
EOF
)"

    echo ""
    gum confirm "Voltar ao menu?" --default=yes --affirmative="Sim" --negative="Não" || return
  else
    # Fallback sem gum
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Branches Protegidas

Estas branches NUNCA serão deletadas:

$(printf '  • %s\n' "${PROTECTED_BRANCHES[@]}")
EOF

    if [ ${#EXCLUDE_PATTERNS[@]} -gt 0 ]; then
      echo ""
      echo "Padrões de exclusão (CLI):"
      printf '  • %s\n' "${EXCLUDE_PATTERNS[@]}"
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    read -p "Pressione ENTER para voltar..."
  fi
}

# Seleção de branches para deletar
select_branches_to_delete() {
  local base_branch="$1"

  clear
  show_banner
  show_context_message "Use ↑↓ para navegar, SPACE para selecionar, ENTER para confirmar"

  # Obter branches candidatas
  local candidates
  candidates=$(get_candidate_branches)

  if [ -z "$candidates" ]; then
    if command -v gum &> /dev/null; then
      gum style \
        --foreground="$COLOR_WARNING" \
        --border="rounded" \
        --padding="1 2" \
        "⚠️  Nenhuma branch disponível para deletar"
      echo ""
      gum confirm "Voltar ao menu?" --default=yes || return
    else
      echo "⚠️  Nenhuma branch disponível para deletar"
      echo ""
      read -p "Pressione ENTER para voltar..."
    fi
    return 1
  fi

  # Adicionar opção "← Exit" no topo
  local options="← Exit"$'\n'"$candidates"

  if command -v gum &> /dev/null; then
    # Seleção com gum filter (permite múltipla seleção)
    local selected
    selected=$(echo "$options" | gum filter \
      --placeholder="Digite para filtrar... (ESC para voltar)" \
      --indicator="●" \
      --no-limit)

    # Se selecionou Exit ou cancelou
    if [ -z "$selected" ] || echo "$selected" | grep -q "← Exit"; then
      return 1
    fi

    echo "$selected"
  else
    # Fallback sem gum - lista numerada
    echo "Branches disponíveis para deleção:"
    echo "  0) ← Exit (voltar)"
    echo ""

    local -a branch_array
    local index=1
    while IFS= read -r branch; do
      echo "  $index) $branch"
      branch_array[$index]="$branch"
      ((index++))
    done <<< "$candidates"

    echo ""
    read -p "Digite os números das branches separados por espaço (ex: 1 3 5): " selections

    if [ -z "$selections" ] || [[ "$selections" == *"0"* ]]; then
      return 1
    fi

    # Converter seleções em branches
    local selected_branches=""
    for num in $selections; do
      if [ "$num" -gt 0 ] && [ "$num" -lt "$index" ]; then
        selected_branches+="${branch_array[$num]}"$'\n'
      fi
    done

    echo "${selected_branches%$'\n'}"
  fi
}

# Confirmação de deleção
confirm_deletion() {
  local branches="$1"
  local count
  count=$(echo "$branches" | wc -l)

  echo ""

  if command -v gum &> /dev/null; then
    gum style \
      --foreground="$COLOR_WARNING" \
      --bold \
      "⚠️  Deletar $count branch(es) selecionada(s)?"

    echo ""
    gum style --foreground="$COLOR_ERROR" "Branches que serão DELETADAS:"
    echo "$branches" | while read -r branch; do
      gum style --foreground="$COLOR_ERROR" "  • $branch"
    done
    echo ""

    gum confirm \
      "Confirmar deleção?" \
      --default=no \
      --affirmative="Sim, deletar" \
      --negative="Não, cancelar"
  else
    # Fallback sem gum
    echo "⚠️  Deletar $count branch(es) selecionada(s)?"
    echo ""
    echo "Branches que serão DELETADAS:"
    echo "$branches" | while read -r branch; do
      echo "  • $branch"
    done
    echo ""

    read -p "Confirmar deleção? (y/N): " confirm
    [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]
  fi
}

# Deletar branches
delete_branches() {
  local branches="$1"

  echo ""

  if command -v gum &> /dev/null; then
    gum style --foreground="$COLOR_INFO" "Deletando branches..."
  else
    echo "Deletando branches..."
  fi

  echo ""

  local success=0
  local failed=0
  local skipped=0

  while IFS= read -r branch; do
    [ -z "$branch" ] && continue

    # Validações de segurança
    if ! validate_branch_exists "$branch"; then
      ((skipped++))
      continue
    fi

    if ! validate_not_protected "$branch"; then
      ((skipped++))
      continue
    fi

    if ! check_current_branch "$branch"; then
      ((skipped++))
      continue
    fi

    # Tentar deletar
    if git branch -D "$branch" &> /dev/null; then
      if command -v gum &> /dev/null; then
        gum style --foreground="$COLOR_SUCCESS" "✓ $branch deletada"
      else
        echo "✓ $branch deletada"
      fi
      ((success++))
    else
      if command -v gum &> /dev/null; then
        gum style --foreground="$COLOR_ERROR" "✗ Falha ao deletar $branch"
      else
        echo "✗ Falha ao deletar $branch"
      fi
      ((failed++))
    fi
  done <<< "$branches"

  echo ""

  if command -v gum &> /dev/null; then
    gum style \
      --border="rounded" \
      --border-foreground="$COLOR_SUCCESS" \
      --padding="1 2" \
      "$(cat <<EOF
$(gum style --bold --foreground="$COLOR_SUCCESS" "Concluído!")

Branches deletadas: $success
$([ $failed -gt 0 ] && echo "Falhas: $failed")
$([ $skipped -gt 0 ] && echo "Ignoradas (validação): $skipped")
EOF
)"
  else
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Concluído!

Branches deletadas: $success
$([ $failed -gt 0 ] && echo "Falhas: $failed")
$([ $skipped -gt 0 ] && echo "Ignoradas (validação): $skipped")
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
  fi

  echo ""
  sleep 2
}

#============================================================
# MAIN LOOP
#============================================================

main_loop() {
  local base_branch
  base_branch=$(detect_base_branch)

  while true; do
    # Mostrar menu principal
    local menu_choice
    menu_choice=$(show_main_menu)

    case "$menu_choice" in
      "Deletar branches")
        # Selecionar branches
        local selected_branches
        selected_branches=$(select_branches_to_delete "$base_branch")

        # Se cancelou ou selecionou Exit
        if [ $? -ne 0 ] || [ -z "$selected_branches" ]; then
          continue
        fi

        # Confirmar deleção
        if confirm_deletion "$selected_branches"; then
          delete_branches "$selected_branches"
        fi
        ;;

      "Ver branches protegidas")
        show_protected_branches
        ;;

      "Ajuda")
        show_help_screen
        ;;

      "Exit")
        clear
        if command -v gum &> /dev/null; then
          gum style \
            --foreground="$COLOR_SUCCESS" \
            "👋 Até logo!"
        else
          echo "👋 Até logo!"
        fi
        exit 0
        ;;

      *)
        # ESC ou cancelamento
        exit 0
        ;;
    esac
  done
}

#============================================================
# ENTRY POINT
#============================================================

main() {
  # Verificar se está em repositório git
  check_git_repo

  # Verificar dependências
  check_dependencies

  # Detectar branch base
  BASE_BRANCH=$(detect_base_branch)

  # Entrar no loop principal
  main_loop
}

# Executar
main "$@"
