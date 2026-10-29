# Estudo de RAM da pill

Medição no host, eDP-1, Quickshell 0.3.2, Qt 6.12.0. PSS vem de
`/proc/<pid>/smaps_rollup`; RSS é mostrado só como referência porque superestima
bibliotecas Qt compartilhadas.

## Números atuais

| Estado | PSS | RSS |
|---|---:|---:|
| Idle limpo | 142,5 MB | 230,7 MB |
| Bar settings | 165,8 MB | 261,2 MB |
| Após fechar Bar | 191,4 MB | 279,7 MB |
| Todas as 41 surfaces | ~280 MB | ~382 MB |
| Lock | 53,0 MB | — |
| CPU idle/pós-surface | 0,5% | — |

O budget atual é 180 MB idle, 230 MB post e 55 MB lock. O uso normal passa; o
stress de todas as surfaces não.

## O que a medição por página mostra

Processo recém-iniciado, abrindo uma página por vez e medindo PSS logo depois:

```text
bar           181,6 MB
settings      181,3 MB
sysmon        195,9 MB
appearance    199,2 MB
display       203,0 MB
keybinds      210,4 MB
packages      210,7 MB
mixer         213,6 MB
wallpaper     217,2 MB
power         219,2 MB
after-tail    218,7 MB
```

Isso não significa que cada página custe sempre dezenas de MB. A primeira
abertura da Bar tem o maior salto; depois, tipos e componentes compartilhados já
estão no processo, e páginas seguintes acrescentam poucos MB cada.

## Causa raiz

1. **A Bar é a página mais pesada para iniciar.** Ela contém o editor de
   componentes, a lista de status, zonas e controles. O compactador reduziu o
   pico de ~198 MB para a faixa de 166–181 MB, mas ela ainda é a maior parcela
   de cache inicial.
2. **O Loader frio libera objetos, não o cache de tipos QML.** Depois que uma
   página foi carregada, o `QQmlEngine` mantém tipos, unidades compiladas,
   bindings e caches ligados à engine até o processo morrer. Por isso fechar as
   surfaces não devolve a PSS ao valor limpo. Isso é cache de processo, não um
   crescimento sem limite.
3. **Repetir a mesma página estabiliza.** Abrir/fechar Bar dez vezes estabilizou
   perto de 176–191 MB, enquanto abrir 41 páginas diferentes chegou a ~280 MB.
   O padrão é de cache por tipo/página, não de vazamento por ciclo.
4. **A base já está relativamente enxuta.** `MALLOC_CONF` já usa
   `retain:false` e decay curto. O PSS anônimo é a maior parte; as bibliotecas
   compartilhadas ficam em torno de 37–41 MB de PSS_File.
5. **Status e serviços sempre vivos** continuam sendo a principal oportunidade
   de baixar o idle, mas não resolvem sozinhos o stress de 41 páginas.

## Evidência de que reiniciar a engine resolve

Um processo limpo volta para ~142 MB. Um processo que abriu as páginas fica em
~218 MB com dez páginas e ~280 MB com todas as 41. A diferença é memória de
engine/cache, não estado funcional que precise ficar residente.

## Opções

### A. Cluster de status sob demanda

Impacto estimado no idle: **15–25 MB**.
Impacto no stress: pequeno.
Custo: médio. Exige separar a fileira de status em um componente/loader e
resolver largura, âncoras do Ame e a primeira abertura.

Não é um ganho de stress. É a melhor opção para reduzir o piso de RAM.

### B. Serviços ociosos preguiçosos

Impacto estimado: **5–15 MB**.
Custo: baixo a médio.
Candidatos: `Cliphist`, `Weather`, `PackageUpdates`, `Walls` e modelos de mídia
quando não há consumidor visível. Precisa manter o ícone da barra correto e
evitar atraso perceptível.

### C. Enxugar a página Bar

Impacto no pico normal: **10–20 MB**.
Impacto no stress: baixo a médio.
Custo: médio. A lista de status/zonas e o editor ainda criam muitos objetos.
Um editor com um item por vez já foi feito; o próximo passo é reduzir a lista
de status a uma lista virtualizada ou a uma única linha selecionada, se isso
não custar navegação.

### D. Consolidar tipos das páginas de Settings

Impacto no stress: **potencial de 40–80 MB**.
Impacto no idle: baixo.
Custo: alto.
É a opção com melhor retorno para o cenário de 41 páginas: em vez de 30+ QML
types únicos, usar uma shell de Settings e páginas dirigidas por dados, com
poucos delegates reutilizados. Menos tipos no cache, menos bindings e menos
objetos por página.

### E. Isolar Settings em outro processo

Impacto no stress: pode zerar o cache no processo da pill, mas **duplica a base
Qt/QML** enquanto o segundo processo estiver aberto.
Custo: alto.
Para uma página, a soma pode ficar pior que o processo único. Só faz sentido
com um processo de Settings que carrega uma página e é encerrado depois.

### F. Reciclar o processo depois de ociosidade

Impacto: devolve o processo ao piso de ~142 MB.
Custo de UX: o shell reinicia; se a pill estiver escondida, o efeito é pequeno,
mas há risco de flicker, perda de estado transitório e reaparecimento do crash
reporter. Não deve ser o caminho principal; serve como último recurso opcional.

### G. Variáveis de cache/JIT

`QML_DISABLE_DISK_CACHE` atua no cache em disco, não necessariamente no cache
de tipos residente. Desligar JIT pode reduzir páginas de código, mas costuma
aumentar CPU. Não há evidência, nas medições atuais, de que isso resolva os
~140 MB de cache de páginas; precisa de A/B antes de virar padrão.

## Recomendação

Ordem de maior retorno sem sacrificar a experiência:

1. **Cluster de status sob demanda** para baixar o idle.
2. **Serviços ociosos preguiçosos** para completar o piso.
3. **Enxugar a Bar** para reduzir o primeiro pico.
4. **Consolidar os tipos de Settings** para atacar o stress de verdade.
5. Só então considerar reciclagem de processo ou isolamento.

Metas realistas:

```text
idle           120–130 MB PSS
Bar aberta     150–170 MB PSS
10 páginas     190–210 MB PSS
41 páginas     210–230 MB PSS
CPU            <= 0,5%
```

## Gates propostos

- Medir PSS em idle limpo, após uma página e após a varredura das 41.
- Registrar PSS por página para detectar regressão de cache.
- Manter o gate de CPU pós-fechamento em <= 0,5%.
- Comparar sempre processo limpo versus processo com cache; não misturar os
  dois números.

## Referências

- [Qt QML Disk Cache](https://doc.qt.io/archives/qt-6.4/qmldiskcache.html)
- [Qt Quick Deployment](https://doc.qt.io/qt-6.8/qtquick-deployment.html)

## Atualização após implementar o cluster lazy

A fileira de status agora é criada por `BarStatusRow.qml` somente quando a barra
está expandida. Medi again com dois monitores conectados (eDP-1 + HDMI-A-1):

```text
idle, status não carregado   158,7 MB PSS   0,4% CPU
hover, status carregado      187,5 MB PSS
todas as 41 surfaces         328,0 MB PSS
```

A diferença de ~29 MB entre idle e hover mostra o ganho do carregamento lazy.
O stress de páginas continua sendo cache de tipos QML; ele não é resolvido por
esse carregamento e segue como o próximo alvo arquitetural.
