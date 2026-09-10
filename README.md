<p align="center">
  <img src="docs/postigo.png" width="128" alt="Ícone do Postigo: uma portinhola de latão com fresta acesa">
</p>

# Postigo

A portinhola na porta por onde se olha quem chegou. Fica na barra de menu do Mac, grava a webcam, e quando você sai da sala a tela apaga e a câmera continua.

## Instalar

Cola isto no Terminal e aperta Enter. Não precisa de Xcode, Git, nem conta.

```bash
curl -fsSL https://raw.githubusercontent.com/alandebortolo/Postigo/main/install.sh | bash
```

Ele baixa o app, põe em `~/Applications`, tira o aviso de “desenvolvedor não identificado” e abre. Mac com chip da Apple (M1 ou mais novo) e macOS 14 ou mais novo.

Se o Terminal te assustar: [baixa o Postigo.zip](https://github.com/alandebortolo/Postigo/releases/latest), dá dois cliques, arrasta o `Postigo.app` para Aplicativos, depois **clica com o botão direito > Abrir**.

O ícone mora na barra de menu, em cima à direita. Não aparece no Dock.

## Primeiro minuto

1. Clica no ícone da portinhola.
2. **Preferências** — a câmera aparece ao vivo. O Mac pede permissão de Câmera: deixa.
3. **Gravar** liga. **Parar** desliga. **Sair da sala** apaga a tela e segue gravando.
4. Quando voltar, aperta **qualquer tecla**. A tela acende e a gravação para.

Mouse não acorda. Se alguém mexer no mouse enquanto você está fora, o Postigo marca e guarda o clipe.

## O que ele faz

| | |
|---|---|
| Parado | Só o ícone. LED da câmera apagado. |
| Gravando | Webcam contínua, 720p, sem áudio. |
| Ausente | Tela preta. Só guarda quando tem movimento (uns 20 s antes e 10 s depois). Qualquer tecla acorda. |

Arquivos em `~/Movies/Postigo`. Teto de 10 GB: o lixo sai primeiro, clipe com movimento não. Se o disco encher de evidência, ele para em vez de apagar.

O LED verde da FaceTime **acende sempre** que está gravando. No MacBook a câmera está na tampa: fechar a tampa desliga.

## Desinstalar

Mata o app, joga `~/Applications/Postigo.app` no Lixo. As gravações ficam em `~/Movies/Postigo` até você apagar a pasta.

```bash
killall Postigo 2>/dev/null; rm -rf ~/Applications/Postigo.app
```

## Compilar

Quem já tem Xcode:

```bash
git clone https://github.com/alandebortolo/Postigo.git
cd Postigo
make install
```
