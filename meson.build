project('Crosspipe', 'vala', 'c',
  version: '0.1.1',
  license: 'GPL-3.0-only',
  meson_version: '>= 0.59.0',
  default_options: [
    'warning_level=2',
    'werror=false',
  ],
)

# Application ID
app_id = 'io.github.dp0sk.Crosspipe'

# Dependencies
gtk_dep = dependency('gtk4', version: '>= 4.10')
adw_dep = dependency('libadwaita-1', version: '>= 1.4')
gee_dep = dependency('gee-0.8')
pipewire_dep = dependency('libpipewire-0.3')
xml_dep = dependency('libxml-2.0')

# Vala compiler
valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')
m_dep = cc.find_library('m', required: false)

# Configuration
conf_data = configuration_data()
conf_data.set_quoted('APP_ID', app_id)
conf_data.set_quoted('APP_NAME', 'Crosspipe')
conf_data.set_quoted('APP_VERSION', meson.project_version())
conf_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
conf_data.set_quoted('DATADIR', get_option('prefix') / get_option('datadir'))

config_file = configure_file(
  input: 'src/config.vala.in',
  output: 'config.vala',
  configuration: conf_data,
)

# Source files
sources = files(
  'src/Application.vala',
  'src/Window.vala',
  
  # Canvas
  'src/canvas/Canvas.vala',
  'src/canvas/CanvasItem.vala',
  'src/canvas/Node.vala',
  'src/canvas/Port.vala',
  'src/canvas/Connection.vala',
  
  # Backend
  'src/backend/Backend.vala',
  'src/backend/PipeWireBackend.vala',
  
  # Commands
  'src/commands/Command.vala',
)

# C sources for PipeWire wrapper
c_sources = files(
  'src/backend/pipewire_wrapper.c',
)


# Executable
executable('crosspipe',
  sources,
  c_sources,
  config_file,
  include_directories: include_directories('src/backend'),
  dependencies: [
    gtk_dep,
    adw_dep,
    gee_dep,
    xml_dep,
    m_dep,
    pipewire_dep,
  ],
  vala_args: [
    '--target-glib=2.76',
    '--pkg=posix',
    '--pkg=libxml-2.0',
    '--vapidir=' + meson.current_source_dir() / 'src/vapi',
    meson.current_source_dir() / 'src/vapi/gpw.vapi',
  ],
  install: true,
)


# Data files
subdir('data')

# Translations
# subdir('po')

# Summary
summary({
  'prefix': get_option('prefix'),
  'bindir': get_option('prefix') / get_option('bindir'),
  'datadir': get_option('prefix') / get_option('datadir'),
}, section: 'Directories')

summary({
  'GTK4': gtk_dep.version(),
  'Libadwaita': adw_dep.version(),
  'PipeWire': pipewire_dep.version(),
}, section: 'Dependencies')
