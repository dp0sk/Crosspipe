#!/usr/bin/env bash

flatpak-builder build-flatpak/build io.github.dp0sk.Crosspipe.yml --force-clean
flatpak build-export build-flatpak/export build-flatpak/build
flatpak build-bundle build-flatpak/export build-flatpak/io.github.dp0sk.Crosspipe.flatpak io.github.dp0sk.Crosspipe