# KeyboardBlock

App de barra de menu para **bloquear o teclado do MacBook** enquanto você limpa
as teclas fisicamente.

Sem desligar a máquina: o bloqueio acontece com o Mac ligado, então apertar
tecla não liga nada. O teclado volta com um clique do mouse.

```
⌨️  ícone cinza   → teclado normal
⌨️  1:47 (vermelho) → teclado bloqueado, faltam 1min47s
```

## Como funciona

Cria um [`CGEventTap`](https://developer.apple.com/documentation/coregraphics) no
nível da sessão e descarta os eventos de teclado (`keyDown`, `keyUp`,
`flagsChanged`, teclas de mídia). Não usa `sudo`, não altera nada em disco e não
persiste estado no sistema.

**Falha segura por construção:** o tap vive dentro do processo. Se o app travar,
for morto ou você clicar em "Sair", o teclado volta na hora. É a diferença
principal em relação a remapear teclas com `hidutil`, que deixa o sistema num
estado persistente e pode te trancar fora.

## Instalação

Requer macOS 13+ e Xcode Command Line Tools.

```bash
./scripts/install.sh
```

Depois:

1. Abra: `open -a KeyboardBlock`
2. Clique no ícone da barra de menu → **Bloquear teclado**.
3. O macOS vai pedir **Acessibilidade**. Ative o KeyboardBlock em
   *Ajustes do Sistema › Privacidade e Segurança › Acessibilidade*.
4. **Feche e reabra o app** (a permissão só vale no próximo lançamento).

> Instale em `/Applications` **antes** de conceder a permissão. O macOS amarra a
> permissão ao caminho/assinatura do app — se você conceder em `build/` e depois
> mover, precisa conceder de novo.

## Uso

| Ação | Como |
|---|---|
| Bloquear | clique no ícone → **Bloquear teclado** |
| Liberar | clique no ícone → **Liberar agora** |
| Liberar sem olhar a barra | **segure o botão direito por 1,5s** |
| Liberar sozinho | timer de 1/2/5/10 min (padrão: 2 min) |

O tempo é **sempre limitado** — não existe "bloquear para sempre". Três redes de
segurança independentes: o timer, o gesto de botão direito e o fato de o tap
morrer junto com o processo.

## Limitações (honestas)

- **Não impede ligar o Mac.** Com a máquina desligada nenhum software roda — a
  tecla liga o Mac e ponto. O fluxo correto é limpar com o Mac **ligado e o
  teclado bloqueado**, em vez de desligado.
- **Bloqueia todos os teclados**, não só o interno. Se você tem teclado externo e
  precisa dele durante a limpeza, esse não é o app (exigiria `IOKit` seize com
  root).
- **Teclas de mídia/brilho** também são bloqueadas, mas o *display* ainda pode
  acordar com uma tecla pressionada — o evento morre depois do handler de power.
- **Precisa de Acessibilidade**, e a permissão está ligada à assinatura do
  binário. Com assinatura ad-hoc, cada `./scripts/build-app.sh` pode exigir nova
  concessão. Para evitar:

  ```bash
  CODESIGN_IDENTITY="Apple Development: voce@exemplo.com (XXXXXXXXXX)" ./scripts/build-app.sh
  ```

  (ou crie um certificado autoassinado no Acesso às Chaves e use o nome dele)
- **Fora da App Store.** Sandbox não combina com event tap de bloqueio.
  Distribuir para terceiros exigiria notarização.

## Ícone do app

`Resources/AppIcon.png` (quadrado, 1024×1024, full-bleed) é convertido em
`AppIcon.icns` no build, com as 10 resoluções, e referenciado por
`CFBundleIconFile`. Também aceita um `.icns` pronto em `Resources/AppIcon.icns`.

No macOS 26 o sistema aplica a máscara squircle e o fundo de vidro por cima —
por isso a arte vai full-bleed, sem margem e sem cantos arredondados.

O ícone da **barra de menu** é outro: um SF Symbol (`keyboard` / `keyboard.fill`)
definido em `AppDelegate.updateAppearance()`.

## Estrutura

```
Sources/KeyboardBlock/
  main.swift            boot do NSApplication como app de barra (LSUIElement)
  AppDelegate.swift     ícone, menu, timer, gesto de escape
  KeyboardBlocker.swift CGEventTap: cria, descarta eventos, reativa se o
                        sistema desativar por timeout
Resources/Info.plist    bundle (LSUIElement=true, sem Dock icon)
Resources/AppIcon.png   arte do ícone (1024x1024, full-bleed)
scripts/build-app.sh    compila e monta o .app
scripts/make-icns.sh    PNG -> .icns com as 10 resoluções
scripts/install.sh      build + copia para /Applications
```

## Desenvolvimento

```bash
swift build            # compila
./scripts/build-app.sh # gera build/KeyboardBlock.app
```

Testar o bloqueio de verdade exige conceder Acessibilidade — não dá para
automatizar isso sem interação no diálogo do sistema.
