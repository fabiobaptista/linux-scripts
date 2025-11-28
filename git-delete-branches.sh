#!/usr/bin/env bash

# Branches que nunca devem ser apagadas
PROTECTED=("main" "master" "development")

# Se o usuário passar padrões por argumento ex: ./script 1234 hot
EXCLUDES=("$@")

# Junta tudo (padrões + protegidas)
ALL_EXCLUDES=("${PROTECTED[@]}" "${EXCLUDES[@]}")

# Transforma lista em regex (ex: main|master|1234)
EXCLUDE_REGEX=$(printf "%s|" "${ALL_EXCLUDES[@]}")
EXCLUDE_REGEX="${EXCLUDE_REGEX%|}"

# Lista branches e TRIM
BRANCHES=$(git branch --format="%(refname:short)" | sed 's/^[ \t]*//;s/[ \t]*$//')

# Filtra
CANDIDATES=$(echo "$BRANCHES" | grep -v -E "$EXCLUDE_REGEX")

echo "Branches candidatas:"
echo "$CANDIDATES"
echo ""

# Preview bonito e seguro
PREVIEW_CMD='git log --oneline --decorate --graph --color=always $(echo {+} | xargs) --max-count=20'

# Seleção interativa
SELECTED=$(echo "$CANDIDATES" \
  | fzf --multi \
        --ansi \
        --preview="$PREVIEW_CMD" \
        --preview-window=right:70% \
        --header="Selecione as branches que deseja APAGAR:" \
        --bind "ctrl-a:toggle-all")

if [ -z "$SELECTED" ]; then
  echo "Nenhuma branch selecionada. Saindo."
  exit 0
fi

echo ""
echo "Branches selecionadas:"
echo "$SELECTED"

echo ""
read -p "Confirmar deleção? (y/N): " CONFIRM

if [[ "$CONFIRM" != "y" ]]; then
  echo "Cancelado."
  exit 0
fi

# Deleção segura
echo "$SELECTED" | xargs -r git branch -D

echo ""
echo "Concluído."
