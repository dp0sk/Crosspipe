# Crosspipe

![Crosspipe Icon](https://raw.githubusercontent.com/dp0sk/Crosspipe/refs/heads/main/attachments/icon.svg)

## PipeWire graph GTK4/Libadwaita GUI.
Crosspipe is a visual graph manager for PipeWire, built with GTK4/Libadwaita and Vala, following the GNOME Human Interface Guidelines.

![Light theme](https://raw.githubusercontent.com/dp0sk/Crosspipe/refs/heads/main/attachments/screenshot-light.png)
![Dark theme](https://raw.githubusercontent.com/dp0sk/Crosspipe/refs/heads/main/attachments/screenshot-dark.png)

https://raw.githubusercontent.com/dp0sk/Crosspipe/refs/heads/main/attachments/screencast.mp4

## Features

- Visual graph of PipeWire nodes and connections
- Drag-and-drop connection management
- Native GTK4/Libadwaita interface, following GNOME HIG

## Dependencies

- GTK4 >= 4.10
- libadwaita >= 1.4
- libgee 0.8
- libpipewire 0.3
- libxml-2.0
- valac

## Building Flatpak from source

Clone the repository:

```bash
git clone https://github.com/dp0sk/Crosspipe.git
cd Crosspipe
```

Build & Install using the manifest:

```bash
flatpak-builder builddir io.github.dp0sk.Crosspipe.yml --user --install
```

Run:

```bash
flatpak run io.github.dp0sk.Crosspipe
```

Uninstall:

```bash
flatpak uninstall --user io.github.dp0sk.Crosspipe
```

## Building from source (meson)

Clone the repository:

```bash
git clone https://github.com/dp0sk/Crosspipe.git
cd Crosspipe
```

Set up the build directory:

```bash
meson setup build
```

Compile:

```bash
meson compile -C build
```

Install (requires root or sudo):

```bash
sudo meson install -C build
```

Run:

```bash
crosspipe
```
