# Convenções de QML e Hyprland

Este documento fixa as regras que o gate do repositório verifica. Ele cobre o
que o projeto tem de específico; o guia genérico de QML e a wiki do Hyprland
continuam sendo a fonte de linguagem e de opções.

## QML

### Superfícies

Toda página da pill deriva de `PillSurface` ou de `SettingsSurface`. A página
declara `implicitHeight`, registra suas linhas em `rows` e deixa o host cuidar
de morph, foco, clique de fora, scroll e animação.

`PillSurface` é a única dona do viewport. Não adicione `WheelHandler` na página,
nem um `MouseArea` que consuma wheel: o backdrop do shell é o único caminho de
scroll. A barra de rolagem é desenhada pelo host a partir de
`SurfaceChrome.scrollTarget`.

### Singletons

Estado compartilhado entre pill e lock deriva de `Singleton` e é declarado em
`Singletons/qmldir`. O nome importado é o mesmo do arquivo e do `qmldir`.
Defaults de configuração vivem em `Flags`; estado derivado de processo ou de
arquivo vive no singleton que o possui.

Um singleton não deve criar outra instância de si mesmo. Funções expostas para
delegates são chamadas pelo nome do singleton, como `Players.isIdle()`.

### Componentes e delegates

Delegates usam `required property` para os dados que recebem. Quando um
componente inline precisa acessar ids do componente externo, o arquivo recebe
`pragma ComponentBehavior: Bound`; não adicione esse pragma em massa sem testar
porque ele altera a resolução de ids em componentes aninhados.

`Loader` é usado para superfícies que precisam existir de forma síncrona para
medir tamanho e responder ao morph. `LazyLoader` é apropriado para janelas ou
conteúdo que pode ser criado depois, em tempo de frame. A escolha atual da pill
permanece `Loader` até existir um teste de ciclo de vida que justifique a troca.

### Imports

Imports ficam no topo, em ordem estável: QtQuick, Quickshell, submódulos,
Singletons, JS. JS puro compartilhado fica sob `Singletons/` quando o único
consumidor é um singleton, ou sob `lib/` quando é uma biblioteca geral. Evite import de arquivo `.js` entre diretórios a
partir de um singleton; um parser local no próprio diretório `Singletons/` é
resolvido sem a ambiguidade de caminho.

### Escala, fonte e medidas

Medidas visuais são derivadas de `s`, que vem da escala da tela e de
`Flags.uiScale`. Não use pixels fixos para espaçamento, raio, ícone ou
scrollbar. Texto elide quando divide espaço com um controle; não deixe uma
label crescer sobre o controle.

### Warnings

`qmllint` tem baseline em `tools/qml-warning-baseline.json`. O gate falha em
qualquer warning novo. A baseline é atualizada apenas depois de revisar a
mensagem e confirmar que ela não esconde um problema real:

```text
node tools/check-qml-warnings.mjs --update
```

Não use a baseline para aceitar um novo erro de QML. `Error:` é sempre falha.

## Hyprland

### API Lua

Módulos usam a API atual do Hyprland:

- configuração: `hl.config`
- binds: `hl.bind` e `hl.dsp.*`
- regras de janela: `hl.window_rule`
- regras de layer: `hl.layer_rule`
- execução em evento: `hl.exec_cmd` enquanto o evento exigir, ou o dispatcher
  equivalente quando a documentação confirmar a mesma semântica

Não use `windowrulev2`, `layerrule =` textual, `bind =` textual ou outras formas
legadas. O check `tools/check-hypr-api.sh` rejeita essas formas nos `.lua`.

### Módulos

Cada módulo tem um dono: `decoration.lua`, `input.lua`, `monitors.lua`,
`animations.lua`, `binds.lua`, `autostart.lua`, `window_rules.lua` e
`ui-blur.lua`. Um módulo não reescreve o estado de outro. Regras de layer da
pill ficam em `ui-blur.lua`; regras de janela ficam em `window_rules.lua`.

Depois de editar Lua, valide com:

```text
luac -p configs/hypr/modules/*.lua
Hyprland --verify-config
hyprctl configerrors
```

### Documentação

As fontes usadas para esta convenção foram consultadas em 2026-10-28:

- [Hyprland config options](https://wiki.hypr.land/configuring/core/config-options/)
- [Hyprland layer rules](https://wiki.hypr.land/configuring/core/rules/layer-rules/)
- [Hyprland window rules](https://wiki.hypr.land/configuring/core/rules/window-rules/)
- [Quickshell PanelWindow](https://quickshell.org/docs/v0.3.2/types/Quickshell/PanelWindow/)
- [Quickshell LazyLoader](https://quickshell.org/docs/v0.3.2/types/Quickshell/LazyLoader/)
- [Quickshell Singleton](https://quickshell.org/docs/v0.3.2/types/Quickshell/Singleton/)
- [Quickshell Variants](https://quickshell.org/docs/v0.3.2/types/Quickshell/Variants/)
- [Quickshell QML language](https://quickshell.org/docs/v0.3.2/guide/qml-language/)
