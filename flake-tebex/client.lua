-- flake Tebex Client Script
-- This script handles the client-side functionality for the Tebex store integration

-- Event to show available packages
RegisterNetEvent('flake-tebex:ShowPackages', function(packages)
    if not packages or #packages == 0 then
        lib.notify({
            title = 'No Packages',
            description = 'You don\'t have any packages to claim',
            type = 'error'
        })
        return
    end

    -- Format packages for menu
    local menuItems = {}
    for _, pkg in ipairs(packages) do
        table.insert(menuItems, {
            title = pkg.title,
            description = 'Package ID: ' .. pkg.id,
            onSelect = function()
                TriggerServerEvent('flake-tebex:GetPackageDetails', pkg.id)
            end
        })
    end

    -- Show menu
    lib.registerContext({
        id = 'tebex_packages_menu',
        title = 'Your Packages',
        options = menuItems
    })

    lib.showContext('tebex_packages_menu')
end)

-- Event to show package details
RegisterNetEvent('flake-tebex:ShowPackageDetails', function(packageID, packageData)
    if not packageData then return end

   -- print("[flake Tebex] Showing package details for: " .. packageID)
   -- print("[flake Tebex] Package title: " .. packageData.title)

    -- Format included items for display
    local includedText = ''
    for _, text in ipairs(packageData.included_text) do
        includedText = includedText .. '• ' .. text .. '\n'
    end

    -- Check if there are selectable options
    local hasOptions = false
    local optionMenus = {}

   -- print("[flake Tebex] Checking for selectable options...")
   -- print("[flake Tebex] Number of rewards: " .. #packageData.included_rewards)

    for i, reward in ipairs(packageData.included_rewards) do
       -- print("[flake Tebex] Checking reward " .. i)
        if reward.option then
           -- print("[flake Tebex] Found selectable option: " .. (reward.label or "Unnamed"))
            hasOptions = true

            -- Create option menu
            local options = {}
            for j, option in ipairs(reward.option) do
               -- print("[flake Tebex] Adding option: " .. (option.label or option.model))
                table.insert(options, {
                    value = option.model,
                    label = option.label .. " (" .. option.model .. ")"
                })
            end

            table.insert(optionMenus, {
                type = 'select',
                label = reward.label,
                description = reward.placeholder or 'Select an option',
                options = options,
                required = true
            })
        else
           -- print("[flake Tebex] Reward " .. i .. " is not selectable")
        end
    end

    if hasOptions then
       -- print("[flake Tebex] Package has selectable options, showing selection dialog")
        -- Show selection menu first
        local inputs = lib.inputDialog('Select Package Options', optionMenus)

        if not inputs then
          --  print("[flake Tebex] User cancelled selection")
            return
        end

       -- print("[flake Tebex] User made selections: " .. json.encode(inputs))

        -- Confirm selection
        local selectedOptions = {}
        local selectionText = 'Selected options:\n'

        for i, selection in ipairs(inputs) do
            table.insert(selectedOptions, selection)

            -- Find the label for this selection
            for _, option in ipairs(optionMenus[i].options) do
                if option.value == selection then
                    selectionText = selectionText .. '• ' .. option.label .. '\n'
                    break
                end
            end
        end

        -- Show confirmation dialog
        local confirm = lib.alertDialog({
            header = 'Confirm Package Claim',
            content = 'Package: ' .. packageData.title .. '\n\n' .. includedText .. '\n' .. selectionText,
            cancel = true
        })

        if confirm == 'confirm' then
            --print("[flake Tebex] User confirmed package claim with selections")
            TriggerServerEvent('flake-tebex:ClaimPackage', packageID, selectedOptions)
        else
            --print("[flake Tebex] User cancelled package claim")
        end
    else
       -- print("[flake Tebex] Package has no selectable options, showing confirmation dialog")
        -- No options, just confirm
        local confirm = lib.alertDialog({
            header = 'Confirm Package Claim',
            content = 'Package: ' .. packageData.title .. '\n\n' .. includedText,
            cancel = true
        })

        if confirm == 'confirm' then
            --print("[flake Tebex] User confirmed package claim")
            TriggerServerEvent('flake-tebex:ClaimPackage', packageID, {})
        else
           -- print("[flake Tebex] User cancelled package claim")
        end
    end
end)

-- Register command for opening packages menu
RegisterCommand('packages', function()
    TriggerServerEvent('flake-tebex:GetPackages')
end, false)

-- Register key binding for packages menu
RegisterKeyMapping('packages', 'Open packages menu', 'keyboard', 'F7')

-- Initialize
print('[flake Tebex] Client initialized')