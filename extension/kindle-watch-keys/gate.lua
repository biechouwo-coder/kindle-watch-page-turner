-- Diagnostic-first quota. Consume before sending; never retry automatically.
local M = {}
function M.new(now)
    local g = {remaining=0, until_time=0, failed=false, reading=false, last=-math.huge}
    function g:status()
        if self.failed then return "DISABLED: restart required after an error" end
        if now() >= self.until_time then self.remaining, self.reading = 0, false end
        if self.reading then return "mode=reading; expires_in=" .. math.floor(self.until_time-now()) .. "s" end
        return "armed_actions=" .. self.remaining
    end
    function g:arm(n)
        assert(not self.failed and not self.reading and (n == 1 or n == 5), "Invalid arming request")
        self.remaining, self.until_time = n, now() + 120
    end
    function g:start_reading(duration)
        assert(not self.failed and type(duration)=="number" and duration>=60 and duration<=7200, "Invalid reading session")
        self.reading, self.remaining, self.until_time = true, 0, now() + duration
    end
    function g:take()
        self:status()
        if self.failed then return false, "Session disabled after an error" end
        if not self.reading and self.remaining < 1 then return false, "Page actions are disarmed or session expired" end
        local t = now()
        if t - self.last < 1.5 then return false, "Wait before next page action" end
        if not self.reading then self.remaining = self.remaining - 1 end
        self.last = t
        return true
    end
    function g:fail() self.failed, self.remaining, self.reading = true, 0, false end
    return g
end
return M
