# Nebula Wireshark Lua Dissector Changes

This file documents what was changed in the modified `nebula.lua` dissector so the work can be resumed later.

## Scope of the current Lua file

The modified dissector keeps the original Nebula UDP dissector behavior and adds handshake decoding for the default Nebula handshake layout only:

- protocol registration remains `Proto("nebula", "nebula")`
- default UDP port remains `4242`
- `all_ports` preference is kept for hole-punch debugging
- default Noise public key length is fixed as `32` bytes
- this assumes the default Curve25519 / X25519 layout
- non-default curves, such as larger P-256 keys, are not handled

The main new constant is:

```lua
local NOISE_KEY_LEN = 32 -- default Curve25519 / X25519 public key length
```

## Existing Nebula header parsing kept

The dissector still parses the normal 16-byte Nebula header:

- version
- type
- subtype
- reserved
- remote index
- message counter
- payload

For handshake packets, the message counter is also shown as the handshake stage.

## New handshake fields added

The Lua file adds new Wireshark fields for handshake and Noise data:

- `nebula.handshake.stage`
- `nebula.handshake.noise.e`
- `nebula.handshake.noise.s`
- `nebula.handshake.encrypted`
- `nebula.handshake.plaintext`
- `nebula.handshake.details`
- `nebula.handshake.note`
- `nebula.handshake.unknown`

These are appended separately to `nebula.fields` through an `extra_fields` table and `table.insert()`. This was done to keep the extension easy to compare against the original upstream Lua file.

## New handshake details fields added

The Lua file adds fields for decoded `NebulaHandshakeDetails` values:

- `nebula.handshake.cert`
- `nebula.handshake.initiator_index`
- `nebula.handshake.responder_index`
- `nebula.handshake.time_unix_ns`
- `nebula.handshake.cert_version`

The parser expects the outer plaintext handshake payload to contain top-level protobuf field `1`, which is treated as `NebulaHandshakeDetails`.

Inside `NebulaHandshakeDetails`, the parser handles:

- field `1`: certificate bytes
- field `2`: initiator index
- field `3`: responder index
- field `5`: handshake time as Unix nanoseconds
- field `8`: certificate version

Unknown fields are preserved as `nebula.handshake.unknown` instead of being silently ignored.

## New certificate fields added

The Lua file attempts to parse the initiator certificate from stage 1 and expose useful identity fields:

- `nebula.cert.format`
- `nebula.cert.name`
- `nebula.cert.network`
- `nebula.cert.unsafe_network`
- `nebula.cert.group`
- `nebula.cert.not_before`
- `nebula.cert.not_after`
- `nebula.cert.public_key`
- `nebula.cert.is_ca`
- `nebula.cert.issuer`
- `nebula.cert.curve`
- `nebula.cert.signature`
- `nebula.cert.parse_note`
- `nebula.cert.unknown`

The parser chooses certificate parsing mode with this rule:

- parse as v2 if `cert_version == 2` or if the first byte is ASN.1 SEQUENCE `0x30`
- otherwise parse as v1 protobuf

## Stage 1 handshake behavior

For handshake packets where:

```text
Nebula type == 0
message counter / stage == 1
```

The parser assumes this byte layout after the 16-byte Nebula header:

```text
bytes 16..47   Noise ephemeral public key e, plaintext, 32 bytes
bytes 48..79   Noise static public key s, plaintext, 32 bytes
bytes 80..end  plaintext NebulaHandshake protobuf payload
```

The stage 1 parser then:

1. adds `nebula.handshake.noise.e`
2. adds `nebula.handshake.noise.s`
3. parses the remaining plaintext payload as `NebulaHandshake`
4. parses `NebulaHandshakeDetails`
5. extracts certificate bytes
6. parses the certificate and tries to show the cert name and related fields

This is the part that makes the initiator certificate name visible in Wireshark when present in the stage 1 plaintext handshake.

## Stage 2 handshake behavior

For handshake packets where:

```text
Nebula type == 0
message counter / stage == 2
```

The parser assumes this layout:

```text
bytes 16..47   Noise ephemeral public key e, plaintext, 32 bytes
bytes 48..end  encrypted handshake bytes
```

The Lua file does not try to parse responder certificate fields from stage 2. It only shows the plaintext Noise `e` key and labels the rest as encrypted.

## Unknown handshake stages

For handshake packets with a counter other than `1` or `2`, the Lua file adds a note:

```text
unknown handshake counter; leaving payload undecoded
```

No protobuf or certificate parsing is attempted for unknown stages.

## v1 certificate parser

The v1 parser is protobuf-based.

It parses the outer v1 certificate as:

- field `1`: certificate details
- field `2`: signature

Inside certificate details, it attempts to parse:

- field `1`: name
- field `2`: IP/network values
- field `3`: unsafe network values
- field `4`: groups
- field `5`: not-before time
- field `6`: not-after time
- field `7`: public key
- field `8`: CA flag
- field `9`: issuer
- field `100`: curve

The v1 network parser collects repeated or packed uint32 values and pairs IP values with mask values. It formats those pairs as CIDR-style strings when possible.

## v2 certificate parser

The v2 parser is a best-effort ASN.1 DER parser.

It expects an outer ASN.1 SEQUENCE and attempts to parse:

- details container
- curve
- public key
- signature

Inside the details container, it attempts to parse:

- name
- networks
- unsafe networks
- groups
- CA flag
- not-before time
- not-after time
- issuer

The v2 network parser currently exposes network entries as raw hex. It does not fully format every `netip.Prefix` binary value into CIDR notation.

## Helper functions added

The Lua file adds helper functions for:

- protobuf varint reading
- protobuf length-delimited field reading
- protobuf field skipping
- byte-to-hex formatting
- uint32-to-IPv4 formatting
- mask-to-prefix conversion
- Unix timestamp formatting
- packed uint32 protobuf parsing
- v1 certificate protobuf parsing
- ASN.1 DER length parsing
- ASN.1 DER TLV parsing
- v2 certificate parsing
- handshake payload parsing
- handshake body dispatch

Important function entry points:

- `dissect_handshake_body()` decides how to parse stage 1, stage 2, or unknown handshake stages.
- `parse_nebula_handshake_payload()` parses the plaintext stage 1 `NebulaHandshake` protobuf.
- `parse_handshake_details()` parses `NebulaHandshakeDetails`.
- `parse_certificate()` chooses v1 or v2 cert parsing.
- `parse_cert_v1()` and `parse_cert_v1_details()` parse v1 protobuf certs.
- `parse_cert_v2()` and `parse_cert_v2_details()` parse v2 ASN.1 DER certs.

## Expert warnings added

The Lua file keeps the existing expert handling for:

- hole-punch packet
- punchy keepalive packet
- packet shorter than the 16-byte Nebula header

It adds warnings for:

- handshake body too short for the default Curve25519 IX layout
- malformed protobuf varint
- malformed protobuf length-delimited field

## Current limitations

- Only the default 32-byte Curve25519 / X25519 Noise key layout is handled.
- Stage 2 is not decrypted.
- Responder certificate/name/details from stage 2 are not parsed.
- Normal data packets are not decrypted.
- v2 certificate network formatting is incomplete and currently exposes some values as raw hex.
- Unknown protobuf and certificate fields are preserved as raw fields, not fully decoded.
- The parser should be tested against real captures before being considered stable.

## Plugin conflict note

The file registers the protocol as:

```lua
local nebula = Proto("nebula", "nebula")
```

Only one active Lua plugin can register that same protocol name/description. Do not load this modified file at the same time as another Nebula Lua dissector copy.
