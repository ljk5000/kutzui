# Contributing

Small fixes and bug reports are welcome.

## Bugs

Open a [GitHub issue](https://github.com/ljk5000/kutzui/issues). Say what you expected, what
happened, and the version in `KutzUI/KutzUI.toc`. A `/kutz mon` summary helps when an addon errors.
Do not paste saved-variable files, character or guild names, or chat logs.

## Security

See [SECURITY.md](SECURITY.md). Use private vulnerability reporting for a security issue. Do not
file it as a public issue.

## Working on the code

You need Node 22. From `tools/`:

```
npm ci
node check_all.js ../KutzUI
```

`RESULT` lines and `ALL CHECKS PASSED` are the bar. Details are in [tools/README.md](tools/README.md).
The fake game checks the addon's own logic. It cannot tell you how a frame looks in the client.

A module that is switched off must create no frames, timers, or events. Do not hook Blizzard
frames or functions: on this client a hook runs inside Blizzard's call and taints it. Poll
instead, the way the existing modules do.

Match the style of the file you are editing. A comment should say what the code is doing, or why
the client forces a choice.

Do not commit saved variables, screenshots of a live character, chat, or anything under `export/`.
Do not add tags. Version and release steps are in the README, and the maintainer cuts releases.
