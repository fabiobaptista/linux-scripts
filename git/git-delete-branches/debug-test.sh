#!/usr/bin/env bash

# Script de debug para identificar onde falha
LOGFILE="/tmp/git-delete-branches-debug.log"

echo "=== DEBUG LOG - $(date) ===" > "$LOGFILE"
echo "TERM=$TERM" >> "$LOGFILE"
echo "Shell: $SHELL" >> "$LOGFILE"
echo "WSL: $(uname -a)" >> "$LOGFILE"
echo "" >> "$LOGFILE"

# Testar cada comando gum individualmente
echo "[TEST 1] gum style simples..." | tee -a "$LOGFILE"
if gum style "Teste" 2>> "$LOGFILE"; then
    echo "  ✅ OK" | tee -a "$LOGFILE"
else
    echo "  ❌ FALHOU (exit code: $?)" | tee -a "$LOGFILE"
fi

echo "" >> "$LOGFILE"
echo "[TEST 2] gum style com cores..." | tee -a "$LOGFILE"
if gum style --foreground="#7D56F4" "Teste colorido" 2>> "$LOGFILE"; then
    echo "  ✅ OK" | tee -a "$LOGFILE"
else
    echo "  ❌ FALHOU (exit code: $?)" | tee -a "$LOGFILE"
fi

echo "" >> "$LOGFILE"
echo "[TEST 3] gum style com italic..." | tee -a "$LOGFILE"
if gum style --foreground="#7D56F4" --italic "Teste italic" 2>> "$LOGFILE"; then
    echo "  ✅ OK" | tee -a "$LOGFILE"
else
    echo "  ❌ FALHOU (exit code: $?)" | tee -a "$LOGFILE"
fi

echo "" >> "$LOGFILE"
echo "[TEST 4] gum style com border..." | tee -a "$LOGFILE"
if gum style --border="rounded" --border-foreground="#7D56F4" "Teste border" 2>> "$LOGFILE"; then
    echo "  ✅ OK" | tee -a "$LOGFILE"
else
    echo "  ❌ FALHOU (exit code: $?)" | tee -a "$LOGFILE"
fi

echo "" >> "$LOGFILE"
echo "[TEST 5] gum choose..." | tee -a "$LOGFILE"
if echo -e "Opção 1\nOpção 2\nExit" | gum choose --header="Teste" 2>> "$LOGFILE"; then
    echo "  ✅ OK (selecionou: $?)" | tee -a "$LOGFILE"
else
    echo "  ❌ FALHOU (exit code: $?)" | tee -a "$LOGFILE"
fi

echo "" >> "$LOGFILE"
echo "=== Teste do script real ===" | tee -a "$LOGFILE"

# Testar chamadas que o script faz
echo "[TEST 6] show_banner simulation..." | tee -a "$LOGFILE"
if gum style \
    --foreground="#7D56F4" \
    --border="rounded" \
    --border-foreground="#7D56F4" \
    --padding="1 4" \
    --width=50 \
    --align="center" \
    "Git Branch Delete v2.0.0" 2>> "$LOGFILE"; then
    echo "  ✅ OK" | tee -a "$LOGFILE"
else
    echo "  ❌ FALHOU (exit code: $?)" | tee -a "$LOGFILE"
fi

echo "" >> "$LOGFILE"
echo "[TEST 7] gum choose com argumentos diretos (como no menu)..." | tee -a "$LOGFILE"
echo "Selecione uma opção e pressione Enter:" | tee -a "$LOGFILE"

set +e
choice=$(gum choose \
    --header="Menu Principal" \
    --header.foreground="#7D56F4" \
    --selected.foreground="#02BA84" \
    --cursor.foreground="#7D56F4" \
    "Deletar branches" \
    "Ver branches protegidas" \
    "Ajuda" \
    "Exit" 2>> "$LOGFILE")
exit_code=$?
set -e

echo "  Exit code: $exit_code" | tee -a "$LOGFILE"
echo "  Choice: '$choice'" | tee -a "$LOGFILE"
echo "  Choice length: ${#choice}" | tee -a "$LOGFILE"

if [ $exit_code -eq 0 ] && [ -n "$choice" ]; then
    echo "  ✅ OK - Selecionou: $choice" | tee -a "$LOGFILE"
else
    echo "  ❌ PROBLEMA - exit_code=$exit_code, choice='$choice'" | tee -a "$LOGFILE"
fi

echo "" | tee -a "$LOGFILE"
echo "=== Resultados ===" | tee -a "$LOGFILE"
echo "Log completo salvo em: $LOGFILE"
cat "$LOGFILE"
