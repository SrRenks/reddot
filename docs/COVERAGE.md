# Cobertura de auditoria

Este documento registra o que foi realmente exercitado, o que é apenas
verificado estaticamente e o que ainda não tem cobertura. Ele existe para evitar
a impressão de que um `check.sh` verde significa que todo o projeto foi testado.

## Estado atual

| Área | Cobertura | Evidência |
|---|---|---|
| QML das 40 superfícies | estática completa + smoke de abertura | `qmllint` em 117 arquivos, `check-surfaces.mjs`, `check-ui-contract.mjs`, `smoke-surfaces.sh` |
| Settings e hubs | boa | lint, contrato de linhas, navegação por teclado, smoke de abertura |
| Barra e status | boa | contrato de status, smoke, reorder manual |
| Pacotes | boa | parser puro + 18 fixtures Node; health por fonte, idade e fallback |
| Scripts Hyprland | parcial | `sh -n`, testes de launch-guard, updater e wallcolors |
| Helpers TLP/ThinkPad | boa | testes próprios + selftest do installer |
| Instalador Python | boa para lógica | dry-run, deploy/distro/pkg/fallbacks/tui selftests em tempdir |
| Systemd/udev/polkit/TLP | parcial | udev verify, sintaxe JS da regra polkit, forma do target, política TLP |
| Hyprland/Lua | parcial | `Hyprland --verify-config`, `luac -p` |
| Lock shell | apenas sintaxe | QML lint; sem smoke de autenticação/bloqueio |
| Documentação | revisão de caminhos | sem link checker automatizado |
| Performance/RAM | não coberta | sem medição contínua nem orçamento |
| Segurança dos helpers | parcial | allowlist e polkit inspecionados, sem teste adversarial |

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
```

O `check.sh` roda o contrato, o gate de integração, os testes existentes, o lint
de todos os QML, scripts, Lua, Hyprland e drift.

## Próximos alvos, se houver outro ciclo

1. teste de comportamento Qt Quick para scroll, drag e back;
2. smoke do lock shell;
3. orçamento de PSS/RAM e tempo de abertura dos hubs;
4. revisão adversarial dos helpers e do updater;
5. link checker da documentação.
