# Git Branch Delete - Enhanced UI

Script interativo para deletar branches Git de forma segura com interface visual moderna usando `gum`.

## Características

- 🎨 **Interface visual moderna** com `gum` (Charm CLI framework)
- 🔄 **Loop automático** de exclusão - delete múltiplas branches em sequência
- 📊 **Preview completo** com informações detalhadas da branch:
  - Autor do último commit
  - Data de criação e último commit
  - Commits ahead/behind da branch base
  - Status merged/not merged
  - Arquivos modificados
  - Git log (últimos 20 commits)
- 🛡️ **Proteção inteligente** de branches importantes (main, master, development, etc.)
- ❓ **Tela de ajuda integrada** com instruções completas
- 🚀 **Seleção múltipla** de branches com filtro
- ⚡ **Performance otimizada** para repositórios grandes
- ✅ **Validações de segurança** - previne deleção de branch atual ou protegidas
- 🎯 **Fallback completo** - funciona sem gum (modo texto simples)

## Dependências

- **git** (geralmente já instalado)
- **gum** (Charm CLI framework) - *recomendado para interface visual*

### Instalação do gum

**Ubuntu/Debian:**
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum
```

**macOS:**
```bash
brew install gum
```

**Windows (WSL):**
Use as instruções do Ubuntu/Debian acima.

**Binário (todas as plataformas):**
https://github.com/charmbracelet/gum/releases

**Nota:** O script funciona sem gum, mas com interface de texto simples.

## Uso

### Básico

```bash
cd seu-repositorio
./git-delete-branches-v2.sh
```

Você verá um menu interativo com 4 opções:
1. **Deletar branches** - Selecione branches para deletar
2. **Ver branches protegidas** - Lista branches que nunca serão deletadas
3. **Ajuda** - Instruções completas de uso
4. **Exit** - Sair do script

### Com Padrões de Exclusão

Exclua branches que contêm padrões específicos além das protegidas:

```bash
# Excluir branches contendo "1234" ou "hotfix"
./git-delete-branches-v2.sh 1234 hotfix

# Excluir branches de uma sprint específica
./git-delete-branches-v2.sh sprint-42
```

Esses padrões serão adicionados à lista de exclusão junto com as branches protegidas.

## Navegação

### Com gum (interface visual)
- `↑↓` - Mover entre opções
- `SPACE` - Selecionar/desselecionar branch
- `ENTER` - Confirmar seleção
- `ESC` - Voltar ao menu
- `CTRL+C` - Sair imediatamente
- Digite texto para **filtrar** a lista de branches

### Sem gum (modo texto)
- Digite o **número** da opção desejada
- Para seleção múltipla: `1 3 5` (números separados por espaço)
- `y/N` - Confirmar ações
- `CTRL+C` - Sair

## Branches Protegidas

As seguintes branches **NUNCA** serão deletadas automaticamente:
- `main`
- `master`
- `development`
- `develop`
- `staging`
- `production`

Essas branches não aparecem na lista de seleção e são filtradas automaticamente.

## Preview de Branches

Ao selecionar branches para deletar, você verá informações detalhadas:

```
Branch: feature/nova-funcionalidade
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 Criada: 2025-11-15 10:30
👤 Último autor: fabiobaptista
📝 Último commit: 2025-11-28 11:37 (5 minutes ago)

📊 Status:
  • 3 commits à frente de main
  • 0 commits atrás de main
  • Estado: Not merged

📁 Arquivos modificados (últimos 10):
  • src/components/Header.tsx
  • src/utils/helpers.ts
  • README.md

📋 Commits recentes (últimos 20):
* abc1234 Fix header bug
* def5678 Add helper functions
...
```

Essas informações ajudam você a decidir se realmente quer deletar a branch.

## Validações de Segurança

O script implementa **3 camadas de validação** antes de deletar cada branch:

1. ✅ **Branch existe?** - Verifica se a branch realmente existe no repositório
2. ✅ **Não é protegida?** - Garante que não está na lista de branches protegidas
3. ✅ **Não é a atual?** - Previne deleção da branch em que você está trabalhando

Se qualquer validação falhar, a branch é **ignorada** com mensagem clara do motivo.

## Fluxo de Uso

```
┌─────────────────┐
│  Menu Principal │
└────────┬────────┘
         │
         ├─→ Deletar branches
         │   ├─→ Selecionar branches (com preview)
         │   ├─→ Confirmar deleção
         │   ├─→ Executar deleção (com validações)
         │   └─→ Voltar ao menu  ← Loop automático!
         │
         ├─→ Ver branches protegidas
         │   └─→ Voltar ao menu
         │
         ├─→ Ajuda
         │   └─→ Voltar ao menu
         │
         └─→ Exit
             └─→ Sair do script
```

**Destaque:** Após deletar branches, você volta automaticamente ao menu! Pode deletar várias branches em sequência sem reiniciar o script.

## FAQ

### P: Como adicionar mais branches protegidas?

**R:** Edite a variável `PROTECTED_BRANCHES` no início do script:

```bash
readonly PROTECTED_BRANCHES=("main" "master" "development" "develop" "staging" "production" "sua-branch")
```

### P: O script funciona em repositórios muito grandes?

**R:** Sim! O preview é limitado a:
- **20 commits** no git log
- **10 arquivos** na lista de modificados

Isso garante performance mesmo em repos com milhares de commits.

### P: Posso deletar a branch atual?

**R:** Não, o script previne isso automaticamente com uma validação. Você verá um erro claro:

```
❌ Erro: Não é possível deletar a branch atual (sua-branch)

Mude para outra branch primeiro:
  git checkout main
```

### P: O que acontece se eu tentar deletar uma branch protegida?

**R:** A branch será **ignorada** automaticamente com mensagem de erro. O script nunca permite deletar branches protegidas, mesmo se você tentar forçar.

### P: Como funciona sem gum?

**R:** O script detecta automaticamente se gum está instalado. Sem gum, você verá:
- Menus numerados (1, 2, 3, 4)
- Input via teclado tradicional
- Texto simples sem cores

Todas as funcionalidades continuam funcionando, apenas sem a interface visual bonita.

### P: Posso usar em ambiente WSL?

**R:** Sim! Funciona perfeitamente no WSL. Siga as instruções de instalação do gum para Ubuntu/Debian.

## Exemplos de Uso

### Exemplo 1: Limpar branches de feature antigas

```bash
./git-delete-branches-v2.sh

# No menu: escolha "1) Deletar branches"
# Selecione múltiplas branches antigas
# Confirme a deleção
# Script volta ao menu automaticamente
```

### Exemplo 2: Limpar branches de uma sprint específica

```bash
# Excluir branches da sprint-15 da lista
./git-delete-branches-v2.sh sprint-15

# Agora branches contendo "sprint-15" não aparecerão
```

### Exemplo 3: Ver quais branches estão protegidas

```bash
./git-delete-branches-v2.sh

# No menu: escolha "2) Ver branches protegidas"
# Verá a lista completa + padrões de exclusão CLI
```

## Estrutura de Arquivos

```
git-delete-branches/
├── git-delete-branches.sh          # Script original (fzf)
├── git-delete-branches-v2.sh       # Script novo (gum) ← Use este!
└── README.md                       # Esta documentação
```

## Versão

**v2.0.0** - Reescrita completa com gum, loop automático, validações e preview completo.

Versão anterior (v1.x): Usava `fzf`, sem loop, sem validações robustas.

## Licença

MIT

## Contribuindo

Contribuições são bem-vindas! Por favor:
1. Fork o repositório
2. Crie uma branch para sua feature
3. Commit suas mudanças
4. Abra um Pull Request

## Suporte

Para reportar bugs ou sugerir melhorias:
- Abra uma issue no repositório
- Descreva o problema ou sugestão claramente
- Inclua informações do ambiente (OS, versão do bash, versão do gum)

---

**Desenvolvido com ❤️ usando [gum](https://github.com/charmbracelet/gum)**
