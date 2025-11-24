# Zafado

Simple ToDo Printing for ESC/POS Printers

> [!NOTE]
> This is mostly a PoC at this point in time and will probably not work with your printer.

## Overview

A lightweight HTTP server that accepts todo items via API and prints them instantly on ESC/POS thermal printers.

## Features

- REST API for todo submission
- Direct ESC/POS thermal printer support
- Zero external dependencies
- Immediate printing (stateless operation)

## Quick Start

Requires Zig 0.14.1

```bash
zig build run
```

## API Endpoints

- `POST /todo`: Print raw body text
- `GET /status`: Get queue size

