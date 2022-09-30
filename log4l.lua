--- Log4L by Compec

local ftbl = {}
local api = {}
if fs.exists("latest.log") then
    if (not fs.exists("/.log")) then
        fs.makeDir("/.log")
        fs.move("/latest.log","/.log/"..os.date("%Y-%m-%e-%H-%M-%S"))
    elseif not fs.isDir(("/.log")) then
        fs.delete("/.log")
        fs.makeDir("/.log")
        fs.move("/latest.log","/.log/"..os.date("%Y-%m-%e-%H-%M-%S"))
    else
        fs.move("/latest.log","/.log/"..os.date("%Y-%m-%e-%H-%M-%S"))
    end
end
local lgstr = ""

function ftbl.gtDat()
    local dat = os.date("%d%b%Y %R:%S.")
    local epo = tostring(os.epoch("local"))
    epo = string.sub(epo,#epo-2,#epo)
    return dat..epo
end

function api.create(name)
    name = name or "main"
    return setmetatable({ tnm = name, flhndl = fs.open("/latest.log","w") },{__index = ftbl})
end

function ftbl:log(msg,use,level)
    use = use or "undefined"
    level = level or 0
    local lvs = { [0] = "INFO", [1] = "WARN", [2] = "ERROR", [3] = "FATAL", [4] = "DEBUG" }
    lgstr = lgstr.."["..ftbl.gtDat().."] ["..self.tnm.."/"..lvs[level].."]: "..msg.."\n"
end

function ftbl:flush()
    self.flhndl.write(lgstr)
    self.flhndl.flush()
end

function ftbl:stop()
    self.flhndl.write(lgstr)
    self.flhndl.close()
end

return api