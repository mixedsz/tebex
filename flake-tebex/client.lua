-- /redeem — players type this after completing a Tebex purchase.
-- An ox_lib input dialog asks for the transaction code from their
-- purchase confirmation email (e.g. tbx-xxxxxxxxxxxxxxxxxxxxxxxx).

RegisterCommand('redeem', function()
    local input = lib.inputDialog('Tebex Redeem', {
        {
            type        = 'input',
            label       = 'Transaction Code',
            description = 'Enter the transaction code from your Tebex purchase confirmation email.',
            placeholder = 'tbx-xxxxxxxxxxxxxxxxxxxxxxxx',
            required    = true,
            min         = 4,
            max         = 64,
        },
    })

    if not input or not input[1] or input[1] == '' then return end

    local code = input[1]:gsub('%s+', '')

    lib.notify({
        title       = 'Tebex',
        description = 'Verifying your code, please wait...',
        type        = 'inform',
        duration    = 4000,
    })

    TriggerServerEvent('flake-tebex:RedeemTransaction', code)
end, false)

RegisterNetEvent('flake-tebex:Notify', function(msg, notifType)
    lib.notify({
        title       = 'Tebex',
        description = msg,
        type        = notifType or 'inform',
        duration    = 7000,
    })
end)
