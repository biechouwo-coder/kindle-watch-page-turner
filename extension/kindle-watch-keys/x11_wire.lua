-- GPL-3.0-or-later; adapted from kindle-button-mapper-rs/src/xkey.rs.
-- X11 core protocol only. No touch-device, kernel-input, or keymap mutation.
local M = {}
local function zeros(n) return string.rep(string.char(0), n) end
local function u16(n) return string.char(n % 256, math.floor(n / 256) % 256) end
local function u32(n) return u16(n % 65536) .. u16(math.floor(n / 65536)) end
local function read16(s, p)
    assert(p >= 0 and #s >= p + 2, "Short X11 reply")
    return s:byte(p + 1) + s:byte(p + 2) * 256
end
local function read32(s, p) return read16(s, p) + read16(s, p + 2) * 65536 end
local function title_parts(title)
    local prefix, id = title:match("^(.-)ID:([^_]+)")
    if prefix ~= "L:A_N:application_" or id ~= "com.lab126.booklet.reader" then
        return nil
    end
    return prefix, id
end
local function matches(name, prefix, id)
    local p, i = title_parts(name)
    return p == prefix and i == id
end
M.title_parts = title_parts
M.u16, M.u32, M.read16, M.read32 = u16, u32, read16, read32
local X = {}; X.__index = X
function M.connect(io)
    local self = setmetatable({io = io, sequence = 0}, X)
    io:write("l" .. zeros(1) .. u16(11) .. zeros(8))
    local head = io:read(8)
    assert(head:byte(1) == 1, "X11 connection refused")
    assert(read16(head, 2) == 11, "Unexpected X11 version")
    local n = read16(head, 6) * 4
    assert(n >= 32 and n <= 1024 * 1024, "Invalid X11 setup length")
    local setup = io:read(n)
    local vendor = read16(setup, 16)
    local padded = math.floor((vendor + 3) / 4) * 4
    assert(setup:byte(21) >= 1, "X11 has no screens")
    local formats = setup:byte(22)
    self.root = read32(setup, 32 + padded + formats * 8)
    assert(self.root > 1, "Invalid root window")
    return self
end
function X:request(s)
    assert(#s >= 4 and #s % 4 == 0 and read16(s, 2) * 4 == #s, "Malformed X11 request")
    self.io:write(s)
    self.sequence = (self.sequence + 1) % 65536
end
function X:reply()
    local h = self.io:read(32)
    if h:byte(1) == 0 then error("X11 protocol error " .. tostring(h:byte(2))) end
    assert(h:byte(1) == 1, "Unexpected X11 packet")
    assert(read16(h, 2) == self.sequence, "X11 reply sequence mismatch")
    local n = read32(h, 4) * 4
    assert(n <= 1024 * 1024, "Oversized X11 reply")
    return h, n > 0 and self.io:read(n) or ""
end
function X:tree(window)
    self:request(string.char(15, 0) .. u16(2) .. u32(window))
    local h, body = self:reply()
    local count = read16(h, 16)
    assert(count <= 256 and #body == count * 4, "Invalid X11 window tree")
    local children = {}
    for i = 0, count - 1 do children[#children + 1] = read32(body, i * 4) end
    return children
end
function X:name(window)
    self:request(string.char(20, 0) .. u16(6) .. u32(window) .. u32(39) .. zeros(8) .. u32(128))
    local h, body = self:reply()
    if h:byte(2) == 0 then return "" end
    assert(h:byte(2) == 8, "Unexpected window-name format")
    local n = read32(h, 16)
    assert(n <= #body, "Short window-name property")
    return body:sub(1, n)
end
function X:find_reader(title)
    local prefix, id = title_parts(title)
    assert(prefix, "Foreground app is not the native reader")
    local queue, visited, found = {self.root}, {}, {}
    local count = 0
    while #queue > 0 do
        local parent = table.remove(queue)
        assert(not visited[parent], "Cyclic X11 tree")
        visited[parent] = true
        count = count + 1
        assert(count <= 256, "Too many X11 windows")
        for _, child in ipairs(self:tree(parent)) do
            if matches(self:name(child), prefix, id) then found[#found + 1] = child end
            queue[#queue + 1] = child
        end
    end
    assert(#found == 1, "Expected one native reader window; found " .. #found)
    return found[1]
end
local function key_packet(root, window, code, kind)
    local event = string.char(kind, code) .. zeros(6) .. u32(root) .. u32(window) .. zeros(14) .. string.char(1, 0)
    assert(#event == 32)
    return string.char(25, 0) .. u16(11) .. u32(window) .. zeros(4) .. event
end
M.key_packet = key_packet
function X:send_page(window, next_page)
    assert(type(next_page) == "boolean", "Invalid page direction")
    -- Linux keycode + Xorg's evdev offset, as used by the reference project.
    local code = next_page and 117 or 112
    -- KEY_PAGEDOWN = 109, +8 = 117. KEY_PAGEUP = 104, +8 = 112.
    local press = key_packet(self.root, window, code, 2)
    local release = key_packet(self.root, window, code, 3)
    -- Queue press, release, then an X11 round-trip in one bounded write.
    self.io:write(press .. release .. string.char(43, 0, 1, 0))
    self.sequence = (self.sequence + 3) % 65536
    self:reply()
end
return M
