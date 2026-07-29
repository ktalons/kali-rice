# legacy — the i3 attempt

The first version of this repo was an i3 rice: tiling, polybar, picom.

It was dropped on 2026-07-29 after using it. The tiling model was the
problem, not the configuration. i3's tabbed layout is a property of a
container in its tree, not a task list, so windows could not be moved
between "tabs" the way a taskbar implies, and mixing a terminal with a GUI
tool like dirbuster squeezed both into unusable strips. i3 also destroys
empty workspaces, so the bar only ever showed workspaces that already had
windows in them — which read as "clicking the workspace does nothing".

XFCE does one-app-per-screen with a real bottom taskbar natively, and was
already installed. The Catppuccin theming, HTB tooling, shell, prompt and
tmux config all carried over unchanged; only the window manager changed.

These files still work if you want to go back — `kali-desktop-i3` is still
installed and i3 remains selectable at the greeter. They are simply no
longer linked into $HOME by the bootstrap.
