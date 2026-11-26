-- GPL-3.0-or-later. Refuse page events outside the awake native reader.
local wire = require("x11_wire")
local transport = require("x11_transport")
local M = {}; local baseline_pid
local function prop(owner, key)
    -- Fixed commands only. Missing timeout/lipc means refusal, never fallback.
    local pipe = assert(io.popen("timeout 2 lipc-get-prop " .. owner .. " " .. key .. " 2>/dev/null", "r"))
    local value = pipe:read("*a") or ""
    pipe:close()
    return value:match("^%s*(.-)%s*$")
end
local function foreground()
    local state = prop("com.lab126.powerd", "status")
    if not state:match("Powerd state:%s*Active") then return nil, "Kindle is asleep or power status unavailable" end
    local title = prop("com.lab126.winmgr", "getActiveAppTitle")
    if not wire.title_parts(title) then return nil, "Open a book in the native Kindle reader first" end
    return title
end
local function operate(send, next_page)
    local io, refused
    local ok, result = pcall(function()
        local title, reason = foreground()
        if not title then refused=reason; return end
        io = transport.open()
        if baseline_pid then
            assert(io.peer_pid == baseline_pid, "X11 process changed; end this test session")
        end
        local x = wire.connect(io)
        local window = x:find_reader(title)
        baseline_pid = io.peer_pid
        if send then
            local current, reason = foreground()
            if current ~= title then refused=reason or "Foreground changed; action cancelled"; return end
            x:send_page(window, next_page)
        end
        return string.format("reader_window=0x%x xorg_pid=%d", window, io.peer_pid)
    end)
    if io then io:close() end
    if refused then return false, refused, "blocked" end
    return ok, result, ok and "ok" or "error"
end
function M.probe() return operate(false) end
function M.turn(next_page) return operate(true, next_page) end
return M
