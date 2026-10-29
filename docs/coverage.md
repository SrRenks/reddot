# Cobertura de auditoria

Este documento registra o que foi realmente exercitado, o que é apenas
verificado estaticamente e o que ainda não tem cobertura. Ele existe para evitar
a impressão de que um `check.sh` verde significa que todo o projeto foi testado.

## Estado atual

| Área | Cobertura | Evidência |
|---|---|---|
| QML das 41 superfícies | estática + módulos puros + runtime | lint em 128 arquivos, baseline de 180 ocorrências, testes Node, harness Quickshell e smoke de abertura |
| Settings e hubs | boa | lint, contrato, navegação por teclado, harness QML e Security com fingerprint/idle agrupados |
| Navegação e nomes | fase 1 + Search | manifesto `lib/navigation.js`, tooltips de status, ranking puro, contrato com catálogo/hubs |
| Search | página funcional | `Search.qml`, `lib/search.js`, testes Node, aliases/tags/disponibilidade |
| Barra e status | boa | contrato, smoke, wheel no painel, reorder físico, Escape-cancel, back por catálogo, lastSurface e uiScale 1.25 |
| Pacotes | boa | parser puro + testes Node; backends pacman/dnf/zypper/apt, health por fonte, idade e fallback |
| Scripts Hyprland | parcial | `sh -n`, launch-guard, updater, wallcolors, wallpaper-search sem Python e auditoria de runtime |
| Helpers TLP/ThinkPad | boa + adversarial | testes próprios, casos de metacaracteres/argumentos extras e selftest do installer |
| Instalador Rust | quatro famílias em VM real + recusas explícitas | Arch/Debian 13/Fedora 44/Tumbleweed; quickstart, apply, uninstall e reboot; Leap/Gentoo recusados antes do plano |
| CI | gate estático | workflow em push/PR; QML e Hyprland ficam no gate local; Ubuntu verde após os fixes de portabilidade |
| Harness Python | arquivado | fora do checkout; testes de paridade Python saíram do CI |
| Systemd/udev/polkit/TLP | parcial | udev verify, sintaxe JS da regra polkit, contrato estático do target, política TLP |
| Hyprland/Lua | parcial | `Hyprland --verify-config`, `luac -p` |
| Lock shell | PAM real + duas saídas físicas | QML lint, `check-lock-static.sh`, senha/fingerprint supervisionados; `secure=true` e UI em eDP-1 + HDMI-A-1; autenticação PAM não repetida nesta rodada |
| Documentação | estrutura e links | `check-doc-links.mjs` e docs obrigatórios |
| Performance/RAM | medida e orçamento nesta máquina | PSS/RSS de pill, lock e estados de Settings; `test-perf-budget.sh` host-only |
| Segurança dos helpers | boa | allowlist, polkit, sudoers, guards e casos adversariais de argumentos |

O lock shell foi revisado estaticamente. Ele cria `WlSessionLock` e só chama
`locked = true` pelo gatilho `doLock()`; mesmo assim, um smoke de runtime poderia
bloquear a sessão, então a execução fica fora do gate automático.

## O que os testes não provam

- que o layout de cada superfície está bonito ou legível em toda fonte/escala;
- que cada interação física funciona em todos os temas, escalas e monitores;
- que o instalador real é idempotente em reinstalações repetidas nas quatro famílias;
- que o updater aplica uma atualização real com conflito e rollback em toda instalação;
- que o hotplug por cabo físico e o DPI misto funcionam em todas as combinações;
- que todas as interações individuais de cada superfície estão corretas;
- que o consumo de RAM obedece ao orçamento em máquinas diferentes.

## Leitura quantitativa

Não existe instrumentação de cobertura QML neste repositório; a porcentagem abaixo
é uma **estimativa ponderada por risco**, não um número de cobertura de código.
Ela usa os gates e os testes executados nesta sessão.

| Eixo | Peso | Estado | Cobertura |
|---|---:|---|---:|
| Catálogo, contratos e lint QML | 25% | 41/41 superfícies; 128 QML; 0 warnings novos | 100% |
| Lógica pura e busca | 15% | fuzzy, scroll, ordem, pacotes, search e navegação com testes Node | 100% |
| Runtime das superfícies | 20% | Search, Settings, Bar, lock e smoke das superfícies; não todas manualmente | 85% |
| Lock e autenticação | 15% | PAM real, fingerprint, duas saídas headless | 95% |
| Instalador Rust | 10% | quatro famílias em VM real; duas recusadas por design; updater apply real ainda não exercitado | 90% |
| CI e documentação | 10% | CI Ubuntu verde; links e docs obrigatórios | 100% |
| Hardware e performance | 5% | PSS na máquina de referência; duas saídas físicas no shell; hotplug/DPI misto/lock físico pendentes | 85% |

A estimativa numérica anterior ficou desatualizada com as VMs reais. O repositório
não tem instrumentação de cobertura; a tabela acima é a leitura qualitativa atual,
e os descontos principais são updater apply, hotplug/DPI/lock físico e interações
individuais das superfícies.

## Comandos

```text
sh tools/check.sh                 gate padrão
sh tools/smoke-surfaces.sh        smoke visual de runtime
node tools/check-ui-contract.mjs  contrato estático de UI
node tools/check-qml-warnings.mjs baseline de warnings QML
sh tools/check-hypr-api.sh        API Hyprland e sintaxe Lua
node tools/check-doc-links.mjs    links relativos da documentação
sh tools/check-qml-runtime.sh     harness Quickshell sem janela
```

O `check.sh` roda os gates de contrato, testes, lint dos QML deployados,
baseline de warnings do checkout, scripts, Lua, API Hyprland, documentação e
drift entre checkout e deploy. A matriz de instalação fica em `check-static.sh`
e nos testes Rust de instalação.

## Próximos alvos, se houver outro ciclo

1. updater real com conflito de arquivo e rollback (o apply limpo já passou);
2. hotplug por cabo físico e DPI misto; o lock físico e o hotplug headless já passaram;
3. foco/ativação linha a linha na Search e controles individuais das 41 superfícies;
4. reinstall idempotente nas outras três famílias;
5. decidir sobre dedos extras do `fprintd`.

Leap 15.6 e Gentoo não são pendências de teste: foram removidos do suporte oficial
pela [ADR 0034](decisions/0034-supported-matrix.md).
