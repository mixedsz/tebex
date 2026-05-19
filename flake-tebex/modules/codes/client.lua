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
        {type = 'input', label = 'Code', description = 'Format - TBX-XXXXX', required = true, min = 8, max = 15},
    })

    lib.closeInputDialog()

    if not input then return end

    local code = input[1]

    if not code then
        return
    end

    TriggerServerEvent('flake-tebex:RedeemCode', code)
end

-- Config is now loaded from config/packages.lua