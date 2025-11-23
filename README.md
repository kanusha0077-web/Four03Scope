
# Four03Scope

Four03Scope is a focused **HTTP 403 bypass and behavior mapping toolkit**.

It mutates:

- Paths  
- “Trusted” headers (X-Forwarded-For, X-Real-IP, etc.)  
- HTTP methods  
- HTTP protocol versions  

…to help you spot **inconsistent access control** and potential 403 bypasses.  
It also integrates a quick **Wayback Machine** check so you can see if the target path was ever exposed historically.

> ⚠ Use this tool only on targets you are authorized to test.

---

## ✨ Features

### 1. Baseline Probe

Four03Scope first hits the target path:

BASE_URL + PATH  => baseline status and size

Every later test is compared against this baseline. Any request that changes the status code or response size is flagged as:

```text
[! interesting]
```

to make anomalies stand out.

---

### 2. Path Mutation Scan

Section: **PATH MUTATION SCAN**

Generates a large set of mutated paths:

* Dot-dot traversals
* Encoded path segments (`%2e`, `%2f`, `%00`, `%09`, `%0d`, `%20`, `%23`, etc.)
* Extra slashes, `;`, and mixing of encodings
* Common extensions: `.php`, `.asp`, `.bak`, `.env`, `.config`, `.sql`, `.json`, etc.

This is aimed at catching:

* Inconsistent normalization
* Backend routing quirks
* Misconfigured path filters and WAF rules

---

### 3. Trust Header Spoofing

Section: **TRUST HEADER SPOOFING**

Sends requests with a variety of “trust” headers:

* `X-Forwarded-For`
* `X-Forwarded-Port`
* `X-Forwarded`
* `Host`, `X-Host`
* `X-ProxyUser-Ip`
* `X-Custom-IP-Authorization`
* `X-Remote-IP`, `X-Originating-IP`, `X-Remote-Addr`, `X-Client-IP`, `X-Real-IP`
* `X-Original-URL`, `X-Rewrite-URL`

The idea is to see whether a proxy, load balancer, or app layer is:

* Misusing these for auth/ACL decisions
* Trusting spoofed internal IPs (e.g. `127.0.0.1`, `10.0.0.1`)

---

### 4. Method Surface Probe

Section: **METHOD SURFACE PROBE**

Tries:

* `PUT`, `POST`, `CONNECT`, `TRACE`, `PATCH`, `HEAD`

Some servers block `GET` but allow other verbs to hit the same path with different behavior (sometimes even 2xx).

---

### 5. Protocol Negotiation Tests

Section: **PROTOCOL NEGOTIATION TESTS**

Asks for:

* HTTP/0.9
* HTTP/1.0
* HTTP/1.1
* HTTP/2

Using curl flags like `--http0.9`, `--http1.0`, `--http1.1`, `--http2`.

This can reveal:

* Different behavior behind a proxy or CDN
* Legacy handlers that don’t enforce the same ACLs

---

### 6. Archive Recon (Wayback Machine)

Section: **ARCHIVE RECON (Wayback Machine)**

Queries:

```text
https://archive.org/wayback/available?url=<target>
```

If `jq` is installed, it cleanly prints:

* Whether a snapshot is available
* Snapshot URL
* Snapshot status

If not, it prints raw JSON so you still have the data.

---

### 7. “Interesting” Result Highlighting

For every request (path / header / method / protocol), the script:

* Prints HTTP status (colorized)
* Prints response size
* Compares against the **baseline**

If status or size differs, it appends:

```text
[! interesting]
```

These are the lines you review first.

---

### 8. Output Logging

If you set the env var:

```bash
export FOUR03SCOPE_OUT=results.txt
```

The script will:

* Print normal colored output to the terminal
* Append a **color-stripped copy** of each line to `results.txt`

Perfect for later diffing, grepping, or sharing.

---

## 🔧 Requirements

* **bash**
* **curl** (required)
* **figlet** (optional, for the banner)
* **jq** (optional, for pretty Wayback output)

On Debian/Ubuntu:

```bash
sudo apt-get install curl figlet jq
```

---

## 📦 Installation

```bash
git clone https://github.com/YOUR_USERNAME/Four03Scope.git
cd Four03Scope
chmod +x four03scope.sh
```

---

## ▶ Usage

Basic syntax:

```bash
./four03scope.sh <base_url> <path>
```

Examples:

```bash
./four03scope.sh https://example.com admin
./four03scope.sh https://example.com admin/index.php
./four03scope.sh https://example.com server-status
```

Optional: log to a file:

```bash
export FOUR03SCOPE_OUT=four03scope-results.txt
./four03scope.sh https://example.com admin
```

---

## ⚠ Legal / Ethical

This tool is intended for:

* Security researchers
* Penetration testers
* Bug bounty hunters

Use it **only** on targets where you have explicit permission. Unauthorized testing can be illegal.

---

## 📝 License

Add your preferred license here (MIT, Apache-2.0, custom, etc.).

---

## 🙌 Credits

Original idea & base script: **nazmul__ethi**
Refactor & enhancements: this version of **Four03Scope**.

```
```
