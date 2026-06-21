function DebugPrint(...)
    if not Config.debug then return end
    local msg = {}
    for _, v in ipairs({ ... }) do
        msg[#msg + 1] = tostring(v)
    end
    print('^6[METEO DEMOSERVICE]^0 ' .. table.concat(msg, ', '))
end

function toBool(val, default)
    if val == nil then return default end
    if val == true or val == 1 or val == '1' then return true end
    if val == false or val == 0 or val == '0' then return false end
    return default
end
