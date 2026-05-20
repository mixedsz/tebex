RegisterNetEvent('flake-tebex:CopyToClipboard', function(codes)
    if not codes or #codes == 0 then
        return
    end

    local clipboardVal = ''

    for k, v in ipairs(codes) do
        clipboardVal = clipboardVal .. v .. '\t\n'
    end

    lib.setClipboard(clipboardVal)
    lib.notify({
        description = 'Copied codes to clipboard',
        type = 'success'
    })
end)

RegisterNetEvent('flake-tebex:OpenCodeRedeem', function()
    OpenRedeemDialog()
end)

function OpenRedeemDialog()
    local input = lib.inputDialog('Redeem a Code', {
        {type = 'input', label = 'Code', description = 'TBX-XXXXX code or Tebex order ID (tbx-...)', required = true, min = 8, max = 50},
    })

    lib.closeInputDialog()

    if not input then return end

    local code = input[1]
    if not code then return end

    -- A Tebex order ID has 2+ dashes (e.g. tbx-32713926a4571-6ded32); a TBX code has exactly 1 (TBX-XXXXX)
    local _, dashCount = code:gsub('-', '')
    if dashCount >= 2 and code:lower():sub(1, 4) == 'tbx-' then
        TriggerServerEvent('flake-tebex:RedeemTebexOrder', code:lower())
    else
        TriggerServerEvent('flake-tebex:RedeemCode', code)
    end
end

-- Config is now loaded from config/packages.lua