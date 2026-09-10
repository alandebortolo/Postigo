# Postigo — o que o app é

Decisão de 2026-09-09. App interno, um Mac, sem distribuição.
Nome e ícone: 2026-09-09 (postigo = a portinhola na porta por onde se olha quem chegou).

Não é câmera invisível. O LED verde da FaceTime acende sempre que a sessão de captura está
ligada; no MacBook fechar a tampa desliga a câmera. O produto é câmera de presença na mesa:
menu bar, cota de disco, modo ausente que finge o Mac dormido.

Bundle id `br.com.designmaster.postigo`. Ninguém instalou ainda, então não há
permissão de Câmera nem pasta antiga para preservar (2026-09-10).

## Modos

- Parado: ícone no tray, LED apagado, zero disco.
- Gravando: webcam contínua em segmentos. Default da gravação manual: guarda mesmo sem movimento.
- Ausente: overlay preto em todos os displays, brilho 0, Dock/menu escondidos, Mac não dorme.
  Default: só promove arquivo se houver movimento (pré-roll de um segmento ~20 s + trailing 10 s).
  Mouse não acorda; marca intrusão e força guardar o clipe.
  Qualquer tecla acorda e para a gravação (2026-09-10: o atalho+PIN saiu porque atrapalhava).

## Disco

- Default `~/Movies/Postigo` (fora do iCloud Documents). Pasta configurável.
- Cota 10 GB, retenção 48 h.
- Apaga o mais antigo sem movimento primeiro. Clipe `_motion` / `_preroll` e JPEG não saem
  para abrir cota — se só restar protegido acima da cota, a gravação para.
- 720p 15 fps HEVC (fallback H.264) ~800 kbps.

## Fora de escopo de propósito

- Sem áudio (default).
- Sem captura de tela.
- Sem upload, Telegram, aviso no celular.
- Sem esconder LED, sem esconder do Activity Monitor.
