-- Flake Tebex Packages Configuration
-- This file contains all package configurations

-- Initialize Config globally
Config = {}

-- Package configurations
Config.Packages = {
    {
        title = "Diamond Package",
        included_text = {
            "$1,000,000 Money",
            "Two Supporter Car",
            "x3 Ultimate Bundles",
        },
        included_rewards = {
            {
                label = "Select a vehicle",
                placeholder = "Choose a vehicle",
                option = {
                    {
                        model = "a1hellcat", label = "Hellcat", type = 'vehicle'
                    },
                    {
                        model = "a1chrysler", label = "Crysler", type = 'vehicle'
                    },
                    {
                        model = "a1jeep", label = "TrackHawk", type = 'vehicle'
                    },
                }
            },
            {
                label = "Select a vehicle",
                placeholder = "Choose a vehicle",
                option = {
                    {
                        model = "a1hellcat", label = "Hellcat", type = 'vehicle'
                    },
                    {
                        model = "a1chrysler", label = "Crysler", type = 'vehicle'
                    },
                    {
                        model = "a1jeep", label = "TrackHawk", type = 'vehicle'
                    },
                }
            },
            {
                type = "item", name = 'money', amount = 1000000
            },
            {
                type = "item", name = 'xmasbundle', amount = 3
            },
        }
    },
    {
        title = "Gold Package",
        included_text = {
            "$500,000 Money",
            "One Supporter Car",
            "x2 Ultimate Drops",
        },
        included_rewards = {
            {
                label = "Select a vehicle",
                placeholder = "Choose a vehicle",
                option = {
                    {
                        model = "adder", label = "Adder", type = 'vehicle'
                    },
                    {
                        model = "panto", label = "Panto", type = 'vehicle'
                    },
                    {
                        model = "phantom", label = "Phantom", type = 'vehicle'
                    },
                }
            },
            {
                type = "item", name = 'money', amount = 500000
            },
            {
                type = "item", name = 'ultimate_drop', amount = 2
            },
        }
    },
    {
        title = "Silver Package",
        included_text = {
            "$250,000 Money",
            "x1 Ultimate Drop",
        },
        included_rewards = {
            {
                type = "item", name = 'money', amount = 250000
            },
            {
                type = "item", name = 'ultimate_drop', amount = 1
            },
        }
    },
    {
        title = "Bronze Package",
        included_text = {
            "$100,000 Money",
        },
        included_rewards = {
            {
                type = "item", name = 'money', amount = 100000
            },
        }
    }
}

-- Tebex API configuration
-- Get your secret key from: Tebex Dashboard > Your Store > Game Servers > Secret Key
Config.Tebex = {
    enabled = true,
    secret_key = "YOUR_TEBEX_SECRET_KEY",
}

-- Print debug info
--print('[Flake Tebex] Config.Packages initialized with ' .. #Config.Packages .. ' packages')
--print('[Flake Tebex] Package titles:')
for i, pkg in ipairs(Config.Packages) do
   -- print('  - ' .. i .. ': ' .. pkg.title)
end
