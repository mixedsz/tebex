-- Flake Tebex Discord Webhook Module
-- This module handles Discord webhook integration for the Tebex system

local RESOURCE_NAME = GetCurrentResourceName()

-- Ensure Config.Discord exists
if not Config then
   -- print('[Flake Tebex] ERROR: Config is nil in Discord webhook module')
    Config = {}
end

-- For backward compatibility, also check the JSON config
local function LoadWebhookConfig()
    local configFile = LoadResourceFile(RESOURCE_NAME, "discord_webhook_config.json")
    if configFile then
        local loadedConfig = json.decode(configFile)
        if loadedConfig then
          --  print('[Flake Tebex] Found Discord webhook JSON config, loading values')

            -- Initialize Config.Discord if it doesn't exist
            if not Config.Discord then
                Config.Discord = {}
            end

            -- Merge loaded config with Config.Discord
            for k, v in pairs(loadedConfig) do
                if k == "colors" and type(v) == "table" then
                    Config.Discord.colors = v
                else
                    Config.Discord[k] = v
                end
            end
        end
    else
     --   print('[Flake Tebex] WARNING: discord_webhook_config.json not found, using default values')

        -- Set default configuration if needed
        if not Config.Discord then
            Config.Discord = {
                enabled = true,
                webhook_url = "https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz",
                colors = {
                    package_created = 5793266,   -- Light Green
                    package_claimed = 5763719,   -- Green
                    code_created = 7419530,      -- Purple
                    code_redeemed = 2067276      -- Cyan
                },
                botName = "Flake Tebex",
                botAvatar = ""
            }
        end
    end
end

-- Function to send webhook message
local function SendWebhook(data)
    if not Config.Discord or not Config.Discord.enabled then
      --  print("[Flake Tebex] Discord webhook is disabled")
        return
    end

    if not Config.Discord.webhook_url or Config.Discord.webhook_url == "" or Config.Discord.webhook_url == "https://discord.com/api/webhooks/YOUR_WEBHOOK_URL_HERE" or Config.Discord.webhook_url == "https://discord.com/api/webhooks/1234567890/abcdefghijklmnopqrstuvwxyz" then
       -- print("[Flake Tebex] Discord webhook URL not properly configured. Please update discord_webhook_config.json")
        return
    end

    -- Set default webhook properties
    data.username = data.username or Config.Discord.botName
    data.avatar_url = data.avatar_url or Config.Discord.botAvatar

    -- Convert data to JSON and send
    PerformHttpRequest(Config.Discord.webhook_url, function(err, text, headers)
        if err ~= 200 and err ~= 204 then
          --  print("[Flake Tebex] Discord webhook error: " .. tostring(err))
        end
    end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
end

-- Function to create and send a rich embed webhook
local function SendRichWebhook(webhookType, title, description, fields, color, footer, thumbnail, image)
    -- Determine color to use
    if Config.Discord and Config.Discord.colors and Config.Discord.colors[webhookType] then
        color = color or Config.Discord.colors[webhookType]
    else
        color = color or 3447003 -- Default blue if not specified
    end

    -- Create embed
    local embed = {
        title = title,
        description = description,
        color = color,
        fields = fields or {},
        footer = footer and { text = footer } or { text = "Flake Tebex • " .. os.date("%Y-%m-%d %H:%M:%S") },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    -- Add thumbnail if provided
    if thumbnail then
        embed.thumbnail = { url = thumbnail }
    end

    -- Add image if provided
    if image then
        embed.image = { url = image }
    end

    -- Send webhook with embed
    SendWebhook({
        embeds = { embed }
    })
end

-- Function to log package creation
function LogPackageCreation(adminName, adminIdentifier, playerName, playerIdentifier, packageTitle, packageID)
    local title = "📦 Package Created"
    local description = string.format("Admin **%s** created a **%s** package for player **%s**", adminName, packageTitle, playerName)

    local fields = {
        { name = "Admin", value = adminName .. " (" .. adminIdentifier .. ")", inline = true },
        { name = "Player", value = playerName .. " (" .. playerIdentifier .. ")", inline = true },
        { name = "Package", value = packageTitle, inline = true },
        { name = "Package ID", value = packageID, inline = true },
        { name = "Date & Time", value = os.date("%B %d, %Y at %H:%M %p"), inline = false }
    }

    SendRichWebhook("package_created", title, description, fields, Config.Discord.colors.package_created)
end

-- Function to log package claiming
function LogPackageClaim(playerName, playerIdentifier, packageTitle, packageID, rewards)
    local title = "🎁 Package Claimed"
    local description = string.format("Player **%s** claimed a **%s** package", playerName, packageTitle)

    -- Format rewards text
    local rewardsText = ""
    for _, reward in ipairs(rewards) do
        if reward.type == "item" then
            rewardsText = rewardsText .. "• " .. reward.name .. " x" .. reward.amount .. "\n"
        elseif reward.type == "vehicle" then
            rewardsText = rewardsText .. "• Vehicle: " .. (reward.label or reward.model) .. "\n"
        end
    end

    local fields = {
        { name = "Player", value = playerName .. " (" .. playerIdentifier .. ")", inline = true },
        { name = "Package", value = packageTitle, inline = true },
        { name = "Package ID", value = packageID, inline = true },
        { name = "Rewards", value = rewardsText ~= "" and rewardsText or "No rewards", inline = false },
        { name = "Date & Time", value = os.date("%B %d, %Y at %H:%M %p"), inline = false }
    }

    SendRichWebhook("package_claimed", title, description, fields, Config.Discord.colors.package_claimed)
end

-- Function to log code generation
function LogCodeGeneration(adminName, adminIdentifier, item, amount, codes)
    local title = "🔑 Codes Generated"
    local description = string.format("Admin **%s** generated **%d** codes for **%s**", adminName, #codes, item)

    -- Format codes text (limit to 10 codes if there are many)
    local codesText = ""
    local maxCodesToShow = 10
    for i = 1, math.min(#codes, maxCodesToShow) do
        codesText = codesText .. "• " .. codes[i] .. "\n"
    end

    if #codes > maxCodesToShow then
        codesText = codesText .. "• ... and " .. (#codes - maxCodesToShow) .. " more"
    end

    local fields = {
        { name = "Admin", value = adminName .. " (" .. adminIdentifier .. ")", inline = true },
        { name = "Reward", value = item .. " x" .. amount, inline = true },
        { name = "Number of Codes", value = tostring(#codes), inline = true },
        { name = "Codes", value = codesText, inline = false },
        { name = "Date & Time", value = os.date("%B %d, %Y at %H:%M %p"), inline = false }
    }

    SendRichWebhook("code_created", title, description, fields, Config.Discord.colors.code_created)
end

-- Function to log code redemption
function LogCodeRedemption(playerName, playerIdentifier, code, rewardName, rewardAmount)
    local title = "✅ Code Redeemed"
    local description = string.format("Player **%s** redeemed code **%s**", playerName, code)

    local fields = {
        { name = "Player", value = playerName .. " (" .. playerIdentifier .. ")", inline = true },
        { name = "Code", value = code, inline = true },
        { name = "Reward", value = rewardName .. " x" .. rewardAmount, inline = true },
        { name = "Date & Time", value = os.date("%B %d, %Y at %H:%M %p"), inline = false }
    }

    SendRichWebhook("code_redeemed", title, description, fields, Config.Discord.colors.code_redeemed)
end

-- Initialize webhook system
LoadWebhookConfig()

-- Print debug info
--print('[Flake Tebex] Discord webhook system initialized')
--print('[Flake Tebex] Discord webhook URL: ' .. (Config.Discord and Config.Discord.webhook_url or "Not configured"))
--print('[Flake Tebex] Discord webhook enabled: ' .. tostring(Config.Discord and Config.Discord.enabled or false))

-- Debug colors
if Config.Discord and Config.Discord.colors then
    --print('[Flake Tebex] Discord webhook colors:')
    for k, v in pairs(Config.Discord.colors) do
        --print('  - ' .. k .. ': ' .. tostring(v))
    end
else
    --print('[Flake Tebex] WARNING: Discord webhook colors not configured')
end

-- Register events for webhook logging
RegisterNetEvent('flake-discord:PackageCreation', function(adminName, adminIdentifier, playerName, playerIdentifier, packageTitle, packageID)
    LogPackageCreation(adminName, adminIdentifier, playerName, playerIdentifier, packageTitle, packageID)
end)

RegisterNetEvent('flake-discord:PackageClaim', function(playerName, playerIdentifier, packageTitle, packageID, rewards)
    LogPackageClaim(playerName, playerIdentifier, packageTitle, packageID, rewards)
end)

RegisterNetEvent('flake-discord:CodeGeneration', function(adminName, adminIdentifier, item, amount, codes)
    LogCodeGeneration(adminName, adminIdentifier, item, amount, codes)
end)

RegisterNetEvent('flake-discord:CodeRedemption', function(playerName, playerIdentifier, code, rewardName, rewardAmount)
    LogCodeRedemption(playerName, playerIdentifier, code, rewardName, rewardAmount)
end)

-- Export functions
exports('LogPackageCreation', LogPackageCreation)
exports('LogPackageClaim', LogPackageClaim)
exports('LogCodeGeneration', LogCodeGeneration)
exports('LogCodeRedemption', LogCodeRedemption)
