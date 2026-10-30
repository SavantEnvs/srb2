local t = {10, 20, 30, x = "a", ["y z"] = {1, 2, {3}}}
for i, v in ipairs(t) do t[i] = v * 2 end
local s = string.format("%d-%s", #t, tostring(t.x)) .. "\n"
while #s < 40 do s = s .. s end
repeat s = s:sub(2) until #s < 20
return setmetatable({}, {__index = function(_, k) return t[k] end, __concat = function(a, b) return s end})
