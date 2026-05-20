-- Flake Tebex Server Script
-- This script handles the server-side functionality for the Tebex store integration

-- Dependencies
local MySQL = MySQL or exports.oxmysql
local Discord = exports[GetCurrentResourceName()]

-- Load framework compatibility layer
local Framework
local RESOURCE_NAME = GetCurrentResourceName()
local frameworkFile = LoadResourceFile(RESOURCE_NAME, "framework.lua")
if frameworkFile then
    local loadFramework, err = load(frameworkFile, 'framework.lua')
    if loadFramework then
        Framework = loadFramework()
    else
        print('[flake Tebex] ERROR: Failed to load framework.lua: ' .. tostring(err))
        Framework = {} -- Create empty framework to prevent errors
    end
else
    print('[flake Tebex] ERROR: framework.lua not found')
    Framework = {} -- Create empty framework to prevent errors
end

-- Local variables
local PACKAGES_DATA = {}
local PLAYER_PACKAGES = {}
local REDEEMED_ORDERS = {}
local TEBEX_ORDER_COOLDOWN = {}

-- Load Config from config/packages.lua
-- Config is loaded via shared_scripts in fxmanifest.lua

-- Ensure Config is properly initialized
if not Config then
    print('[flake Tebex] ERROR: Config is nil, initializing empty table')
    Config = {}
end

if not Config.Packages then
   -- print('[flake Tebex] WARNING: Config.Packages is nil, initializing empty table')
    Config.Packages = {}

    -- Try to load the config file directly
    local configFile = LoadResourceFile(RESOURCE_NAME, "config/packages.lua")
    if configFile then
       -- print('[flake Tebex] Found config file, attempting to load manually')

        -- Create a temporary function to load the config
        local loadConfig = load(configFile)
        if loadConfig then
            -- Execute the config file
            loadConfig()
            --print('[flake Tebex] Config file loaded manually')
        else
           -- print('[flake Tebex] Failed to load config file')
        end
    else
        --print('[flake Tebex] Config file not found')
    end
end

-- Debug: Print Config to verify it's loaded correctly
--print('[flake Tebex] Config loaded. Type: ' .. type(Config))
if type(Config) == "table" then
    --print('[flake Tebex] Config.Packages type: ' .. type(Config.Packages))
    if type(Config.Packages) == "table" then
        --print('[flake Tebex] Config.Packages count: ' .. #Config.Packages)

        -- Print all packages for debugging
        for i, pkg in ipairs(Config.Packages) do
            --print('[flake Tebex] Package ' .. i .. ': ' .. (pkg.title or "No title"))
        end
    else
        --print('[flake Tebex] Config.Packages is not a table')
    end
else
    --print('[flake Tebex] Config is not a table')
end

-- Initialize packages data
local function InitializePackages()
    local packagesFile = LoadResourceFile(RESOURCE_NAME, "packages.json")
    if packagesFile then
        PACKAGES_DATA = json.decode(packagesFile) or {}
    else
        PACKAGES_DATA = {}
        SaveResourceFile(RESOURCE_NAME, "packages.json", json.encode(PACKAGES_DATA, {indent=true}), -1)
    end

    -- Load player packages data
    local playerPackagesFile = LoadResourceFile(RESOURCE_NAME, "player_packages.json")
    if playerPackagesFile then
        PLAYER_PACKAGES = json.decode(playerPackagesFile) or {}
    else
        PLAYER_PACKAGES = {}
        SaveResourceFile(RESOURCE_NAME, "player_packages.json", json.encode(PLAYER_PACKAGES, {indent=true}), -1)
    end

    -- Load redeemed Tebex orders
    local redeemedOrdersFile = LoadResourceFile(RESOURCE_NAME, "redeemed_orders.json")
    if redeemedOrdersFile then
        REDEEMED_ORDERS = json.decode(redeemedOrdersFile) or {}
    else
        REDEEMED_ORDERS = {}
        SaveResourceFile(RESOURCE_NAME, "redeemed_orders.json", json.encode(REDEEMED_ORDERS, {indent=true}), -1)
    end
end

-- Save packages data
local function SavePackagesData()
    SaveResourceFile(RESOURCE_NAME, "packages.json", json.encode(PACKAGES_DATA, {indent=true}), -1)
end

-- Save player packages data
local function SavePlayerPackagesData()
    SaveResourceFile(RESOURCE_NAME, "player_packages.json", json.encode(PLAYER_PACKAGES, {indent=true}), -1)
end

-- Save redeemed Tebex orders
local function SaveRedeemedOrders()
    SaveResourceFile(RESOURCE_NAME, "redeemed_orders.json", json.encode(REDEEMED_ORDERS, {indent=true}), -1)
end

-- Generate a unique package ID
local function GeneratePackageID()
    local id = "PKG-" .. math.random(100000, 999999)
    if PACKAGES_DATA[id] then
        return GeneratePackageID()
    end
    return id
end

-- Check if player has a package
local function HasPlayerPackage(identifier, packageID)
    if not PLAYER_PACKAGES[identifier] then
        return false
    end

    for _, pkg in ipairs(PLAYER_PACKAGES[identifier]) do
        if pkg.id == packageID then
            return true
        end
    end

    return false
end

-- Add package to player
local function AddPackageToPlayer(identifier, packageID, packageData)
    if not PLAYER_PACKAGES[identifier] then
        PLAYER_PACKAGES[identifier] = {}
    end

    table.insert(PLAYER_PACKAGES[identifier], {
        id = packageID,
        title = packageData.title,
        claimed = false,
        claimedAt = nil,
        rewards = {},
        createdAt = os.time()
    })

    SavePlayerPackagesData()
end

-- Mark package as claimed
local function MarkPackageAsClaimed(identifier, packageID, rewards)
    if not PLAYER_PACKAGES[identifier] then
        return false
    end

    for i, pkg in ipairs(PLAYER_PACKAGES[identifier]) do
        if pkg.id == packageID then
            PLAYER_PACKAGES[identifier][i].claimed = true
            PLAYER_PACKAGES[identifier][i].claimedAt = os.time()
            PLAYER_PACKAGES[identifier][i].rewards = rewards
            SavePlayerPackagesData()
            return true
        end
    end

    return false
end

-- Get package by ID
local function GetPackageByID(packageID)
    return PACKAGES_DATA[packageID]
end

-- Get package from config by title
local function GetPackageFromConfigByTitle(title)
    -- Check if Config and Config.Packages exist
    if not Config then
       -- print("[flake Tebex] ERROR: Config is nil")
        return nil
    end

    if not Config.Packages then
        --print("[flake Tebex] ERROR: Config.Packages is nil")

        -- Try to reload the config file directly
        local configFile = LoadResourceFile(RESOURCE_NAME, "config/packages.lua")
        if configFile then
           -- print('[flake Tebex] Found config file, attempting to load manually')

            -- Create a temporary function to load the config
            local loadConfig = load(configFile)
            if loadConfig then
                -- Execute the config file
                loadConfig()
               -- print('[flake Tebex] Config file loaded manually')
            else
               -- print('[flake Tebex] Failed to load config file')
                return nil
            end
        else
          --  print('[flake Tebex] Config file not found')
            return nil
        end

        -- If still nil after reload attempt, return nil
        if not Config.Packages then
          --  print("[flake Tebex] Config.Packages is still nil after reload attempt")
            return nil
        end
    end

  --  print("[flake Tebex] Config type: " .. type(Config))
  --  print("[flake Tebex] Config.Packages type: " .. type(Config.Packages))
  --  print("[flake Tebex] Looking for package: " .. tostring(title))

    -- Try to get the count safely
    local count = 0
    if type(Config.Packages) == "table" then
        count = #Config.Packages
    end
  --  print("[flake Tebex] Config.Packages count: " .. count)

    -- Print all available packages for debugging
 --   print("[flake Tebex] Available packages:")
    if type(Config.Packages) == "table" then
        for i, pkg in ipairs(Config.Packages) do
            if type(pkg) == "table" and pkg.title then
               -- print("  - " .. i .. ": " .. tostring(pkg.title))
            else
              --  print("  - " .. i .. ": Invalid package format")
            end
        end
    else
      --  print("  No packages available - Config.Packages is not a table")
    end

    -- First try exact match (case insensitive)
    local titleLower = string.lower(title)
    for _, pkg in ipairs(Config.Packages) do
        if string.lower(pkg.title) == titleLower then
           -- print("[flake Tebex] Found exact match package: " .. pkg.title)
            return pkg
        end
    end

    -- If exact match fails, try if the input is a substring of any package title
    for _, pkg in ipairs(Config.Packages) do
        if string.find(string.lower(pkg.title), titleLower) then
           -- print("[flake Tebex] Found package by substring match: " .. pkg.title)
            return pkg
        end
    end

    -- If that fails, try if any package title is a substring of the input
    for _, pkg in ipairs(Config.Packages) do
        if string.find(titleLower, string.lower(pkg.title)) then
           -- print("[flake Tebex] Found package where package title is substring of input: " .. pkg.title)
            return pkg
        end
    end

    -- If all else fails, try to match the first word
    local firstWord = titleLower:match("^(%S+)")
    if firstWord then
        for _, pkg in ipairs(Config.Packages) do
            if string.lower(pkg.title):match("^" .. firstWord) then
               -- print("[flake Tebex] Found package by first word match: " .. pkg.title)
                return pkg
            end
        end
    end

   -- print("[flake Tebex] Package not found: " .. title)
    return nil
end

-- Give rewards to player
local function GiveRewardsToPlayer(source, rewards)
    local player = Framework.GetPlayer(source)
    if not player then return false end

   -- print("[flake Tebex] Giving rewards to player: " .. GetPlayerName(source))
   -- print("[flake Tebex] Number of rewards: " .. #rewards)

    for i, reward in ipairs(rewards) do
       -- print("[flake Tebex] Processing reward " .. i .. ": Type = " .. (reward.type or "nil"))

        if reward.type == "item" then
           -- print("[flake Tebex] Giving item: " .. reward.name .. " x" .. reward.amount)
            Framework.AddItem(player, reward.name, reward.amount)
        elseif reward.type == "vehicle" then
          --  print("[flake Tebex] Giving vehicle: " .. reward.model)

            -- Generate a random plate
            local plate = GenerateRandomPlate()
            local vehicleName = reward.label or reward.model

            -- Use the framework's vehicle addition function
            Framework.AddVehicle(player, reward.model, plate, vehicleName, source)
        end
    end

    return true
end

-- Generate a random license plate
function GenerateRandomPlate()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local plate = ""

    for i = 1, 8 do
        local rand = math.random(1, #chars)
        plate = plate .. string.sub(chars, rand, rand)
    end

    return plate
end

-- Event to redeem a Tebex order by transaction ID (e.g. tbx-32713926a4571-6ded32)
RegisterNetEvent('flake-tebex:RedeemTebexOrder', function(transactionId)
    local source = source

    if not transactionId or not transactionId:match('^tbx%-[%w]+%-[%w]+$') then
        lib.notify(source, { title = 'Tebex', description = 'Invalid transaction ID format.', type = 'error' })
        return
    end

    -- Cooldown: prevent spam (5 seconds)
    if TEBEX_ORDER_COOLDOWN[source] and os.time() - TEBEX_ORDER_COOLDOWN[source] <= 5 then
        return
    end
    TEBEX_ORDER_COOLDOWN[source] = os.time()

    -- Prevent double redemption
    if REDEEMED_ORDERS[transactionId] then
        lib.notify(source, { title = 'Tebex', description = 'This order has already been redeemed!', type = 'error' })
        return
    end

    local player = Framework.GetPlayer(source)
    if not player then return end

    -- Check Tebex config
    if not Config.Tebex or not Config.Tebex.enabled then
        lib.notify(source, { title = 'Tebex', description = 'Tebex integration is not enabled. Contact an admin.', type = 'error' })
        return
    end

    local secretKey = Config.Tebex.secret_key
    if not secretKey or secretKey == "YOUR_TEBEX_SECRET_KEY" then
        lib.notify(source, { title = 'Tebex', description = 'Tebex is not configured. Contact an admin.', type = 'error' })
        return
    end

    lib.notify(source, { title = 'Tebex', description = 'Verifying your code, please wait...', type = 'inform' })

    local identifier = Framework.GetIdentifier(player)

    PerformHttpRequest("https://plugin.tebex.io/payments/" .. transactionId, function(statusCode, responseText, headers)
        -- Player may have disconnected during async request
        if not GetPlayerName(source) then return end

        if statusCode == 200 then
            local data = json.decode(responseText)
            if not data then
                lib.notify(source, { title = 'Tebex', description = 'Failed to process order response.', type = 'error' })
                return
            end

            -- Verify the order status is Complete
            local statusData = data.status
            local isComplete = false
            if type(statusData) == 'table' then
                isComplete = statusData.id == 1 or statusData.description == "Complete"
            elseif type(statusData) == 'number' then
                isComplete = statusData == 1
            elseif type(statusData) == 'string' then
                isComplete = statusData == "Complete"
            end

            if not isComplete then
                lib.notify(source, { title = 'Tebex', description = 'Order is not complete or has been refunded.', type = 'error' })
                return
            end

            -- Match Tebex packages to local config and create them for the player
            local packagesGiven = 0
            for _, pkg in ipairs(data.packages or {}) do
                local configPkg = GetPackageFromConfigByTitle(pkg.name or "")
                if configPkg then
                    local packageID = GeneratePackageID()
                    PACKAGES_DATA[packageID] = {
                        title = configPkg.title,
                        included_text = configPkg.included_text,
                        included_rewards = configPkg.included_rewards,
                        createdAt = os.time()
                    }
                    SavePackagesData()
                    AddPackageToPlayer(identifier, packageID, PACKAGES_DATA[packageID])
                    packagesGiven = packagesGiven + 1
                end
            end

            -- Record this order so it cannot be redeemed again
            REDEEMED_ORDERS[transactionId] = { identifier = identifier, redeemedAt = os.time() }
            SaveRedeemedOrders()

            if packagesGiven > 0 then
                lib.notify(source, { title = 'Tebex', description = 'Order verified! Use /mypackages to claim your rewards.', type = 'success' })
            else
                lib.notify(source, { title = 'Tebex', description = 'Order verified but no matching packages found. Contact an admin.', type = 'warning' })
            end

        elseif statusCode == 403 then
            lib.notify(source, { title = 'Tebex', description = 'Could not reach Tebex right now, try again shortly. (HTTP 403)', type = 'error' })
        elseif statusCode == 404 then
            lib.notify(source, { title = 'Tebex', description = 'Order not found. Please check your transaction ID.', type = 'error' })
        else
            lib.notify(source, { title = 'Tebex', description = 'Failed to verify order. (HTTP ' .. tostring(statusCode) .. ')', type = 'error' })
        end
    end, 'GET', '', { ['X-Tebex-Secret'] = secretKey })
end)

-- Initialize on resource start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == RESOURCE_NAME then
        -- Ensure Config is properly loaded
        if not Config or not Config.Packages or #Config.Packages == 0 then
           -- print('[flake Tebex] WARNING: Config.Packages is not properly loaded, attempting to reload')

            -- Try to load the config file directly
            local configFile = LoadResourceFile(RESOURCE_NAME, "config/packages.lua")
            if configFile then
               -- print('[flake Tebex] Found config file, attempting to load manually')

                -- Create a temporary function to load the config
                local loadConfig = load(configFile)
                if loadConfig then
                    -- Execute the config file
                    loadConfig()
                   -- print('[flake Tebex] Config file loaded manually')

                    -- Print debug info
                   -- print('[flake Tebex] Config.Packages count after reload: ' .. (Config.Packages and #Config.Packages or 0))
                    if Config.Packages then
                        for i, pkg in ipairs(Config.Packages) do
                          --  print('[flake Tebex] Package ' .. i .. ': ' .. (pkg.title or "No title"))
                        end
                    end
                else
                   -- print('[flake Tebex] Failed to load config file')
                end
            else
               -- print('[flake Tebex] Config file not found')
            end
        end

        InitializePackages()
        print('[flake Tebex] Server initialized')
    end
end)

-- Command to create a package for a player
lib.addCommand('createpackage', {
    help = 'Create a package for a player',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'Target player ID',
        },
        {
            name = 'packageTitle',
            type = 'string',
            help = 'Package title from config',
        }
    },
    restricted = 'group.admin'
}, function(source, args, raw)
    local targetPlayer = Framework.GetPlayer(args.target)
    if not targetPlayer then
        lib.notify(source, {
            title = 'Error',
            description = 'Player not found',
            type = 'error'
        })
        return
    end

    -- Default to Diamond Package if no package title is provided
    local packageTitle = args.packageTitle or "Diamond Package"
    -- print("[flake Tebex] Creating package: " .. packageTitle .. " for player ID: " .. args.target)

    local packageConfig = GetPackageFromConfigByTitle(packageTitle)
    if not packageConfig then
        -- List available packages
        local availablePackages = "Available packages:\n"
        for i, pkg in ipairs(Config.Packages) do
            availablePackages = availablePackages .. "- " .. pkg.title .. "\n"
        end

        lib.notify(source, {
            title = 'Error',
            description = 'Package not found in config: ' .. packageTitle .. '\n' .. availablePackages,
            type = 'error'
        })
        return
    end

    local packageID = GeneratePackageID()
    PACKAGES_DATA[packageID] = {
        title = packageConfig.title,
        included_text = packageConfig.included_text,
        included_rewards = packageConfig.included_rewards,
        createdAt = os.time()
    }

    SavePackagesData()
    local identifier = Framework.GetIdentifier(targetPlayer)
    AddPackageToPlayer(identifier, packageID, PACKAGES_DATA[packageID])

    lib.notify(source, {
        title = 'Success',
        description = 'Package created for player: ' .. packageID,
        type = 'success'
    })

    -- Notify the target player
    lib.notify(args.target, {
        title = 'New Package',
        description = 'You have received a new package: ' .. packageConfig.title,
        type = 'success'
    })

    -- Log the action
    local adminName = GetPlayerName(source)
    local playerName = GetPlayerName(args.target)
    local playerDetail = ("%s created package for %s"):format(adminName, playerName)

    local time = os.date("%B %d, %Y at %H:%M %p")
    local description = ("**Admin:** %s\n**Player:** %s (%s)\n**Package:** %s\n**Package ID:** %s\n**Date & Time:** %s"):format(
        adminName,
        playerName,
        identifier,
        packageConfig.title,
        packageID,
        time
    )

    -- Send to existing logging system
    TriggerEvent('flake-logs:SendCustom', "tebex_package", "Package Created", playerDetail, description)

    -- Send to Discord webhook
    local adminPlayer = Framework.GetPlayer(source)
    local adminIdentifier = Framework.GetIdentifier(adminPlayer)
    TriggerEvent('flake-discord:PackageCreation', adminName, adminIdentifier, playerName, identifier, packageConfig.title, packageID)

end)

-- Command to list player's packages
lib.addCommand('mypackages', {
    help = 'List your available packages',
}, function(source, args, raw)
    local player = Framework.GetPlayer(source)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)

    if not PLAYER_PACKAGES[identifier] or #PLAYER_PACKAGES[identifier] == 0 then
        lib.notify(source, {
            title = 'No Packages',
            description = 'You don\'t have any packages',
            type = 'error'
        })
        return
    end

    -- Send the packages to the client
    local packages = {}
    for _, pkg in ipairs(PLAYER_PACKAGES[identifier]) do
        if not pkg.claimed then
            table.insert(packages, {
                id = pkg.id,
                title = pkg.title,
                createdAt = pkg.createdAt
            })
        end
    end

    TriggerClientEvent('flake-tebex:ShowPackages', source, packages)
end)

-- Event to claim a package
RegisterNetEvent('flake-tebex:ClaimPackage', function(packageID, selectedRewards)
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)

    --print("[flake Tebex] Player " .. GetPlayerName(source) .. " is claiming package: " .. packageID)
    --print("[flake Tebex] Selected rewards: " .. json.encode(selectedRewards))

    if not HasPlayerPackage(identifier, packageID) then
        lib.notify(source, {
            title = 'Error',
            description = 'Package not found or already claimed',
            type = 'error'
        })
        return
    end

    local packageData = GetPackageByID(packageID)
    if not packageData then
        lib.notify(source, {
            title = 'Error',
            description = 'Package data not found',
            type = 'error'
        })
        return
    end

    -- Process rewards
    local finalRewards = {}

    -- Debug info
    --print("[flake Tebex] Processing package rewards")
   -- print("[flake Tebex] Package has " .. #packageData.included_rewards .. " rewards")

    -- Count how many selectable rewards we have
    local selectableRewardsCount = 0
    for _, reward in ipairs(packageData.included_rewards) do
        if reward.option then
            selectableRewardsCount = selectableRewardsCount + 1
        end
    end
    --print("[flake Tebex] Package has " .. selectableRewardsCount .. " selectable rewards")

    -- Add selected rewards
    if selectedRewards and type(selectedRewards) == 'table' then
       -- print("[flake Tebex] Processing " .. #selectedRewards .. " selected rewards")

        local selectableRewardIndex = 1
        for i, reward in ipairs(packageData.included_rewards) do
            if reward.option then
                if selectableRewardIndex <= #selectedRewards then
                    local selection = selectedRewards[selectableRewardIndex]
                 --   print("[flake Tebex] Processing selection " .. selectableRewardIndex .. ": " .. selection)

                    -- Find the matching option
                    for _, option in ipairs(reward.option) do
                        if option.model == selection then
                          --  print("[flake Tebex] Found matching option: " .. option.model)
                            table.insert(finalRewards, option)
                            break
                        end
                    end

                    selectableRewardIndex = selectableRewardIndex + 1
                end
            end
        end
    else
     --   print("[flake Tebex] No selected rewards provided")
    end

    -- Add fixed rewards
    --print("[flake Tebex] Adding fixed rewards")
    for i, reward in ipairs(packageData.included_rewards) do
        if reward.type and not reward.option then
            --print("[flake Tebex] Adding fixed reward " .. i .. ": " .. reward.type .. " - " .. (reward.name or "unnamed"))
            table.insert(finalRewards, reward)
        end
    end

   -- print("[flake Tebex] Final rewards count: " .. #finalRewards)

    -- Give rewards to player
    if GiveRewardsToPlayer(source, finalRewards) then
        -- Mark package as claimed
        if MarkPackageAsClaimed(identifier, packageID, finalRewards) then
            lib.notify(source, {
                title = 'Success',
                description = 'Package claimed successfully',
                type = 'success'
            })

            -- Log the action
            local playerName = GetPlayerName(source)
            local playerDetail = ("%s claimed package %s"):format(playerName, packageID)

            local time = os.date("%B %d, %Y at %H:%M %p")
            local rewardsText = ""
            for _, reward in ipairs(finalRewards) do
                if reward.type == "item" then
                    rewardsText = rewardsText .. reward.name .. " x" .. reward.amount .. "\n"
                elseif reward.type == "vehicle" then
                    rewardsText = rewardsText .. "Vehicle: " .. reward.model .. " (" .. reward.label .. ")\n"
                end
            end

            local description = ("**Player:** %s (%s)\n**Package:** %s\n**Package ID:** %s\n**Rewards:**\n%s\n**Date & Time:** %s"):format(
                playerName,
                identifier,
                packageData.title,
                packageID,
                rewardsText,
                time
            )

            -- Send to existing logging system
            TriggerEvent('flake-logs:SendCustom', "tebex_package", "Package Claimed", playerDetail, description)

            -- Send to Discord webhook
            TriggerEvent('flake-discord:PackageClaim', playerName, identifier, packageData.title, packageID, finalRewards)


        else
            lib.notify(source, {
                title = 'Error',
                description = 'Failed to mark package as claimed',
                type = 'error'
            })
        end
    else
        lib.notify(source, {
            title = 'Error',
            description = 'Failed to give rewards',
            type = 'error'
        })
    end
end)

-- Event to get package details
RegisterNetEvent('flake-tebex:GetPackageDetails', function(packageID)
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)

    if not HasPlayerPackage(identifier, packageID) then
        lib.notify(source, {
            title = 'Error',
            description = 'Package not found or already claimed',
            type = 'error'
        })
        return
    end

    local packageData = GetPackageByID(packageID)
    if not packageData then
        lib.notify(source, {
            title = 'Error',
            description = 'Package data not found',
            type = 'error'
        })
        return
    end

    TriggerClientEvent('flake-tebex:ShowPackageDetails', source, packageID, packageData)
end)

-- Command to check a player's packages (admin only)
lib.addCommand('checkpackages', {
    help = 'Check a player\'s packages',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'Target player ID',
        }
    },
    restricted = 'group.admin'
}, function(source, args, raw)
    local targetPlayer = Framework.GetPlayer(args.target)
    if not targetPlayer then
        lib.notify(source, {
            title = 'Error',
            description = 'Player not found',
            type = 'error'
        })
        return
    end

    local identifier = Framework.GetIdentifier(targetPlayer)

    if not PLAYER_PACKAGES[identifier] or #PLAYER_PACKAGES[identifier] == 0 then
        lib.notify(source, {
            title = 'No Packages',
            description = 'Player doesn\'t have any packages',
            type = 'error'
        })
        return
    end

    -- Format packages for display
    local packagesList = "Packages for " .. GetPlayerName(args.target) .. ":\n"
    for i, pkg in ipairs(PLAYER_PACKAGES[identifier]) do
        local status = pkg.claimed and "Claimed" or "Not Claimed"
        local date = os.date("%Y-%m-%d %H:%M", pkg.createdAt)
        packagesList = packagesList .. i .. ". " .. pkg.title .. " [" .. pkg.id .. "] - " .. status .. " - Created: " .. date .. "\n"
    end

    -- Send to admin
    TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 0},
        multiline = true,
        args = {"SYSTEM", packagesList}
    })
end)

-- Command to remove a package
lib.addCommand('removepackage', {
    help = 'Remove a package from a player',
    params = {
        {
            name = 'target',
            type = 'playerId',
            help = 'Target player ID',
        },
        {
            name = 'packageID',
            type = 'string',
            help = 'Package ID to remove',
        }
    },
    restricted = 'group.admin'
}, function(source, args, raw)
    local targetPlayer = Framework.GetPlayer(args.target)
    if not targetPlayer then
        lib.notify(source, {
            title = 'Error',
            description = 'Player not found',
            type = 'error'
        })
        return
    end

    local identifier = Framework.GetIdentifier(targetPlayer)

    if not PLAYER_PACKAGES[identifier] then
        lib.notify(source, {
            title = 'Error',
            description = 'Player has no packages',
            type = 'error'
        })
        return
    end

    local found = false
    for i, pkg in ipairs(PLAYER_PACKAGES[identifier]) do
        if pkg.id == args.packageID then
            table.remove(PLAYER_PACKAGES[identifier], i)
            found = true
            break
        end
    end

    if found then
        SavePlayerPackagesData()
        lib.notify(source, {
            title = 'Success',
            description = 'Package removed successfully',
            type = 'success'
        })

        -- Log the action
        local adminName = GetPlayerName(source)
        local playerName = GetPlayerName(args.target)
        local playerDetail = ("%s removed package from %s"):format(adminName, playerName)

        local time = os.date("%B %d, %Y at %H:%M %p")
        local description = ("**Admin:** %s\n**Player:** %s (%s)\n**Package ID:** %s\n**Date & Time:** %s"):format(
            adminName,
            playerName,
            identifier,
            args.packageID,
            time
        )

        -- Send to existing logging system
        TriggerEvent('flake-logs:SendCustom', "tebex_package", "Package Removed", playerDetail, description)


    else
        lib.notify(source, {
            title = 'Error',
            description = 'Package not found',
            type = 'error'
        })
    end
end)

-- Command to list all available package types
lib.addCommand('listpackages', {
    help = 'List all available package types',
    restricted = 'group.admin'
}, function(source, args, raw)
    local packagesList = "Available Package Types:\n"

    for i, pkg in ipairs(Config.Packages) do
        packagesList = packagesList .. i .. ". " .. pkg.title .. "\n"
        packagesList = packagesList .. "   Includes:\n"

        for _, text in ipairs(pkg.included_text) do
            packagesList = packagesList .. "   - " .. text .. "\n"
        end
    end

    -- Send to admin
    TriggerClientEvent('chat:addMessage', source, {
        color = {255, 255, 0},
        multiline = true,
        args = {"SYSTEM", packagesList}
    })

    -- Also show in console for easier copy-paste
   -- print("[flake Tebex] " .. packagesList)
end)

-- Event to get player's packages
RegisterNetEvent('flake-tebex:GetPackages', function()
    local source = source
    local player = Framework.GetPlayer(source)
    if not player then return end

    local identifier = Framework.GetIdentifier(player)

    if not PLAYER_PACKAGES[identifier] or #PLAYER_PACKAGES[identifier] == 0 then
        lib.notify(source, {
            title = 'No Packages',
            description = 'You don\'t have any packages',
            type = 'error'
        })
        return
    end

    -- Send the packages to the client
    local packages = {}
    for _, pkg in ipairs(PLAYER_PACKAGES[identifier]) do
        if not pkg.claimed then
            table.insert(packages, {
                id = pkg.id,
                title = pkg.title,
                createdAt = pkg.createdAt
            })
        end
    end

    TriggerClientEvent('flake-tebex:ShowPackages', source, packages)
end)

-- Initialize on resource start
-- Ensure Config is properly loaded
if not Config or not Config.Packages or #Config.Packages == 0 then
    --print('[flake Tebex] WARNING: Config.Packages is not properly loaded, attempting to reload')

    -- Try to load the config file directly
    local configFile = LoadResourceFile(RESOURCE_NAME, "config/packages.lua")
    if configFile then
       -- print('[flake Tebex] Found config file, attempting to load manually')

        -- Create a temporary function to load the config
        local loadConfig = load(configFile)
        if loadConfig then
            -- Execute the config file
            loadConfig()
           -- print('[flake Tebex] Config file loaded manually')

            -- Print debug info
           -- print('[flake Tebex] Config.Packages count after reload: ' .. (Config.Packages and #Config.Packages or 0))
            if Config.Packages then
                for i, pkg in ipairs(Config.Packages) do
                  --  print('[flake Tebex] Package ' .. i .. ': ' .. (pkg.title or "No title"))
                end
            end
        else
           -- print('[flake Tebex] Failed to load config file')
        end
    else
       -- print('[flake Tebex] Config file not found')
    end
end

InitializePackages()
--print('[flake Tebex] Server initialized')
