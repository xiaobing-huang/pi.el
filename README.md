# Pi

An Emacs client for [Pi Coding Agent](https://pi.dev/)

![screenshot](docs/screenshot.png)

## Setup

### Install the Pi Agent

```bash
npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# Start Pi and run `/login` to configure your provider
pi
```

### Install `pi.el`

```elisp
(use-package pi
  :ensure t
  :vc (:url "git@github.com:ananthakumaran/pi.el.git"
       :rev :newest)
  :commands (pi-chat))
```

## Usage

Run `M-x pi-chat` from any file in your project to start a Pi chat
session. Checkout [documentation](https://ananthakumaran.in/pi.el/)
for more details.
