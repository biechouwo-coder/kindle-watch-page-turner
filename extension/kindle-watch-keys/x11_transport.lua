-- GPL-3.0-or-later. Linux ARM transport for the bounded X11 core client.
local ffi = require("ffi")
local clock = require("socket").gettime
ffi.cdef[[
struct kwk_sockaddr_un { unsigned short family; char path[108]; };
struct kwk_timeval { long sec; long usec; };
struct kwk_ucred { int pid; unsigned int uid; unsigned int gid; };
int socket(int, int, int);
int connect(int, const void *, unsigned int);
int setsockopt(int, int, int, const void *, unsigned int);
int getsockopt(int, int, int, void *, unsigned int *);
long send(int, const void *, unsigned long, int);
long recv(int, void *, unsigned long, int);
int close(int);
int getpid(void);
]]
local M = {}; local T = {}; T.__index = T
function M.open()
    local fd = ffi.C.socket(1, 1, 0)
    assert(fd >= 0, "Cannot create X11 socket")
    local t = setmetatable({fd = fd, deadline = clock() + 4}, T)
    local ok, err = pcall(function()
        local timeout = ffi.new("struct kwk_timeval[1]")
        timeout[0].sec, timeout[0].usec = 0, 500000
        assert(ffi.C.setsockopt(fd, 1, 20, timeout, ffi.sizeof(timeout[0])) == 0, "Cannot set X11 read timeout")
        assert(ffi.C.setsockopt(fd, 1, 21, timeout, ffi.sizeof(timeout[0])) == 0, "Cannot set X11 write timeout")
        local address = ffi.new("struct kwk_sockaddr_un[1]")
        address[0].family = 1
        local path = "/tmp/.X11-unix/X0"
        ffi.copy(address[0].path, path)
        assert(ffi.C.connect(fd, address, 2 + #path + 1) == 0, "Cannot connect to X11")
        local cred = ffi.new("struct kwk_ucred[1]")
        local length = ffi.new("unsigned int[1]", ffi.sizeof(cred[0]))
        assert(ffi.C.getsockopt(fd, 1, 17, cred, length) == 0 and cred[0].pid > 1, "Cannot identify X11 process")
        t.peer_pid = tonumber(cred[0].pid)
    end)
    if not ok then t:close(); error(err) end
    return t
end
function T:write(s)
    local buffer = ffi.new("char[?]", #s)
    ffi.copy(buffer, s, #s)
    local offset = 0
    while offset < #s do
        assert(clock() < self.deadline, "X11 operation budget exceeded")
        local n = tonumber(ffi.C.send(self.fd, buffer + offset, #s - offset, 0x4000))
        assert(n > 0, "X11 write failed; no retry")
        offset = offset + n
    end
end
function T:read(length)
    assert(length > 0 and length <= 1024 * 1024, "Invalid read size")
    local buffer = ffi.new("char[?]", length)
    local offset = 0
    while offset < length do
        assert(clock() < self.deadline, "X11 operation budget exceeded")
        local n = tonumber(ffi.C.recv(self.fd, buffer + offset, length - offset, 0))
        assert(n > 0, "X11 read failed or connection closed")
        offset = offset + n
    end
    return ffi.string(buffer, length)
end
function T:close()
    if self.fd and self.fd >= 0 then ffi.C.close(self.fd); self.fd = -1 end
end
function M.pid() return tonumber(ffi.C.getpid()) end
return M
