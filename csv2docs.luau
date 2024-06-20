-- Written by @nazuh on discord

--
--------------------------------------------------------------------------------
--         FILE:  csv2docs.luau
--        USAGE:  lune run csv2docs.luau
--  DESCRIPTION:  Converts CSV Files in the /games directory to markdown for display
--      OPTIONS:  ---
-- REQUIREMENTS:  lune https://lune-org.github.io/docs
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  Nazuh (@nazuh), itsnazuh@gmail.com
--      COMPANY:  ---
--      VERSION:  1.0
--      CREATED:  June 19th 2024
--     REVISION:  ---
--------------------------------------------------------------------------------
--

-- // Imports
local fs = require('@lune/fs')
local regex = require('@lune/regex')
local net = require('@lune/net')

-- // Constants
local CSV_FILES_DIRECTORY = 'games'
local OUTPUT_DIRECTORY = 'docs/By Genre'
local INVALIDLINE_REGEX = regex.new('^\\s*$')

-- // Runtime
local DirectoryExists = fs.isDir(CSV_FILES_DIRECTORY)
if not DirectoryExists then
    warn('Directory "games" in doesn\'t exist the current working directory!')
    return
end

-- / Load .env file
local EnvExists = fs.isFile('.env')
if not EnvExists then
    warn('A .env file must exist in the current working directory!')
    return
end

local ENVFileContent = fs.readFile('.env')
local ROBLOSECURITY = ENVFileContent:split('\n')[1]:gsub('.ROBLOSECURITY=', '')

-- / Decipher csv files
local OutputFilePath, OutputContent

for Index, CSVFileName: string in fs.readDir(CSV_FILES_DIRECTORY) do
    local RealPath = CSV_FILES_DIRECTORY .. '/' .. CSVFileName
    if not fs.isFile(RealPath) then
        warn('The given path is not a file! path:', RealPath)
        continue
    end

    local FileContent: string = fs.readFile(RealPath)
    if not FileContent then
        warn('Failed to read file at path! path:', RealPath)
        continue
    end

    -- Decipher CSV Content
    --[[
        ? - means value is optional

        Expected Setup:
        Game Name, Game Description, Direct Game Link, Direct Group Link?
    ]]
    print('Deciphering File:', CSVFileName)
    print('File\'s Input Path:', RealPath)

    -- setup output file content
    OutputFilePath = OUTPUT_DIRECTORY .. '/' .. CSVFileName:sub(1, #CSVFileName - 4) .. '.md'
    print('File\'s Output Path:', OutputFilePath .. '\n')
    OutputContent = '<div class="grid cards" markdown>\n'

    local Lines = FileContent:split('\n')

    local function IsValidLine(Line: string): boolean
        return INVALIDLINE_REGEX:isMatch(Line) == false
    end

    for _, Line in Lines do
        if not IsValidLine(Line) then
            print('Recieved invalid line:', _, Line)
            continue
        end

        -- gets game's asset id
        local AssetId = Line:gsub('https://www.roblox.com/games/', ''):split('/')[1]
        local UniverseId = nil
        -- print('AssetId:', AssetId)

        local GameName, GameDesc = 'Unknown Game', ''
        do -- Get Game Name + Desc
            local Query = 'https://games.roblox.com/v1/games/multiget-place-details?placeIds=' .. AssetId
            local Response = net.request({
                url = Query,
                method = 'GET',
                headers = {
                    ['Content-Type'] = 'application/json',
                    -- ['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
                    ['Cookie'] = '.ROBLOSECURITY=' .. ROBLOSECURITY ..';'
                }
            })

            local Body = net.jsonDecode(Response.body)
            if Response.ok then
                GameName = Body[1].name
                -- GameDesc = Body[1].description
                -- Setup game desc
                local GameDescLines = Body[1].description:split('\n')

                for _Index, _Line in GameDescLines do
                    if _Index ~= 1 then
                        GameDesc ..= '\n'
                    end
                    GameDesc ..= '\t' .. _Line
                end

                UniverseId = Body[1].universeId
            else
                warn('Line:', _, 'Failed to get game name and game description for game:', Line)
            end
        end

        OutputContent ..= '\n- ## **' .. GameName .. '**'
        -- // Get Game image
        if UniverseId then
            local Query = `https://thumbnails.roblox.com/v1/games/icons?universeIds={UniverseId}&returnPolicy=PlaceHolder&size=128x128&format=Png&isCircular=false`
            local Response = net.request({
                url = Query,
                method = 'GET',
                headers = {
                    ['Content-Type'] = 'application/json',
                    ['size'] = '256x256'
                }
            })

            local Body = net.jsonDecode(Response.body)
            if Response.ok then
                local ImageUrl = Body.data[1].imageUrl

                OutputContent ..= `\n\n\t![GameIcon]({ImageUrl})` .. '{ align=right }'
            end
        end

        local IsOver200Chars = #GameDesc > 200
        OutputContent ..= '\n' .. GameDesc:gsub('# ', ''):sub(1, 200) .. (if IsOver200Chars then '...' else '')
        OutputContent ..= '\n\n\t---'

        -- // Setup Buttons

        -- Game Button
        OutputContent ..= `\n\t[Play]({Line:sub(1, #Line - 1)})` .. '{ .md-button .md-button--primary target="_blank" }'
        
        -- Creator Button
        -- commented out as im not sure of a way to differentiate between the creator being a group or user
        -- OutputContent ..= `\n\t[Creator]({Line:sub(1, #Line - 1)})` .. '{ .md-button .md-button--primary target="_blank" }'
        
        OutputContent ..= '\n'
    end

    OutputContent ..= '\n</div>'
    fs.writeFile(OutputFilePath, OutputContent)
end