local nebula = Proto("nebula", "nebula")

local default_settings = {
    port = 4242,
    all_ports = false,
}

local NOISE_KEY_LEN = 32 -- default Curve25519 / X25519 public key length

nebula.prefs.port = Pref.uint(
    "Port number",
    default_settings.port,
    "The UDP port number for Nebula"
)

nebula.prefs.all_ports = Pref.bool(
    "All ports",
    default_settings.all_ports,
    "Assume nebula packets on any port, useful when dealing with hole punching"
)

local pf_version = ProtoField.new(
    "version",
    "nebula.version",
    ftypes.UINT8,
    nil,
    base.DEC,
    0xF0
)

local pf_type = ProtoField.new(
    "type",
    "nebula.type",
    ftypes.UINT8,
    {
        [0] = "handshake",
        [1] = "message",
        [2] = "recvError",
        [3] = "lightHouse",
        [4] = "test",
        [5] = "closeTunnel",
    },
    base.DEC,
    0x0F
)

local pf_subtype = ProtoField.new(
    "subtype",
    "nebula.subtype",
    ftypes.UINT8,
    nil,
    base.DEC
)

local pf_subtype_test = ProtoField.new(
    "subtype",
    "nebula.subtype",
    ftypes.UINT8,
    {
        [0] = "request",
        [1] = "reply",
    },
    base.DEC
)

local pf_subtype_handshake = ProtoField.new(
    "subtype",
    "nebula.subtype",
    ftypes.UINT8,
    {
        [0] = "ix_psk0",
    },
    base.DEC
)

local pf_reserved = ProtoField.new(
    "reserved",
    "nebula.reserved",
    ftypes.UINT16,
    nil,
    base.HEX
)

local pf_remote_index = ProtoField.new(
    "remote index",
    "nebula.remote_index",
    ftypes.UINT32,
    nil,
    base.DEC
)

local pf_message_counter = ProtoField.new(
    "counter",
    "nebula.counter",
    ftypes.UINT64,
    nil,
    base.DEC
)

local pf_payload = ProtoField.new(
    "payload",
    "nebula.payload",
    ftypes.BYTES,
    nil,
    base.NONE
)

-- Handshake / Noise fields
local pf_hs_stage = ProtoField.new("handshake stage", "nebula.handshake.stage", ftypes.UINT64, nil, base.DEC)
local pf_hs_noise_e = ProtoField.new("Noise ephemeral public key e", "nebula.handshake.noise.e", ftypes.BYTES, nil, base.NONE)
local pf_hs_noise_s = ProtoField.new("Noise static public key s", "nebula.handshake.noise.s", ftypes.BYTES, nil, base.NONE)
local pf_hs_encrypted = ProtoField.new("encrypted handshake bytes", "nebula.handshake.encrypted", ftypes.BYTES, nil, base.NONE)
local pf_hs_plaintext = ProtoField.new("plaintext handshake payload", "nebula.handshake.plaintext", ftypes.BYTES, nil, base.NONE)
local pf_hs_details = ProtoField.new("NebulaHandshakeDetails", "nebula.handshake.details", ftypes.BYTES, nil, base.NONE)
local pf_hs_note = ProtoField.new("note", "nebula.handshake.note", ftypes.STRING)
local pf_hs_unknown = ProtoField.new("unknown protobuf field", "nebula.handshake.unknown", ftypes.BYTES, nil, base.NONE)

-- NebulaHandshakeDetails fields
local pf_hs_cert = ProtoField.new("certificate bytes", "nebula.handshake.cert", ftypes.BYTES, nil, base.NONE)
local pf_hs_initiator_index = ProtoField.new("initiator index", "nebula.handshake.initiator_index", ftypes.STRING)
local pf_hs_responder_index = ProtoField.new("responder index", "nebula.handshake.responder_index", ftypes.STRING)
local pf_hs_time = ProtoField.new("handshake time unix ns", "nebula.handshake.time_unix_ns", ftypes.STRING)
local pf_hs_cert_version = ProtoField.new("certificate version", "nebula.handshake.cert_version", ftypes.STRING)

-- Certificate fields, v1 protobuf and v2 ASN.1 DER where practical
local pf_cert_format = ProtoField.new("certificate format", "nebula.cert.format", ftypes.STRING)
local pf_cert_name = ProtoField.new("certificate name", "nebula.cert.name", ftypes.STRING)
local pf_cert_network = ProtoField.new("certificate network", "nebula.cert.network", ftypes.STRING)
local pf_cert_unsafe_network = ProtoField.new("certificate unsafe network", "nebula.cert.unsafe_network", ftypes.STRING)
local pf_cert_group = ProtoField.new("certificate group", "nebula.cert.group", ftypes.STRING)
local pf_cert_not_before = ProtoField.new("certificate not before", "nebula.cert.not_before", ftypes.STRING)
local pf_cert_not_after = ProtoField.new("certificate not after", "nebula.cert.not_after", ftypes.STRING)
local pf_cert_public_key = ProtoField.new("certificate public key", "nebula.cert.public_key", ftypes.BYTES, nil, base.NONE)
local pf_cert_is_ca = ProtoField.new("certificate is CA", "nebula.cert.is_ca", ftypes.STRING)
local pf_cert_issuer = ProtoField.new("certificate issuer", "nebula.cert.issuer", ftypes.BYTES, nil, base.NONE)
local pf_cert_curve = ProtoField.new("certificate curve", "nebula.cert.curve", ftypes.STRING)
local pf_cert_signature = ProtoField.new("certificate signature", "nebula.cert.signature", ftypes.BYTES, nil, base.NONE)
local pf_cert_parse_note = ProtoField.new("certificate parse note", "nebula.cert.parse_note", ftypes.STRING)
local pf_cert_unknown = ProtoField.new("unknown certificate field", "nebula.cert.unknown", ftypes.BYTES, nil, base.NONE)

nebula.fields = {
    pf_version,
    pf_type,
    pf_subtype,
    pf_subtype_handshake,
    pf_subtype_test,
    pf_reserved,
    pf_remote_index,
    pf_message_counter,
    pf_payload,
}

-- Add parser extension fields separately, so this remains easy to diff against upstream.
local extra_fields = {
    pf_hs_stage,
    pf_hs_noise_e,
    pf_hs_noise_s,
    pf_hs_encrypted,
    pf_hs_plaintext,
    pf_hs_details,
    pf_hs_note,
    pf_hs_unknown,
    pf_hs_cert,
    pf_hs_initiator_index,
    pf_hs_responder_index,
    pf_hs_time,
    pf_hs_cert_version,
    pf_cert_format,
    pf_cert_name,
    pf_cert_network,
    pf_cert_unsafe_network,
    pf_cert_group,
    pf_cert_not_before,
    pf_cert_not_after,
    pf_cert_public_key,
    pf_cert_is_ca,
    pf_cert_issuer,
    pf_cert_curve,
    pf_cert_signature,
    pf_cert_parse_note,
    pf_cert_unknown,
}

for _, field in ipairs(extra_fields) do
    table.insert(nebula.fields, field)
end

local ef_holepunch = ProtoExpert.new(
    "nebula.holepunch.expert",
    "Nebula hole punch packet",
    expert.group.PROTOCOL,
    expert.severity.NOTE
)

local ef_punchy = ProtoExpert.new(
    "nebula.punchy.expert",
    "Nebula punchy keepalive packet",
    expert.group.PROTOCOL,
    expert.severity.NOTE
)

local ef_short = ProtoExpert.new(
    "nebula.short.expert",
    "Nebula packet shorter than 16-byte header",
    expert.group.MALFORMED,
    expert.severity.ERROR
)

local ef_short_handshake = ProtoExpert.new(
    "nebula.handshake.short.expert",
    "Nebula handshake body is too short for the default Curve25519 IX layout",
    expert.group.MALFORMED,
    expert.severity.WARN
)

local ef_bad_varint = ProtoExpert.new(
    "nebula.protobuf.bad_varint.expert",
    "Malformed protobuf varint",
    expert.group.MALFORMED,
    expert.severity.WARN
)

local ef_bad_length = ProtoExpert.new(
    "nebula.protobuf.bad_length.expert",
    "Malformed protobuf length-delimited field",
    expert.group.MALFORMED,
    expert.severity.WARN
)

nebula.experts = {
    ef_holepunch,
    ef_punchy,
    ef_short,
    ef_short_handshake,
    ef_bad_varint,
    ef_bad_length,
}

local type_field = Field.new("nebula.type")
local subtype_field = Field.new("nebula.subtype")

local function min(a, b)
    if a < b then
        return a
    end
    return b
end

local function read_varint(tvbuf, offset, limit)
    local value = 0
    local multiplier = 1
    local pos = offset

    while pos < limit and (pos - offset) < 10 do
        local b = tvbuf:range(pos, 1):uint()
        value = value + (b % 128) * multiplier
        pos = pos + 1

        if b < 128 then
            return value, pos - offset
        end

        multiplier = multiplier * 128
    end

    return nil, 0
end

local function read_len_field(tvbuf, offset, limit)
    local length, n = read_varint(tvbuf, offset, limit)
    if length == nil then
        return nil, nil, nil
    end

    local value_offset = offset + n
    if value_offset + length > limit then
        return nil, nil, nil
    end

    return value_offset, length, n
end

local function skip_protobuf_field(tvbuf, offset, limit, wire_type)
    if wire_type == 0 then
        local _, n = read_varint(tvbuf, offset, limit)
        if n == 0 then
            return nil
        end
        return offset + n
    elseif wire_type == 1 then
        if offset + 8 > limit then
            return nil
        end
        return offset + 8
    elseif wire_type == 2 then
        local value_offset, length = read_len_field(tvbuf, offset, limit)
        if value_offset == nil then
            return nil
        end
        return value_offset + length
    elseif wire_type == 5 then
        if offset + 4 > limit then
            return nil
        end
        return offset + 4
    end

    return nil
end

local function bytes_to_hex(tvbuf, offset, length)
    local parts = {}
    for i = 0, length - 1 do
        parts[#parts + 1] = string.format("%02x", tvbuf:range(offset + i, 1):uint())
    end
    return table.concat(parts)
end

local function uint32_to_ipv4(v)
    local a = math.floor(v / 16777216) % 256
    local b = math.floor(v / 65536) % 256
    local c = math.floor(v / 256) % 256
    local d = v % 256
    return string.format("%d.%d.%d.%d", a, b, c, d)
end

local function bytes_to_ipv4(tvbuf, offset)
    return string.format(
        "%d.%d.%d.%d",
        tvbuf:range(offset, 1):uint(),
        tvbuf:range(offset + 1, 1):uint(),
        tvbuf:range(offset + 2, 1):uint(),
        tvbuf:range(offset + 3, 1):uint()
    )
end

local function bytes_to_ipv6(tvbuf, offset)
    local parts = {}
    for i = 0, 14, 2 do
        parts[#parts + 1] = string.format("%x", tvbuf:range(offset + i, 2):uint())
    end
    return table.concat(parts, ":")
end

local function netip_prefix_to_string(tvbuf, offset, length)
    if length == 5 then
        return bytes_to_ipv4(tvbuf, offset) .. "/" .. tostring(tvbuf:range(offset + 4, 1):uint())
    elseif length == 17 then
        return bytes_to_ipv6(tvbuf, offset) .. "/" .. tostring(tvbuf:range(offset + 16, 1):uint())
    end

    return bytes_to_hex(tvbuf, offset, length)
end

local function mask_to_prefix(mask)
    local prefix = 0
    local seen_zero = false

    for i = 31, 0, -1 do
        local bit = math.floor(mask / (2 ^ i)) % 2
        if bit == 1 then
            if seen_zero then
                return nil
            end
            prefix = prefix + 1
        else
            seen_zero = true
        end
    end

    return prefix
end

local function add_v1_network_pairs(tree, tvbuf, values, field)
    local i = 1
    while i <= #values do
        local ip = values[i].value
        local ip_start = values[i].start
        local ip_len = values[i].len
        local mask = values[i + 1] and values[i + 1].value or nil
        local label

        if mask ~= nil then
            local prefix = mask_to_prefix(mask)
            if prefix ~= nil then
                label = uint32_to_ipv4(ip) .. "/" .. tostring(prefix)
            else
                label = uint32_to_ipv4(ip) .. "/" .. uint32_to_ipv4(mask)
            end
        else
            label = uint32_to_ipv4(ip)
        end

        tree:add(field, tvbuf:range(ip_start, ip_len), label)
        i = i + 2
    end
end

local function curve_name(v)
    if v == 0 then
        return "CURVE25519 (0)"
    elseif v == 1 then
        return "P256 (1)"
    end
    return tostring(v)
end

local function unix_time_string(v)
    if v == nil then
        return ""
    end

    -- Nebula cert notBefore/notAfter are Unix seconds. Handshake Time is Unix ns,
    -- so callers should not use this helper for that field.
    local ok, s = pcall(function()
        return os.date("!%Y-%m-%dT%H:%M:%SZ", v)
    end)

    if ok and s ~= nil then
        return tostring(v) .. " (" .. s .. ")"
    end

    return tostring(v)
end

local function parse_packed_uint32s(tvbuf, offset, length, out)
    local pos = offset
    local limit = offset + length

    while pos < limit do
        local v, n = read_varint(tvbuf, pos, limit)
        if v == nil then
            return false
        end
        out[#out + 1] = { value = v, start = pos, len = n }
        pos = pos + n
    end

    return true
end

local function parse_cert_v1_details(tvbuf, tree, offset, length)
    local limit = offset + length
    local pos = offset
    local ips = {}
    local subnets = {}

    while pos < limit do
        local tag_start = pos
        local tag, tag_len = read_varint(tvbuf, pos, limit)
        if tag == nil then
            tree:add_proto_expert_info(ef_bad_varint)
            return
        end

        local field_num = math.floor(tag / 8)
        local wire_type = tag % 8
        pos = pos + tag_len

        if field_num == 1 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_cert_name, tvbuf:range(value_offset, value_len), tvbuf:range(value_offset, value_len):string())
            pos = value_offset + value_len

        elseif (field_num == 2 or field_num == 3) and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            local dst = ips
            if field_num == 3 then
                dst = subnets
            end
            dst[#dst + 1] = { value = v, start = pos, len = n }
            pos = pos + n

        elseif (field_num == 2 or field_num == 3) and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            local dst = ips
            if field_num == 3 then
                dst = subnets
            end
            if not parse_packed_uint32s(tvbuf, value_offset, value_len, dst) then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            pos = value_offset + value_len

        elseif field_num == 4 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_cert_group, tvbuf:range(value_offset, value_len), tvbuf:range(value_offset, value_len):string())
            pos = value_offset + value_len

        elseif field_num == 5 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            tree:add(pf_cert_not_before, tvbuf:range(pos, n), unix_time_string(v))
            pos = pos + n

        elseif field_num == 6 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            tree:add(pf_cert_not_after, tvbuf:range(pos, n), unix_time_string(v))
            pos = pos + n

        elseif field_num == 7 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_cert_public_key, tvbuf:range(value_offset, value_len))
            pos = value_offset + value_len

        elseif field_num == 8 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            local is_ca = "false"
            if v ~= 0 then
                is_ca = "true"
            end
            tree:add(pf_cert_is_ca, tvbuf:range(pos, n), is_ca)
            pos = pos + n

        elseif field_num == 9 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_cert_issuer, tvbuf:range(value_offset, value_len))
            pos = value_offset + value_len

        elseif field_num == 100 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            tree:add(pf_cert_curve, tvbuf:range(pos, n), curve_name(v))
            pos = pos + n

        else
            local next_pos = skip_protobuf_field(tvbuf, pos, limit, wire_type)
            if next_pos == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_cert_unknown, tvbuf:range(tag_start, next_pos - tag_start))
            pos = next_pos
        end
    end

    add_v1_network_pairs(tree, tvbuf, ips, pf_cert_network)
    add_v1_network_pairs(tree, tvbuf, subnets, pf_cert_unsafe_network)
end

local function parse_cert_v1(tvbuf, tree, offset, length)
    local limit = offset + length
    local pos = offset

    tree:add(pf_cert_format, tvbuf:range(offset, min(length, 1)), "v1 protobuf")

    while pos < limit do
        local tag_start = pos
        local tag, tag_len = read_varint(tvbuf, pos, limit)
        if tag == nil then
            tree:add_proto_expert_info(ef_bad_varint)
            return
        end

        local field_num = math.floor(tag / 8)
        local wire_type = tag % 8
        pos = pos + tag_len

        if field_num == 1 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            local details_tree = tree:add(pf_hs_details, tvbuf:range(value_offset, value_len))
            parse_cert_v1_details(tvbuf, details_tree, value_offset, value_len)
            pos = value_offset + value_len

        elseif field_num == 2 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_cert_signature, tvbuf:range(value_offset, value_len))
            pos = value_offset + value_len

        else
            local next_pos = skip_protobuf_field(tvbuf, pos, limit, wire_type)
            if next_pos == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_cert_unknown, tvbuf:range(tag_start, next_pos - tag_start))
            pos = next_pos
        end
    end
end

local function read_der_len(tvbuf, offset, limit)
    if offset >= limit then
        return nil, nil
    end

    local b = tvbuf:range(offset, 1):uint()
    if b < 128 then
        return b, 1
    end

    local count = b - 128
    if count == 0 or count > 4 or offset + 1 + count > limit then
        return nil, nil
    end

    local v = 0
    for i = 1, count do
        v = (v * 256) + tvbuf:range(offset + i, 1):uint()
    end

    return v, 1 + count
end

local function read_der_tlv(tvbuf, offset, limit)
    if offset >= limit then
        return nil
    end

    local tag = tvbuf:range(offset, 1):uint()
    local len, len_len = read_der_len(tvbuf, offset + 1, limit)
    if len == nil then
        return nil
    end

    local value_offset = offset + 1 + len_len
    if value_offset + len > limit then
        return nil
    end

    return {
        tag = tag,
        start = offset,
        header_len = 1 + len_len,
        value_offset = value_offset,
        length = len,
        next_offset = value_offset + len,
    }
end

local function der_int_value(tvbuf, offset, length)
    if length <= 0 then
        return 0
    end

    local v = 0
    for i = 0, length - 1 do
        v = (v * 256) + tvbuf:range(offset + i, 1):uint()
    end

    return v
end

local function parse_v2_networks(tvbuf, tree, offset, length, field)
    local pos = offset
    local limit = offset + length

    while pos < limit do
        local tlv = read_der_tlv(tvbuf, pos, limit)
        if tlv == nil then
            tree:add(pf_cert_parse_note, "could not parse ASN.1 network entry")
            return
        end

        if tlv.tag == 0x04 then
            tree:add(field, tvbuf:range(tlv.value_offset, tlv.length), netip_prefix_to_string(tvbuf, tlv.value_offset, tlv.length))
        else
            tree:add(pf_cert_unknown, tvbuf:range(tlv.start, tlv.next_offset - tlv.start))
        end

        pos = tlv.next_offset
    end
end

local function parse_v2_groups(tvbuf, tree, offset, length)
    local pos = offset
    local limit = offset + length

    while pos < limit do
        local tlv = read_der_tlv(tvbuf, pos, limit)
        if tlv == nil then
            tree:add(pf_cert_parse_note, "could not parse ASN.1 group entry")
            return
        end

        if tlv.tag == 0x0c then
            tree:add(pf_cert_group, tvbuf:range(tlv.value_offset, tlv.length), tvbuf:range(tlv.value_offset, tlv.length):string())
        else
            tree:add(pf_cert_unknown, tvbuf:range(tlv.start, tlv.next_offset - tlv.start))
        end

        pos = tlv.next_offset
    end
end

local function parse_cert_v2_details(tvbuf, tree, offset, length)
    local pos = offset
    local limit = offset + length

    while pos < limit do
        local tlv = read_der_tlv(tvbuf, pos, limit)
        if tlv == nil then
            tree:add(pf_cert_parse_note, "could not parse ASN.1 certificate details")
            return
        end

        if tlv.tag == 0x80 then
            tree:add(pf_cert_name, tvbuf:range(tlv.value_offset, tlv.length), tvbuf:range(tlv.value_offset, tlv.length):string())
        elseif tlv.tag == 0xa1 then
            parse_v2_networks(tvbuf, tree, tlv.value_offset, tlv.length, pf_cert_network)
        elseif tlv.tag == 0xa2 then
            parse_v2_networks(tvbuf, tree, tlv.value_offset, tlv.length, pf_cert_unsafe_network)
        elseif tlv.tag == 0xa3 then
            parse_v2_groups(tvbuf, tree, tlv.value_offset, tlv.length)
        elseif tlv.tag == 0x84 then
            local is_ca = "false"
            if tlv.length > 0 and tvbuf:range(tlv.value_offset, 1):uint() ~= 0 then
                is_ca = "true"
            end
            tree:add(pf_cert_is_ca, tvbuf:range(tlv.value_offset, tlv.length), is_ca)
        elseif tlv.tag == 0x85 then
            tree:add(pf_cert_not_before, tvbuf:range(tlv.value_offset, tlv.length), unix_time_string(der_int_value(tvbuf, tlv.value_offset, tlv.length)))
        elseif tlv.tag == 0x86 then
            tree:add(pf_cert_not_after, tvbuf:range(tlv.value_offset, tlv.length), unix_time_string(der_int_value(tvbuf, tlv.value_offset, tlv.length)))
        elseif tlv.tag == 0x87 then
            tree:add(pf_cert_issuer, tvbuf:range(tlv.value_offset, tlv.length))
        else
            tree:add(pf_cert_unknown, tvbuf:range(tlv.start, tlv.next_offset - tlv.start))
        end

        pos = tlv.next_offset
    end
end

local function parse_cert_v2(tvbuf, tree, offset, length)
    local limit = offset + length
    local outer = read_der_tlv(tvbuf, offset, limit)

    tree:add(pf_cert_format, tvbuf:range(offset, min(length, 1)), "v2 ASN.1 DER")

    if outer == nil or outer.tag ~= 0x30 then
        tree:add(pf_cert_parse_note, "not an ASN.1 SEQUENCE")
        return
    end

    local pos = outer.value_offset
    local outer_limit = outer.value_offset + outer.length

    while pos < outer_limit do
        local tlv = read_der_tlv(tvbuf, pos, outer_limit)
        if tlv == nil then
            tree:add(pf_cert_parse_note, "could not parse ASN.1 certificate field")
            return
        end

        if tlv.tag == 0xa0 then
            local details_tree = tree:add(pf_hs_details, tvbuf:range(tlv.start, tlv.next_offset - tlv.start))
            parse_cert_v2_details(tvbuf, details_tree, tlv.value_offset, tlv.length)
        elseif tlv.tag == 0x81 then
            local v = 0
            if tlv.length > 0 then
                v = tvbuf:range(tlv.value_offset, 1):uint()
            end
            tree:add(pf_cert_curve, tvbuf:range(tlv.value_offset, tlv.length), curve_name(v))
        elseif tlv.tag == 0x82 then
            tree:add(pf_cert_public_key, tvbuf:range(tlv.value_offset, tlv.length))
        elseif tlv.tag == 0x83 then
            tree:add(pf_cert_signature, tvbuf:range(tlv.value_offset, tlv.length))
        else
            tree:add(pf_cert_unknown, tvbuf:range(tlv.start, tlv.next_offset - tlv.start))
        end

        pos = tlv.next_offset
    end
end

local function parse_certificate(tvbuf, tree, offset, length, cert_version)
    if length == 0 then
        tree:add(pf_cert_parse_note, "empty certificate")
        return
    end

    local first = tvbuf:range(offset, 1):uint()

    if cert_version == 2 or first == 0x30 then
        parse_cert_v2(tvbuf, tree, offset, length)
    else
        parse_cert_v1(tvbuf, tree, offset, length)
    end
end

local function parse_handshake_details(tvbuf, tree, offset, length)
    local limit = offset + length
    local pos = offset
    local cert_tree = nil
    local cert_offset = nil
    local cert_len = nil
    local cert_version = nil

    while pos < limit do
        local tag_start = pos
        local tag, tag_len = read_varint(tvbuf, pos, limit)
        if tag == nil then
            tree:add_proto_expert_info(ef_bad_varint)
            return
        end

        local field_num = math.floor(tag / 8)
        local wire_type = tag % 8
        pos = pos + tag_len

        if field_num == 1 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            cert_tree = tree:add(pf_hs_cert, tvbuf:range(value_offset, value_len))
            cert_offset = value_offset
            cert_len = value_len
            pos = value_offset + value_len

        elseif field_num == 2 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            tree:add(pf_hs_initiator_index, tvbuf:range(pos, n), tostring(v))
            pos = pos + n

        elseif field_num == 3 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            tree:add(pf_hs_responder_index, tvbuf:range(pos, n), tostring(v))
            pos = pos + n

        elseif field_num == 5 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            tree:add(pf_hs_time, tvbuf:range(pos, n), tostring(v))
            pos = pos + n

        elseif field_num == 8 and wire_type == 0 then
            local v, n = read_varint(tvbuf, pos, limit)
            if v == nil then
                tree:add_proto_expert_info(ef_bad_varint)
                return
            end
            cert_version = v
            tree:add(pf_hs_cert_version, tvbuf:range(pos, n), tostring(v))
            pos = pos + n

        else
            local next_pos = skip_protobuf_field(tvbuf, pos, limit, wire_type)
            if next_pos == nil then
                tree:add_proto_expert_info(ef_bad_length)
                return
            end
            tree:add(pf_hs_unknown, tvbuf:range(tag_start, next_pos - tag_start))
            pos = next_pos
        end
    end

    if cert_tree ~= nil then
        parse_certificate(tvbuf, cert_tree, cert_offset, cert_len, cert_version)
    end
end

local function parse_nebula_handshake_payload(tvbuf, tree, offset, length)
    local limit = offset + length
    local pos = offset
    local payload_tree = tree:add(pf_hs_plaintext, tvbuf:range(offset, length))

    while pos < limit do
        local tag_start = pos
        local tag, tag_len = read_varint(tvbuf, pos, limit)
        if tag == nil then
            payload_tree:add_proto_expert_info(ef_bad_varint)
            return
        end

        local field_num = math.floor(tag / 8)
        local wire_type = tag % 8
        pos = pos + tag_len

        if field_num == 1 and wire_type == 2 then
            local value_offset, value_len = read_len_field(tvbuf, pos, limit)
            if value_offset == nil then
                payload_tree:add_proto_expert_info(ef_bad_length)
                return
            end
            local details_tree = payload_tree:add(pf_hs_details, tvbuf:range(value_offset, value_len))
            parse_handshake_details(tvbuf, details_tree, value_offset, value_len)
            pos = value_offset + value_len

        else
            local next_pos = skip_protobuf_field(tvbuf, pos, limit, wire_type)
            if next_pos == nil then
                payload_tree:add_proto_expert_info(ef_bad_length)
                return
            end
            payload_tree:add(pf_hs_unknown, tvbuf:range(tag_start, next_pos - tag_start))
            pos = next_pos
        end
    end
end

local function dissect_handshake_body(tvbuf, pktlen, tree, stage)
    local body_offset = 16
    local body_len = pktlen - body_offset
    local stage_s = tostring(stage)

    tree:add(pf_hs_stage, tvbuf:range(8, 8))

    if body_len <= 0 then
        return
    end

    local hs_tree = tree:add(pf_payload, tvbuf:range(body_offset, body_len))
    hs_tree:add(pf_hs_note, "Default Curve25519 IX layout: stage 1 has plaintext e, s, and NebulaHandshake payload; stage 2 has plaintext e then encrypted bytes")

    if stage_s == "1" then
        if body_len < (NOISE_KEY_LEN * 2) then
            hs_tree:add_proto_expert_info(ef_short_handshake)
            if body_len >= NOISE_KEY_LEN then
                hs_tree:add(pf_hs_noise_e, tvbuf:range(body_offset, NOISE_KEY_LEN))
                hs_tree:add(pf_hs_encrypted, tvbuf:range(body_offset + NOISE_KEY_LEN, body_len - NOISE_KEY_LEN))
            else
                hs_tree:add(pf_hs_encrypted, tvbuf:range(body_offset, body_len))
            end
            return
        end

        hs_tree:add(pf_hs_noise_e, tvbuf:range(body_offset, NOISE_KEY_LEN))
        hs_tree:add(pf_hs_noise_s, tvbuf:range(body_offset + NOISE_KEY_LEN, NOISE_KEY_LEN))

        local payload_offset = body_offset + (NOISE_KEY_LEN * 2)
        local payload_len = pktlen - payload_offset
        if payload_len > 0 then
            parse_nebula_handshake_payload(tvbuf, hs_tree, payload_offset, payload_len)
        end

    elseif stage_s == "2" then
        if body_len < NOISE_KEY_LEN then
            hs_tree:add_proto_expert_info(ef_short_handshake)
            hs_tree:add(pf_hs_encrypted, tvbuf:range(body_offset, body_len))
            return
        end

        hs_tree:add(pf_hs_noise_e, tvbuf:range(body_offset, NOISE_KEY_LEN))

        local encrypted_offset = body_offset + NOISE_KEY_LEN
        local encrypted_len = body_len - NOISE_KEY_LEN
        if encrypted_len > 0 then
            hs_tree:add(pf_hs_encrypted, tvbuf:range(encrypted_offset, encrypted_len))
        end

    else
        hs_tree:add(pf_hs_note, "unknown handshake counter; leaving payload undecoded")
    end
end

function nebula.dissector(tvbuf, pktinfo, root)
    pktinfo.cols.protocol:set("NEBULA")

    local pktlen = tvbuf:len()
    local tree = root:add(nebula, tvbuf:range(0, pktlen))

    if pktlen == 0 then
        tree:add_proto_expert_info(ef_holepunch)
        pktinfo.cols.info:append(" (holepunch)")
        return
    elseif pktlen == 1 then
        tree:add_proto_expert_info(ef_punchy)
        pktinfo.cols.info:append(" (punchy)")
        return
    elseif pktlen < 16 then
        tree:add_proto_expert_info(ef_short)
        pktinfo.cols.info:append(" (short nebula packet)")
        return
    end

    tree:add(pf_version, tvbuf:range(0, 1))

    local type_item = tree:add(pf_type, tvbuf:range(0, 1))
    local nebula_type = bit.band(tvbuf:range(0, 1):uint(), 0x0F)

    if nebula_type == 0 then
        local stage = tvbuf(8, 8):uint64()

        tree:add(pf_subtype_handshake, tvbuf:range(1, 1))
        type_item:append_text(" stage " .. tostring(stage))

        pktinfo.cols.info:append(
            " (" ..
            type_field().display ..
            ", stage " ..
            tostring(stage) ..
            ", " ..
            subtype_field().display ..
            ")"
        )
    elseif nebula_type == 4 then
        tree:add(pf_subtype_test, tvbuf:range(1, 1))

        pktinfo.cols.info:append(
            " (" ..
            type_field().display ..
            ", " ..
            subtype_field().display ..
            ")"
        )
    else
        tree:add(pf_subtype, tvbuf:range(1, 1))

        pktinfo.cols.info:append(
            " (" ..
            type_field().display ..
            ")"
        )
    end

    tree:add(pf_reserved, tvbuf:range(2, 2))
    tree:add(pf_remote_index, tvbuf:range(4, 4))
    tree:add(pf_message_counter, tvbuf:range(8, 8))

    if nebula_type == 0 then
        local stage = tvbuf(8, 8):uint64()
        dissect_handshake_body(tvbuf, pktlen, tree, stage)
    elseif pktlen > 16 then
        tree:add(pf_payload, tvbuf:range(16, pktlen - 16))
    end
end

function nebula.prefs_changed()
    if default_settings.all_ports == nebula.prefs.all_ports
        and default_settings.port == nebula.prefs.port then
        return
    end

    DissectorTable.get("udp.port"):remove_all(nebula)

    if nebula.prefs.all_ports then
        for i = 0, 65535 do
            DissectorTable.get("udp.port"):add(i, nebula)
        end
    else
        DissectorTable.get("udp.port"):add(nebula.prefs.port, nebula)
    end

    default_settings.all_ports = nebula.prefs.all_ports
    default_settings.port = nebula.prefs.port
end

DissectorTable.get("udp.port"):add(default_settings.port, nebula)
