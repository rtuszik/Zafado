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

## Configuration

The server looks for a `config.toml` file in the current working directory. The parser expects a simple flat key-value pair format (prop=value).

Supported configuration keys:

| Key | Description | Example |
| :--- | :--- | :--- |
| `printer.ip` | IP address of the network printer | `192.168.1.50` |
| `printer.port` | Port of the network printer | `9100` |
| `server.port` | HTTP server listening port | `8080` |

### Example `config.toml`

```toml
printer.ip=192.168.1.50
printer.port=9100
server.port=8080
```

> [!NOTE]
> Only network printers are currently supported via configuration. The format does NOT support TOML tables yet (e.g. `[printer]`), only flat keys.

## API Reference

### Print Todo

Submit a text body to be printed on the configured thermal printer.

- **URL**: `/todo`
- **Method**: `POST`
- **Body**: Plain text content
- **Success Response**:
  - **Code**: `201 Created`
  - **Content**: `Todo printed!`

**Example:**
```bash
curl -X POST http://localhost:8080/todo -d "Buy milk"
```


### Check Status

Get the current number of items in the print queue.

- **URL**: `/status`
- **Method**: `GET`
- **Success Response**:
  - **Code**: `200 OK`
  - **Content**: `Queue has <N> items`

**Example:**
```bash
curl http://localhost:8080/status
```


## Build & Run

Requires Zig 0.15.2

### Run

```bash
zig build run
```

### Test

```bash
zig build test
```

### Binary

You can also build the binary directly:

```bash
zig build
```

The binary will be available at `zig-out/bin/Zafado`. You can run it like this:

```bash
./zig-out/bin/Zafado
```

