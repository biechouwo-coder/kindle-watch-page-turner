-- GPL-3.0-or-later. Diagnostic-first native-reader key remote.
local root = "/mnt/us/extensions/kindle-watch-keys/"
package.path = root .. "?.lua;common/?.lua;rocks/share/lua/5.1/?.lua;" .. package.path
package.cpath = "./?.so;common/?.so;rocks/lib/lua/5.1/?.so;" .. package.cpath
local socket = require("socket")
local transport = require("x11_transport")
local keys = require("native_keys")
local gate = require("gate").new(socket.gettime)
local config = dofile(root .. "config.lua")
local mode = arg and arg[1] == "reading" and "reading" or "diagnostic"
local duration = mode == "reading" and config.reading_duration or config.duration
if mode == "reading" then gate:start_reading(duration) end
io.stdout:setvbuf("no"); io.stderr:setvbuf("no")
local running = true
local function dispatch(method, target)
    if method ~= "GET" then return 405, "GET required" end
    if target == "/health" then return 200, "Kindle key remote v2.1; mode=" .. mode .. "; no touch injection" end
    local path, token = target:match("^([^?]+)%?token=([0-9a-f]+)$")
    if not path or token ~= config.token then return 403, "Invalid route or token" end
    if path == "/status" then return 200, gate:status() end
    if path == "/stop" then running = false; return 200, "Stopping key remote" end
    if path == "/probe" or path == "/arm-once" or path == "/arm-five" then
        if mode == "reading" and path ~= "/probe" then return 409, "Reading mode is already enabled" end
        if gate.failed then return 409, gate:status() end
        local ok, detail = keys.probe()
        print(os.date("%H:%M:%S"), "PROBE", ok and detail or ("REFUSED: " .. tostring(detail)))
        if not ok then return 409, tostring(detail) end
        if path ~= "/probe" then gate:arm(path == "/arm-once" and 1 or 5) end
        return 200, detail .. "; " .. gate:status()
    end
    if path == "/next" or path == "/prev" then
        local allowed, message = gate:take()
        if not allowed then return 409, message end
        local ok, detail, kind = keys.turn(path == "/next")
        if not ok then
            if kind == "blocked" then
                print(os.date("%H:%M:%S"), "KEY BLOCKED (reader not ready)", tostring(detail))
                return 409, tostring(detail)
            end
            gate:fail()
            print(os.date("%H:%M:%S"), "KEY REFUSED; SESSION DISABLED", tostring(detail))
            return 503, "Session disabled after key error: " .. tostring(detail)
        end
        print(os.date("%H:%M:%S"), path == "/next" and "NEXT KEY" or "PREVIOUS KEY", detail)
        return 200, "X11 key press/release acknowledged; confirm page visually; " .. gate:status()
    end
    return 404, "Unknown route"
end
local server = assert(socket.bind("0.0.0.0", config.port))
server:settimeout(0.5)
local f = assert(io.open(root .. "runtime/server.pid", "w"))
f:write(transport.pid(), "\n"); f:close()
print(os.date("%H:%M:%S"), "V2.1 started; mode=" .. mode .. "; duration " .. duration)
local deadline = socket.gettime() + duration
local reasons = {[200]="OK",[400]="Bad Request",[403]="Forbidden",[404]="Not Found",[405]="Method Not Allowed",[409]="Conflict",[500]="Internal Server Error",[503]="Service Unavailable"}
while running and socket.gettime() < deadline do
    local client = server:accept()
    if client then
        client:settimeout(1)
        local line = client:receive("*l")
        local method, target = (line or ""):match("^(%u+) ([^ ]+) HTTP/1%.[01]$")
        local complete = false
        for _ = 1, 40 do
            local h = client:receive("*l")
            if h == "" then complete = true; break end
            if not h or #h > 4096 then break end
        end
        local code, body = 400, "Invalid request"
        if method and complete then
            local ok, c, b = pcall(dispatch, method, target)
            if ok then code, body = c, b
            else gate:fail(); code, body = 500, "Request failed; session disabled"; print("REQUEST ERROR", tostring(c)) end
        end
        body = body .. "\n"
        client:send("HTTP/1.1 " .. code .. " " .. reasons[code] .. "\r\nContent-Type: text/plain\r\nContent-Length: " .. #body .. "\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" .. body)
        client:close()
    end
end
server:close()
print(os.date("%H:%M:%S"), "V2 session ended")
