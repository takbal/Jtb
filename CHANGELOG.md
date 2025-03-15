# Changelog

## 0.3.15 (2025-03-15)


Full set of changes: [`0.3.14...0.3.15`](https://github.com/takbal/Jtb/compare/0.3.14...0.3.15)

## 0.3.14 (2025-03-15)


Full set of changes: [`0.3.13...0.3.14`](https://github.com/takbal/Jtb/compare/0.3.13...0.3.14)

## 0.3.13 (2025-03-15)


Full set of changes: [`0.3.12...0.3.13`](https://github.com/takbal/Jtb/compare/0.3.12...0.3.13)

## 0.3.12 (2025-03-15)

#### New Features

* update to 1.11.4

Full set of changes: [`0.3.10...0.3.12`](https://github.com/takbal/Jtb/compare/0.3.10...0.3.12)

## 0.3.10 (2025-03-12)

#### New Features

* added @sp macro that allows clearing thread state
* added gc_if (conditional GC)

Full set of changes: [`0.3.9...0.3.10`](https://github.com/takbal/Jtb/compare/0.3.9...0.3.10)

## 0.3.9 (2024-01-02)

#### New Features

* updated packages

Full set of changes: [`0.3.8...0.3.9`](https://github.com/takbal/Jtb/compare/0.3.8...0.3.9)

## 0.3.8 (2023-12-13)

#### New Features

* updated to 1.9
* parexec tests
* parexec tool for threaded execution with repo, progress, logging, parameter sweeps
* added files unit test
* added get_common_path_prefix()
* sample parquet for images
* added Parquet image command
#### Fixes

* removed Parameters dependency
* removed Params dependency, using @kwdefs
* KeyedArray matrices plotting
* image commands
* propfill for 1-dimensional arrays

Full set of changes: [`0.3.7...0.3.8`](https://github.com/takbal/Jtb/compare/0.3.7...0.3.8)

## 0.3.7 (2023-09-06)

#### New Features

* added unit test, return values for parexec
* new threaded parallel sweeper over keyword params
* added adaptive fractiler
* added get_field_sizes()
#### Fixes

* initial check-in for new projects

Full set of changes: [`0.3.6...0.3.7`](https://github.com/takbal/Jtb/compare/0.3.6...0.3.7)

## 0.3.6 (2023-05-28)

#### New Features

* use include_plotlyjs for disp'ed plots
* added equal_partition to exported
* trace_fractile: Y STDs are now scaled to mean rather log
#### Fixes

* non-recursive without join

Full set of changes: [`0.3.5...0.3.6`](https://github.com/takbal/Jtb/compare/0.3.5...0.3.6)

## 0.3.5 (2023-05-03)

#### New Features

* trace_fractile: added log for Y stds
* added forced symbol parsing

Full set of changes: [`0.3.4...0.3.5`](https://github.com/takbal/Jtb/compare/0.3.4...0.3.5)

## 0.3.4 (2023-04-21)

#### New Features

* ensure readd dev packages

Full set of changes: [`0.3.3...0.3.4`](https://github.com/takbal/Jtb/compare/0.3.3...0.3.4)

## 0.3.3 (2023-04-11)

#### New Features

* added the ability to add repos after creation
* moved files into mkj project; installation script

Full set of changes: [`0.3.2...0.3.3`](https://github.com/takbal/Jtb/compare/0.3.2...0.3.3)

## 0.3.2 (2023-04-09)

#### New Features

* register command: allow registering at any registry

Full set of changes: [`0.3.1...0.3.2`](https://github.com/takbal/Jtb/compare/0.3.1...0.3.2)

## 0.3.1 (2023-04-07)

#### New Features

* support for csv.gz
* added getdir() to list directories
* auto-stepping in get_color
* opened up colorway functions
* moved Revise first in startup
* added AcceleratedArrays support for convert_kc
* added disp() for plotly figs over net
#### Fixes

* plotting export
* gitlab repo

Full set of changes: [`0.3.0...0.3.1`](https://github.com/takbal/Jtb/compare/0.3.0...0.3.1)

## 0.3.0 (2023-03-09)

#### New Features

* overhaul to match changes in mkj
* shell function to call julia
* large overhaul of mkj. Moved into mkj.toml all config
