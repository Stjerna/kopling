# difforama

See what changed in a git repo, and how the changes connect, on a canvas
in your browser. Made for reviewing work done by coding agents.

## Install

Linux and macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/Stjerna/difforama/main/install.sh | sh
```

It updates itself once a day. Run `difforama update` to update now.

## Use

Run it inside a git repo:

```sh
difforama
```

It opens the canvas in your browser on your uncommitted changes, so an
agent's edits show up as it works. Use `-b main` for your branch's work,
or `-l 1` for the last commit. Run `difforama --help` for more.

## What it does

- Each changed file is a card. Arrows join a file to the code it uses.
- Click a file to see its diff, its changed functions, and what it uses
  and what uses it.
- The riskiest files are marked, with what to check: callers not
  updated, new dead code, a missing test, and more.
- Files are numbered in reading order, so you meet the building blocks
  first.
- Group files by folder or by role, like test, controller or config.
- Filters narrow the canvas by folder, language, impact and more.
- Live mode follows along while an agent works.
- Open your GitHub pull requests, comment on lines, and approve, without
  leaving the page.
- Put several repos on one canvas. An API call links to the controller
  that serves it in another repo, through your OpenAPI files.
- Language servers check the links, when you have them installed.
- Open a file in your editor, and commit or discard from the page.

## Privacy

Everything runs on your machine. The canvas is a local server at
`http://localhost:4747`. It only answers its own page, and only your user
on the computer.
