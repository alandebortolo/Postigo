# Postigo

Câmera de presença no menu bar do Mac. Interno, um usuário, sem loja.

O nome é o postigo: a portinhola na porta por onde se olha quem chegou. No ausente a
tela fica preta, a webcam segue gravando, e só o atalho `Ctrl+Opt+Cmd+Shift+U` + PIN
acorda e para.

O LED verde da FaceTime acende enquanto grava. No MacBook a câmera está na tampa:
fechar a tampa desliga a captura.

## Build

```bash
./check.sh          # testes + smoke + .app
make install        # copia para ~/Applications/Postigo.app
make run
```

Primeira abertura: Ajustes > Privacidade e segurança > Câmera > Postigo. O atalho de
acordar não precisa de Acessibilidade. Sem Acessibilidade, o log de mouse no ausente
pode ficar mudo; o atalho e o PIN continuam valendo.

## Defaults

| Item | Valor |
|---|---|
| Pasta | `~/Movies/Postigo` (usa `~/Movies/DeskCam` se essa já existir) |
| Cota | 5 GB |
| Retenção | 48 h |
| Vídeo | 720p 15 fps HEVC, sem áudio |
| Manual | guarda mesmo sem movimento, segmentos de 5 min |
| Ausente | só movimento, segmentos de 20 s, pré-roll + trailing 10 s |
| PIN | `1234` (muda em Preferências) |
| Abrir no login | desligado (e, se ligar, sobe parado) |

Failsafe: bateria ≤ 10% ou cota cheia só de clipes protegidos tira o overlay e para.

## Layout da pasta

```
Recordings/   mp4 (sufixo _motion / _preroll quando for o caso)
Snapshots/    jpeg no começo do movimento e a cada 5 s enquanto houver
Temp/         segmento em andamento
events.jsonl  registro
```
