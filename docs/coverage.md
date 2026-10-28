# Cobertura de auditoria

Este documento registra o que foi realmente exercitado, o que é apenas
verificado estaticamente e o que ainda não tem cobertura. Ele existe para evitar
a impressão de que um `check.sh` verde significa que todo o projeto foi testado.

## Estado atual

| Área | Cobertura | Evidência |
|---|---|---|
| QML das 40 superfícies | estática + módulos puros + runtime | lint em 126 arquivos, baseline de 180 ocorrências, testes Node, harness Quickshell e smoke de abertura |
| Settings e hubs | boa | lint, contrato, navegação por teclado, harness QML e Security com fingerprint/idle agrupados |
| Barra e status | boa | contrato de status, smoke, reorder físico e cancelamento com Escape |
| Pacotes | boa | parser puro + testes Node; health por fonte, idade e fallback |
| Scripts Hyprland | parcial | `sh -n`, testes de launch-guard, updater e wallcolors |
| Helpers TLP/ThinkPad | boa + adversarial | testes próprios, casos de metacaracteres/argumentos extras e selftest do installer |
| Instalador Python | lógica, matriz e deploy isolado | dry-run, selftests, matriz de 5 famílias e deploy/re-deploy/uninstall em config root temporário |
| CI | gate estático | workflow em push/PR; QML e Hyprland ficam no gate local |
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
- que drag, wheel e teclado se comportam como esperado em todas as combinações;
- que o instalador real (não dry-run) é idempotente em todas as distros;
- que o lock shell autentica e desbloqueia corretamente;
- que o consumo de RAM fica dentro de um limite.

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

1. gesto físico final de drag/back em compositor real;
2. lock sobre duas saídas em sessão supervisionada;
3. matriz de instalação em VMs por distro;
4. fuzz adversarial mais agressivo dos helpers e do updater;
5. orçamento de PSS definido a partir de medições reais;
6. decisão sobre remover dedos extras do `fprintd`;
6. teste multi-monitor em hardware com duas saídas.
