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
| Scripts Hyprland | parcial | `sh -n`, testes de launch-guard, updater e wallcolors |
| Helpers TLP/ThinkPad | boa + adversarial | testes próprios, casos de metacaracteres/argumentos extras e selftest do installer |
| Instalador Python | lógica, matriz e deploy isolado | dry-run, selftests, matriz de 5 famílias e deploy/re-deploy/uninstall em config root temporário |
| CI | gate estático | workflow em push/PR; QML e Hyprland ficam no gate local; Ubuntu verde após os fixes de portabilidade |
| Systemd/udev/polkit/TLP | parcial | udev verify, sintaxe JS da regra polkit, contrato estático do target, política TLP |
| Hyprland/Lua | parcial | `Hyprland --verify-config`, `luac -p` |
| Lock shell | PAM real + two outputs | QML lint, `check-lock-static.sh`, senha/fingerprint supervisionados e `WlSessionLock.secure=true` em eDP-1 + headless |
| Documentação | estrutura e links | `check-doc-links.mjs` e docs obrigatórios |
| Performance/RAM | medida e orçamento nesta máquina | PSS/RSS de pill, lock e estados de Settings; `test-perf-budget.sh` host-only |
| Segurança dos helpers | boa | allowlist, polkit, sudoers, guards e casos adversariais de argumentos |

O lock shell foi revisado estaticamente. Ele cria `WlSessionLock` e só chama
`locked = true` pelo gatilho `doLock()`; mesmo assim, um smoke de runtime poderia
bloquear a sessão, então a execução fica fora do gate automático.

## O que os testes não provam

- que o layout de cada superfície está bonito ou legível em toda fonte/escala;
- que cada interação física funciona em todos os temas, escalas e monitores;
- que o instalador real (não dry-run) é idempotente em todas as distros;
- que o updater aplica uma atualização real sem conflito em toda instalação;
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
| Instalador | 10% | matriz de 5 famílias + dry-run + deploy sandbox; sem VMs reais | 75% |
| CI e documentação | 10% | CI Ubuntu verde; links e docs obrigatórios | 100% |
| Hardware e performance | 5% | PSS na máquina de referência; sem duas saídas físicas | 80% |

**Estimativa atual: ~93% dos caminhos críticos e ~82% do projeto total.**

Os maiores descontos são os testes que exigem VMs reais, duas saídas físicas,
foco por linha na Search e uma aplicação real do updater.

## Comandos

```text
sh tools/check.sh                 gate padrão
sh tools/smoke-surfaces.sh        smoke visual de runtime
sh tools/check-integration.sh     instalador + arquivos de sistema
node tools/check-ui-contract.mjs  contrato estático de UI
node tools/check-qml-warnings.mjs baseline de warnings QML
sh tools/check-hypr-api.sh        API Hyprland e sintaxe Lua
node tools/check-doc-links.mjs    links relativos da documentação
sh tools/check-qml-runtime.sh     harness Quickshell sem janela
```

O `check.sh` roda os gates de contrato, integração, testes, lint dos QML
deployados, baseline de warnings do checkout, scripts, Lua, API Hyprland,
documentação e drift entre checkout e deploy.

## Próximos alvos, se houver outro ciclo

1. matriz de instalação em VMs por distro;
2. decisão sobre remover dedos extras do `fprintd`;
3. teste multi-monitor em hardware físico com duas saídas.
